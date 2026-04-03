import SwiftUI

// MARK: - EventStatus

enum EventStatus: String {
    case done
    case active
    case upcoming
}

// MARK: - ScheduleItem

struct ScheduleItem: Identifiable {
    let id = UUID()
    let scheduleTime: String
    let title: String
    let status: EventStatus
    let tag: String?
    let tagColor: Color?
    let detail: CurrentEventData
}
