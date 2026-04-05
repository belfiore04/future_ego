import SwiftUI

// MARK: - CategoryType

enum CategoryType: String, CaseIterable, Identifiable {
    case memory, diet, outing, focus, exercise
    var id: String { rawValue }
}

// MARK: - TimeRange

enum TimeRange: String, CaseIterable, Identifiable {
    case month, week, day
    var id: String { rawValue }

    var label: String {
        switch self {
        case .month: "本月"
        case .week: "本周"
        case .day: "今日"
        }
    }
}

// MARK: - CategoryCard

struct CategoryCard: Identifiable {
    let id: CategoryType
    let icon: String
    let label: String
    let color: Color
    let summary: String
    let description: String
}

// MARK: - DietDetail

struct DietChartEntry: Identifiable {
    let id = UUID()
    let day: String
    let home: Int
    let out: Int
}

struct DietDetail {
    let chartData: [DietChartEntry]
    let totalMeals: Int
    let homeCook: Int
    let eatOut: Int
    let delivery: Int
    let highlights: [String]
}

// MARK: - OutingReviewDetail

struct OutingChartEntry: Identifiable {
    let id = UUID()
    let day: String
    let places: Int
}

struct OutingReviewDetail {
    let chartData: [OutingChartEntry]
    let totalPlaces: Int
    let totalDistance: String
    let topPlaces: [String]
    let highlights: [String]
}

// MARK: - FocusDetail

struct FocusChartEntry: Identifiable {
    let id = UUID()
    let day: String
    let hours: Double
}

struct FocusDetail {
    let chartData: [FocusChartEntry]
    let totalHours: Double
    let avgPerDay: String
    let longestStreak: String
    let highlights: [String]
}

// MARK: - ExerciseDetail

struct ExerciseChartEntry: Identifiable {
    let id = UUID()
    let name: String
    let value: Int
    let color: Color
}

struct ExerciseDetail {
    let chartData: [ExerciseChartEntry]
    let totalMinutes: Int
    let activeDays: Int
    let calories: String
    let highlights: [String]
}

// MARK: - MemoryDetail

struct MemoryItem: Identifiable {
    let id = UUID()
    let time: String
    let type: String
    let text: String
    let image: URL?
    let rotate: Double?
}

struct MemoryDetail {
    let items: [MemoryItem]
    let highlights: [String]
}

// MARK: - TimeRangeData

struct TimeRangeData {
    let diet: DietDetail
    let outing: OutingReviewDetail
    let focus: FocusDetail
    let exercise: ExerciseDetail
    let memory: MemoryDetail
}

// MARK: - ReviewSampleData

enum ReviewSampleData {

    // MARK: Category Cards

    static let categoryCards: [CategoryCard] = [
        CategoryCard(
            id: .memory,
            icon: "📅",
            label: "日历",
            color: Color(hex: "FF2D55"),
            summary: "今日 8 条记忆",
            description: "记录生活点滴 · 珍藏美好时光"
        ),
        CategoryCard(
            id: .diet,
            icon: "🍽️",
            label: "饮食",
            color: Color(hex: "FF9500"),
            summary: "自炊占比 57%",
            description: "本周自炊 12 次 · 外食 5 次"
        ),
        CategoryCard(
            id: .outing,
            icon: "📍",
            label: "外出",
            color: Color(hex: "007AFF"),
            summary: "到访 5 个地点",
            description: "步行 12.3km · 活动丰富"
        ),
        CategoryCard(
            id: .focus,
            icon: "🎯",
            label: "专注",
            color: Color(hex: "5856D6"),
            summary: "累计 18.5 小时",
            description: "日均 2.6h · 保持稳定"
        ),
        CategoryCard(
            id: .exercise,
            icon: "🏃",
            label: "运动",
            color: Color(hex: "34C759"),
            summary: "活动 4 天",
            description: "315 分钟 · 消耗 1,280kcal"
        ),
    ]

