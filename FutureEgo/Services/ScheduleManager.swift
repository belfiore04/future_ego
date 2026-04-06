import Foundation
import SwiftUI

// MARK: - ScheduleManager

/// Bridges AI function calls to actual schedule data operations.
/// Singleton accessed from both AIService (tool execution) and SwiftUI views.
@MainActor
class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    /// Current schedule list — starts empty on first launch; mutated by user/AI.
    /// Previews that need demo data should pass `SampleData.schedule` explicitly.
    @Published var schedule: [ScheduleItem] = []
    @Published var currentIndex: Int = 0

    @AppStorage("use_mock_data") private var useMockData = false

    private init() {
        LaunchTrace.mark("ScheduleManager.init (empty schedule)")
        if useMockData {
            loadMockData()
        }
    }

    // MARK: - Mock Data (Developer)

    /// Replaces the schedule with `SampleData.schedule` for testing all
    /// activity detail page types. Called when the developer toggle is ON.
    func loadMockData() {
        schedule = SampleData.schedule
        currentIndex = 0
    }

    /// Restores the schedule to empty when mock mode is turned off.
    func clearMockData() {
        schedule = []
        currentIndex = 0
    }

    /// Advances `currentIndex` to the next item, wrapping around.
    /// Only meaningful when mock data is loaded.
    func advanceToNextActivity() {
        guard !schedule.isEmpty else { return }
        currentIndex = (currentIndex + 1) % schedule.count
    }

    // MARK: - Snapshot for AI Context

    /// Build a compact, human-readable snapshot of the current schedule.
    /// Injected into the AI system prompt so the model knows exactly what
    /// events exist, their precise titles, times, type/subtype tags and
    /// status — enabling accurate references, modifications, and deletions.
    ///
    /// Example output:
    /// ```
    /// - [09:30 到达] 广告组营销会 · outing · ● 进行中
    /// - [12:00] 麻辣烫外卖 · eating/delivery · ○ 未开始
    /// - [14:00 - 16:00] Q2 PPT · concentrating · ○ 未开始 · deadline 2026-04-10
    /// - [18:30] 游泳 · exercising · ✓ 已完成
    /// ```
    func snapshotForAI() -> String {
        guard !schedule.isEmpty else {
            return "（今日暂无日程）"
        }

        let lines = schedule.map { item -> String in
            let statusMark: String
            switch item.status {
            case .done:     statusMark = "✓ 已完成"
            case .active:   statusMark = "● 进行中"
            case .upcoming: statusMark = "○ 未开始"
            }

            let timeLabel = item.detail.displayTimeRange
            let tag = item.detail.typeTag
            let title = item.title.isEmpty ? item.detail.displayTitle : item.title

            var line = "- [\(timeLabel)] \(title) · \(tag) · \(statusMark)"

            // Extra per-type annotations (deadline, companion, etc.)
            if case .concentrating(let d) = item.detail, let deadline = d.deadline {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                line += " · deadline \(df.string(from: deadline))"
            }
            return line
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Function Handlers

    /// Single entry point matching the AIService single-tool design.
    /// `type` + `subType` dispatch into the appropriate `Activity` case; any
    /// parameter that doesn't apply to the chosen case is silently ignored.
    ///
    /// Dispatch matrix:
    /// - `type == "outing"`                         → `.outing(OutingDetail)`
    /// - `type == "eating" && subType == "delivery"` → `.eating(.delivery(...))`
    /// - `type == "eating" && subType == "cook"`     → `.eating(.cook(...))`
    /// - `type == "eating" && subType == "eat_out"`  → `.eating(.eatOut(...))`
    /// - `type == "concentrating"`                  → `.concentrating(...)`
    /// - `type == "exercising"`                     → `.exercising(...)`
    /// - anything else falls back to `.concentrating` so the call never fails.
    func addSchedule(
        type: String,
        subType: String? = nil,
        title: String,
        date: String,
        startTime: String,
        endTime: String? = nil,
        // outing
        destination: String? = nil,
        destinationAddress: String? = nil,
        itemsToBring: [String]? = nil,
        // eating.delivery
        shopName: String? = nil,
        orderItems: [[String: Any]]? = nil,
        estimatedDeliveryMinutes: Int? = nil,
        estimatedTotalPrice: Double? = nil,
        // eating.cook
        dishes: [[String: Any]]? = nil,
        cookDurationMinutes: Int? = nil,
        ingredients: [[String: Any]]? = nil,
        // eating.eat_out
        companion: String? = nil,
        restaurantName: String? = nil,
        restaurantType: String? = nil,
        restaurantAddress: String? = nil,
        recommendedDishes: [String]? = nil,
        // concentrating
        deadline: String? = nil,
        steps: [String]? = nil,
        isAISuggested: Bool = false,
        // exercising
        exerciseType: String? = nil,
        venueName: String? = nil,
        venueAddress: String? = nil,
        userEquipment: [String]? = nil,
        aiSuggestedEquipment: [String]? = nil,
        // common
        notes: String? = nil
    ) -> String {
        // MARK: Date parsing helpers (closure-local)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let baseDay = dayFormatter.date(from: date) ?? Date()
        let cal = Calendar.current
        func parseTime(_ str: String) -> Date {
            let parts = str.split(separator: ":").compactMap { Int($0) }
            let hour = parts.first ?? 0
            let minute = parts.count > 1 ? parts[1] : 0
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDay) ?? baseDay
        }
        func parseDate(_ str: String) -> Date? {
            dayFormatter.date(from: str)
        }
        let startDate = parseTime(startTime)
        let endDate = endTime.map(parseTime) ?? cal.date(byAdding: .hour, value: 1, to: startDate) ?? startDate

        // MARK: Build Activity based on (type, subType)
        let detail: Activity
        switch type.lowercased() {
        case "outing", "location":
            detail = .outing(OutingDetail(
                arrivalTime: startDate,
                destination: destination ?? destinationAddress ?? "",
                destinationCoordinate: nil,
                activityName: title,
                itemsToBring: itemsToBring ?? [],
                transitDurationMinutes: nil,
                drivingDurationMinutes: nil,
                latestDepartureTime: nil
            ))

        case "eating":
            detail = .eating(buildEatingDetail(
                subType: subType,
                title: title,
                startDate: startDate,
                endDate: endDate,
                shopName: shopName,
                orderItems: orderItems,
                estimatedDeliveryMinutes: estimatedDeliveryMinutes,
                estimatedTotalPrice: estimatedTotalPrice,
                dishes: dishes,
                cookDurationMinutes: cookDurationMinutes,
                ingredients: ingredients,
                companion: companion,
                restaurantName: restaurantName,
                restaurantType: restaurantType,
                restaurantAddress: restaurantAddress,
                recommendedDishes: recommendedDishes
            ))

        case "concentrating", "concentrate", "focus":
            detail = .concentrating(ConcentratingDetail(
                startTime: startDate,
                endTime: endDate,
                taskName: title,
                deadline: deadline.flatMap(parseDate),
                steps: steps ?? [],
                isAISuggested: isAISuggested
            ))

        case "exercising", "exercise":
            detail = .exercising(ExercisingDetail(
                time: startDate,
                exerciseType: exerciseType ?? title,
                venueName: venueName ?? "",
                venueCoordinate: nil,
                venueAddress: venueAddress ?? "",
                userEquipment: userEquipment ?? [],
                aiSuggestedEquipment: aiSuggestedEquipment ?? []
            ))

        default:
            // Fallback: treat unknown types as a concentrating block so the
            // tool call never fails. Notes go into steps as a single entry.
            detail = .concentrating(ConcentratingDetail(
                startTime: startDate,
                endTime: endDate,
                taskName: title,
                deadline: deadline.flatMap(parseDate),
                steps: steps ?? (notes.map { [$0] } ?? []),
                isAISuggested: isAISuggested
            ))
        }

        // MARK: Build ScheduleItem
        let timeRange = endTime != nil ? "\(startTime) - \(endTime!)" : startTime
        let newItem = ScheduleItem(
            scheduleTime: timeRange,
            title: title,
            status: .upcoming,
            tag: nil,
            tagColor: nil,
            detail: detail
        )

        // Insert at the correct position sorted by time
        let insertIndex = schedule.firstIndex { $0.scheduleTime > timeRange } ?? schedule.count
        schedule.insert(newItem, at: insertIndex)

        // MARK: Reminder integration
        //
        // For `outing` we delegate to the new ReminderService API (implemented
        // by task-6). Keeping the call site stable — the signature is
        // documented in task-4/report.md so task-6 can land the impl.
        if case .outing(let outingDetail) = detail {
            Task {
                await ReminderService.shared.scheduleOutingReminders(
                    for: outingDetail,
                    scheduleId: newItem.id
                )
            }
        } else if let address = destinationAddress ?? destination, !address.isEmpty {
            // Preserve legacy smartReminders path for non-outing items that
            // still carry a location string — this keeps the existing
            // pendingCallReminders infrastructure active until task-6 lands.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            if let eventDate = formatter.date(from: "\(date) \(startTime)") {
                ReminderService.shared.scheduleSmartReminders(
                    for: title,
                    at: address,
                    eventTime: eventDate
                )
            }
        }

        return "已添加日程「\(title)」到 \(date) \(startTime)"
    }

    // MARK: - Eating sub-type builder

    /// Factored out of `addSchedule` to keep the Swift type-checker happy and
    /// make the three eating branches individually readable.
    private func buildEatingDetail(
        subType: String?,
        title: String,
        startDate: Date,
        endDate: Date,
        shopName: String?,
        orderItems: [[String: Any]]?,
        estimatedDeliveryMinutes: Int?,
        estimatedTotalPrice: Double?,
        dishes: [[String: Any]]?,
        cookDurationMinutes: Int?,
        ingredients: [[String: Any]]?,
        companion: String?,
        restaurantName: String?,
        restaurantType: String?,
        restaurantAddress: String?,
        recommendedDishes: [String]?
    ) -> EatingDetail {
        switch (subType ?? "").lowercased() {
        case "delivery":
            let items = (orderItems ?? []).map { dict -> OrderItem in
                OrderItem(
                    name: dict["name"] as? String ?? "",
                    quantity: dict["quantity"] as? Int ?? 1,
                    price: Decimal((dict["price"] as? Double) ?? 0)
                )
            }
            let total = estimatedTotalPrice.map { Decimal($0) }
                ?? items.reduce(Decimal(0)) { $0 + $1.price * Decimal($1.quantity) }
            return .delivery(DeliveryDetail(
                mealTime: startDate,
                shopName: shopName ?? title,
                estimatedDeliveryMinutes: estimatedDeliveryMinutes ?? 30,
                orderItems: items,
                estimatedTotalPrice: total,
                isAIInferred: true
            ))

        case "cook":
            let cookDishes = (dishes ?? []).map { dict -> CookDish in
                CookDish(
                    name: dict["name"] as? String ?? "",
                    steps: dict["steps"] as? [String] ?? []
                )
            }
            let ings = (ingredients ?? []).map { dict -> Ingredient in
                Ingredient(
                    name: dict["name"] as? String ?? "",
                    quantity: dict["quantity"] as? String ?? ""
                )
            }
            let duration = cookDurationMinutes
                ?? max(Int(endDate.timeIntervalSince(startDate) / 60), 30)
            return .cook(CookDetail(
                startTime: startDate,
                dishes: cookDishes.isEmpty ? [CookDish(name: title, steps: [])] : cookDishes,
                cookDurationMinutes: duration,
                ingredients: ings
            ))

        case "eat_out", "eatout":
            return .eatOut(EatOutDetail(
                appointmentTime: startDate,
                companion: companion ?? "",
                restaurantName: restaurantName ?? title,
                restaurantType: restaurantType ?? "",
                restaurantCoordinate: nil,
                restaurantAddress: restaurantAddress ?? "",
                recommendedDishes: recommendedDishes ?? []
            ))

        default:
            // Unknown eating sub-type: fall back to delivery with bare info so
            // the call still yields a valid Activity payload.
            return .delivery(DeliveryDetail(
                mealTime: startDate,
                shopName: shopName ?? title,
                estimatedDeliveryMinutes: estimatedDeliveryMinutes ?? 30,
                orderItems: [],
                estimatedTotalPrice: estimatedTotalPrice.map { Decimal($0) } ?? Decimal(0),
                isAIInferred: true
            ))
        }
    }

    // MARK: - Delete / Modify

    func deleteSchedule(title: String, date: String?) -> String {
        // Cancel reminders for matching items before removing. Match either the
        // ScheduleItem.title or the Activity.displayTitle so fuzzy references
        // to e.g. "Q2 PPT" still resolve to a `.concentrating` whose taskName
        // contains that substring.
        func matches(_ item: ScheduleItem) -> Bool {
            if title == "所有" || title.contains("所有") { return true }
            if item.title.contains(title) { return true }
            if item.detail.displayTitle.contains(title) { return true }
            return false
        }

        for item in schedule where matches(item) {
            ReminderService.shared.cancelReminders(for: item.title)
        }

        let before = schedule.count
        schedule.removeAll(where: matches)
        let removed = before - schedule.count
        if removed > 0 {
            // Clamp currentIndex if it's now out of bounds
            if currentIndex >= schedule.count {
                currentIndex = max(0, schedule.count - 1)
            }
            return "已删除 \(removed) 个日程"
        }
        return "未找到匹配的日程「\(title)」"
    }

    func modifySchedule(title: String, date: String?, changes: [String: String]) -> String {
        // Fuzzy match on either the top-level title or the inner displayTitle.
        guard let index = schedule.firstIndex(where: {
            $0.title.contains(title) || $0.detail.displayTitle.contains(title)
        }) else {
            return "未找到日程「\(title)」"
        }

        let item = schedule[index]
        let newTime = changes["start_time"]
            ?? item.scheduleTime.components(separatedBy: " - ").first
            ?? item.scheduleTime
        let newEndTime = changes["end_time"]
        let newTitle = changes["title"] ?? item.title

        // Rebuild time range
        let timeRange: String
        if let end = newEndTime {
            timeRange = "\(newTime) - \(end)"
        } else if changes["start_time"] != nil {
            timeRange = newTime
        } else {
            timeRange = item.scheduleTime
        }

        let newItem = ScheduleItem(
            id: item.id,
            scheduleTime: timeRange,
            title: newTitle,
            status: item.status,
            tag: item.tag,
            tagColor: item.tagColor,
            detail: item.detail // Keep original detail payload intact
        )
        schedule[index] = newItem

        return "已修改日程「\(title)」"
    }

    // MARK: - Query / Reminder / Suggest

    func querySchedule(date: String, timeRange: String?) -> String {
        if schedule.isEmpty {
            return "今天没有安排"
        }
        var result = "日程安排：\n"
        for item in schedule {
            let status: String
            switch item.status {
            case .done:     status = "[已完成]"
            case .active:   status = "[进行中]"
            case .upcoming: status = "[待办]"
            }
            result += "\(status) \(item.scheduleTime) \(item.title)\n"
        }
        return result
    }

    func setReminder(message: String, datetime: String, type: String) -> String {
        // TODO: Wire to UNUserNotificationCenter / CallKit in later tasks
        return "已设置\(type == "call" ? "电话" : "")提醒：\(datetime) \(message)"
    }

    func suggestSchedule(
        suggestion: String,
        date: String,
        startTime: String,
        endTime: String?,
        reason: String
    ) -> String {
        return "建议：\(suggestion)（\(reason)）"
    }
}
