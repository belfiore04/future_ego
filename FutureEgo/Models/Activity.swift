import Foundation
import CoreLocation

// MARK: - GeoPoint (Codable wrapper for CLLocationCoordinate2D)

/// `CLLocationCoordinate2D` is not `Codable` natively, so we wrap it.
/// Use `GeoPoint(coordinate:)` and `.coordinate` to bridge to MapKit APIs.
struct GeoPoint: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Activity (top-level 2-tier enum)

/// Top-level activity classification for a schedule item.
/// This replaces the old flat `CurrentEventData` enum. `.todo` is intentionally
/// removed — all previously-todo items must be mapped to concrete activities.
enum Activity: Codable, Hashable {
    case outing(OutingDetail)
    case eating(EatingDetail)
    case concentrating(ConcentratingDetail)
    case exercising(ExercisingDetail)
}

// MARK: - Activity display helpers

extension Activity {
    /// Short legacy-style time label used by existing UI until downstream tasks
    /// re-skin each detail view. Falls back to a reasonable default per category.
    ///
    /// Formatting rules (also consumed by `ScheduleManager.snapshotForAI`):
    /// - outing:           "HH:mm 到达"
    /// - eating/delivery:  "HH:mm"
    /// - eating/cook:      "HH:mm 开始做饭"
    /// - eating/eat_out:   "HH:mm"
    /// - concentrating:    "HH:mm - HH:mm"
    /// - exercising:       "HH:mm"
    var displayTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        switch self {
        case .outing(let d):
            return "\(formatter.string(from: d.arrivalTime)) 到达"
        case .eating(let eating):
            switch eating {
            case .delivery(let d):
                return formatter.string(from: d.mealTime)
            case .cook(let c):
                return "\(formatter.string(from: c.startTime)) 开始做饭"
            case .eatOut(let e):
                return formatter.string(from: e.appointmentTime)
            }
        case .concentrating(let d):
            return "\(formatter.string(from: d.startTime)) - \(formatter.string(from: d.endTime))"
        case .exercising(let d):
            return formatter.string(from: d.time)
        }
    }

    /// A single human-readable title for the activity, pulled from the payload's
    /// most-descriptive field. Useful for fuzzy title matching in
    /// `ScheduleManager.deleteSchedule` / `modifySchedule` and for the
    /// snapshotForAI output.
    var displayTitle: String {
        switch self {
        case .outing(let d):
            return d.activityName
        case .eating(let eating):
            switch eating {
            case .delivery(let d):
                return d.shopName
            case .cook(let c):
                return c.dishes.first?.name ?? "自己做饭"
            case .eatOut(let e):
                return e.restaurantName
            }
        case .concentrating(let d):
            return d.taskName
        case .exercising(let d):
            return d.exerciseType.isEmpty ? d.venueName : d.exerciseType
        }
    }

    /// Short tag like "outing" / "eating/delivery" / "concentrating" / etc.
    /// Used in `snapshotForAI` so the model can disambiguate subtypes.
    var typeTag: String {
        switch self {
        case .outing:
            return "outing"
        case .eating(let eating):
            switch eating {
            case .delivery: return "eating/delivery"
            case .cook:     return "eating/cook"
            case .eatOut:   return "eating/eat_out"
            }
        case .concentrating:
            return "concentrating"
        case .exercising:
            return "exercising"
        }
    }
}

// MARK: - EatingDetail (nested enum)

/// Second-tier classification for `.eating`. The three cases correspond to the
/// legacy `.delivery / .cook / .eatOut` CurrentEventData variants.
enum EatingDetail: Codable, Hashable {
    case delivery(DeliveryDetail)
    case cook(CookDetail)
    case eatOut(EatOutDetail)
}

// MARK: - OutingDetail

struct OutingDetail: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var arrivalTime: Date
    var destination: String
    var destinationCoordinate: GeoPoint?
    var activityName: String
    var itemsToBring: [String]
    var transitDurationMinutes: Int?
    var drivingDurationMinutes: Int?
    var latestDepartureTime: Date?
    /// Optional inspirational quote shown on the detail page. Populated later
    /// by AI post-processing or curated content — never by the AI tool call
    /// that creates the schedule. Defaults to `nil`; existing call sites are
    /// unaffected because the explicit init below does not require it.
    var inspirationQuote: String? = nil

    init(
        id: UUID = UUID(),
        arrivalTime: Date,
        destination: String,
        destinationCoordinate: GeoPoint? = nil,
        activityName: String,
        itemsToBring: [String] = [],
        transitDurationMinutes: Int? = nil,
        drivingDurationMinutes: Int? = nil,
        latestDepartureTime: Date? = nil
    ) {
        self.id = id
        self.arrivalTime = arrivalTime
        self.destination = destination
        self.destinationCoordinate = destinationCoordinate
        self.activityName = activityName
        self.itemsToBring = itemsToBring
        self.transitDurationMinutes = transitDurationMinutes
        self.drivingDurationMinutes = drivingDurationMinutes
        self.latestDepartureTime = latestDepartureTime
    }
}

// MARK: - DeliveryDetail

struct OrderItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantity: Int
    var price: Decimal

    init(id: UUID = UUID(), name: String, quantity: Int = 1, price: Decimal) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.price = price
    }
}

