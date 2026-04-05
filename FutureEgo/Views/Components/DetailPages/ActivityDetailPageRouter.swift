import SwiftUI

// MARK: - ActivityDetailPageRouter
//
// Dispatches the currently focused `Activity` to the matching
// redesigned detail page. Wave 3 wires the six real pages produced
// in Wave 2 (exercising / outing / delivery / cook / eatOut /
// concentrating). The switch is intentionally exhaustive — no
// `default:` branch — so the compiler flags any future additions to
// `Activity` / `EatingDetail`.
//
// Spec: `/home/jun/future_ego/.pm/2026-04-06/task-10/spec.md`.

struct ActivityDetailPageRouter: View {
    let activity: Activity

    var body: some View {
        switch activity {
        case .outing(let detail):
            OutingDetailPage(detail: detail)
        case .exercising(let detail):
            ExercisingDetailPage(detail: detail)
        case .eating(.delivery(let detail)):
            DeliveryDetailPage(detail: detail)
        case .eating(.cook(let detail)):
            CookDetailPage(detail: detail)
        case .eating(.eatOut(let detail)):
            EatOutDetailPage(detail: detail)
        case .concentrating(let detail):
            ConcentratingDetailPage(detail: detail)
        }
    }
}
