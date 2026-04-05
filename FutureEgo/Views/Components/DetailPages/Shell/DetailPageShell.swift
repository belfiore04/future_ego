import SwiftUI

// MARK: - DetailPageShell
//
// The single shared "chrome" used by every activity detail page. It
// draws the pieces that are 100% identical across all 7 Figma pages so
// each concrete page only has to fill its own content slot. Layout is
// pinned to the Figma 390×844 coordinate grid; positions come straight
// from `.pm/2026-04-06/ground-truth.md` §3 (Root) + §4 (共享 shell).
//
// Z-order (bottom → top) — do not rearrange casually, the overlap
// between the Hero card and the content card is a load-bearing detail:
//   1. Gray back fill (#F2F2F7)
//   2. Outer white card (390 × 844, rounded 40, twin drop shadows)
//   3. Hero card (340 × 239 @ (25, 94), rounded 29, palette primary)
//   4. Hero illustration + motivational copy inside Hero card
//   5. Content card (340 × 459 @ (25, 270), rounded 29, 1px palette
//      stroke) — overlaps the Hero card by 63pt
//   6. Giant time / activity name / location line — positioned over the
//      content card but straddling the Hero↔content boundary
//   7. Floating action pills (camera | AI coach)
//   8. TabBar
//   9. Status bar row ("9:41 ...") on top of everything
//
// Positions below are labeled with their Figma-absolute (x, y).

struct DetailPageShell<ContentCardBody: View>: View {
    let palette: DetailPagePalette
    /// "12:00" / "19:00" / "1:23:21" — formatting is the caller's job.
    let timeString: String
    /// e.g. "胸部力量训练 · 乐刻健身房".
    let activityName: String
    /// e.g. "慧多港商场 5F" or "配送约需35min，记得提前点单".
    /// The "◎" prefix is prepended automatically.
    let locationLine: String
    /// e.g. "想象你已经做完了胸部力量训练…"
    let motivationalText: String
    /// SF Symbol name for the Hero card placeholder illustration.
    let heroSymbolName: String
    @ViewBuilder let contentCardBody: () -> ContentCardBody

    // Figma canvas size for every detail page.
    private let canvasWidth: CGFloat = 390
    private let canvasHeight: CGFloat = 844

    // Outer wrapper background (artboard gray from ground-truth §3).
    private let backgroundGray = Color(
        red: 0xF2 / 255.0,
        green: 0xF2 / 255.0,
        blue: 0xF7 / 255.0
    )

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundGray
                .ignoresSafeArea()

            shellCanvas
                .frame(width: canvasWidth, height: canvasHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // MARK: - Canvas

    private var shellCanvas: some View {
        ZStack(alignment: .topLeading) {
            // 1 + 2. Outer white card — the drop shadow needs to render
            // against the gray back fill so the white rounded rect lives
            // here rather than as a background on the container.
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color.white)
                .frame(width: canvasWidth, height: canvasHeight)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.1), radius: 12.5, x: 0, y: 20)

            // 3. Hero card @ (25, 94) 340 × 239
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(palette.primary)
                .frame(width: 340, height: 239)
                .offset(x: 25, y: 94)

            // 4a. Motivational copy @ (43, 138) 140 × 84 inside Hero
            Text(motivationalText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white)
                .lineSpacing(2)
                .frame(width: 140, height: 84, alignment: .topLeading)
                .offset(x: 43, y: 138)

            // 4b. Hero illustration @ (220, 110) = Hero(25,94) + (195, 16)
            HeroIllustration(symbolName: heroSymbolName, palette: palette)
                .offset(x: 220, y: 110)

            // 5. Content card @ (25, 270) 340 × 459 — overlaps Hero by
            // 63pt (94 + 239 - 270 = 63) per ground-truth.
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(Color.white)
                .frame(width: 340, height: 459)
                .overlay(
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .stroke(palette.primary, lineWidth: 1)
                )
                .offset(x: 25, y: 270)

