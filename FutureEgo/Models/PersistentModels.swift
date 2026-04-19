import SwiftData
import Foundation

// MARK: - Schedule Status Persistence

@Model
class PersistedScheduleStatus {
    /// Schedule item title (unique identifier since SampleData titles are unique)
    @Attribute(.unique) var title: String
    /// Status string: done / active / upcoming
    var statusRaw: String
    /// Completed step indices for an Activity's step list (e.g. ConcentratingDetail.steps or CookDish.steps)
    var completedStepIndices: [Int]
    /// Last updated timestamp
    var updatedAt: Date

    init(title: String, statusRaw: String = "upcoming", completedStepIndices: [Int] = [], updatedAt: Date = .now) {
        self.title = title
        self.statusRaw = statusRaw
        self.completedStepIndices = completedStepIndices
        self.updatedAt = updatedAt
    }
}

// MARK: - Sticker Persistence

@Model
class PersistedSticker {
    var id: UUID
    /// Sticker image file name (stored in Documents/stickers/)
    var imageFileName: String
    /// Sticker position x on screen
    var positionX: Double
    /// Sticker position y on screen
    var positionY: Double
    /// Scale factor
    var scale: Double
    /// Created timestamp
    var createdAt: Date

    init(id: UUID = UUID(), imageFileName: String, positionX: Double = 0, positionY: Double = 0, scale: Double = 1.0, createdAt: Date = .now) {
        self.id = id
        self.imageFileName = imageFileName
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.createdAt = createdAt
    }
}

// MARK: - Chat Message Persistence

@Model
class PersistedChatMessage {
    var id: UUID
    /// "user" or "ai"
    var role: String
    var text: String
    var timestamp: Date

    init(id: UUID = UUID(), role: String, text: String, timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Schedule Persistence
//
// Stores the full schedule array so it survives app relaunch. The inner
// `Activity` enum is Codable; we persist it as a JSON blob rather than
// flattening every associated-value field into SwiftData columns, because
// the shape varies per type/sub_type and flattening would require a
// migration every time we add a field to one of the detail structs.

@Model
class PersistedSchedule {
    @Attribute(.unique) var id: UUID
    /// Display string ("HH:MM" or "HH:MM - HH:MM") — mirrors ScheduleItem.scheduleTime.
    var scheduleTime: String
    var title: String
    /// Manual status override ("done" / "active" / "upcoming"). `.upcoming`
    /// is the sentinel for "no override, derive from time at read time".
    var statusRaw: String
    /// JSON-encoded `Activity` enum. Decoded back at load time.
    var detailBlob: Data
    var createdAt: Date

    init(
        id: UUID,
        scheduleTime: String,
        title: String,
        statusRaw: String,
        detailBlob: Data,
        createdAt: Date = .now
    ) {
        self.id = id
        self.scheduleTime = scheduleTime
        self.title = title
        self.statusRaw = statusRaw
        self.detailBlob = detailBlob
        self.createdAt = createdAt
    }
}
