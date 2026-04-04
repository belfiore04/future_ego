import Foundation

// MARK: - AIService

/// Communicates with the Alibaba Cloud Bailian API (OpenAI-compatible format)
/// to power the AI Coach conversation in ``CallingOverlay``.
actor AIService {
    static let shared = AIService()

    // MARK: - Configuration

    private let apiKey = "sk-a80c8b8cfc0049f49a8213120f0bd6c8"
    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    private let model = "qwen-plus"

    private let systemPrompt = """
        你是「交联」App 的 AI Coach。你是一个温暖、有洞察力的生活教练。\
        你帮助用户规划日程、提升效率、保持健康的生活习惯。\
        回复要简洁有力，中文回答，一般不超过 3 句话。\
        适当使用 emoji 增加亲和力。
        """

    // MARK: - Conversation State

    private var conversationHistory: [[String: String]] = []

    // MARK: - Public API

    /// Send a user message and return the assistant's reply.
    /// Maintains full conversation history for multi-turn context.
    func sendMessage(_ text: String) async throws -> String {
        // Append user turn
        conversationHistory.append(["role": "user", "content": text])

        // Build messages array: system + history
        var requestMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        requestMessages.append(contentsOf: conversationHistory)

        // Build request body
        let body: [String: Any] = [
            "model": model,
            "messages": requestMessages,
            "temperature": 0.7,
            "max_tokens": 500
        ]

        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse response
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AIServiceError.parsingFailed
        }

        // Append assistant turn to history
        conversationHistory.append(["role": "assistant", "content": content])

        return content
    }

    /// Clear conversation history (called when the user hangs up).
    func resetConversation() {
        conversationHistory = []
    }
}

// MARK: - Error Types

enum AIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let code):
            return "服务器错误 (\(code))"
        case .parsingFailed:
            return "解析回复失败"
        }
    }
}
