import SwiftUI

// MARK: - DetailPageShell
//
// Shared chrome for all activity detail pages. Two overlapping cards:
//
//   Back card (palette-colored): progress rings on the right, left side
//   reserved for future content (currently just palette background).
//
//   Front card (white): slides up/down over the Back card like a slider
//   phone. Contains an info section (time, name, location — provided by
//   each page) and an interactive section (checklists, dishes, steps —
//   also provided by each page) inside a ScrollView.
//
// Fold/unfold interaction:
//   Swipe Front card UP   → fold   → covers Back card, more content visible
//   Swipe Front card DOWN → unfold → reveals Back card with progress rings
//
// All layout is PROPORTIONAL — no fixed pixel coordinates. Card sizes
// and positions are computed from the available GeometryReader space.
// Font sizes remain fixed (they don't scale with screen size, per iOS
// convention).

struct DetailPageShell<InfoSection: View, InteractiveSection: View>: View {
    let palette: DetailPagePalette
    let dailyProgress: Double
    let activityProgress: Double
    let infoSection: () -> InfoSection
    let interactiveSection: () -> InteractiveSection

    @State private var isFolded = true

    /// Bumped once per state flip so `.sensoryFeedback` can fire. Wraps
    /// at overflow; absolute value irrelevant, only change matters.
    @State private var hapticTick: Int = 0
    /// Direction the current ongoing gesture has already committed in this
    /// pass: -1 = committed to fold, +1 = committed to unfold, 0 = no
    /// commit yet. Reset on gesture end. Allows the user to reverse
    /// direction within the same gesture (drag down then up → unfold then
    /// fold) while preventing repeated triggers from the same direction.
    @State private var committedDirection: Int = 0

    /// How far the finger has to travel from the gesture's starting point
    /// before we flip the state and fire a haptic. Low = hair-trigger;
    /// high = deliberate swipe.
    private let commitThreshold: CGFloat = 40

    init(
        palette: DetailPagePalette,
        dailyProgress: Double = 0.5,
        activityProgress: Double = 0.3,
        @ViewBuilder infoSection: @escaping () -> InfoSection,
        @ViewBuilder interactiveSection: @escaping () -> InteractiveSection
    ) {
        self.palette = palette
        self.dailyProgress = dailyProgress
        self.activityProgress = activityProgress
        self.infoSection = infoSection
        self.interactiveSection = interactiveSection
    }

    // MARK: Layout ratios — tune these in Xcode Preview