    // MARK: - Time Range Data

    static let timeRangeData: [TimeRange: TimeRangeData] = [
        .month: monthData,
        .week: weekData,
        .day: dayData,
    ]

    // MARK: Month Data

    private static let monthData = TimeRangeData(
        diet: monthDiet,
        outing: monthOuting,
        focus: monthFocus,
        exercise: monthExercise,
        memory: monthMemory
    )

    private static let monthDiet = DietDetail(
        chartData: [
            DietChartEntry(day: "第1周", home: 10, out: 4),
            DietChartEntry(day: "第2周", home: 8, out: 6),
            DietChartEntry(day: "第3周", home: 11, out: 3),
            DietChartEntry(day: "第4周", home: 12, out: 2),
        ],
        totalMeals: 84,
        homeCook: 41,
        eatOut: 22,
        delivery: 21,
        highlights: [
            "3月自炊比例从第1周的 71% 提升至第4周的 86%",
            "外卖次数逐周减少，月末控制良好",
            "尝试了 6 道新菜品，烹饪技能提升",
            "建议控制晚餐时间，避免超过 20:00 进食",
        ]
    )

    private static let monthOuting = OutingReviewDetail(
        chartData: [
            OutingChartEntry(day: "第1周", places: 4),
            OutingChartEntry(day: "第2周", places: 5),
            OutingChartEntry(day: "第3周", places: 3),
            OutingChartEntry(day: "第4周", places: 6),
        ],
        totalPlaces: 18,
        totalDistance: "48km",
        topPlaces: ["798艺术区", "故宫", "奥林匹克森林公园", "西单", "三里屯"],
        highlights: [
            "3月到访 18 个不同地点，生活丰富度提升",
            "步行总里程 48km，日均 1.5km",
            "第4周最活跃，出行 6 次",
            "建议探索更多自然景点来放松心情",
        ]
    )

    private static let monthFocus = FocusDetail(
        chartData: [
            FocusChartEntry(day: "第1周", hours: 15),
            FocusChartEntry(day: "第2周", hours: 18),
            FocusChartEntry(day: "第3周", hours: 16),
            FocusChartEntry(day: "第4周", hours: 19),
        ],
        totalHours: 68,
        avgPerDay: "2.2h",
        longestStreak: "第4周 日均2.7h",
        highlights: [
            "3月累计专注 68 小时，呈上升趋势",
            "第4周最佳，日均专注 2.7 小时",
            "番茄工作法使用率提高，效率明显改善",
            "建议保持专注时段，目标提升至日均 3h",
        ]
    )

    private static let monthExercise = ExerciseDetail(
        chartData: [
            ExerciseChartEntry(name: "跑步", value: 360, color: Color(hex: "34C759")),
            ExerciseChartEntry(name: "瑜伽", value: 240, color: Color(hex: "5856D6")),
            ExerciseChartEntry(name: "力量", value: 180, color: Color(hex: "FF9500")),
            ExerciseChartEntry(name: "步行", value: 480, color: Color(hex: "007AFF")),
        ],
        totalMinutes: 1260,
        activeDays: 16,
        calories: "5,120",
        highlights: [
            "3月运动 16 天，总时长 1260 分钟",
            "跑步能力提升，配速从 6'30 降至 6'05",
            "新增瑜伽训练，灵活性有所改善",
            "建议保持每周至少 4 天活动的节奏",
        ]
    )

    private static let monthMemory = MemoryDetail(
        items: [
            MemoryItem(time: "08:00", type: "text", text: "今天天气真好，去公园散步了。", image: nil, rotate: nil),
            MemoryItem(time: "12:30", type: "text", text: "中午和朋友一起吃了顿美味的午餐。", image: nil, rotate: nil),
            MemoryItem(time: "18:00", type: "text", text: "晚上和家人一起看了部电影。", image: nil, rotate: nil),
            MemoryItem(time: "20:00", type: "text", text: "睡前读了一本好书，感觉很放松。", image: nil, rotate: nil),
        ],
        highlights: [
            "记录了 4 条生活点滴",
            "今天和朋友一起吃了顿美味的午餐",
            "晚上和家人一起看了部电影",
            "睡前读了一本好书，感觉很放松",
        ]
    )