            // 5b. Content slot — each page paints whatever it wants
            // inside the 340 × 459 content card. A top inset leaves
            // space for the giant-time / activity-name / location-line
            // header stack rendered in step 6. Derivation (in content-
            // card-local coords, i.e. subtract the card's y=270 origin
            // from each header element's absolute shell y):
            //   - Location line (last header) top     = 451 - 270 = 181
            //   - Location line height @ 15pt system ≈ 15 × 1.2 ≈ 18
            //   - Location line bottom                = 181 + 18  = 199
            //   - Safety margin                                   +  8
            //   - Inset                                           = 207
            // This keeps the header overlays at their existing absolute
            // positions (unchanged) while pushing the @ViewBuilder body
            // below the header zone so ContentLayout titles no longer
            // collide with the huge-time / activity / location stack.
            contentCardBody()
                .padding(.top, 207)
                .frame(width: 340, height: 459, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                .offset(x: 25, y: 270)

            // 6a. Giant time @ (41, 315). Positioned on top of the
            // content card so it visually straddles the Hero↔content
            // boundary (the baseline sits below y=270). The maxWidth
            // frame (340 content card - 2×16 padding = 308) gives
            // HugeTimeDisplay's minimumScaleFactor an anchor to shrink
            // against for long timers like "1:23:21".
            HugeTimeDisplay(timeString: timeString, palette: palette)
                .frame(maxWidth: 308, alignment: .leading)
                .offset(x: 41, y: 315)

            // 6b. Activity name @ (41, 403) 22pt SF Pro Bold. maxWidth
            // 308 clamps long names like "Diaz · Need韩国创意料理（韩餐）"
            // within the content card and gives minimumScaleFactor an
            // anchor width to trigger on.
            Text(activityName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 308, alignment: .leading)
                .offset(x: 41, y: 403)

            // 6c. Location line @ (41, 451) 15pt SF Pro regular black
            HStack(spacing: 4) {
                Text("◎")
                Text(locationLine)
            }
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color.black)
            .offset(x: 41, y: 451)

            // 7. Floating action pills — horizontally centered at
            // y=741.5 (top of the 226 × 42.5 pill). The outer container
            // is 390 wide so `.offset(x: (390-226)/2, y: 741.5)` = (82, 741.5).
            FloatingActionPills(palette: palette)
                .offset(x: (canvasWidth - 226) / 2, y: 741.5)

            // 8. TabBar — the component already pads itself to 390 × 64
            // so offset by y=780 from the canvas origin.
            DetailPageTabBar(palette: palette)
                .offset(x: 0, y: 780)

            // 9. Status bar row — hand-drawn "9:41" etc., part of the
            // Figma asset. Kept on top of everything so it peeks above
            // the Hero card on every page.
            statusBar
                .offset(x: 0, y: 0)
        }
        .frame(width: canvasWidth, height: canvasHeight, alignment: .topLeading)
    }

    // MARK: - Status bar

    /// Mimics the "9:41  •••  wifi  battery" row that Figma bakes into
    /// every artboard. The right-side system glyphs are approximated
    /// with SF Symbols and will be refined once the real status-bar
    /// component lands.
    private var statusBar: some View {
        HStack(spacing: 0) {
            Text("9:41")
                .font(.custom("SF Pro Display", size: 17, relativeTo: .body))
                .fontWeight(.semibold)
                .foregroundStyle(Color.black)
                .offset(x: 24, y: 21)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(Color.black)
            .offset(x: -24, y: 21)
        }
        .frame(width: canvasWidth, height: 45.5, alignment: .top)
    }
}

#Preview("DetailPageShell — exercising") {
    DetailPageShell(
        palette: .green,
        timeString: "12:00",
        activityName: "胸部力量训练 · 乐刻健身房",
        locationLine: "慧多港商场 5F",
        motivationalText: "想象你已经做完了胸部力量训练，胸部肌肉饱满紧致，身体也更加挺拔，你已经变得越来越自信啦！",
        heroSymbolName: "figure.strengthtraining.traditional"
    ) {
        Color.clear
    }
}

#Preview("DetailPageShell — outing") {
    DetailPageShell(
        palette: .blue,
        timeString: "12:00",
        activityName: "创意品牌营销会议",
        locationLine: "朝阳区798艺术区 A1座",
        motivationalText: "做了那么久的营销方案一定没问题的，好好表现吧！",
        heroSymbolName: "briefcase.fill"
    ) {
        Color.clear
    }
}
