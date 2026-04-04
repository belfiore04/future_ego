import SwiftData
import Foundation

// MARK: - Schedule Status Persistence

@Model
class PersistedScheduleStatus {
    /// Schedule item title (unique identifier since SampleData titles are unique)
    @Attribute(.unique) var title: String
    /// Status string: done / active / upcoming
    var statusRaw: String
    /// Completed step indices for TodoEvent
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