    // MARK: Week Data

    private static let weekData = TimeRangeData(
        diet: weekDiet,
        outing: weekOuting,
        focus: weekFocus,
        exercise: weekExercise,
        memory: weekMemory
    )

    private static let weekDiet = DietDetail(
        chartData: [
            DietChartEntry(day: "周一", home: 2, out: 1),
            DietChartEntry(day: "周二", home: 3, out: 0),
            DietChartEntry(day: "周三", home: 2, out: 1),
            DietChartEntry(day: "周四", home: 1, out: 2),
            DietChartEntry(day: "周五", home: 2, out: 1),
            DietChartEntry(day: "周六", home: 3, out: 0),
            DietChartEntry(day: "周日", home: 2, out: 1),
        ],
        totalMeals: 21,
        homeCook: 12,
        eatOut: 5,
        delivery: 4,
        highlights: [
            "本周自炊比例达到 57%，比上周提升 12%",
            "周二和周六全天自炊，值得保持",
            "外卖次数控制在 4 次，符合目标",
            "推荐增加蔬菜摄入量，本周蔬菜偏少",
        ]
    )

    private static let weekOuting = OutingReviewDetail(
        chartData: [
            OutingChartEntry(day: "周一", places: 1),
            OutingChartEntry(day: "周二", places: 0),
            OutingChartEntry(day: "周三", places: 2),
            OutingChartEntry(day: "周四", places: 1),
            OutingChartEntry(day: "周五", places: 3),
            OutingChartEntry(day: "周六", places: 2),
            OutingChartEntry(day: "周日", places: 1),
        ],
        totalPlaces: 5,
        totalDistance: "12.3km",
        topPlaces: ["798艺术区", "三里屯太古里", "朝阳公园", "国贸商城", "书店"],
        highlights: [
            "本周外出活动丰富，到访 5 个不同地点",
            "步行总里程 12.3km，保持了良好活动量",
            "周五最活跃，到访了 3 个地点",
            "建议周末多去户外公园走走",
        ]
    )

    private static let weekFocus = FocusDetail(
        chartData: [
            FocusChartEntry(day: "周一", hours: 3.2),
            FocusChartEntry(day: "周二", hours: 2.8),
            FocusChartEntry(day: "周三", hours: 1.5),
            FocusChartEntry(day: "周四", hours: 3.5),
            FocusChartEntry(day: "周五", hours: 2.0),
            FocusChartEntry(day: "周六", hours: 3.0),
            FocusChartEntry(day: "周日", hours: 2.5),
        ],
        totalHours: 18.5,
        avgPerDay: "2.6h",
        longestStreak: "周四 3.5h",
        highlights: [
            "累计专注 18.5 小时，日均 2.6 小时",
            "周四表现最佳，连续专注 3.5 小时",
            "周三专注时间较短，受会议影响较大",
            "建议设置「勿扰时段」来保护专注时间",
        ]
    )

    private static let weekExercise = ExerciseDetail(
        chartData: [
            ExerciseChartEntry(name: "跑步", value: 90, color: Color(hex: "34C759")),
            ExerciseChartEntry(name: "瑜伽", value: 60, color: Color(hex: "5856D6")),
            ExerciseChartEntry(name: "力量", value: 45, color: Color(hex: "FF9500")),
            ExerciseChartEntry(name: "步行", value: 120, color: Color(hex: "007AFF")),
        ],
        totalMinutes: 315,
        activeDays: 4,
        calories: "1,280",
        highlights: [
            "本周活动 4 天，运动总时长 315 分钟",
            "步行占比最高（120分钟），日常活动量充足",
            "跑步 90 分钟，心肺功能持续提升",
            "建议增加拉伸训练来平衡运动类型",
        ]
    )

