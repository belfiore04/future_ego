import Foundation
import SwiftUI

// MARK: - ScheduleManager

/// Bridges AI function calls to actual schedule data operations.
/// Singleton accessed from both AIService (tool execution) and SwiftUI views.
@MainActor
class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    /// Current schedule list (initialized from SampleData, then mutated by user/AI).
    @Published var schedule: [ScheduleItem] = SampleData.schedule
    @Published var currentIndex: Int = SampleData.currentIndex

    private init() {}

    // MARK: - Function Handlers

    func addSchedule(
        title: String,
        date: String,
        startTime: String,
        endTime: String?,
        type: String,
        location: String?,
        items: [String]?,
        notes: String?
    ) -> String {
        let detail: CurrentEventData
        switch type {
        case "location":
            detail = .location(LocationEvent(
                time: startTime,
                endTime: endTime,
                name: title,
                address: location ?? "",
                cardTitle: "备注",
                items: items ?? []
            ))
        case "cook":
            detail = .cook(CookEvent(
                time: startTime,
                dishes: [CookDish(name: title, steps: items ?? [])],
                cookTime: endTime.map { "约\($0)完成" } ?? "",
                ingredients: []
            ))
        case "eat_out":
            detail = .eatOut(EatOutEvent(
                time: startTime,
                guest: "",
                restaurant: title,
                cuisine: notes ?? "",
                address: location ?? "",
                recommendedDishes: []
            ))
        case "delivery":
            detail = .delivery(DeliveryEvent(
                time: startTime,
                shop: title,
                deliveryTime: endTime ?? "约30分钟",
                items: [],
                totalPrice: notes ?? ""
            ))
        default: // "todo"
            detail = .todo(TodoEvent(
                time: startTime,
                endTime: endTime ?? "",
                name: title,
                deadline: notes ?? "",
                steps: items ?? []
            ))
        }

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

        return "已添加日程「\(title)」到 \(date) \(startTime)"
    }

    func deleteSchedule(title: String, date: String?) -> String {
        let before = schedule.count
        schedule.removeAll { item in
            item.title.contains(title) || title.contains("所有")
        }
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
        guard let index = schedule.firstIndex(where: { $0.title.contains(title) }) else {
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
            scheduleTime: timeRange,
            title: newTitle,
            status: item.status,
            tag: item.tag,
            tagColor: item.tagColor,
            detail: item.detail // Keep original detail
        )
        schedule[index] = newItem

        return "已修改日程「\(title)」"
    }

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
