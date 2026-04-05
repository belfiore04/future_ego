import SwiftUI

// MARK: - ActivityDetailPageRouter
//
// Dispatches the currently focused `Activity` to the matching redesigned
// detail page (Wave 2 / Wave 3 output). This replaces the old
// `CurrentEventView` switchboard and is the single entry point used by
// `CurrentTabView` to render the body of the "此刻" tab.
//
// The switch is intentionally exhaustive with no `default:` branch so the
// compiler flags any future additions to `Activity` / `EatingDetail`.
//
// Spec: `/home/jun/.pm/2026-04-06/task-10/spec.md`.

struct ActivityDetailPageRouter: View {
    let activity: Activity

    var body: some View {
        switch activity {
        case .outing(let d):
            OutingDetailPage(detail: d)
        case .exercising(let d):
            ExercisingDetailPage(detail: d)
        case .eating(.delivery(let d)):
            DeliveryDetailPage(detail: d)
        case .eating(.cook(let d)):
            CookDetailPage(detail: d)
        case .eating(.eatOut(let d)):
            EatOutDetailPage(detail: d)
        case .concentrating(let d):
            ConcentratingDetailPage(detail: d)
        }
    }
}