    private static let weekMemory = MemoryDetail(
        items: [
            MemoryItem(time: "08:00", type: "text", text: "今天天气真好，去公园散步了。", image: nil, rotate: nil),
            MemoryItem(time: "12:30", type: "text", text: "中午和朋友一起吃了顿美味的午餐。", image: nil, rotate: nil),
            MemoryItem(time: "18:00", type: "text", text: "晚上和家人一起看了部电影。", image: nil, rotate: nil),
            MemoryItem(time: "20:00", type: "text", text: "睡前读了一本好书，感觉很放松。", image: nil, rotate: nil),
        ],
        highlights: [
            "记录了 4 条生活点滴",
            "今天和朋友一起吃了顿美味的午餐",
            "晚上和家人一起看了部电影",
            "睡前读了一本好书，感觉很放松",
        ]
    )

    // MARK: Day Data

    private static let dayData = TimeRangeData(
        diet: dayDiet,
        outing: dayOuting,
        focus: dayFocus,
        exercise: dayExercise,
        memory: dayMemory
    )

    private static let dayDiet = DietDetail(
        chartData: [
            DietChartEntry(day: "早餐", home: 1, out: 0),
            DietChartEntry(day: "午餐", home: 0, out: 1),
            DietChartEntry(day: "晚餐", home: 1, out: 0),
        ],
        totalMeals: 3,
        homeCook: 2,
        eatOut: 1,
        delivery: 0,
        highlights: [
            "今日自炊 2 餐，早晚均在家决",
            "午餐外食，选择了轻食沙拉",
            "全天无外卖，保持了健康饮食",
            "建议明天继续保持这个节奏",
        ]
    )

    private static let dayOuting = OutingReviewDetail(
        chartData: [
            OutingChartEntry(day: "上午", places: 0),
            OutingChartEntry(day: "下午", places: 2),
            OutingChartEntry(day: "晚上", places: 1),
        ],
        totalPlaces: 3,
        totalDistance: "3.2km",
        topPlaces: ["咖啡厅", "书店", "超市"],
        highlights: [
            "今日外出 3 次，活动适中",
            "下午去了咖啡厅和书店",
            "步行 3.2km，达到日常目标",
            "建议晚上可以散步增加活动量",
        ]
    )

    private static let dayFocus = FocusDetail(
        chartData: [
            FocusChartEntry(day: "上午", hours: 1.5),
            FocusChartEntry(day: "下午", hours: 2.0),
            FocusChartEntry(day: "晚上", hours: 1.0),
        ],
        totalHours: 4.5,
        avgPerDay: "4.5h",
        longestStreak: "下午 2h",
        highlights: [
            "今日专注 4.5 小时，超过日均水平",
            "下午专注效率最高，完成 2 小时",
            "上午和晚上各完成 1-1.5 小时",
            "建议明天继续保持高专注状态",
        ]
    )

    private static let dayExercise = ExerciseDetail(
        chartData: [
            ExerciseChartEntry(name: "跑步", value: 30, color: Color(hex: "34C759")),
            ExerciseChartEntry(name: "步行", value: 45, color: Color(hex: "007AFF")),
        ],
        totalMinutes: 75,
        activeDays: 1,
        calories: "320",
        highlights: [
            "今日运动 75 分钟，完成日常目标",
            "晨跑 30 分钟，保持了良好状态",
            "日常步行 45 分钟",
            "建议明天增加拉伸训练",
        ]
    )

    // swiftlint:disable line_length
    private static let dayMemory = MemoryDetail(
        items: [
            dayMemoryItem0, dayMemoryItem1, dayMemoryItem2, dayMemoryItem3,
            dayMemoryItem4, dayMemoryItem5, dayMemoryItem6, dayMemoryItem7,
        ],
        highlights: [
            "记录了 8 条生活点滴，丰富多彩",
            "今天运动、工作、阅读都有涉及",
            "饮食健康，早晚沙拉搭配合理",
            "保持了良好的作息节奏",
        ]
    )

