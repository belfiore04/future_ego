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

    /// Schedule items created via AI tool calls during the current call session.
    /// `CallingOverlay` observes this list and renders a card bubble for each
    /// new entry, giving the user immediate visual confirmation. Cleared by
    /// `clearAIAddedItemsThisCall()` when the call ends.
    @Published private(set) var aiAddedItemsThisCall: [ScheduleItem] = []

    /// Call from the AIService when a call session starts or ends so the
    /// overlay only shows cards for the current conversation.
    func clearAIAddedItemsThisCall() {
        aiAddedItemsThisCall = []
    }

    @AppStorage("use_mock_data") private var useMockData = false

    /// Fires once per minute so SwiftUI views that read `item.liveStatus`
    /// re-render when an event's time window rolls from upcoming → active
    /// → done. Without this, status changes are only reflected when some
    /// other @Published field happens to change.
    private var statusTicker: Timer?

    private init() {
        LaunchTrace.mark("ScheduleManager.init begin")
        if useMockData {
            loadMockData()
        } else {
            // Restore schedule from SwiftData so user's events survive relaunch.
            schedule = PersistenceService.shared.loadAllSchedules()
            LaunchTrace.mark("ScheduleManager.init loaded \(schedule.count) from disk")
        }
        startStatusTicker()
    }

    /// Mock mode is a developer-only snapshot; never mirror it to disk, or
    /// toggling mock off would leave fake items in the real schedule.
    private var persistenceEnabled: Bool { !useMockData }

    private func startStatusTicker() {
        statusTicker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }

    // MARK: - Mock Data (Developer)

    /// Replaces the schedule with `SampleData.schedule` for testing all
    /// activity detail page types. Called when the developer toggle is ON.
    func loadMockData() {
        schedule = SampleData.schedule
        currentIndex = 0
    }

    /// Restores the schedule from disk when mock mode is turned off so the
    /// user's real events come back.
    func clearMockData() {
        schedule = PersistenceService.shared.loadAllSchedules()
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
        // Reject unparseable dates rather than silently defaulting to today.
        // Previously `?? Date()` would land "明天的会" on today if the AI
        // sent a malformed string; the model now gets an error and retries.
        guard let baseDay = dayFormatter.date(from: date) else {
            return "日期格式错误：「\(date)」应为 YYYY-MM-DD"
        }
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

        // Insert at the correct chronological position based on the
        // detail's actual Date (sortKey). The old string compare on
        // scheduleTime (HH:MM) silently folded multi-day schedules into a
        // single day's time-of-day ordering.
        let newKey = newItem.detail.sortKey
        let insertIndex = schedule.firstIndex { $0.detail.sortKey > newKey } ?? schedule.count
        schedule.insert(newItem, at: insertIndex)

        if persistenceEnabled {
            PersistenceService.shared.upsertSchedule(newItem)
        }

        // Notify the call overlay so it can render a confirmation card.
        aiAddedItemsThisCall.append(newItem)

        // Kick off non-blocking MKLocalSearch so the detail page can show a
        // real map pin. The AI only provides name/address strings; we resolve
        // lat/lng here. Silently skipped for types that have no location.
        resolveAndAttachCoordinate(for: newItem)

        // MARK: Reminder integration
        //
        // outing → full ETA-based pipeline (home → destination MKDirections,
        // 15-min notification + 10-min CallKit reminder).
        // eat_out → single 30-min-before "准备出发" reminder.
        // Other types (concentrating, exercising, eating.delivery/cook) have
        // no reminders today.
        switch detail {
        case .outing(let outingDetail):
            Task {
                await ReminderService.shared.scheduleOutingReminders(
                    for: outingDetail,
                    scheduleId: newItem.id
                )
            }
        case .eating(.eatOut(let eatOutDetail)):
            ReminderService.shared.scheduleEatOutReminders(
                for: eatOutDetail,
                scheduleId: newItem.id
            )
        default:
            break
        }

        // Return a minimal ack so the model's follow-up reply doesn't parrot
        // the title/date/time back at the user — CallingOverlay already renders
        // a full card for the new item.
        return "OK"
    }

    // MARK: - Location Resolution (MapKit)

    /// Kick off an MKLocalSearch for the item's destination/venue/restaurant
    /// name and write the resulting GeoPoint back into the Activity enum.
    /// Non-blocking: runs in a detached Task; if the lookup fails the item
    /// just stays without a coordinate.
    private func resolveAndAttachCoordinate(for item: ScheduleItem) {
        let query: String?
        switch item.detail {
        case .outing(let d):
            query = d.destination
        case .exercising(let d):
            query = d.venueAddress.isEmpty ? d.venueName : d.venueAddress
        case .eating(.eatOut(let d)):
            query = d.restaurantAddress.isEmpty ? d.restaurantName : d.restaurantAddress
        default:
            return
        }
        guard let q = query, !q.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let point = await LocationResolverService.resolve(q) else { return }
            self?.applyCoordinate(point, to: item.id)
        }
    }

    /// Find the item by id and write `point` into the appropriate coordinate
    /// field of its Activity payload. No-op if the item was removed or its
    /// type doesn't carry a coordinate.
    private func applyCoordinate(_ point: GeoPoint, to id: UUID) {
        guard let idx = schedule.firstIndex(where: { $0.id == id }) else { return }
        let item = schedule[idx]
        let newDetail: Activity
        switch item.detail {
        case .outing(var d):
            d.destinationCoordinate = point
            newDetail = .outing(d)
        case .exercising(var d):
            d.venueCoordinate = point
            newDetail = .exercising(d)
        case .eating(.eatOut(var d)):
            d.restaurantCoordinate = point
            newDetail = .eating(.eatOut(d))
        default:
            return
        }
        let updated = ScheduleItem(
            id: item.id,
            scheduleTime: item.scheduleTime,
            title: item.title,
            status: item.status,
            tag: item.tag,
            tagColor: item.tagColor,
            detail: newDetail
        )
        schedule[idx] = updated

        if persistenceEnabled {
            PersistenceService.shared.upsertSchedule(updated)
        }
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
        let isBulk = title.contains("所有")

        // Narrow by day first if the AI gave us one — reduces the chance of
        // a fuzzy title accidentally nuking events on other days.
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let targetDay = date.flatMap { dayFormatter.date(from: $0) }
        let cal = Calendar.current

        func sameDay(_ item: ScheduleItem) -> Bool {
            guard let targetDay else { return true }
            return cal.isDate(item.detail.sortKey, inSameDayAs: targetDay)
        }

        func titleMatches(_ item: ScheduleItem) -> Bool {
            if isBulk { return true }
            if item.title.contains(title) { return true }
            if item.detail.displayTitle.contains(title) { return true }
            return false
        }

        func matches(_ item: ScheduleItem) -> Bool {
            sameDay(item) && titleMatches(item)
        }

        let victims = schedule.filter(matches)

        if victims.isEmpty {
            return "未找到匹配的日程「\(title)」"
        }

        // Safety net: the old implementation substring-matched title against
        // every item and silently deleted them all. Saying "取消会议" with
        // three different meetings in the day would zap all three. Now we
        // refuse to proceed for ambiguous fuzzy deletes and hand the AI back
        // a list to re-ask the user with — unless the user explicitly said
        // "所有" (isBulk).
        if !isBulk && victims.count > 1 {
            let list = victims
                .prefix(5)
                .map { "「\($0.title)」\($0.scheduleTime)" }
                .joined(separator: "、")
            return "匹配到 \(victims.count) 条：\(list)。请说得更具体（哪天、哪个时间）。"
        }

        for item in victims {
            ReminderService.shared.cancelReminders(scheduleId: item.id)
            if persistenceEnabled {
                PersistenceService.shared.deleteSchedule(id: item.id)
            }
        }

        schedule.removeAll(where: matches)
        if currentIndex >= schedule.count {
            currentIndex = max(0, schedule.count - 1)
        }
        return "已删除 \(victims.count) 个日程"
    }

    func modifySchedule(title: String, date: String?, changes: [String: String]) -> String {
        // Fuzzy match on either the top-level title or the inner displayTitle.
        guard let index = schedule.firstIndex(where: {
            $0.title.contains(title) || $0.detail.displayTitle.contains(title)
        }) else {
            return "未找到日程「\(title)」"
        }

        let item = schedule[index]
        let cal = Calendar.current

        // --- Figure out the new time window.
        //
        // The AI sends changes as "HH:MM" strings scoped to the event's
        // existing day. To rebuild the detail's Date fields we anchor to the
        // original sortKey's day.
        func parseTime(_ str: String, on day: Date) -> Date? {
            let parts = str.split(separator: ":").compactMap { Int($0) }
            guard let hour = parts.first, (0...23).contains(hour) else { return nil }
            let minute = parts.count > 1 ? parts[1] : 0
            guard (0...59).contains(minute) else { return nil }
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        }

        let anchorDay = item.detail.sortKey
        let (origStart, origEnd) = item.detail.timeWindow
        let origDuration = origEnd.timeIntervalSince(origStart)

        let newStart: Date
        if let startStr = changes["start_time"] {
            guard let parsed = parseTime(startStr, on: anchorDay) else {
                return "时间格式错误：「\(startStr)」应为 HH:MM"
            }
            newStart = parsed
        } else {
            newStart = origStart
        }

        let newEnd: Date
        if let endStr = changes["end_time"] {
            guard let parsed = parseTime(endStr, on: anchorDay) else {
                return "时间格式错误：「\(endStr)」应为 HH:MM"
            }
            newEnd = parsed
        } else if changes["start_time"] != nil {
            // Start moved but end wasn't explicitly set — preserve the
            // original duration so "推迟一小时" doesn't collapse a 2-hour
            // block into a single time point.
            newEnd = newStart.addingTimeInterval(origDuration)
        } else {
            newEnd = origEnd
        }

        // --- Rebuild the detail with new times (and optional location/title).
        var newDetail = rewriteActivityTimes(item.detail, start: newStart, end: newEnd)
        var locationChanged = false
        if let loc = changes["location"], !loc.isEmpty {
            if let rewritten = rewriteActivityLocation(newDetail, to: loc) {
                newDetail = rewritten
                locationChanged = true
            }
            // For types without a location concept (concentrating / cook /
            // delivery) we silently ignore the location change — it's the
            // only sensible option short of rejecting the whole modify.
        }

        // --- Rebuild the display time string. Keep a range if the original
        // had one OR if the user explicitly provided an end_time.
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let startStr = fmt.string(from: newStart)
        let endStr = fmt.string(from: newEnd)
        let hadRange = item.scheduleTime.contains(" - ") || changes["end_time"] != nil
        let newScheduleTime = hadRange ? "\(startStr) - \(endStr)" : startStr

        let newTitle = changes["title"] ?? item.title

        let newItem = ScheduleItem(
            id: item.id,
            scheduleTime: newScheduleTime,
            title: newTitle,
            status: item.status,
            tag: item.tag,
            tagColor: item.tagColor,
            detail: newDetail
        )

        // Remove + re-insert so the array stays sorted by the (possibly
        // moved) sortKey. In-place assignment would leave a moved event at
        // its old position until the next addSchedule.
        schedule.remove(at: index)
        let newKey = newItem.detail.sortKey
        let insertIndex = schedule.firstIndex { $0.detail.sortKey > newKey } ?? schedule.count
        schedule.insert(newItem, at: insertIndex)

        if persistenceEnabled {
            PersistenceService.shared.upsertSchedule(newItem)
        }

        // Re-register reminders if the time moved; cancel+re-schedule handles both.
        if changes["start_time"] != nil || changes["end_time"] != nil || locationChanged {
            switch newDetail {
            case .outing(let d):
                Task {
                    await ReminderService.shared.scheduleOutingReminders(for: d, scheduleId: newItem.id)
                }
            case .eating(.eatOut(let d)):
                ReminderService.shared.scheduleEatOutReminders(for: d, scheduleId: newItem.id)
            default:
                break
            }
        }

        // If location changed, re-resolve its map coordinate.
        if locationChanged {
            resolveAndAttachCoordinate(for: newItem)
        }

        return "已修改日程「\(title)」"
    }

    // MARK: - Activity rewriters (used by modifySchedule)

    /// Apply new start/end Dates to whichever per-type field actually holds
    /// the event's time. Structs whose schema doesn't have an end field
    /// (outing, exercising, eating.delivery, eating.eatOut) just take the
    /// new start — the end is synthesized from a default duration via
    /// `Activity.timeWindow` as before.
    private func rewriteActivityTimes(_ activity: Activity, start: Date, end: Date) -> Activity {
        switch activity {
        case .outing(var d):
            d.arrivalTime = start
            return .outing(d)
        case .eating(.delivery(var d)):
            d.mealTime = start
            return .eating(.delivery(d))
        case .eating(.cook(var d)):
            d.startTime = start
            let minutes = max(5, Int(end.timeIntervalSince(start) / 60))
            d.cookDurationMinutes = minutes
            return .eating(.cook(d))
        case .eating(.eatOut(var d)):
            d.appointmentTime = start
            return .eating(.eatOut(d))
        case .concentrating(var d):
            d.startTime = start
            d.endTime = end
            return .concentrating(d)
        case .exercising(var d):
            d.time = start
            return .exercising(d)
        }
    }

    /// Write a new location string into whichever name/address field the
    /// Activity uses. Returns nil for types that have no location concept
    /// so the caller can decide whether to warn or silently ignore.
    /// Invalidates any cached coordinate so MapKit will re-resolve.
    private func rewriteActivityLocation(_ activity: Activity, to location: String) -> Activity? {
        switch activity {
        case .outing(var d):
            d.destination = location
            d.destinationCoordinate = nil
            return .outing(d)
        case .eating(.eatOut(var d)):
            d.restaurantName = location
            d.restaurantCoordinate = nil
            return .eating(.eatOut(d))
        case .exercising(var d):
            d.venueName = location
            d.venueCoordinate = nil
            return .exercising(d)
        case .concentrating, .eating(.delivery), .eating(.cook):
            return nil
        }
    }

    // MARK: - Query / Reminder / Suggest

    func querySchedule(date: String, timeRange: String?) -> String {
        // Parse the target day. Falls back to today if the AI sends garbage,
        // matching addSchedule's lenient behavior; we log at the call site
        // by returning the parsed day in the response.
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let target = dayFormatter.date(from: date) ?? Date()
        let calendar = Calendar.current

        // Narrow to items whose sortKey falls on the target day.
        var filtered = schedule.filter {
            calendar.isDate($0.detail.sortKey, inSameDayAs: target)
        }

        // Further narrow by timeRange bucket (morning/afternoon/evening).
        // `all` and `nil` keep the full day.
        switch timeRange?.lowercased() {
        case "morning":
            filtered = filtered.filter { calendar.component(.hour, from: $0.detail.sortKey) < 12 }
        case "afternoon":
            filtered = filtered.filter {
                let h = calendar.component(.hour, from: $0.detail.sortKey)
                return h >= 12 && h < 18
            }
        case "evening":
            filtered = filtered.filter { calendar.component(.hour, from: $0.detail.sortKey) >= 18 }
        default:
            break
        }

        guard !filtered.isEmpty else {
            return "这个时段没有安排"
        }

        var result = "日程安排：\n"
        for item in filtered {
            let status: String
            switch item.liveStatus {
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
