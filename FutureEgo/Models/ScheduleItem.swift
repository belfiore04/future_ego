import SwiftUI

// MARK: - EventStatus

enum EventStatus: String, Codable {
    case done
    case active
    case upcoming
}

// MARK: - ScheduleItem

struct ScheduleItem: Identifiable {
    let id: UUID
    let scheduleTime: String
    let title: String
    let status: EventStatus
    let tag: String?
    let tagColor: Color?
    let detail: Activity

    init(
        id: UUID = UUID(),
        scheduleTime: String,
        title: String,
        status: EventStatus,
        tag: String? = nil,
        tagColor: Color? = nil,
        detail: Activity
    ) {
        self.id = id
        self.scheduleTime = scheduleTime
        self.title = title
        self.status = status
        self.tag = tag
        self.tagColor = tagColor
        self.detail = detail
    }
}
