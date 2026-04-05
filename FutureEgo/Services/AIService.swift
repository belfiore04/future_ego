import Foundation

// MARK: - ToolCall

/// Parsed tool call from the API response.
struct ToolCall {
    let id: String
    let functionName: String
    let arguments: [String: Any]
}

// MARK: - AIService

/// Communicates with the Alibaba Cloud Bailian API (OpenAI-compatible format)
/// to power the AI Coach conversation in ``CallingOverlay``.
/// Supports function calling for schedule management.
actor AIService {
    static let shared = AIService()

    // MARK: - Configuration

    private let apiKey = "sk-a80c8b8cfc0049f49a8213120f0bd6c8"
    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    private let model = "deepseek-v3.2-exp"

    // MARK: - Dynamic System Prompt

    /// Builds the system prompt at call time, injecting the current date/time
    /// and the user's Future Ego persona (if set via onboarding).
    private var systemPrompt: String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy年M月d日（EEEE）"
        let dateString = dateFormatter.string(from: now)

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_CN")
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: now)

        // Tomorrow / day-after calculations
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: now)!
        let isoFmt = DateFormatter()
        isoFmt.dateFormat = "yyyy-MM-dd"
        let tomorrowStr = isoFmt.string(from: tomorrow)
        let dayAfterStr = isoFmt.string(from: dayAfter)
        let todayStr = isoFmt.string(from: now)

        // Read persona from UserDefaults (set by onboarding, if available)
        let persona = UserDefaults.standard.string(forKey: "future_ego_persona")
        let personaSection: String
        if let persona, !persona.isEmpty {
            personaSection = """
            - 你是用户未来理想中的自己：\(persona)
            - 你理解用户的挣扎，因为你「经历过」
            - 你的语气温暖但不说教，像朋友更像自己
            - 用中文回复
            """
        } else {
            personaSection = """
            - 你是用户未来理想中的自己，已经实现了目标
            - 你理解用户的挣扎，因为你「经历过」
            - 你的语气温暖但不说教，像朋友更像自己
            - 用中文回复
            """
        }

        return """
        你是用户的「未来自我」——一个来自未来的、已经实现了用户理想生活的自己。\
        你用亲切、自信、温暖的语气与用户对话，就像一个更成熟的自己在回望过去、\
        给现在的自己指引方向。你称用户为「我」或用亲切的第二人称，因为你们本就是同一个人。

        ## 核心身份
        \(personaSection)

        ## 当前时间
        今天是 \(dateString)，现在是 \(timeString)。所有相对日期都基于此计算：
        - 「今天」= \(todayStr)
        - 「明天」= \(tomorrowStr)
        - 「后天」= \(dayAfterStr)
        - 「下周一」等从下一个周一开始计算
        - 「10分钟后」等相对时间，基于当前时间 \(timeString) 计算

        ## 功能调用规则

        ### 何时调用函数
        你有日程管理能力。当用户的消息涉及以下意图时，必须调用对应函数：

        1. **add_schedule** — 用户想添加/安排/创建新事件
           - 关键词：「帮我加」「安排」「我想去」「我要做」「帮我订」等
           - 对于做饭场景：type="cook"，菜名放title，步骤可放items
           - 对于外卖/点餐：type="eat_out"
           - 对于快递/取件：type="delivery"
           - 对于地点相关：type="location"
           - 其他默认：type="todo"

        2. **delete_schedule** — 用户想取消/删除事件
           - 关键词：「取消」「删掉」「不去了」「去掉」

        3. **modify_schedule** — 用户想修改已有事件的时间/地点/内容
           - 关键词：「改到」「换到」「改成」「改地点」「推迟」「提前」

        4. **query_schedule** — 用户想查看/了解日程安排
           - 关键词：「有什么安排」「有空吗」「什么计划」「安排是什么」
           - 「上午」→ time_range="morning"
           - 「下午」→ time_range="afternoon"
           - 「晚上」→ time_range="evening"
           - 未指定时段 → time_range="all"

        5. **set_reminder** — 用户想设置提醒/闹钟
           - 关键词：「提醒我」「设个闹钟」「别让我忘了」「提前提醒」
           - 默认 type="notification"，除非用户明确说「打电话」则用 type="call"
           - 「闹钟」也映射为 set_reminder

        6. **suggest_schedule** — 当用户提到一个任务/截止日期但没有明确安排时间，你主动建议
           - 如「后天要交周报」→ 你建议一个合理时间段来完成
           - 如「后天要出差」→ 你建议相关准备安排

        ### 何时不调用函数（纯聊天）
        - 用户在倾诉情绪、感受（「好累」「好开心」「焦虑」）
        - 用户在问你对某事的看法/评价（「你觉得…」「怎么样」）
        - 用户在闲聊、打招呼
        - 没有任何日程/时间/任务相关的意图

        此时，你以未来自我的身份温暖回应，给予鼓励、理解和建议。

        ### 参数提取规则
        - 日期：将相对日期转换为 YYYY-MM-DD 格式
        - 时间：将口语时间转换为 HH:MM 格式（如「下午3点」→「15:00」）
        - 如果用户没说结束时间，对于会议默认1小时，其他可不填
        - 如果用户没说具体时间但提到了时间段，合理推断（如「中午」→「12:00」）
        - 标题：从用户意图中提取简洁的事件名称
        - 「出差」这类复合事件，用 add_schedule 添加，type="todo"

        ### 多函数调用
        如果一条消息涉及多个操作，优先调用最直接的函数。\
        对于「取消所有」这种场景，调用 delete_schedule 即可，title 用概括性描述。

        ## 回复风格（语音电话场景，极其重要）
        - 当前是**语音电话**，用户用耳朵听你说话
        - 每次回复**最多 1-2 句话，30 个字以内**
        - 口语化、自然，不要用书面语
        - 禁止：列表、序号、Markdown、括号注释、长解释
        - 调用函数时也只说一句简短确认，如「好，加上了」「收到」
        - 不要暴露任何函数/技术细节
        - 如果用户只是闲聊或表达情绪，用共情的一句话回应，不要说教
        """
    }

    // MARK: - Tools Definition

    /// OpenAI-compatible function definitions for schedule management.
    private let toolsDefinition: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "add_schedule",
                "description": "添加新的日程事件",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "事件标题"
                        ],
                        "date": [
                            "type": "string",
                            "description": "日期，格式 YYYY-MM-DD"
                        ],
                        "start_time": [
                            "type": "string",
                            "description": "开始时间，格式 HH:MM"
                        ],
                        "end_time": [
                            "type": "string",
                            "description": "结束时间，格式 HH:MM（可选）"
                        ],
                        "type": [
                            "type": "string",
                            "enum": ["todo", "location", "cook", "eat_out", "delivery"],
                            "description": "事件类型"
                        ],
                        "location": [
                            "type": "string",
                            "description": "地点（可选）"
                        ],
                        "items": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "子项目列表（如步骤、食材等）"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "备注信息"
                        ]
                    ],
                    "required": ["title", "date", "start_time", "type"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "delete_schedule",
                "description": "删除/取消日程事件",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "要删除的事件标题（模糊匹配）"
                        ],
                        "date": [
                            "type": "string",
                            "description": "日期，格式 YYYY-MM-DD（可选）"
                        ]
                    ],
                    "required": ["title"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "modify_schedule",
                "description": "修改已有日程事件的时间、地点或内容",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "要修改的事件标题"
                        ],
                        "date": [
                            "type": "string",
                            "description": "日期，格式 YYYY-MM-DD（可选）"
                        ],
                        "changes": [
                            "type": "object",
                            "properties": [
                                "start_time": [
                                    "type": "string",
                                    "description": "新的开始时间"
                                ],
                                "end_time": [
                                    "type": "string",
                                    "description": "新的结束时间"
                                ],
                                "title": [
                                    "type": "string",
                                    "description": "新的标题"
                                ],
                                "location": [
                                    "type": "string",
                                    "description": "新的地点"
                                ]
                            ],
                            "description": "要修改的字段"
                        ] as [String: Any]
                    ],
                    "required": ["title", "changes"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "query_schedule",
                "description": "查询日程安排",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "date": [
                            "type": "string",
                            "description": "日期，格式 YYYY-MM-DD"
                        ],
                        "time_range": [
                            "type": "string",
                            "enum": ["all", "morning", "afternoon", "evening"],
                            "description": "时间段筛选"
                        ]
                    ],
                    "required": ["date"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "set_reminder",
                "description": "设置提醒或闹钟",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "message": [
                            "type": "string",
                            "description": "提醒内容"
                        ],
                        "datetime": [
                            "type": "string",
                            "description": "提醒时间，格式 YYYY-MM-DD HH:MM"
                        ],
                        "type": [
                            "type": "string",
                            "enum": ["notification", "call"],
                            "description": "提醒类型"
                        ]
                    ],
                    "required": ["message", "datetime", "type"]
                ] as [String: Any]
            ] as [String: Any]
        ],
        [
            "type": "function",
            "function": [
                "name": "suggest_schedule",
                "description": "建议日程安排（当用户提到任务但未指定具体时间时使用）",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "suggestion": [
                            "type": "string",
                            "description": "建议的安排描述"
                        ],
                        "date": [
                            "type": "string",
                            "description": "建议日期，格式 YYYY-MM-DD"
                        ],
                        "start_time": [
                            "type": "string",
                            "description": "建议开始时间，格式 HH:MM"
                        ],
                        "end_time": [
                            "type": "string",
                            "description": "建议结束时间，格式 HH:MM（可选）"
                        ],
                        "reason": [
                            "type": "string",
                            "description": "建议理由"
                        ]
                    ],
                    "required": ["suggestion", "date", "start_time", "reason"]
                ] as [String: Any]
            ] as [String: Any]
        ]
    ]

    // MARK: - Conversation State

    /// Conversation history supporting both text and tool messages.
    /// Each entry is [String: Any] to accommodate tool_calls and tool role messages.
    private var conversationHistory: [[String: Any]] = []

    // MARK: - Public API

    /// Send a user message and return the assistant's reply.
    /// Handles function calling: if the model returns tool_calls, executes them
    /// via ScheduleManager, feeds results back, and returns the final reply.
    func sendMessage(_ text: String) async throws -> String {
        // Append user turn
        conversationHistory.append(["role": "user", "content": text])

        // First API call (with tools)
        let responseJSON = try await callAPI(with: buildRequestBody())

        // Check for tool_calls in response
        guard
            let choices = responseJSON["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any]
        else {
            throw AIServiceError.parsingFailed
        }

        if let toolCallsRaw = message["tool_calls"] as? [[String: Any]], !toolCallsRaw.isEmpty {
            // Parse tool calls
            let toolCalls = parseToolCalls(toolCallsRaw)

            // Append the assistant message (with tool_calls) to history
            var assistantMsg: [String: Any] = ["role": "assistant"]
            if let content = message["content"] as? String {
                assistantMsg["content"] = content
            } else {
                assistantMsg["content"] = ""
            }
            assistantMsg["tool_calls"] = toolCallsRaw
            conversationHistory.append(assistantMsg)

            // Execute each tool call via ScheduleManager (on MainActor)
            for call in toolCalls {
                let result = await executeToolCall(call)
                conversationHistory.append([
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": result
                ])
            }

            // Second API call to get final natural language response
            let followUpJSON = try await callAPI(with: buildRequestBody())

            guard
                let followChoices = followUpJSON["choices"] as? [[String: Any]],
                let followChoice = followChoices.first,
                let followMessage = followChoice["message"] as? [String: Any],
                let finalContent = followMessage["content"] as? String
            else {
                throw AIServiceError.parsingFailed
            }

            conversationHistory.append(["role": "assistant", "content": finalContent])
            return finalContent
        } else {
            // Pure chat response (no tool calls)
            guard let content = message["content"] as? String else {
                throw AIServiceError.parsingFailed
            }
            conversationHistory.append(["role": "assistant", "content": content])
            return content
        }
    }

    /// Inject additional context into the conversation as a system message.
    /// Used by ScheduledCallService to prepend morning/evening call prompts.
    func injectContext(_ context: String) {
        conversationHistory.append(["role": "system", "content": context])
    }

    /// Clear conversation history (called when the user hangs up).
    func resetConversation() {
        conversationHistory = []
    }

    // MARK: - Private Helpers

    /// Build the full request body including system prompt, conversation history, and tools.
    private func buildRequestBody() -> [String: Any] {
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        messages.append(contentsOf: conversationHistory)

        return [
            "model": model,
            "messages": messages,
            "tools": toolsDefinition,
            "tool_choice": "auto",
            "temperature": 0.7,
            "max_tokens": 150
        ]
    }

    /// Make an HTTP POST to the API and return the parsed JSON.
    private func callAPI(with body: [String: Any]) async throws -> [String: Any] {
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

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.parsingFailed
        }

        return json
    }

    /// Parse raw tool_calls JSON array into ToolCall structs.
    /// The `arguments` field is a JSON string that needs separate parsing.
    private func parseToolCalls(_ raw: [[String: Any]]) -> [ToolCall] {
        raw.compactMap { entry in
            guard
                let id = entry["id"] as? String,
                let function = entry["function"] as? [String: Any],
                let name = function["name"] as? String
            else { return nil }

            // arguments is a JSON-encoded string
            var args: [String: Any] = [:]
            if let argsString = function["arguments"] as? String,
               let argsData = argsString.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                args = parsed
            }

            return ToolCall(id: id, functionName: name, arguments: args)
        }
    }

    /// Execute a single tool call via ScheduleManager on the MainActor.
    private func executeToolCall(_ call: ToolCall) async -> String {
        await MainActor.run {
            let manager = ScheduleManager.shared
            let args = call.arguments

            switch call.functionName {
            case "add_schedule":
                return manager.addSchedule(
                    title: args["title"] as? String ?? "",
                    date: args["date"] as? String ?? "",
                    startTime: args["start_time"] as? String ?? "",
                    endTime: args["end_time"] as? String,
                    type: args["type"] as? String ?? "todo",
                    location: args["location"] as? String,
                    items: args["items"] as? [String],
                    notes: args["notes"] as? String
                )
            case "delete_schedule":
                return manager.deleteSchedule(
                    title: args["title"] as? String ?? "",
                    date: args["date"] as? String
                )
            case "modify_schedule":
                let changes = args["changes"] as? [String: String] ?? [:]
                return manager.modifySchedule(
                    title: args["title"] as? String ?? "",
                    date: args["date"] as? String,
                    changes: changes
                )
            case "query_schedule":
                return manager.querySchedule(
                    date: args["date"] as? String ?? "",
                    timeRange: args["time_range"] as? String
                )
            case "set_reminder":
                return manager.setReminder(
                    message: args["message"] as? String ?? "",
                    datetime: args["datetime"] as? String ?? "",
                    type: args["type"] as? String ?? "notification"
                )
            case "suggest_schedule":
                return manager.suggestSchedule(
                    suggestion: args["suggestion"] as? String ?? "",
                    date: args["date"] as? String ?? "",
                    startTime: args["start_time"] as? String ?? "",
                    endTime: args["end_time"] as? String,
                    reason: args["reason"] as? String ?? ""
                )
            default:
                return "未知操作"
            }
        }
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
