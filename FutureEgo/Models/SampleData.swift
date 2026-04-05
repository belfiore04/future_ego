import SwiftUI

// MARK: - Sample Data
//
// Task #3 migration: all 8 sample items are built against the new 2-tier
// `Activity` enum (Task #1). The placeholder `.concentrating` items that
// Task #1 left tagged `TODO(task-3)` have been replaced with a curated set
// that covers every activity kind + every eating sub-type, per the spec:
//
//   outing        × 1
//   eating.delivery × 1
//   eating.cook     × 1
//   eating.eatOut   × 1
//   concentrating × 2 (one user-created, one AI-suggested)
//   exercising    × 2 (one with equipment, one without)
//
// All times are computed as offsets from `Date()` so the sample schedule
// always looks "today" regardless of when it is rendered. One item spans
// "now" and is marked `.active`; items before it are `.done`; items after
// are `.upcoming`. `currentIndex` points at the `.active` item.

enum SampleData {
    /// The index of the currently active schedule item (the one whose time
    /// range contains "now"). Must stay in sync with the ordering in
    /// `schedule` below.
    static let currentIndex = 2

    /// Ordered schedule for the day. Items are chronological; statuses are
    /// derived from each item's relationship to `Date()` at build time.
    static let schedule: [ScheduleItem] = [
        item0, item1, item2, item3, item4, item5, item6, item7
    ]

    // MARK: - Date helpers

    /// Returns `Date() + hours` (fractional hours allowed via minutes).
    /// All sample items anchor off `Date()` so the fixture is always "today".
    private static func offset(hours: Int, minutes: Int = 0) -> Date {
        let cal = Calendar.current
        let withHours = cal.date(byAdding: .hour, value: hours, to: Date()) ?? Date()
        return cal.date(byAdding: .minute, value: minutes, to: withHours) ?? withHours
    }

