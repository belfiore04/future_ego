import SwiftData
import UIKit

// MARK: - PersistenceService

@MainActor
class PersistenceService: ObservableObject {
    static let shared = PersistenceService()

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([
            PersistedScheduleStatus.self,
            PersistedSticker.self,
            PersistedChatMessage.self,
            PersistedSchedule.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    // MARK: - Schedule (full items)

    /// JSON coders shared by the schedule encode/decode paths.
    private static let scheduleEncoder = JSONEncoder()
    private static let scheduleDecoder = JSONDecoder()

    /// Load every persisted schedule item, decoded back into ScheduleItem.
    /// Undecodable rows are skipped (they'd come from a stale schema), so a
    /// bad migration doesn't wipe the list — just elides the bad entries.
    func loadAllSchedules() -> [ScheduleItem] {
        let descriptor = FetchDescriptor<PersistedSchedule>(sortBy: [SortDescriptor(\.createdAt)])
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows.compactMap { row -> ScheduleItem? in
            guard let detail = try? Self.scheduleDecoder.decode(Activity.self, from: row.detailBlob) else {
                return nil
            }
            let status = EventStatus(rawValue: row.statusRaw) ?? .upcoming
            return ScheduleItem(
                id: row.id,
                scheduleTime: row.scheduleTime,
                title: row.title,
                status: status,
                tag: nil,
                tagColor: nil,
                detail: detail
            )
        }
    }

    /// Insert or update the persisted row for a ScheduleItem. Called after
    /// every ScheduleManager mutation so the on-disk state always mirrors
    /// the in-memory array.
    func upsertSchedule(_ item: ScheduleItem) {
        guard let blob = try? Self.scheduleEncoder.encode(item.detail) else { return }
        let id = item.id
        let predicate = #Predicate<PersistedSchedule> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first {
            existing.scheduleTime = item.scheduleTime
            existing.title = item.title
            existing.statusRaw = item.status.rawValue
            existing.detailBlob = blob
        } else {
            let row = PersistedSchedule(
                id: item.id,
                scheduleTime: item.scheduleTime,
                title: item.title,
                statusRaw: item.status.rawValue,
                detailBlob: blob
            )
            context.insert(row)
        }
        try? context.save()
    }

    func deleteSchedule(id: UUID) {
        let predicate = #Predicate<PersistedSchedule> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let row = try? context.fetch(descriptor).first {
            context.delete(row)
            try? context.save()
        }
    }

    // MARK: - Schedule Status

    func loadScheduleStatus(for title: String) -> PersistedScheduleStatus? {
        let predicate = #Predicate<PersistedScheduleStatus> { $0.title == title }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? context.fetch(descriptor).first
    }

    func saveScheduleStatus(title: String, status: String, completedSteps: [Int]) {
        if let existing = loadScheduleStatus(for: title) {
            existing.statusRaw = status
            existing.completedStepIndices = completedSteps
            existing.updatedAt = .now
        } else {
            let new = PersistedScheduleStatus(title: title, statusRaw: status, completedStepIndices: completedSteps)
            context.insert(new)
        }
        try? context.save()
    }

    // MARK: - Stickers

    func loadStickers() -> [PersistedSticker] {
        let descriptor = FetchDescriptor<PersistedSticker>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveSticker(image: UIImage) -> PersistedSticker? {
        guard let data = image.pngData() else { return nil }
        let fileName = UUID().uuidString + ".png"
        let dir = Self.stickersDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent(fileName)
        try? data.write(to: fileURL)

        let sticker = PersistedSticker(imageFileName: fileName)
        context.insert(sticker)
        try? context.save()
        return sticker
    }

    func deleteSticker(_ sticker: PersistedSticker) {
        // Delete image file
        let fileURL = Self.stickersDirectory.appendingPathComponent(sticker.imageFileName)
        try? FileManager.default.removeItem(at: fileURL)
        context.delete(sticker)
        try? context.save()
    }

    func loadStickerImage(_ sticker: PersistedSticker) -> UIImage? {
        let fileURL = Self.stickersDirectory.appendingPathComponent(sticker.imageFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static var stickersDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("stickers")
    }

    // MARK: - Chat Messages

    func loadChatHistory() -> [PersistedChatMessage] {
        let descriptor = FetchDescriptor<PersistedChatMessage>(sortBy: [SortDescriptor(\.timestamp)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveChatMessage(role: String, text: String) {
        let msg = PersistedChatMessage(role: role, text: text)
        context.insert(msg)
        try? context.save()
    }

    func clearChatHistory() {
        let descriptor = FetchDescriptor<PersistedChatMessage>()
        if let all = try? context.fetch(descriptor) {
            for msg in all { context.delete(msg) }
        }
        try? context.save()
    }
}
