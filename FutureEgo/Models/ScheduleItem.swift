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
    /// Manual status override (e.g. user marked something `.done` explicitly).
    /// `.upcoming` here is the sentinel for "no override, derive from time"
    /// — use `liveStatus` for display.
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

    /// Status computed from `detail.timeWindow` vs `now`. If the stored
    /// `status` is `.done`, we honor it as an explicit manual completion
    /// (so a user-marked-done event stays done even after the time window
    /// rolls off). Otherwise we derive:
    /// - `now < start` → `.upcoming`
    /// - `start ≤ now ≤ end` → `.active`
    /// - `now > end` → `.done`
    ///
    /// Views should read `liveStatus`, not `status`, so they reflect the
    /// clock. `ScheduleManager` ticks `objectWillChange` once a minute to
    /// trigger SwiftUI re-renders.
    var liveStatus: EventStatus {
        if status == .done { return .done }
        let (start, end) = detail.timeWindow
        let now = Date()
        if now < start { return .upcoming }
        if now > end { return .done }
        return .active
    }
}
