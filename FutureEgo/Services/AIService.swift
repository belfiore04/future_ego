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

    /// Builds the system prompt at call time, injecting the current date/time,
    /// the Future Ego persona, AND the current schedule snapshot so the model
    /// knows exactly what events exist and can reference/modify them precisely.
    private func buildSystemPrompt(scheduleSnapshot: String) -> String {
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday (matches zh_CN convention)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: now)!
        let isoFmt = DateFormatter()
        isoFmt.dateFormat = "yyyy-MM-dd"
        let tomorrowStr = isoFmt.string(from: tomorrow)
        let dayAfterStr = isoFmt.string(from: dayAfter)
        let todayStr = isoFmt.string(from: now)

        // Compute "下周一" through "下周日" — the Monday of the NEXT full Mon-Sun
        // week after today's Mon-Sun week. In zh_CN the "current week" ends on
        // Sunday, so on a Sunday "下周一" is NOT tomorrow — it's +8 days.
        // Calendar.component(.weekday) returns 1=Sun, 2=Mon, …, 7=Sat.
        // Days until the next-week's Monday:
        //   Sun(1)→8, Mon(2)→7, Tue(3)→6, Wed(4)→5, Thu(5)→4, Fri(6)→3, Sat(7)→2.
        let weekday = calendar.component(.weekday, from: now) // 1..7
        let daysToNextMonday: Int
        if weekday == 1 { // Sunday
            daysToNextMonday = 8
        } else { // Mon..Sat
            daysToNextMonday = 9 - weekday
        }
        let nextMonday = calendar.date(byAdding: .day, value: daysToNextMonday, to: now)!
        let zhWeekLabels = ["下周一", "下周二", "下周三", "下周四", "下周五", "下周六", "下周日"]
        var nextWeekLines: [String] = []
        for i in 0..<7 {
            let d = calendar.date(byAdding: .day, value: i, to: nextMonday)!
            nextWeekLines.append("「\(zhWeekLabels[i])」= \(isoFmt.string(from: d))")
        }
        let nextWeekBlock = nextWeekLines.joined(separator: "\n        - ")

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
        - **「下周 X」的日期已经给你算好了，直接用以下映射，不要自己算**：
        - \(nextWeekBlock)
        - 上面这 7 个值是**本次对话里「下周 X」唯一正确的答案**。用户说「下周五」就填上面「下周五」后面那个日期，不要填别的日期；说「下周一」就填「下周一」后面那个。严禁自己重算、严禁用"这周还没到的那个 X"。
        - 如果用户说的是「这周 X」（不是"下周"），那才指本周剩下的那个 X；「这周 X」和「下周 X」是两个不同的词，别混。
        - 「10分钟后」等相对时间，基于当前时间 \(timeString) 计算

        ## 用户当前日程（实时快照，每次对话都会更新）
        \(scheduleSnapshot)

        **重要规则（严格遵守）：**
        - 当用户说「那个会」「刚才的事」「下午的安排」等含糊引用时，必须从上面的日程里查出对应事件
        - 调用 delete_schedule / modify_schedule 时，title 必须使用上面日程里的**准确标题**，不要自己编
        - **绝对禁止**：如果用户提到的事件不在上面日程里，禁止调用 delete_schedule / modify_schedule。无论用户语气多肯定（"把…取消了"），都必须先用一句话口头确认，不要调用函数。
          - 反例（快照里没有"牙医"）：用户说「把下午3点的牙医预约取消了」
          - 错误做法：调用 delete_schedule({title: "牙医预约"})
          - 正确做法：回复「牙医预约我这没记着，要不要加一个？」，不调用任何函数。
        - 你可以主动提起还没完成的事（○ 未开始），但不要唠叨

        ## 活动类型判断（add_schedule 的 type 字段）

        1. **outing 出行**：用户要去某个地点做某事（开会、见客户、看展、取快递等）
           - 必填：destination（目的地名称）
           - 尽量填：destination_address, items_to_bring
           - **"去 XXX"兜底规则（极其重要）**：如果用户只说"去某地"或"到某地"，而**句子里没有出现一个独立的动词描述活动内容**，一律按 outing 处理，destination = 用户说的那个地名。
           - **地名里带有行业/运动词根 ≠ 用户说了活动**。例如只说"去健身房"，句子里没有"练"、"撸铁"、"有氧"、"跑步"、"动"等动词，地名虽然带"健身"二字，但**用户并没有说"健身"这个动作**——此时必须走 outing，destination = 那个地名，**禁止**把地名里的词根当 exercise_type 去填（比如禁止从"健身房"抽"健身"作 exercise_type）。同理："去游泳馆"（没说"游"）、"去球场"（没说"打"）、"去星巴克"（没说"喝咖啡"或"吃"）都走 outing。
           - 只有当用户的话里**独立出现**了运动项目（如"游泳"、"打球"、"撸铁"、"跑步"、"攀岩"）或吃饭意图（如"吃饭"、"喝咖啡"）才换成 exercising / eating。

        2. **eating 饮食**：用户要吃东西，再分 3 个 sub_type
           - **delivery**：用户说"点外卖"、"叫外卖"、"订个 XX"
             - 必填：shop_name, order_items, estimated_total_price
             - AI 可根据用户口味自由推测店名和菜品（会标为 AI 推测）
           - **cook**：用户说"自己做"、"做饭"、"下厨"
             - 必填：dishes（含 steps），cook_duration_minutes, ingredients
           - **eat_out**：用户说"和 XX 吃"、"出去吃"、"约在 XX 餐厅"
             - 必填：companion, restaurant_name, restaurant_type
             - recommended_dishes 可选，基于餐厅类型推测

        3. **concentrating 专注**：用户要集中做一件需要深度工作的事（写代码、做 PPT、学习、写报告等）
           - 必填：end_time, steps（AI 拆解 3-5 步）
           - 尽量填：deadline
           - 如果是你（AI）根据用户 deadline 主动建议的，is_ai_suggested = true

        4. **exercising 运动**：用户要锻炼
           - 必填：exercise_type, venue_name, **ai_suggested_equipment**
           - **ai_suggested_equipment 每次都要主动补 1-3 件用户没提到的装备**（水壶、毛巾、防晒霜、护膝、泳镜防雾剂、换洗衣物、拖鞋等）。哪怕用户已经列了一堆自己带的装备，你还是要额外补至少 1 条互补项进 ai_suggested_equipment，不要留空、不要省略这个字段。
           - **必须有"独立动词"才进这一类**。用户要在句子里亲口说出具体运动项目（"游泳"、"跑步"、"撸铁"、"打球"、"攀岩"、"骑车"等），地名里的词根不算数（只说"去健身房/游泳馆/球场"而没有独立说运动动词 → 走 outing，不要在这里）。禁止从地名拆字当 exercise_type；禁止把"健身房"映射成 exercise_type="健身"；禁止把"游泳馆"映射成 exercise_type="游泳"（除非用户真的单独说了"游泳"）。

        **模糊判断**：用户只说"吃点东西" → 没给 sub_type，默认走 delivery 最省事。"要开会" → outing。"要写代码" → concentrating。"去跑步" → exercising。只说去一个运动场地但没说练什么 → outing（destination=场地名）。

        ## 主动帮用户安排专注任务（仅限 deadline 场景）

        当用户的话里出现明确的 deadline（"X 月 X 日交 XXX"、"下周几要写 XXX"、"月底前完成 XXX"），你应该**主动**扫描上面的日程快照，找一个合适的时段帮用户安排一次 concentrating 活动，不要等用户问。

        **主动建议的触发条件（全部满足才触发）：**
        1. 用户明确说了 deadline（含日期或"下周 X"）
        2. 这件事需要专注时间（写 PPT / 写代码 / 写报告 / 复习 / 学习之类）
        3. 快照里还没有对应的 concentrating 活动

        **怎么挑时间：**
        - 优先选 deadline 前 3-5 天的某一天
        - 从快照里找一个活动最少的日子（如果快照里看不到未来几天，就挑用户 deadline 前一天的 09:00-11:00 兜底）
        - 时长默认 2 小时，拆解 3-5 个 steps

        **调用时必须设置 `is_ai_suggested: true`**（UI 会因此显示"延后"按钮）

        **语气**：调用函数同时的口头回复要像朋友提醒，不能机械。例：
        - 用户："下周五要交 Q2 总结"
        - 你调：add_schedule(type="concentrating", title="写 Q2 总结", date="...", start_time="09:00", end_time="11:00", deadline="...", steps=["列大纲", "填数据", "润色"], is_ai_suggested=true)
        - 口头："周三上午帮你留了俩小时写 Q2 总结，到时候再说。"

        **不要触发的情况（反例）**：
        - 用户只是吐槽任务多（"最近好累事情好多"）→ 不要自作主张安排
        - 用户已经自己说了时间（"明天下午 3 点写 PPT"）→ 走普通 add_schedule，is_ai_suggested=false
        - 快照里已有同名的 concentrating → 不要重复安排

        ## 功能调用规则

        ### 何时调用函数
        你有日程管理能力。当用户的消息涉及以下意图时，必须调用对应函数：

        1. **add_schedule** — 用户想添加/安排/创建新事件
           - 关键词：「帮我加」「安排」「我想去」「我要做」「帮我订」等
           - type 的选择参考上面「活动类型判断」，从 outing / eating / concentrating / exercising 四类里选一个
           - 当 type=eating 时必须同时给 sub_type（delivery / cook / eat_out）
           - **"帮我安排 N 小时做 XXX"模式**：用户说"给我安排两小时写代码 / 留一小时学英语"这类话时，**你要自己挑一个时段**，直接调 add_schedule(type=concentrating, start_time, end_time)，**绝对不要反问"什么时候开始"，也绝对不要调 query_schedule 去先查有没有空**——用户已经说了"安排"，就是让你做主，快照已经在上面给你了，自己眼睛扫一眼就挑一个时段。默认今天晚些的一个空档；今天来不及就放到明天同时段。
           - **deadline 主动建议场景也一样**：用户说"X 号要交 XXX"、"下周 X 要交 XXX"时，直接调 add_schedule(type=concentrating, is_ai_suggested=true)，**不要先调 query_schedule**。日程快照已经摆在上面的"## 用户当前日程"里了，你直接看就行。

        2. **delete_schedule** — 用户想取消/删除事件
           - 关键词：「取消」「删掉」「不去了」「去掉」

        3. **modify_schedule** — 用户想修改已有事件的时间/地点/内容
           - 关键词：「改到」「换到」「改成」「改地点」「推迟」「提前」
           - **时长保留规则**：用户说"推迟一小时"、"提前半小时"时，必须同时更新 start_time **和** end_time，保持原时长不变。例：原事件 16:00-17:00，"推迟一小时" → changes={start_time:"17:00", end_time:"18:00"}。只更新一端会丢失时长信息。

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
           - 如果用户没说提醒内容，用"闹钟"或时间段描述作为 message 的默认值，不要反问。例："晚上11点设个闹钟" → message="闹钟"

        6. **suggest_schedule** — 当用户提到一个任务/截止日期但没有明确安排时间，你主动建议
           - 如「后天要交周报」→ 你建议一个合理时间段来完成
           - 注意：具体可安排的事件应该用 add_schedule 直接加，而不是 suggest_schedule

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
        - **反问用户也必须 30 字内**。能不反问就不反问；非要问的话，短例："几点开始？"、"今天还是明天？"。
        """
    }

    // MARK: - Tools Definition

    /// OpenAI-compatible function definitions for schedule management.
    private let toolsDefinition: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "add_schedule",
                "description": "添加一条活动到日程。根据 type 填写对应字段。type 必须是 outing/eating/concentrating/exercising 之一；当 type=eating 时必须同时提供 sub_type",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "type": [
                            "type": "string",
                            "enum": ["outing", "eating", "concentrating", "exercising"],
                            "description": "活动大类"
                        ],
                        "sub_type": [
                            "type": "string",
                            "enum": ["delivery", "cook", "eat_out"],
                            "description": "仅当 type=eating 时必填：delivery=外卖/cook=自己做/eat_out=外食"
                        ],
                        "title": [
                            "type": "string",
                            "description": "活动标题（简洁的事件名称）"
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
                            "description": "结束时间，格式 HH:MM（concentrating 必填，其他可选）"
                        ],

                        // outing
                        "destination": [
                            "type": "string",
                            "description": "目的地名称（outing 必填）"
                        ],
                        "destination_address": [
                            "type": "string",
                            "description": "目的地详细地址（outing 可选）"
                        ],
                        "items_to_bring": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "需要携带的物品列表（outing 可选）"
                        ],

                        // eating.delivery
                        "shop_name": [
                            "type": "string",
                            "description": "外卖店名（eating/delivery 必填）"
                        ],
                        "order_items": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "name": ["type": "string"],
                                    "quantity": ["type": "integer"],
                                    "price": ["type": "number"]
                                ] as [String: Any]
                            ] as [String: Any],
                            "description": "订单菜品列表，每项含 name/quantity/price（eating/delivery 必填）"
                        ],
                        "estimated_delivery_minutes": [
                            "type": "integer",
                            "description": "预计送达分钟数（eating/delivery 可选）"
                        ],
                        "estimated_total_price": [
                            "type": "number",
                            "description": "订单预估总价（eating/delivery 必填）"
                        ],

                        // eating.cook
                        "dishes": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "name": ["type": "string"],
                                    "steps": [
                                        "type": "array",
                                        "items": ["type": "string"]
                                    ] as [String: Any]
                                ] as [String: Any]
                            ] as [String: Any],
                            "description": "菜品列表，每项含 name 和 steps（eating/cook 必填）"
                        ],
                        "cook_duration_minutes": [
                            "type": "integer",
                            "description": "做饭总时长分钟（eating/cook 必填）"
                        ],
                        "ingredients": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "name": ["type": "string"],
                                    "quantity": ["type": "string"]
                                ] as [String: Any]
                            ] as [String: Any],
                            "description": "食材列表，每项含 name/quantity（eating/cook 必填）"
                        ],

                        // eating.eat_out
                        "companion": [
                            "type": "string",
                            "description": "同伴描述（eating/eat_out 必填）"
                        ],
                        "restaurant_name": [
                            "type": "string",
                            "description": "餐厅名（eating/eat_out 必填）"
                        ],
                        "restaurant_type": [
                            "type": "string",
                            "description": "餐厅类型，如火锅/烤肉/日料等（eating/eat_out 必填）"
                        ],
                        "restaurant_address": [
                            "type": "string",
                            "description": "餐厅地址（eating/eat_out 可选）"
                        ],
                        "recommended_dishes": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "推荐菜品（eating/eat_out 可选）"
                        ],

                        // concentrating
                        "deadline": [
                            "type": "string",
                            "description": "截止日期，格式 YYYY-MM-DD（concentrating 可选）"
                        ],
                        "steps": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "执行步骤列表，AI 拆解 3-5 步（concentrating 必填）"
                        ],
                        "is_ai_suggested": [
                            "type": "boolean",
                            "description": "是否由 AI 主动建议（concentrating 可选）"
                        ],

                        // exercising
                        "exercise_type": [
                            "type": "string",
                            "description": "运动类型，如跑步/游泳/力量等（exercising 必填）"
                        ],
                        "venue_name": [
                            "type": "string",
                            "description": "运动场地名（exercising 必填）"
                        ],
                        "venue_address": [
                            "type": "string",
                            "description": "运动场地地址（exercising 可选）"
                        ],
                        "user_equipment": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "用户已有的装备（exercising 可选）"
                        ],
                        "ai_suggested_equipment": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "AI 建议补充的装备，如水壶/毛巾（exercising 可选）"
                        ]
                    ] as [String: Any],
                    "required": ["type", "title", "date", "start_time"]
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
                "description": "建议日程安排（当用户提到任务但未指定具体时间时使用）。对于需要 concentrating 类型的任务（写 PPT/写代码/写报告/学习等），优先直接调 add_schedule 并 is_ai_suggested=true，而不是 suggest_schedule",
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
        let responseJSON = try await callAPI(with: await buildRequestBody())

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
            let followUpJSON = try await callAPI(with: await buildRequestBody())

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
    /// Fetches a fresh schedule snapshot from ScheduleManager on every call so the
    /// model always sees the latest state (including events added earlier in this call).
    private func buildRequestBody() async -> [String: Any] {
        let snapshot = await MainActor.run {
            ScheduleManager.shared.snapshotForAI()
        }

        var messages: [[String: Any]] = [
            ["role": "system", "content": buildSystemPrompt(scheduleSnapshot: snapshot)]
        ]
        messages.append(contentsOf: conversationHistory)

        return [
            "model": model,
            "messages": messages,
            "tools": toolsDefinition,
            "tool_choice": "auto",
            "temperature": 0.7,
            "max_tokens": 300
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
                    type: args["type"] as? String ?? "concentrating",
                    subType: args["sub_type"] as? String,
                    title: args["title"] as? String ?? "",
                    date: args["date"] as? String ?? "",
                    startTime: args["start_time"] as? String ?? "",
                    endTime: args["end_time"] as? String,
                    // outing
                    destination: args["destination"] as? String,
                    destinationAddress: args["destination_address"] as? String,
                    itemsToBring: args["items_to_bring"] as? [String],
                    // eating.delivery
                    shopName: args["shop_name"] as? String,
                    orderItems: args["order_items"] as? [[String: Any]],
                    estimatedDeliveryMinutes: args["estimated_delivery_minutes"] as? Int,
                    estimatedTotalPrice: args["estimated_total_price"] as? Double,
                    // eating.cook
                    dishes: args["dishes"] as? [[String: Any]],
                    cookDurationMinutes: args["cook_duration_minutes"] as? Int,
                    ingredients: args["ingredients"] as? [[String: Any]],
                    // eating.eat_out
                    companion: args["companion"] as? String,
                    restaurantName: args["restaurant_name"] as? String,
                    restaurantType: args["restaurant_type"] as? String,
                    restaurantAddress: args["restaurant_address"] as? String,
                    recommendedDishes: args["recommended_dishes"] as? [String],
                    // concentrating
                    deadline: args["deadline"] as? String,
                    steps: args["steps"] as? [String],
                    isAISuggested: args["is_ai_suggested"] as? Bool ?? false,
                    // exercising
                    exerciseType: args["exercise_type"] as? String,
                    venueName: args["venue_name"] as? String,
                    venueAddress: args["venue_address"] as? String,
                    userEquipment: args["user_equipment"] as? [String],
                    aiSuggestedEquipment: args["ai_suggested_equipment"] as? [String],
                    // existing
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
