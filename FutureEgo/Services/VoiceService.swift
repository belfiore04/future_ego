import AVFoundation
import Foundation
import os

// MARK: - VoiceService

/// Manages AVAudioEngine recording (ASR input) and TTS playback.
///
/// - Recording: Captures microphone audio, converts to 16 kHz 16-bit mono PCM,
///   and streams to ASR via ``ASRWebSocketService``.
/// - Playback: Receives text, synthesizes via ``TTSWebSocketService``,
///   collects PCM audio, writes a WAV temp file, and plays via AVAudioPlayer.
@MainActor
final class VoiceService: ObservableObject {
    static let shared = VoiceService()

    // MARK: - Published State

    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var currentTranscript = ""
    @Published var errorMessage: String?

    // MARK: - Callbacks

    /// Called when ASR detects a complete sentence (sentence_end = true).
    var onSentenceComplete: ((String) -> Void)?

    // MARK: - Private Properties

    private let apiKey = "sk-a80c8b8cfc0049f49a8213120f0bd6c8"

    private var audioEngine: AVAudioEngine?
    private var asrService: ASRWebSocketService?
    private var ttsService: TTSWebSocketService?
    private var audioPlayer: AVAudioPlayer?

    /// Thread-safe flag to pause ASR while TTS is playing (accessed from audio tap thread).
    private nonisolated(unsafe) var isPausedForTTS = false

    /// Consecutive frame counter for barge-in detection (accessed from audio tap thread).
    private nonisolated(unsafe) var bargeInFrames = 0

    /// RMS threshold for barge-in detection.
    /// Float PCM samples are in [-1, 1]. Normal speech RMS ≈ 0.05-0.2.
    private static let bargeInRMSThreshold: Float = 0.08

    /// Number of consecutive frames above threshold required to trigger barge-in.
    /// Each frame ≈ 100ms, so 2 frames = ~200ms of sustained voice.
    private static let bargeInFrameCount = 2

    private init() {}

    // MARK: - Start Listening

    func startListening() {
        guard !isListening else { return }

        configureAudioSession()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        // Target ASR format: 16 kHz, 16-bit signed integer, mono
        guard let asrFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            errorMessage = "Failed to create ASR audio format"
            return
        }

        guard let converter = AVAudioConverter(from: hwFormat, to: asrFormat) else {
            errorMessage = "Failed to create audio converter"
            return
        }

