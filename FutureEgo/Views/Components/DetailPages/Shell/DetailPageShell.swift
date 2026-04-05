import SwiftUI

// MARK: - DetailPageShell
//
// The single shared "chrome" used by every activity detail page. It
// draws the pieces that are 100% identical across all 7 Figma pages so
// each concrete page only has to fill its own content slot. Positions
// originate from the Figma 390×844 coordinate grid (see
// `.pm/2026-04-06/ground-truth.md` §3 Root + §4 共享 shell) but are now
// rebased to card-group-local coordinates so the layout adapts to real
// device bounds (iPhone 13/14/15/16 Pro Max / smaller screens) rather
// than being letterboxed inside a fixed 390×844 canvas.
//
// Z-order (bottom → top) — do not rearrange casually, the overlap
// between the Hero card and the content card is a load-bearing detail:
//   1. White background (fills the full window, ignores safe area)
//   2. Hero card (340 × 239 @ local (0, 0), rounded 29, palette primary)
//   3. Hero illustration + motivational copy inside Hero card
//   4. Content card (340 × 459 @ local (0, 176), rounded 29, 1px
//      palette stroke) — overlaps the Hero card by 63pt (239 - 176)
//   5. Giant time / activity name / location line — positioned over
//      the content card but straddling the Hero↔content boundary
//   6. Floating action pills (camera | AI coach) — pinned to bottom
//   7. TabBar — pinned to bottom, above the home-indicator safe area
//
// The iOS status bar (time / battery / wifi) is drawn by the system —
// Shell no longer paints its own "9:41" row.

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
    // Width stays 340 (Figma spec); extra horizontal space on wider
    // devices (15/16 Pro Max) becomes white margin. Height is the
    // bottom of the content card: 176 (content-card top) + 459
    // (content-card height) = 635.
    private let cardGroupWidth: CGFloat = 340
    private let cardGroupHeight: CGFloat = 635

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white
                    .ignoresSafeArea()

                // Card group — anchored to top safe-area inset, centered
                // horizontally. All internal offsets below are LOCAL to
                // this ZStack's top-leading origin (Figma x values have
                // been rebased by −25 since the Hero used to start at
                // canvas x=25).
                //
                // NOTE on small screens (iPhone SE, 375×667): the card
                // group is 635pt tall, and TabBar sits pinned to the
                // bottom. On 667pt devices the card group bottom will
                // overlap / clip under the TabBar; content density is
                // designed for 13/14/15/16-class devices.
                cardGroup
                    .frame(width: cardGroupWidth, height: cardGroupHeight)
                    .position(
                        x: geo.size.width / 2,
                        y: geo.safeAreaInsets.top + cardGroupHeight / 2
                    )

                // Floating pills + TabBar pinned to bottom of screen.
                // TabBar sits just above the home-indicator safe area;
                // pills float 12pt above the TabBar. `ignoresSafeArea`
                // lets the TabBar background extend to the bottom edge
                // on devices without a home indicator.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    FloatingActionPills(palette: palette)
                        .padding(.bottom, 12)
                    DetailPageTabBar(palette: palette)
                }
            }
        }
    }

    // MARK: - Card group
    //
    // Everything inside is positioned RELATIVE to this ZStack's
    // top-leading corner. The Hero card origin is (0, 0); x offsets
    // that used to be canvas-absolute have lost their 25pt left margin
    // (e.g. Hero(25,0) → (0,0); huge time (41,215) → (16,215)).
    private var cardGroup: some View {
        ZStack(alignment: .topLeading) {
            // 1. Hero card @ local (0, 0) 340 × 239
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(palette.primary)
                .frame(width: 340, height: 239)
                .offset(x: 0, y: 0)

            // 2a. Motivational copy @ local (18, 138) 140 × 84 inside Hero
            // (was canvas (43, 138); 43 − 25 = 18)
            Text(motivationalText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white)
                .lineSpacing(2)
                .frame(width: 140, height: 84, alignment: .topLeading)
                .offset(x: 18, y: 138)

            // 2b. Hero illustration @ local (195, 110)
            // (was canvas (220, 110); 220 − 25 = 195)
            HeroIllustration(symbolName: heroSymbolName, palette: palette)
                .offset(x: 195, y: 110)

            // 3. Content card @ local (0, 176) 340 × 459 — overlaps
            // Hero by 63pt (239 − 176 = 63) per ground-truth §2.
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(Color.white)
                .frame(width: 340, height: 459)
                .overlay(
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .stroke(palette.primary, lineWidth: 1)
                )
                .offset(x: 0, y: 176)

            // 3b. Content slot — each page paints whatever it wants
            // inside the 340 × 459 content card. A top inset leaves
            // space for the giant-time / activity-name / location-line
            // header stack rendered in step 4. The whole header stack
            // is shifted UP by 100pt from Figma's absolute positions
            // (option C, user-approved). The rationale: Figma's y=315
            // puts the huge time 139pt deep into the content card,
            // leaving only 158pt of usable content area, which is too
            // tight for 3 of 4 Wave 1 layouts (CheckList ~165,
            // ShoppingList ~207, StepList up to 230). Shifting up 100pt
            // straddles the huge time across the Hero↔content boundary
            // and reclaims 100pt of content area. Derivation (content-
            // card-local coords = card-group-local y − 176):
            //   - Huge time     group y=215 → card-local top =  39
            //   - Activity name group y=303 → card-local top = 127
            //   - Location line group y=351 → card-local top = 175
            //   - Location line height @ 15pt system ≈ 15 × 1.2 ≈ 18
            //   - Location line bottom (last header) = 175 + 18 = 193
            //   - Safety margin                                 +  8
            //   - Inset                                         = 201
            // Usable content area = 459 − 201 = 258pt (was 158pt).
            // Note: this is a deliberate divergence from Figma's
            // absolute positions; iOS renders closer to a conventional
            // profile-card layout.
            contentCardBody()
                .padding(.top, 201)
                .frame(width: 340, height: 459, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                .offset(x: 0, y: 176)

            // 4a. Giant time @ local (16, 215) — shifted UP 100pt from
            // Figma's y=315 per option C. x rebased from canvas 41 to
            // local 16 (41 − 25). The new position straddles the
            // Hero↔content boundary: span y=215..~311 crosses the Hero
            // bottom (y=239) by 24pt and extends ~72pt into the
            // content card. The maxWidth frame (340 content card −
            // 2×16 padding = 308) gives HugeTimeDisplay's
            // minimumScaleFactor an anchor to shrink against for long
            // timers like "1:23:21".
            HugeTimeDisplay(timeString: timeString, palette: palette)
                .frame(maxWidth: 308, alignment: .leading)
                .offset(x: 16, y: 215)

            // 4b. Activity name @ local (16, 303) 22pt SF Pro Bold —
            // shifted UP 100pt from Figma's y=403 per option C.
            // maxWidth 308 clamps long names within the content card
            // and gives minimumScaleFactor an anchor width to trigger on.
            Text(activityName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 308, alignment: .leading)
                .offset(x: 16, y: 303)

            // 4c. Location line @ local (16, 351) 15pt SF Pro regular
            // black — shifted UP 100pt from Figma's y=451 per option C.
            HStack(spacing: 4) {
                Text("◎")
                Text(locationLine)
            }
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color.black)
            .offset(x: 16, y: 351)
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
