import SwiftUI

// MARK: - Color hex init
//
// The old flat `CurrentEventData` enum (and its LocationEvent/TodoEvent/
// EatOutEvent/CookEvent/DeliveryEvent/RecommendedDish/DeliveryItem/… structs)
// previously lived in this file. They have been replaced by the 2-tier
// `Activity` enum defined in `Activity.swift`. The `Color(hex:)` helper is
// retained here because many views depend on it.

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: Double
        switch hex.count {
        case 6: // RGB
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                1
            )
        case 8: // ARGB
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                Double((int >> 24) & 0xFF) / 255
            )
        default:
            (r, g, b, a) = (0, 0, 0, 1)
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