    private let cornerRadius: CGFloat = 29
    private let horizontalPad: CGFloat = 25
    /// Back card height as a fraction of available height.
    private let backCardRatio: CGFloat = 0.28
    /// Front card top position in UNFOLD state (fraction of back card height)
    private let unfoldedRatio: CGFloat = 0.75
    /// Front card top position in FOLD state (fraction of back card height).
    private let foldedRatio: CGFloat = 0.25

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width - horizontalPad * 2
            let backH = geo.size.height * backCardRatio
            let unfoldedY = backH * unfoldedRatio
            let foldedY = backH * foldedRatio
            // Two-state toggle: the card is pinned to exactly one of the two
            // positions at any time. The drag gesture only flips state, it
            // never offsets the card mid-drag.
            let frontY = isFolded ? foldedY : unfoldedY

            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                // ── Back card ──
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(palette.primary,lineWidth:1)
                    )
                    .frame(width: cardW, height: backH)
                    .overlay(alignment: .topTrailing) {
                        ProgressRingView(
                            dailyProgress: dailyProgress,
                            activityProgress: activityProgress
                        )
                        .frame(width: backH * 0.55, height: backH * 0.55)
                        .padding(.trailing, backH * 0.1)
                        .padding(.top,20)
                    }
                    .overlay(alignment: .topLeading) {
                        // Sticker pile lives in the left region of the
                        // back card. Front card is rendered later in
                        // this same ZStack and therefore covers the
                        // pile when it slides down (unfold).
                        StickerBadgeStack(size: backH * 0.55)
                            .padding(.leading, backH * 0.1)
                            .padding(.top, 20)
                            .allowsHitTesting(false)
                    }


                // ── Front card ──
                VStack(
                    alignment: .leading,
                    spacing: 0,

                ) {
                    infoSection()
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 14)

                    Rectangle()
                        .fill(palette.primary)
                        .frame(height: 1)
                        .padding(.horizontal, 24)

                    ScrollView(.vertical, showsIndicators: false) {
                        interactiveSection()
                    }
                }
                .frame(width: cardW, height: 600)
                .background(Color.white)
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(palette.primary,lineWidth:1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
                .offset(y: frontY)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            // Two-state snap. We don't move the card with
                            // the finger; instead, the moment net translation
                            // crosses ±commitThreshold in a direction that
                            // actually flips the current state, we animate
                            // the card to the new state and buzz once.
                            //
                            // committedDirection prevents the same direction
                            // from firing repeatedly while the finger stays
                            // past the threshold. Reversing direction
                            // (e.g. swipe down past threshold → without
                            // lifting, swipe back up past threshold) is
                            // allowed and triggers the opposite flip.
                            let h = value.translation.height
                            let dir: Int
                            if h < -commitThreshold { dir = -1 }
                            else if h > commitThreshold { dir = 1 }
                            else { dir = 0 }

                            guard dir != 0, dir != committedDirection else {
                                if dir == 0 { committedDirection = 0 }
                                return
                            }

                            let wouldChange = (dir == -1 && !isFolded)
                                           || (dir == 1 && isFolded)
                            if wouldChange {
                                withAnimation(.spring(response: 0.35,
                                                      dampingFraction: 0.78)) {
                                    isFolded = (dir == -1)
                                }
                                hapticTick &+= 1
                            }
                            committedDirection = dir
                        }
                        .onEnded { _ in
                            committedDirection = 0
                        }
                )
                .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.9),
                                 trigger: hapticTick)
            }
            .padding(.top,60)

        }.padding(.bottom,100)
    }
}

// MARK: - Previews

#Preview("Shell — exercising (green)") {
    DetailPageShell(
        palette: .green,
        dailyProgress: 0.65,
        activityProgress: 0.3
    ) {
        VStack(alignment: .leading, spacing: 6) {
            HugeTimeDisplay(timeString: "12:00", palette: .green)
            Text("胸部力量训练 · 乐刻健身房")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(DetailPagePalette.green.primary)
                .padding(.bottom,12)
            HStack(spacing: 4) {
                Text("◎").foregroundStyle(DetailPagePalette.green.primary)
                Text("慧多港商场 5F").foregroundStyle(.black)
            }
            .font(.system(size: 15))
            .padding(.bottom,20)
        }
    } interactiveSection: {
        VStack(alignment: .leading, spacing: 8) {
            Text("记得要带")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .padding(.horizontal, 24)
                .padding(.top, 16)
            Text("○ 毛巾").padding(.horizontal, 24)
            Text("○ 运动手表").padding(.horizontal, 24)
            Text("○ 水杯").padding(.horizontal, 24)
        }
    }
}

#Preview("Shell — outing (blue)") {
    DetailPageShell(
        palette: .blue,
        dailyProgress: 0.5,
        activityProgress: 0.6
    ) {
        VStack(alignment: .leading, spacing: 6) {
            HugeTimeDisplay(timeString: "14:30", palette: .blue)
            Text("创意品牌营销会议")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DetailPagePalette.blue.primary)
            HStack(spacing: 4) {
                Text("◎").foregroundStyle(DetailPagePalette.blue.primary)
                Text("朝阳区798艺术区 A1座").foregroundStyle(.black)
            }
            .font(.system(size: 15))
        }
    } interactiveSection: {
        Color.clear.frame(height: 200)
    }
}
