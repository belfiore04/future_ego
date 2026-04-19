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
    @State private var dragOffset: CGFloat = 0

    /// Bumped once when the drag crosses the commit threshold in a direction
    /// that would actually flip `isFolded`. Drives `.sensoryFeedback`.
    @State private var hapticTick: Int = 0
    /// Direction the current drag last committed a haptic for: -1 = fold,
    /// +1 = unfold, 0 = neutral. Prevents continuous buzzing while the
    /// finger stays past the threshold.
    @State private var hapticDirection: Int = 0

    /// How much weight the drag "feels like" inside the valid range.
    /// 1.0 = finger and card move together; lower = card lags behind,
    /// feels heavier. 0.85 gives a subtle pull-back without feeling laggy.
    private let dragFollowRatio: CGFloat = 0.85
    /// Rubber-band stiffness past the range. Smaller = resistance kicks in
    /// sooner. 90 roughly matches iOS scroll overscroll.
    private let rubberBandStiffness: CGFloat = 90
    /// How far the finger has to travel from neutral before we fire the
    /// "打火" haptic. Matches the commit thresholds in onEnded.
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
            let target = isFolded ? foldedY : unfoldedY
            // Apply a < 1.0 follow ratio inside the range so the card feels
            // slightly heavier than the finger, then rubber-band any overflow
            // past the fold / unfold stops.
            let rawY = target + dragOffset * dragFollowRatio
            let frontY = rubberBand(rawY, lower: foldedY, upper: unfoldedY)

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
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.height

                            // Fire one rigid "打火" click the moment the
                            // finger crosses the commit threshold in a
                            // direction that would actually change state.
                            // Guarded by hapticDirection so we only buzz on
                            // the edge, not every frame past the threshold.
                            let raw = value.translation.height
                            let newDir: Int
                            if raw < -commitThreshold { newDir = -1 }
                            else if raw > commitThreshold { newDir = 1 }
                            else { newDir = 0 }

                            if newDir != hapticDirection {
                                let wouldChange = (newDir == -1 && !isFolded)
                                               || (newDir == 1 && isFolded)
                                if wouldChange {
                                    hapticTick &+= 1
                                }
                                hapticDirection = newDir
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.height
                                - value.translation.height
                            withAnimation(.spring(response: 0.4,
                                                  dampingFraction: 0.82)) {
                                if value.translation.height < -40
                                    || velocity < -200
                                {
                                    isFolded = true
                                } else if value.translation.height > 40
                                    || velocity > 200
                                {
                                    isFolded = false
                                }
                                dragOffset = 0
                            }
                            hapticDirection = 0
                        }
                )
                .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.9),
                                 trigger: hapticTick)
            }
            .padding(.top,60)

        }.padding(.bottom,100)
    }

    /// Classic iOS rubber-band: values inside `[lower, upper]` pass through;
    /// values outside are compressed asymptotically so the finger can keep
    /// moving but the card barely follows. `stiffness` controls how fast the
    /// resistance ramps — smaller = more resistance sooner.
    private func rubberBand(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        if value < lower {
            let over = lower - value
            return lower - over / (1 + over / rubberBandStiffness)
        }
        if value > upper {
            let over = value - upper
            return upper + over / (1 + over / rubberBandStiffness)
        }
        return value
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