struct DeliveryDetail: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var mealTime: Date
    var shopName: String
    var estimatedDeliveryMinutes: Int
    var orderItems: [OrderItem]
    var estimatedTotalPrice: Decimal
    var isAIInferred: Bool
    /// Optional inspirational quote shown on the detail page. See
    /// `OutingDetail.inspirationQuote` for rationale.
    var inspirationQuote: String? = nil

    init(
        id: UUID = UUID(),
        mealTime: Date,
        shopName: String,
        estimatedDeliveryMinutes: Int,
        orderItems: [OrderItem] = [],
        estimatedTotalPrice: Decimal,
        isAIInferred: Bool = true
    ) {
        self.id = id
        self.mealTime = mealTime
        self.shopName = shopName
        self.estimatedDeliveryMinutes = estimatedDeliveryMinutes
        self.orderItems = orderItems
        self.estimatedTotalPrice = estimatedTotalPrice
        self.isAIInferred = isAIInferred
    }
}

// MARK: - CookDetail

struct CookDish: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var steps: [String]

    init(id: UUID = UUID(), name: String, steps: [String] = []) {
        self.id = id
        self.name = name
        self.steps = steps
    }
}

struct Ingredient: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantity: String

    init(id: UUID = UUID(), name: String, quantity: String) {
        self.id = id
        self.name = name
        self.quantity = quantity
    }
}

struct CookDetail: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var startTime: Date
    var dishes: [CookDish]
    var cookDurationMinutes: Int
    var ingredients: [Ingredient]
    /// Optional inspirational quote shown on the detail page. See
    /// `OutingDetail.inspirationQuote` for rationale.
    var inspirationQuote: String? = nil

    init(
        id: UUID = UUID(),
        startTime: Date,
        dishes: [CookDish] = [],
        cookDurationMinutes: Int,
        ingredients: [Ingredient] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.dishes = dishes
        self.cookDurationMinutes = cookDurationMinutes
        self.ingredients = ingredients
    }
}

// MARK: - EatOutDetail

struct EatOutDetail: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var appointmentTime: Date
    var companion: String
    var restaurantName: String
    var restaurantType: String
    var restaurantCoordinate: GeoPoint?
    var restaurantAddress: String
    var recommendedDishes: [String]
    /// Optional inspirational quote shown on the detail page. See
    /// `OutingDetail.inspirationQuote` for rationale.
    var inspirationQuote: String? = nil

    init(
        id: UUID = UUID(),
        appointmentTime: Date,
        companion: String,
        restaurantName: String,
        restaurantType: String,
        restaurantCoordinate: GeoPoint? = nil,
        restaurantAddress: String,
        recommendedDishes: [String] = []
    ) {
        self.id = id
        self.appointmentTime = appointmentTime
        self.companion = companion
        self.restaurantName = restaurantName
        self.restaurantType = restaurantType
        self.restaurantCoordinate = restaurantCoordinate
        self.restaurantAddress = restaurantAddress
        self.recommendedDishes = recommendedDishes
    }
}

// MARK: - ConcentratingDetail

struct ConcentratingDetail: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var startTime: Date
    var endTime: Date
    var taskName: String
    var deadline: Date?
    var steps: [String]
    var isAISuggested: Bool
    /// Optional inspirational quote shown on the detail page. See
    /// `OutingDetail.inspirationQuote` for rationale.
    var inspirationQuote: String? = nil

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        taskName: String,
        deadline: Date? = nil,
        steps: [String] = [],
        isAISuggested: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.taskName = taskName
        self.deadline = deadline
        self.steps = steps
        self.isAISuggested = isAISuggested
    }
}

// MARK: - ExercisingDetail

struct ExercisingDetail: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var time: Date
    var exerciseType: String
    var venueName: String
    var venueCoordinate: GeoPoint?
    var venueAddress: String
    var userEquipment: [String]
    var aiSuggestedEquipment: [String]
    /// Optional inspirational quote shown on the detail page. See
    /// `OutingDetail.inspirationQuote` for rationale.
    var inspirationQuote: String? = nil

    init(
        id: UUID = UUID(),
        time: Date,
        exerciseType: String,
        venueName: String,
        venueCoordinate: GeoPoint? = nil,
        venueAddress: String,
        userEquipment: [String] = [],
        aiSuggestedEquipment: [String] = []
    ) {
        self.id = id
        self.time = time
        self.exerciseType = exerciseType
        self.venueName = venueName
        self.venueCoordinate = venueCoordinate
        self.venueAddress = venueAddress
        self.userEquipment = userEquipment
        self.aiSuggestedEquipment = aiSuggestedEquipment
    }
}

// MARK: - ConcentratingDetail elapsed helpers

extension ConcentratingDetail {
    /// Seconds elapsed from `startTime` to `now`. Only meaningful for
    /// in-progress events. A negative return value indicates the event has
    /// not started yet — callers decide whether to show it.
    func elapsedSeconds(at now: Date = Date()) -> TimeInterval {
        now.timeIntervalSince(startTime)
    }

    /// Formats the elapsed time as `"H:MM:SS"` (e.g. `"1:23:21"`), for UI.
    /// Negative elapsed values clamp to zero so the UI never displays a
    /// negative timer.
    func elapsedFormatted(at now: Date = Date()) -> String {
        let total = max(0, Int(elapsedSeconds(at: now)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
