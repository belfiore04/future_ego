import SwiftUI

// MARK: - CurrentEventData

enum CurrentEventData {
    case location(LocationEvent)
    case todo(TodoEvent)
    case eatOut(EatOutEvent)
    case cook(CookEvent)
    case delivery(DeliveryEvent)
}

// MARK: - LocationEvent

struct LocationEvent: Identifiable {
    let id = UUID()
    let time: String
    let endTime: String?
    let name: String
    let address: String
    let cardTitle: String
    let items: [String]
}

// MARK: - TodoEvent

struct TodoEvent: Identifiable {
    let id = UUID()
    let time: String
    let endTime: String
    let name: String
    let deadline: String
    let steps: [String]
}

// MARK: - EatOutEvent

struct RecommendedDish: Identifiable {
    let id = UUID()
    let name: String
    let desc: String
}

struct EatOutEvent: Identifiable {
    let id = UUID()
    let time: String
    let guest: String
    let restaurant: String
    let cuisine: String
    let address: String
    let recommendedDishes: [RecommendedDish]
}

// MARK: - CookEvent

struct CookDish: Identifiable {
    let id = UUID()
    let name: String
    let steps: [String]
}

struct Ingredient: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
}

struct CookEvent: Identifiable {
    let id = UUID()
    let time: String
    let dishes: [CookDish]
    let cookTime: String
    let ingredients: [Ingredient]
}

// MARK: - DeliveryEvent

struct DeliveryItem: Identifiable {
    let id = UUID()
    let name: String
    let price: String
}

struct DeliveryEvent: Identifiable {
    let id = UUID()
    let time: String
    let shop: String
    let deliveryTime: String
    let items: [DeliveryItem]
    let totalPrice: String
}

// MARK: - Color hex init

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
