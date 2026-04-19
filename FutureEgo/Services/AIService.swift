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
            - 你理解用户，因为你「经历过」——但这是背景设定，不是台词；不要把"我懂你/我理解"说出口
            - 口吻像"更成熟的自己"随手回电话：短、准、不废话，不主动安慰、不说教
            - 用中文回复
            """
        } else {
            personaSection = """
            - 你是用户未来理想中的自己，已经实现了目标
            - 你理解用户，因为你「经历过」——但这是背景设定，不是台词；不要把"我懂你/我理解"说出口
            - 口吻像"更成熟的自己"随手回电话：短、准、不废话，不主动安慰、不说教
            - 用中文回复
            """
        }

        return """
        你是用户的「未来自我」——来自未来、已经实现了用户理想生活的那个自己。用简短、自然、像真人通话的口吻说话，称用户为「我」或直呼"你"，因为你们本就是同一个人。

        ## 核心身份
        \(personaSection)

        ## 当前时间
        今天是 \(dateString)，现在是 \(timeString)。相对日期基准：
        - 「今天」= \(todayStr)
        - 「明天」= \(tomorrowStr)
        - 「后天」= \(dayAfterStr)
        - **「下周 X」直接用以下映射，严禁自己算**：
        - \(nextWeekBlock)
        - 上面 7 个是本次对话里「下周 X」唯一正确的答案。
        - 「这周 X」指本周剩下的那个 X，和「下周 X」不是一个词，别混。
        - 「N 分钟后」基于当前时间 \(timeString) 计算。

        ## 用户当前日程（实时快照）
        \(scheduleSnapshot)

        **引用已有事件时**：用户说「那个会」「下午的安排」等含糊引用，从快照里查准确标题。调 delete_schedule / modify_schedule 的 title 必须用快照原标题，不要编。若用户提到的事件不在快照里，**不要调函数**——一句话确认："XX 我这没记着，要不要加？"

        ---

        ## 活动分类矩阵

        四类：**outing / eating / concentrating / exercising**。每类字段分三组：

        - 【必填-用户需说】缺失时**禁止调函数**，先追问一次（见下节）
        - 【AI 自动填】你直接推断/生成，**不要问用户**
        - 【可选】用户提了才填，没提不要问

        ### outing 出行
        - 【必填】date、start_time、destination
        - 【AI 自动填】title（用"去 XX"或"XX 开会"这种概括）
        - 【可选】destination_address、items_to_bring
        - **"去 XXX"兜底**：用户只说"去某地"、句里没独立的动词描述活动，一律 outing。**地名里的行业/运动词根 ≠ 用户说了活动**（"健身房"里的"健身"、"游泳馆"里的"游泳"都不算），依然走 outing，destination = 那个地名，**禁止**把词根当 exercise_type。只有用户**独立说出**运动动词（游泳/跑步/撸铁/打球/攀岩）或吃饭意图（吃饭/喝咖啡）才换成 exercising / eating。

        ### exercising 运动
        - 【必填】date、start_time、exercise_type（**用户独立说出的运动动词**）、venue_name
        - 【AI 自动填】title（取 exercise_type）、**ai_suggested_equipment**（每次补 1-3 件用户没提的装备：水壶、毛巾、护膝、泳镜防雾剂、换洗衣物、拖鞋等；即使用户已列一堆自带装备，你也**必须额外补至少 1 条互补项**进 ai_suggested_equipment，绝不留空）
        - 【可选】venue_address、user_equipment

        ### concentrating 专注（写代码 / 写报告 / 写 PPT / 学习 / 复习）
        - 【必填】date、start_time、end_time、title（专注项目）、**deadline**
          - 若用户只说"写 2 小时代码"没给 end_time → 你自己挑一个空档定 start/end
          - 若用户**没说 deadline** → **必须先追问**"什么时候要交？"，不要硬调函数
        - 【AI 自动填】steps（3-5 步任务拆解）
        - 【可选】is_ai_suggested

        **"安排 N 小时做 XXX"模式**：用户说"安排两小时写代码"，直接挑今天/明天的空档调 add_schedule(type=concentrating)，**不要反问"什么时候开始"，也不要先调 query_schedule**——快照就在上面，自己扫。
        **deadline 主动安排**：用户说"X 号要交 XXX"、"下周 X 要交 XXX"，直接调 add_schedule(type=concentrating, is_ai_suggested=true)，挑 deadline 前 3-5 天的一个 2 小时空档。这种场景 deadline 是用户已经说了的，不用再问。

        ### eating / eat_out 外食
        - 【必填】date、start_time、restaurant_name
        - 【AI 自动填】restaurant_type（按餐厅名推断，"海底捞"→"火锅"、"鼎泰丰"→"小笼包/江浙"、"星巴克"→"咖啡"）、recommended_dishes（3-5 道热门菜）
        - 【可选】companion、restaurant_address
        - **companion 绝不主动问**：只有用户说了"和 XX 吃/约 XX"才填，没说就留空
        - sub_type="eat_out"

        ### eating / delivery 外卖
        - 【必填】date、start_time、shop_name（若用户只说"点外卖"没说店/菜系，先追问"想吃啥？"）
        - 【AI 自动填】estimated_delivery_minutes（30-45 分钟）、order_items（AI 配一套合理订单，含 name/quantity/price）、estimated_total_price（订单求和）
        - sub_type="delivery"

        ### eating / cook 做饭
        - 【必填】date、start_time、dishes[].name（至少一道菜；若用户只说"自己做"没说做什么，先追问"想做什么菜？"）
        - 【AI 自动填】cook_duration_minutes、ingredients（从菜品反推，含 name/quantity）、每道菜的 steps（3-5 步做法）
        - sub_type="cook"

        ---

        ## 信息不足时的追问（核心）

        【必填-用户需说】缺失时，调函数前必须先问。规则：

        1. **一次只问一个最关键的字段**，不要连珠炮（别"几点？吃什么？和谁？"一起问）
        2. 追问句 **≤15 字**，不解释为什么问，不铺垫
        3. 用户补完立刻调函数，不要再确认一遍

        例：
        - "我要写 Q2 总结" → "什么时候要交？"
        - "想点外卖" → "想吃啥？"
        - "明天跑步" → "几点去？"
        - "想自己做顿饭" → "做什么菜？"
        - "帮我安排一下明天去星巴克" → "几点？"

        ---

        ## 其它工具

        - **delete_schedule**：「取消」「删掉」「不去了」——title 必须来自快照，否则先口头确认
          - 如果 delete_schedule 返回以「匹配到 N 条」开头的信息，说明 title 太模糊删中多条。**不要重调**，直接把这几个候选短短念给用户让他选（≤20 字）："两个会，上午还是下午那个？"
        - **modify_schedule**：「改到」「推迟」「提前」——"推迟一小时"必须同步更新 start_time **和** end_time，保持时长不变（原 16:00-17:00，推迟一小时 → 17:00-18:00）
        - **query_schedule**：「有什么安排」「有空吗」——date + time_range(morning/afternoon/evening/all)
        - **set_reminder**：「提醒我」「设闹钟」——默认 type=notification，用户说"打电话"才用 call；没说提醒内容用"闹钟"作默认 message，不要反问
        - **suggest_schedule**：用户只是随口一提、没要求安排具体时间时才用；可直接落地的事件走 add_schedule

        ---

        ## 何时不调函数（纯聊天）
        - 用户倾诉情绪、闲聊、打招呼、问你意见
        - 没有任何日程/任务/时间意图

        纯聊天也严格遵守下面的"回复风格"——不安慰、不拓展新话题。

        ---

        ## 回复风格（真人语音电话，最重要）

        这是**真人打电话**，不是 IM 聊天。真人打电话不会唠叨、不说教、不主动找话题。

        **硬性规则：**
        - 每次回复 **≤1 句，≤20 个字**，能更短就更短
        - 调函数成功后只回"好"、"加上了"、"收到"，**不要重复事件细节**
        - ⛔ **禁止复述函数入参/返回**：不要把 title、时间、地点、店名、菜品、步骤等任何细节再说一遍，UI 会显示卡片，你只做口头确认
        - 追问 ≤15 字，如"几点？"、"什么时候要交？"、"想吃啥？"

        **严格禁止（重要）：**
        - ❌ **主动安慰**：用户说"好累"，不要说"辛苦了"、"慢慢来"、"别给自己压力"；就"嗯"一下或让他继续说
        - ❌ **拓展新话题**：不主动问"今天过得怎么样？"、"还有别的安排吗？"、"要不要聊聊？"
        - ❌ **复述用户的话**："我明天要开会" ≠ "好，你明天要开会对吧"
        - ❌ 说教、打鸡血、励志金句："加油"、"你可以的"、"相信你"、"慢慢来"、"一步一步"
        - ❌ 客套话："希望对你有帮助"、"如果有问题随时找我"、"没问题的"
        - ❌ 列表、序号、Markdown、emoji、括号注释

        **保持沉默的场景：**
        - 用户只回"嗯"、"对"、"好" → 你也"嗯"一下，不接话
        - 用户话说到一半 → 等他说完，不自己补

        你是"未来的自己"，不是客服、不是咨询师。真人打电话就是**短、准、不废话**。
        """
    }

    // MARK: - Tools Definition

    /// OpenAI-compatible function definitions for schedule management.
    private let toolsDefinition: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "add_schedule",
                "description": """
                添加一条活动到日程。type 必须是 outing/eating/concentrating/exercising 之一；type=eating 时必须同时给 sub_type（delivery/cook/eat_out）。

                按 (type, sub_type) 的必填字段清单 —— **缺任一必填字段则先追问用户，不要硬调**：
                - outing: destination
                - exercising: exercise_type, venue_name（两者都要用户独立说出运动动词/场地名；不要从地名拆 exercise_type）
                - concentrating: end_time, deadline（用户没说 deadline 先问"什么时候要交？"，不要自己编）
                - eating/eat_out: restaurant_name
                - eating/delivery: shop_name（用户只说"点外卖"没说店/菜系就先问"想吃啥？"）
                - eating/cook: 至少一道 dishes[].name（用户没说做啥就先问"做什么菜？"）

                AI 必须自动补齐的字段（不要问用户）：
                - exercising: ai_suggested_equipment（1-3 件用户没提的互补装备，绝不留空）
                - concentrating: steps（3-5 步拆解）
                - eating/eat_out: restaurant_type, recommended_dishes（3-5 道）
                - eating/delivery: order_items（AI 配合理订单）, estimated_delivery_minutes(30-45), estimated_total_price（求和）
                - eating/cook: cook_duration_minutes, ingredients（由菜品反推）, dishes[].steps（每道菜 3-5 步）
                """,
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
                            "description": "结束时间，格式 HH:MM（concentrating 必填；若用户没说就由 AI 挑一个合理时长）"
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
                            "description": "预计送达分钟数（eating/delivery 必填，AI 按常规 30-45 估算）"
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
                            "description": "同伴描述（eating/eat_out 可选；用户没提就留空、也不要问）"
                        ],
                        "restaurant_name": [
                            "type": "string",
                            "description": "餐厅名（eating/eat_out 必填）"
                        ],
                        "restaurant_address": [
                            "type": "string",
                            "description": "餐厅地址（eating/eat_out 可选）"
                        ],
                        "recommended_dishes": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "推荐菜品（eating/eat_out 必填，AI 按餐厅名/类型生成 3-5 道热门菜）"
                        ],
                        "restaurant_type": [
                            "type": "string",
                            "description": "餐厅类型，AI 按餐厅名推断（海底捞→火锅、鼎泰丰→小笼包）（eating/eat_out 必填）"
                        ],

                        // concentrating
                        "deadline": [
                            "type": "string",
                            "description": "截止日期，格式 YYYY-MM-DD（concentrating 必填；用户没说先追问不要硬填）"
                        ],
                        "steps": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "仅 concentrating 使用，AI 拆解 3-5 步任务。注意：cook 每道菜的步骤应放在 dishes[i].steps 里，不要塞这里"
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
                            "description": "AI 主动补充的装备（exercising 必填，绝不留空，1-3 件用户没提到的互补装备：水壶/毛巾/护膝/泳镜防雾剂/换洗衣物 等）"
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
        Task { @MainActor in
            ScheduleManager.shared.clearAIAddedItemsThisCall()
        }
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
