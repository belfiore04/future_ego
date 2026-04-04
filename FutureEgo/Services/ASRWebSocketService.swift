import AVFoundation
import Foundation

// MARK: - ASRWebSocketService

/// WebSocket client for Bailian (DashScope) Paraformer real-time ASR.
///
/// Protocol flow:
/// 1. Connect with `Authorization: bearer <key>` header.
/// 2. Send `run-task` JSON to start recognition.
/// 3. Wait for `task-started` event before sending audio.
/// 4. Send PCM audio as binary frames (16 kHz, 16-bit, mono).
/// 5. Receive `result-generated` events with transcription.
/// 6. Send `finish-task` JSON to end recognition.
final class ASRWebSocketService: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let apiKey: String
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private let model = "paraformer-realtime-v2"
    private var taskId: String = ""
    private var isTaskStarted = false

    /// Called on every transcription update. Parameters: (text, isSentenceEnd).
    var onTranscript: ((String, Bool) -> Void)?

    /// Called when the connection or task fails.
    var onError: ((String) -> Void)?

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    // MARK: - Connect

    func connect() {
        guard let url = URL(string: "wss://dashscope.aliyuncs.com/api-ws/v1/inference") else { return }

        var request = URLRequest(url: url)
        request.setValue("bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocket = session?.webSocketTask(with: request)
        webSocket?.resume()

        taskId = UUID().uuidString
        sendStartTask()
        listenForMessages()
    }

    // MARK: - Send Start Task

    private func sendStartTask() {
        let taskMessage: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": model,
                "parameters": [
                    "format": "pcm",
                    "sample_rate": 16000,
                    "language_hints": ["zh"]
                ],
                "input": [String: String]()
            ] as [String: Any]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: taskMessage),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error {
                self?.onError?("ASR run-task send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Send Audio

    /// Send a PCM audio buffer (16 kHz, 16-bit mono) to the ASR service.
    func sendAudio(buffer: AVAudioPCMBuffer) {
        guard isTaskStarted else { return }
        guard let channelData = buffer.int16ChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let data = Data(bytes: channelData[0], count: frameLength * 2)
        webSocket?.send(.data(data)) { _ in }
    }

    /// Send raw PCM data bytes.
    func sendAudioData(_ data: Data) {
        guard isTaskStarted else { return }
        webSocket?.send(.data(data)) { _ in }
    }

    // MARK: - Listen for Messages

    private func listenForMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleTextMessage(text)
                default:
                    break
                }
                self?.listenForMessages()
            case .failure(let error):
                self?.onError?("ASR receive error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Handle Server Events

    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["header"] as? [String: Any],
              let event = header["event"] as? String else { return }

        switch event {
        case "task-started":
            isTaskStarted = true

        case "result-generated":
            guard let payload = json["payload"] as? [String: Any],
                  let output = payload["output"] as? [String: Any],
                  let sentence = output["sentence"] as? [String: Any] else { return }

            let transcriptText = sentence["text"] as? String ?? ""
            let sentenceEnd = sentence["sentence_end"] as? Bool ?? false
            onTranscript?(transcriptText, sentenceEnd)

        case "task-finished":
            break

        case "task-failed":
            let errorCode = header["error_code"] as? String ?? "unknown"
            let errorMsg = header["error_message"] as? String ?? "ASR task failed"
            onError?("ASR error [\(errorCode)]: \(errorMsg)")

        default:
            break
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        guard isTaskStarted else {
            webSocket?.cancel(with: .normalClosure, reason: nil)
            webSocket = nil
            session?.invalidateAndCancel()
            session = nil
            return
        }

        // Send finish-task before closing
        let finishMessage: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [String: String]()
            ] as [String: Any]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: finishMessage),
           let jsonString = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { [weak self] _ in
                self?.webSocket?.cancel(with: .normalClosure, reason: nil)
                self?.webSocket = nil
                self?.session?.invalidateAndCancel()
                self?.session = nil
            }
        } else {
            webSocket?.cancel(with: .normalClosure, reason: nil)
            webSocket = nil
            session?.invalidateAndCancel()
            session = nil
        }

        isTaskStarted = false
    }

    // MARK: - URLSessionWebSocketDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        // Connection established
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        // Connection closed
    }
}
