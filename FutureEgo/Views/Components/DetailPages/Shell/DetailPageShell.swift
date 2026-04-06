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

    @State private var isFolded = false
    @State private var dragOffset: CGFloat = 0

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
    /// Front card top position in UNFOLD state (fraction of back card height).
    private let unfoldedRatio: CGFloat = 0.55
    /// Front card top position in FOLD state (fraction of back card height).
    private let foldedRatio: CGFloat = 0.15

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width - horizontalPad * 2
            let backH = geo.size.height * backCardRatio
            let unfoldedY = backH * unfoldedRatio
            let foldedY = backH * foldedRatio
            let target = isFolded ? foldedY : unfoldedY
            let frontY = max(foldedY, min(unfoldedY, target + dragOffset))

            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                // ── Back card ──
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.primary)
                    .frame(width: cardW, height: backH)
                    .overlay(alignment: .trailing) {
                        ProgressRingView(
                            dailyProgress: dailyProgress,
                            activityProgress: activityProgress
                        )
                        .frame(width: backH * 0.55, height: backH * 0.55)
                        .padding(.trailing, backH * 0.1)
                    }

                // ── Front card ──
                VStack(spacing: 0) {
                    infoSection()
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 0.5)
                        .padding(.horizontal, 24)

                    ScrollView(.vertical, showsIndicators: false) {
                        interactiveSection()
                    }
                }
                .frame(width: cardW, height: geo.size.height - frontY)
                .background(Color.white)
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
                .offset(y: frontY)
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = $0.translation.height }
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
                        }
                )
            }
        }
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
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DetailPagePalette.green.primary)
            HStack(spacing: 4) {
                Text("◎").foregroundStyle(DetailPagePalette.green.primary)
                Text("慧多港商场 5F").foregroundStyle(.black)
            }
            .font(.system(size: 15))
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
