import SwiftUI
import UIKit
import Combine

// MARK: - StickerStore
//
// In-memory mirror of TODAY'S sticker badges, kept in sync with
// `PersistenceService`. Singleton so `CurrentTabView` (writer) and
// `DetailPageShell` (reader) can share state without prop drilling
// through every detail page.
//
// Daily reset rule: stickers created on a previous calendar day are
// purged — both the on-disk PNG file and the SwiftData row. Reset
// fires on three triggers:
//   1. `refresh()` called from `CurrentTabView.onAppear`
//   2. `UIApplication.significantTimeChangeNotification` (midnight,
//      timezone change, etc.) while app is running
//   3. `UIApplication.willEnterForegroundNotification` (returning from
//      background after midnight)

@MainActor
final class StickerStore: ObservableObject {
    static let shared = StickerStore()

    /// Today's badges, oldest first. Newest gets stacked on top in the UI.
    @Published private(set) var badges: [StickerBadge] = []

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        refresh()

        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            .store(in: &cancellables)
    }

    /// Re-read from persistence, purging anything older than today.
    func refresh() {
        PersistenceService.shared.purgeStickersBeforeToday()
        let rows = PersistenceService.shared.loadTodayStickers()
        badges = rows.compactMap { row in
            guard let img = PersistenceService.shared.loadStickerImage(row) else { return nil }
            return StickerBadge(id: row.id, image: img, createdAt: row.createdAt)
        }
    }

    /// Append a new badge. Persists first, then mirrors in memory so the
    /// in-memory id matches the on-disk row.
    func append(image: UIImage) {
        guard let row = PersistenceService.shared.saveSticker(image: image) else { return }
        let badge = StickerBadge(id: row.id, image: image, createdAt: row.createdAt)
        badges.append(badge)
    }
}

// MARK: - Badge model

struct StickerBadge: Identifiable, Equatable {
    let id: UUID
    let image: UIImage
    let createdAt: Date

    /// Stable pseudo-random rotation in [-12°, 12°], derived from the id.
    /// Same badge → same angle every render, so a card refresh doesn't
    /// reshuffle the pile.
    var rotationDegrees: Double {
        let h = abs(id.hashValue)
        return Double(h % 240) / 10.0 - 12.0
    }

    /// Stable pseudo-random horizontal jitter in pt, ±6.
    var horizontalJitter: CGFloat {
        let h = abs(id.hashValue >> 8)
        return CGFloat(h % 120) / 10.0 - 6.0
    }

    static func == (lhs: StickerBadge, rhs: StickerBadge) -> Bool {
        lhs.id == rhs.id
    }
}
