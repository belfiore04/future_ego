import Foundation
import SwiftUI

// MARK: - ThemeManager

/// Single source of truth for the app's dynamic tint color.
///
/// The tint follows the *currently focused* activity type — swapping colors as
/// `ScheduleManager.currentIndex` advances or as the schedule mutates. Views
/// should observe this manager rather than hard-coding per-activity colors.
///
/// Color mapping (see taskboard 2026-04-06 "颜色映射"):
/// - `.outing`         → `#007AFF`
/// - `.exercising`     → `#34C759`
/// - `.eating` (any)   → `#FF9500`
/// - `.concentrating`  → `#5856D6`
/// - `nil` / empty     → `#38B000` (brand green)
///
/// Kept `@MainActor` + singleton for consistency with `ScheduleManager.shared`.
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// The current global tint color. SwiftUI views observing this manager
    /// should bind to `tint` directly (e.g. `TabView(...).tint(themeManager.tint)`).
    @Published var tint: Color = Color(hex: "38B000")

    private init() {}

    /// Update the tint to match the supplied activity. Pass `nil` to fall back
    /// to the brand green used when the schedule is empty.
    ///
    /// The update is wrapped in `withAnimation(.easeInOut(duration: 0.4))` so
    /// observers see a smooth cross-fade instead of an instant color snap.
    func update(for activity: Activity?) {
        let next = Self.color(for: activity)
        // Avoid spurious animation ticks when nothing actually changed.
        guard next != tint else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            tint = next
        }
    }

    /// Pure mapping from activity → hex color. Centralized here so no other
    /// call site needs to know the per-activity palette.
    private static func color(for activity: Activity?) -> Color {
        guard let activity else {
            return Color(hex: "38B000")
        }
        switch activity {
        case .outing:
            return Color(hex: "007AFF")
        case .exercising:
            return Color(hex: "34C759")
        case .eating:
            return Color(hex: "FF9500")
        case .concentrating:
            return Color(hex: "5856D6")
        }
    }
}
