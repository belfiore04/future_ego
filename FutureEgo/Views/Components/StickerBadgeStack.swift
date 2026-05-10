import SwiftUI

// MARK: - StickerBadgeStack
//
// Renders today's sticker badges as a sticky-note pile in the left
// region of the back card. Newest badge sits on top with the largest
// rotation amplitude, older ones recede slightly.
//
// The stack reads from `StickerStore.shared` so any of the four detail
// pages picks it up automatically without prop drilling.
//
// Each badge gets a stable rotation/jitter derived from its UUID
// (see StickerStore.StickerBadge), so re-renders don't reshuffle the
// pile.

struct StickerBadgeStack: View {
    @ObservedObject var store: StickerStore = .shared

    /// Width/height of the square badge frame.
    var size: CGFloat = 92

    /// Pulled from the environment so we don't have to pass it through
    /// every detail-page initializer. `CurrentTabView` injects its
    /// `@Namespace`, and `StickerEditView` commits stickers via
    /// `commitSticker`, which performs a `matchedGeometryEffect` into
    /// the newest badge in this stack.
    @Environment(\.stickerFlightNamespace) private var flightNamespace
    var flightID: String = "sticker-flight"

    /// Most recent badge id, used to advertise the matched-geometry
    /// destination only on the newest sticker (so the fly-in animation
    /// targets the top of the pile).
    private var newestID: UUID? {
        store.badges.last?.id
    }

    var body: some View {
        ZStack {
            // Cap visible pile depth at 5 so the stack doesn't sprawl
            // over the progress ring on busy days. Older badges are
            // still in `store.badges` for persistence; just not drawn.
            let visible = Array(store.badges.suffix(5).enumerated())
            ForEach(visible, id: \.element.id) { offset, badge in
                badgeView(badge: badge, depthFromTop: visible.count - 1 - offset)
            }
        }
        .frame(width: size + 16, height: size + 16)
        .animation(.spring(response: 0.45, dampingFraction: 0.72),
                   value: store.badges.map(\.id))
    }

    @ViewBuilder
    private func badgeView(badge: StickerBadge, depthFromTop: Int) -> some View {
        // Depth 0 = top of pile (newest). Each step back: smaller
        // rotation amplitude, slight scale-down, more transparency.
        let depth = CGFloat(depthFromTop)
        let scale = max(0.86, 1.0 - depth * 0.04)
        let opacity = max(0.55, 1.0 - depth * 0.12)
        let rotation = badge.rotationDegrees * (1.0 - Double(depth) * 0.25)

        let view = ZStack {
            // White paper background — sticky-note vibe and improves
            // contrast against the colored back card.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

            Image(uiImage: badge.image)
                .resizable()
                .scaledToFit()
                .padding(6)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
        .offset(x: badge.horizontalJitter * (1.0 - depth * 0.2),
                y: depth * 4)
        .scaleEffect(scale)
        .opacity(opacity)
        .zIndex(Double(-depthFromTop))

        if depthFromTop == 0, let ns = flightNamespace, badge.id == newestID {
            // The flying overlay in `CurrentTabView` is the source.
            // This badge is the destination — when the overlay is
            // alive, this view animates to take the overlay's
            // geometry; when the overlay disappears, the badge
            // springs back to its natural pile position.
            view.matchedGeometryEffect(id: flightID, in: ns, isSource: false)
        } else {
            view
        }
    }
}
