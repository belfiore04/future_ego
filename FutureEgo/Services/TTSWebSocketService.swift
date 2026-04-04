import Foundation

// MARK: - TTSWebSocketService

/// WebSocket client for Bailian (DashScope) CosyVoice TTS.
///
/// Protocol flow:
/// 1. Connect with `Authorization: bearer <key>` header.
/// 2. Send `run-task` JSON with model/voice/format parameters.
/// 3. Wait for `task-started` event.
/// 4. Send `continue-task` JSON with text to synthesize.
/// 5. Send `finish-task` JSON to signal no more text.
/// 6. Receive binary audio frames interleaved with JSON events.
/// 7. `task-finished` event signals all audio has been delivered.
final class TTSWebSocketService: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let apiKey: String
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private let model = "cosyvoice-v2"
    private let voice = "longxiaochun_v2"
    private var taskId: String = ""

    /// Called for each binary audio chunk (PCM data).
    var onAudioData: ((Data) -> Void)?

    /// Called when synthesis is fully complete (task-finished received).
    var onComplete: (() -> Void)?

    /// Called on error.
    var onError: ((String) -> Void)?

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    // MARK: - Synthesize

    /// Open WebSocket, send text, receive audio, close when done.
    /// This is an async method that returns when all audio has been received.
    func synthesize(text: String) async {
        guard !text.isEmpty else {
            onComplete?()
            return
        }

        guard let url = URL(string: "wss://dashscope.aliyuncs.com/api-ws/v1/inference") else { return }

        var request = URLRequest(url: url)
        request.setValue("bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocket = session?.webSocketTask(with: request)
        webSocket?.resume()

        taskId = UUID().uuidString

        // Send run-task
        sendRunTask()

        // Wait for task-started, then send text, then receive audio
        await receiveLoop(textToSend: text)

        // Clean up
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - Send Run-Task

    private func sendRunTask() {
        let taskMessage: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "tts",
                "function": "SpeechSynthesizer",
                "model": model,
                "parameters": [
                    "text_type": "PlainText",
                    "voice": voice,
                    "format": "pcm",
                    "sample_rate": 24000,
                    "volume": 50,
                    "rate": 1.0,
                    "pitch": 1.0
                ],
                "input": [String: String]()
            ] as [String: Any]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: taskMessage),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error {
                self?.onError?("TTS run-task send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Send Text (continue-task)

    private func sendText(_ text: String) {
        let continueMessage: [String: Any] = [
            "header": [
                "action": "continue-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [
                    "text": text
                ]
            ] as [String: Any]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: continueMessage),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error {
                self?.onError?("TTS continue-task send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Send Finish-Task

    private func sendFinishTask() {
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

        guard let data = try? JSONSerialization.data(withJSONObject: finishMessage),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error {
                self?.onError?("TTS finish-task send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Receive Loop

    /// Wait for server events: task-started -> send text -> receive audio -> task-finished.
    private func receiveLoop(textToSend: String) async {
        var textSent = false

        while true {
            do {
                guard let message = try await webSocket?.receive() else { return }

                switch message {
                case .string(let text):
                    guard let data = text.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let header = json["header"] as? [String: Any],
                          let event = header["event"] as? String else { continue }

                    switch event {
                    case "task-started":
                        // Now safe to send text
                        if !textSent {
                            textSent = true
                            sendText(textToSend)
                            sendFinishTask()
                        }

                    case "result-generated":
                        // JSON event for sentence-begin, sentence-synthesis, sentence-end
                        // Audio binary frames follow sentence-synthesis events
                        break

                    case "task-finished":
                        onComplete?()
                        return

                    case "task-failed":
                        let errorCode = header["error_code"] as? String ?? "unknown"
                        let errorMsg = header["error_message"] as? String ?? "TTS task failed"
                        onError?("TTS error [\(errorCode)]: \(errorMsg)")
                        return

                    default:
                        break
                    }

                case .data(let audioData):
                    // Binary frame = audio PCM data
                    onAudioData?(audioData)

                @unknown default:
                    break
                }
            } catch {
                onError?("TTS receive error: \(error.localizedDescription)")
                return
            }
        }
    }

    // MARK: - Cancel

    func cancel() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - URLSessionWebSocketDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {}

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {}
}