    /// Returns `Date() + days`, used for deadlines.
    private static func offset(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    /// Formats a `Date` as `"HH:mm"` for display strings on `ScheduleItem`.
    private static func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// Builds a `"HH:mm - HH:mm"` display string from two dates.
    private static func range(_ start: Date, _ end: Date) -> String {
        "\(hhmm(start)) - \(hhmm(end))"
    }

    // MARK: - Color palette (reused per-category for tag chips)

    private static let outingColor = Color.brandGreen            // green
    private static let eatingColor = Color(hex: "FF9500")        // orange
    private static let concentratingColor = Color(hex: "5856D6") // indigo
    private static let exercisingColor = Color(hex: "FF2D55")    // pink

    // MARK: - Individual items (split out to help the Swift type checker)

    // 1. exercising — morning run, no equipment (.done, 3h ago)
    private static let item0: ScheduleItem = {
        let time = offset(hours: -3)
        return ScheduleItem(
            scheduleTime: "\(hhmm(time)) 晨跑",
            title: "晨跑 · 奥林匹克森林公园",
            status: .done,
            tag: "运动",
            tagColor: exercisingColor,
            detail: .exercising(ExercisingDetail(
                time: time,
                exerciseType: "跑步",
                venueName: "奥林匹克森林公园南园",
                venueCoordinate: GeoPoint(latitude: 40.0068, longitude: 116.3869),
                venueAddress: "北京市朝阳区科荟路33号",
                userEquipment: [],
                aiSuggestedEquipment: ["运动水壶", "运动臂包", "能量胶"]
            ))
        )
    }()

    // 2. outing — morning meeting at Guomao (.done, arrived 1h ago)
    private static let item1: ScheduleItem = {
        let arrival = offset(hours: -1)
        let depart = offset(hours: -1, minutes: -40)
        return ScheduleItem(
            scheduleTime: "\(hhmm(arrival)) 到达",
            title: "广告组营销会",
            status: .done,
            tag: "外出",
            tagColor: outingColor,
            detail: .outing(OutingDetail(
                arrivalTime: arrival,
                destination: "国贸大厦三层会议室 A",
                destinationCoordinate: GeoPoint(latitude: 39.9080, longitude: 116.4640),
                activityName: "广告组营销会",
                itemsToBring: ["笔记本电脑", "会议材料打印稿", "名片"],
                transitDurationMinutes: 40,
                drivingDurationMinutes: 25,
                latestDepartureTime: depart
            ))
        )
    }()

    // 3. concentrating — AI-suggested weekly report (.active, 30min in of 2h block)
    // This is the `currentIndex` item. It spans "now".
    private static let item2: ScheduleItem = {
        let start = offset(hours: 0, minutes: -30)
        let end = offset(hours: 1, minutes: 30)
        return ScheduleItem(
            scheduleTime: range(start, end),
            title: "写周报",
            status: .active,
            tag: "专注 · AI 建议",
            tagColor: concentratingColor,
            detail: .concentrating(ConcentratingDetail(
                startTime: start,
                endTime: end,
                taskName: "写周报",
                deadline: offset(days: 2),
                steps: [
                    "回顾本周已完成任务",
                    "汇总关键指标与数据",
                    "撰写亮点与风险",
                    "列出下周计划",
                ],
                isAISuggested: true
            ))
        )
    }()

    // 4. eating.delivery — lunch delivery (.upcoming, +2h)
    private static let item3: ScheduleItem = {
        let meal = offset(hours: 2)
        return ScheduleItem(
            scheduleTime: "\(hhmm(meal)) 用餐",
            title: "午餐 · 外卖",
            status: .upcoming,
            tag: "餐食 · 外卖",
            tagColor: eatingColor,
            detail: .eating(.delivery(DeliveryDetail(
                mealTime: meal,
                shopName: "麻辣烫 · 国贸店",
                estimatedDeliveryMinutes: 30,
                orderItems: [
                    OrderItem(name: "招牌麻辣烫(微辣)", quantity: 1, price: Decimal(22)),
                    OrderItem(name: "卤蛋", quantity: 1, price: Decimal(4)),
                    OrderItem(name: "米饭", quantity: 1, price: Decimal(3)),
                ],
                estimatedTotalPrice: Decimal(38),
                isAIInferred: true
            )))
        )
    }()

    // 5. concentrating — afternoon deep work, user-created (.upcoming, +3h to +5h)
    private static let item4: ScheduleItem = {
        let start = offset(hours: 3)
        let end = offset(hours: 5)
        return ScheduleItem(
            scheduleTime: range(start, end),
            title: "Q2 产品评审 PPT",
            status: .upcoming,
            tag: "专注",
            tagColor: concentratingColor,
            detail: .concentrating(ConcentratingDetail(
                startTime: start,
                endTime: end,
                taskName: "Q2 产品评审 PPT",
                deadline: offset(days: 5),
                steps: [
                    "整理大纲与核心结论",
                    "收集数据与截图素材",
                    "绘制关键图表",
                    "润色文案与视觉",
                ],
                isAISuggested: false
            ))
        )
    }()

    // 6. exercising — evening swim, with equipment (.upcoming, +7h)
    private static let item5: ScheduleItem = {
        let time = offset(hours: 7)
        return ScheduleItem(
            scheduleTime: "\(hhmm(time)) 游泳",
            title: "游泳 · 朝阳公园",
            status: .upcoming,
            tag: "运动",
            tagColor: exercisingColor,
            detail: .exercising(ExercisingDetail(
                time: time,
                exerciseType: "游泳",
                venueName: "朝阳公园游泳馆",
                venueCoordinate: GeoPoint(latitude: 39.9389, longitude: 116.4760),
                venueAddress: "北京市朝阳区朝阳公园南路1号",
                userEquipment: ["泳镜", "泳帽"],
                aiSuggestedEquipment: ["水壶", "毛巾", "拖鞋"]
            ))
        )
    }()

    // 7. eating.cook — cook dinner at home (.upcoming, +8h)
    private static let item6: ScheduleItem = {
        let start = offset(hours: 8)
        return ScheduleItem(
            scheduleTime: "\(hhmm(start)) 开煮",
            title: "晚餐 · 在家做",
            status: .upcoming,
            tag: "餐食 · 自炊",
            tagColor: eatingColor,
            detail: .eating(.cook(CookDetail(
                startTime: start,
                dishes: [
                    CookDish(name: "番茄炒蛋", steps: [
                        "番茄切块,鸡蛋打散加少许盐",
                        "热锅冷油,倒入蛋液炒至七分熟盛出",
                        "底油爆香葱花,下番茄炒出沙",
                        "倒回鸡蛋翻炒,加糖和盐调味出锅",
                    ]),
                    CookDish(name: "青菜汤", steps: [
                        "青菜洗净切段",
                        "水烧开后下青菜",
                        "加盐和几滴香油",
                        "出锅前撒葱花",
                    ]),
                ],
                cookDurationMinutes: 45,
                ingredients: [
                    Ingredient(name: "番茄", quantity: "3个"),
                    Ingredient(name: "鸡蛋", quantity: "4颗"),
                    Ingredient(name: "青菜", quantity: "1把"),
                    Ingredient(name: "葱", quantity: "2根"),
                    Ingredient(name: "盐", quantity: "适量"),
                    Ingredient(name: "糖", quantity: "1小勺"),
                ]
            )))
        )
    }()

    // 8. eating.eatOut — hotpot with Lisa (.upcoming, +9h)
    private static let item7: ScheduleItem = {
        let appt = offset(hours: 9)
        return ScheduleItem(
            scheduleTime: "\(hhmm(appt)) 用餐",
            title: "晚餐 · 和 Lisa 吃火锅",
            status: .upcoming,
            tag: "餐食 · 外食",
            tagColor: eatingColor,
            detail: .eating(.eatOut(EatOutDetail(
                appointmentTime: appt,
                companion: "Lisa",
                restaurantName: "海底捞 · 国贸店",
                restaurantType: "火锅",
                restaurantCoordinate: GeoPoint(latitude: 39.9082, longitude: 116.4652),
                restaurantAddress: "北京市朝阳区建国门外大街1号国贸商城 B1",
                recommendedDishes: ["招牌毛肚", "鸭血", "小酥肉", "捞派虾滑"]
            )))
        )
    }()
}
