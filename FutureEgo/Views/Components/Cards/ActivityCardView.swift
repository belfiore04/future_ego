import SwiftUI

// MARK: - ActivityCardView
//
// Top-level dispatcher that switches on an `Activity` value and renders the
// corresponding card. This is the single call site used by both
// `CurrentEventView` and `DailyPlanTabView`'s event detail sheet, so that
// the 6 cards have exactly one place they are wired up.
//
// Covers all 4 `Activity` cases, including all 3 `EatingDetail` sub-cases:
//   .outing                → OutingCard
//   .eating(.delivery)     → DeliveryCard
//   .eating(.cook)         → CookCard
//   .eating(.eatOut)       → EatOutCard
//   .concentrating         → ConcentratingCard
//   .exercising            → ExercisingCard

struct ActivityCardView: View {
    let activity: Activity
    let status: EventStatus

    var body: some View {
        switch activity {
        case .outing(let d):
            OutingCard(detail: d, status: status)

        case .eating(let eating):
            switch eating {
            case .delivery(let d):
                DeliveryCard(detail: d, status: status)
            case .cook(let c):
                CookCard(detail: c, status: status)
            case .eatOut(let e):
                EatOutCard(detail: e, status: status)
            }

        case .concentrating(let d):
            ConcentratingCard(detail: d, status: status)

        case .exercising(let d):
            ExercisingCard(detail: d, status: status)
        }
    }
}

// MARK: - Preview — every case

#Preview("All cases") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(SampleData.schedule) { item in
                ActivityCardView(activity: item.detail, status: item.status)
            }
        }
        .padding()
    }
}
