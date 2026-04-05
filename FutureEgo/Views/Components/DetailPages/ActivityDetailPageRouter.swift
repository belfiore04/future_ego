import SwiftUI

// MARK: - ActivityDetailPageRouter
//
// Dispatches the currently focused `Activity` to the matching
// redesigned detail page. During Wave 0 every branch returns a simple
// `Text` placeholder so the project compiles while the real pages are
// still being written in Wave 2. The switch is intentionally
// exhaustive — no `default:` branch — so the compiler flags any future
// additions to `Activity` / `EatingDetail`.
//
// Spec: `/home/jun/future_ego/.pm/2026-04-06/task-1/spec.md`.

struct ActivityDetailPageRouter: View {
    let activity: Activity

    var body: some View {
        switch activity {
        case .outing:
            stub("outing")
        case .exercising:
            stub("exercising")
        case .eating(.delivery):
            stub("eating-delivery")
        case .eating(.cook):
            stub("eating-cook")
        case .eating(.eatOut):
            stub("eating-eatOut")
        case .concentrating:
            stub("concentrating")
        }
    }

    @ViewBuilder
    private func stub(_ name: String) -> some View {
        Text("TODO: \(name)")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray)
    }
}