    private static let dayMemoryItem0 = MemoryItem(
        time: "08:00",
        type: "breakfast",
        text: "早餐吃得真香",
        image: URL(string: "https://images.unsplash.com/photo-1728035728955-0c159ea5249a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxoZWFsdGh5JTIwYnJlYWtfYXN0JTIwZm9vZHxlbnwxfHx8fDE3NzUyODY2Mjl8MA&ixlib=rb-4.1.0&q=80&w=400"),
        rotate: -2
    )

    private static let dayMemoryItem1 = MemoryItem(
        time: "10:30",
        type: "coffee",
        text: "下午茶时光",
        image: URL(string: "https://images.unsplash.com/photo-1541167760496-1628856ab772?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjb2ZmZWUlMjBsYXR0ZSUyMGFydHxlbnwxfHx8fDE3NzUxOTUwMzZ8MA&ixlib=rb-4.1.0&q=80&w=400"),
        rotate: 3
    )

    private static let dayMemoryItem2 = MemoryItem(
        time: "14:00",
        type: "focus",
        text: "专注工作2小时",
        image: URL(string: "https://images.unsplash.com/photo-1614250836169-b2c6119d9160?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxzdHVkeSUyMGRlc2slMjB3b3Jrc3BhY2V8ZW58MXx8fHwxNzc1MTkxMzc5fDA&ixlib=rb-4.1.0&q=80&w=400"),
        rotate: -1
    )

    private static let dayMemoryItem3 = MemoryItem(
        time: "16:30",
        type: "exercise",
        text: "跑步打卡",
        image: URL(string: "https://images.unsplash.com/photo-1590646299178-1b26ab821e34?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxydW5uaW5nJTIwc2hvZXMlMjBleGVyY2lzZXxlbnwxfHx8fDE3NzUyODY2Mjl8MA&ixlib=rb-4.1.0&q=80&w=400"),
        rotate: 2
    )

    private static let dayMemoryItem4 = MemoryItem(
        time: "18:30",
        type: "dinner",
        text: "晚餐沙拉健康餐",
        image: URL(string: "https://images.unsplash.com/photo-1654458804670-2f4f26ab3154?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxmcmVzaCUyMHNhbGFkJTIwaGVhbHRoeXxlbnwxfHx8fDE3NzUyODY2MzB8MA&ixlib=rb-4.1.0&q=80&w=400"),
        rotate: -3
    )

    private static let dayMemoryItem5 = MemoryItem(
        time: "20:00",
        type: "walk",
        text: "饭后散步",
        image: URL(string: "https://images.unsplash.com/photo-1652793822017-f06cfd41a0e0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjaXR5JTIwd2FsayUyMHN0cmVldHxlbnwxfHx8fDE3NzUyODY2MzF8MA&ixlib=rb-4.1.0&q=80&w=400"),
        rotate: 1
    )

    private static let dayMemoryItem6 = MemoryItem(
        time: "21:30",
        type: "reading",
        text: "睡前阅读",
        image: URL(string: "https://images.unsplash.com/photo-1706195546853-a81b6a190daf?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxib29rJTIwcmVhZGluZyUyMGNvenl8ZW58MXx8fHwxNzc1Mjg2NjMxfDA&ixlib=rb-4.1.0&q=80&w=400"),
        rotate: -2
    )

    private static let dayMemoryItem7 = MemoryItem(
        time: "22:00",
        type: "yoga",
        text: "瑜伽拉伸",
        image: URL(string: "https://images.unsplash.com/photo-1506126613408-eca07ce68773?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b2dhJTIwbWVkaXRhdGlvbnxlbnwxfHx8fDE3NzUyODY2MzB8MA&ixlib=rb-4.1.0&q=80&w=400"),
        rotate: 2
    )
    // swiftlint:enable line_length
}