        // Create and connect ASR service
        let asr = ASRWebSocketService(apiKey: apiKey)
        asr.onTranscript = { [weak self] text, isFinal in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTranscript = text
                if isFinal && !text.isEmpty {
                    self.onSentenceComplete?(text)
                    self.currentTranscript = ""
                }
            }
        }
        asr.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.errorMessage = error
            }
        }
        asr.connect()
        asrService = asr

        // Install tap on microphone input
        // Buffer size ~100ms at hardware sample rate
        let bufferSize = AVAudioFrameCount(hwFormat.sampleRate * 0.1)

        // Capture unowned reference for the realtime audio callback.
        // isPausedForTTS / bargeInFrames are nonisolated(unsafe).
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hwFormat) { [weak self, weak asr] buffer, _ in
            guard let self else { return }

            // --- Barge-in detection during TTS playback ---
            if self.isPausedForTTS {
                let rms = Self.computeRMS(buffer: buffer)
                if rms > Self.bargeInRMSThreshold {
                    self.bargeInFrames += 1
                    if self.bargeInFrames >= Self.bargeInFrameCount {
                        self.bargeInFrames = 0
                        Task { @MainActor [weak self] in
                            self?.handleBargeIn()
                        }
                    }
                } else {
                    self.bargeInFrames = 0
                }
                return
            }

            // --- Normal ASR forwarding ---
            guard let asr else { return }

            // Convert hardware format -> 16kHz mono PCM
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * 16000.0 / hwFormat.sampleRate
            )
            guard frameCapacity > 0,
                  let convertedBuffer = AVAudioPCMBuffer(
                      pcmFormat: asrFormat,
                      frameCapacity: frameCapacity
                  ) else { return }

            var error: NSError?
            var hasProvidedData = false
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if hasProvidedData {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                hasProvidedData = true
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData {
                asr.sendAudio(buffer: convertedBuffer)
            }
        }

        do {
            try engine.start()
            audioEngine = engine
            isListening = true
        } catch {
            errorMessage = "Audio engine start error: \(error.localizedDescription)"
        }
    }

    // MARK: - Stop Listening

    func stopListening() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        asrService?.disconnect()
        asrService = nil

        isListening = false
        currentTranscript = ""
    }

    // MARK: - Speak (TTS)

    /// Synthesize text to speech and play it. Pauses ASR during playback.
    func speak(_ text: String) async {
        guard !text.isEmpty else { return }

        isSpeaking = true
        isPausedForTTS = true

        let tts = TTSWebSocketService(apiKey: apiKey)
        ttsService = tts

        // Collect all audio chunks
        var audioData = Data()
        tts.onAudioData = { chunk in
            audioData.append(chunk)
        }
        tts.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.errorMessage = error
            }
        }

        await tts.synthesize(text: text)

        // If barge-in cancelled us during synthesis, skip playback
        guard isSpeaking else {
            ttsService = nil
            return
        }

        // Play collected audio
        if !audioData.isEmpty {
            await playPCMAudio(data: audioData, sampleRate: 24000)
        }

        ttsService = nil
        isSpeaking = false
        isPausedForTTS = false
    }

    // MARK: - Stop Speaking

    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        ttsService?.cancel()
        ttsService = nil
        isSpeaking = false
        isPausedForTTS = false
    }

    // MARK: - Barge-In

    /// Called from the audio tap thread (via MainActor hop) when sustained voice
    /// activity is detected during TTS playback. Interrupts TTS and lets ASR
    /// capture the user's new utterance.
    private func handleBargeIn() {
        guard isSpeaking else { return }
        stopSpeaking()
        // ASR is already connected and the tap is installed — next buffer will
        // flow through the normal path since isPausedForTTS is now false.
    }

    /// Compute RMS amplitude of a float PCM buffer. Returns 0 for empty/invalid buffers.
    private static func computeRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard frameLength > 0, channels > 0 else { return 0 }

        var sum: Float = 0
        for channel in 0..<channels {
            let data = channelData[channel]
            for i in 0..<frameLength {
                let s = data[i]
                sum += s * s
            }
        }
        let mean = sum / Float(frameLength * channels)
        return mean.squareRoot()
    }

    // MARK: - Stop All

    func stopAll() {
        stopSpeaking()
        stopListening()
    }

    // MARK: - Audio Playback

    /// Write PCM data with a WAV header to a temp file and play it.
    private func playPCMAudio(data: Data, sampleRate: Int) async {
        let wavData = Self.createWAVData(
            pcmData: data,
            sampleRate: sampleRate,
            channels: 1,
            bitsPerSample: 16
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tts_\(UUID().uuidString).wav")

        do {
            try wavData.write(to: tempURL)
            let player = try AVAudioPlayer(contentsOf: tempURL)
            audioPlayer = player
            player.play()

            // Wait for playback to finish
            while player.isPlaying {
                try await Task.sleep(for: .milliseconds(100))
            }

            audioPlayer = nil
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            errorMessage = "Audio playback error: \(error.localizedDescription)"
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
        }
    }

    // MARK: - WAV Header Generation

    /// Create a complete WAV file (RIFF header + PCM data).
    static func createWAVData(
        pcmData: Data,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int
    ) -> Data {
        var header = Data()
        let dataSize = UInt32(pcmData.count)
        let fileSize = dataSize + 36

        // RIFF chunk
        header.append("RIFF".data(using: .ascii)!)
        header.append(littleEndian: fileSize)
        header.append("WAVE".data(using: .ascii)!)

        // fmt sub-chunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(littleEndian: UInt32(16))           // Sub-chunk size
        header.append(littleEndian: UInt16(1))            // Audio format: PCM
        header.append(littleEndian: UInt16(channels))
        header.append(littleEndian: UInt32(sampleRate))
        let byteRate = UInt32(sampleRate * channels * bitsPerSample / 8)
        header.append(littleEndian: byteRate)
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        header.append(littleEndian: blockAlign)
        header.append(littleEndian: UInt16(bitsPerSample))

        // data sub-chunk
        header.append("data".data(using: .ascii)!)
        header.append(littleEndian: dataSize)

        return header + pcmData
    }
}

// MARK: - Data + Little-Endian Helpers

private extension Data {
    mutating func append(littleEndian value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(littleEndian value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
