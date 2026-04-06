import SwiftUI

// MARK: - DetailPageShell
//
// The single shared "chrome" used by every activity detail page. It
// draws the pieces that are 100% identical across all 7 Figma pages so
// each concrete page only has to fill its own content slot.
//
// Geometry is derived from the FigmaMake HTML export
// (`Exercising（fold）.tsx`), Container1-local coordinates (root y=94
// subtracted). Card-group-local further subtracts x=25 since the Hero
// starts at canvas x=25.
//
// Z-order (bottom → top) — do not rearrange casually, the 180pt
// overlap between the Hero card and the content card is load-bearing:
//   1. White background (fills the full window, ignores safe area)
//   2. Hero card  (340 × 239 @ local (0, 0), rounded 29, palette primary)
//   3. Content card (340 × 459 @ local (0, 59), rounded 29, 1px
//      palette stroke) — overlaps Hero by 180pt (239 − 59)
//   4. Content body (@ViewBuilder) inside content card, padded 230pt
//   5. Hero illustration (140 × 139 @ local (170, 16))
//   6. Motivational text (140 × 84, center-y 86, white, ABOVE content card)
//   7. Huge time / activity name / location line — absolute overlays
//
// FloatingActionPills and DetailPageTabBar are APP CHROME — they are
// NOT rendered by the Shell. The parent screen / NavigationStack is
// responsible for those.
//
// The iOS status bar (time / battery / wifi) is drawn by the system —
// Shell does not paint its own "9:41" row.

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

    // Card group geometry — fixed by design regardless of screen size.
    // Width stays 340 (FigmaMake spec); extra horizontal space on wider
    // devices becomes white margin. Height = content card bottom:
    // 59 (content-card top) + 459 (content-card height) = 518.
    private let cardGroupWidth: CGFloat = 340
    private let cardGroupHeight: CGFloat = 518

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white
                    .ignoresSafeArea()

                // Card group — anchored to top safe-area inset, centered
                // horizontally. All internal offsets are card-group-local
                // (Figma x values rebased by −25).
                cardGroup
                    .frame(width: cardGroupWidth, height: cardGroupHeight)
                    .position(
                        x: geo.size.width / 2,
                        y: geo.safeAreaInsets.top + cardGroupHeight / 2
                    )
            }
        }
    }

    // MARK: - Card group
    //
    // Everything inside is positioned RELATIVE to this ZStack's
    // top-leading corner. The Hero card origin is (0, 0).
    //
    // FigmaMake Container1-local coords (x rebased by −25):
    //   Hero card:        (0, 0)   340 × 239
    //   Content card:     (0, 59)  340 × 459  overlap = 180pt
    //   Illustration:     (170, 16) 140 × 139
    //   Motivational text: (18, 44) 140 × 84  (center-y=86, −42 for half-height)
    //   Huge time:        (16, 104) center-y=133, −29 for half-height
    //   Activity name:    (22, 192) 22pt bold
    //   Location line:    (22, 240) 15pt regular
    //   Content body:     content-card-local y=230 (289 − 59)
    private var cardGroup: some View {
        ZStack(alignment: .topLeading) {
            // ── Layer 1: Hero card @ local (0, 0) 340 × 239 ──
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(palette.primary)
                .frame(width: 340, height: 239)

            // ── Layer 2: Content card @ local (0, 59) 340 × 459 ──
            // Overlaps Hero by 180pt (239 − 59).
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(Color.white)
                .frame(width: 340, height: 459)
                .overlay(
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .stroke(palette.primary, lineWidth: 1)
                )
                .offset(x: 0, y: 59)

            // ── Layer 3: Content body inside content card ──
            // Content starts at container-local y=289 (LocationView top
            // in FigmaMake). Content-card-local = 289 − 59 = 230pt.
            // Usable area = 459 − 230 = 229pt.
            contentCardBody()
                .padding(.top, 230)
                .frame(width: 340, height: 459, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                .offset(x: 0, y: 59)

            // ── Layer 4: Hero illustration @ local (170, 16) 140 × 139 ──
            // FigmaMake: left-[195px] top-[16px] inside Container1;
            // card-group-local x = 195 − 25 = 170.
            HeroIllustration(symbolName: heroSymbolName, palette: palette)
                .offset(x: 170, y: 16)

            // ── Layer 5: Motivational text ──
            // FigmaMake: left-[43px] top-[86px] -translate-y-1/2,
            // h-[84px] w-[140px], white, font-[510] 15px.
            // Card-group-local: x = 43 − 25 = 18, center-y = 86,
            // top = 86 − 42 = 44. Must render ABOVE content card so
            // white text on green hero is not occluded.
            Text(motivationalText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white)
                .lineSpacing(2)
                .frame(width: 140, height: 84, alignment: .topLeading)
                .offset(x: 18, y: 44)

            // ── Layer 6: Huge time @ local (16, 104) ──
            // FigmaMake: top-[227px] root → container-local 133,
            // -translate-y-1/2, h-[58px] → top = 133 − 29 = 104.
            // left = calc(50% − 154px) in 390 frame → 41 root → 16 local.
            // 96pt Instrument Sans Bold, palette color.
            HugeTimeDisplay(timeString: timeString, palette: palette)
                .frame(maxWidth: 308, alignment: .leading)
                .offset(x: 16, y: 104)

            // ── Layer 7: Activity name @ local (22, 192) ──
            // FigmaMake: left-[47px] top-[286px] root → container-local
            // (22, 192). 22pt Bold, palette color.
            Text(activityName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 296, alignment: .leading)
                .offset(x: 22, y: 192)

            // ── Layer 8: Location line @ local (22, 240) ──
            // FigmaMake: left-[47px] top-[334px] root → container-local
            // (22, 240). "◎" in palette color, rest in black, 15pt.
            HStack(spacing: 4) {
                Text("◎")
                    .foregroundStyle(palette.primary)
                Text(locationLine)
                    .foregroundStyle(Color.black)
            }
            .font(.system(size: 15, weight: .regular))
            .offset(x: 22, y: 240)
        }
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
