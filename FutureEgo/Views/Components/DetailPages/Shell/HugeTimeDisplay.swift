import SwiftUI

// MARK: - HugeTimeDisplay
//
// The 96pt brand-tinted giant time label that straddles the Hero card
// and the content card boundary on every detail page. Rendering is
// pure — positioning is the shell's responsibility; this view only
// draws a single `Text`.
//
// Ground truth (`.pm/2026-04-06/ground-truth.md` §3 字体体系 + §4 共享
// shell 巨型时间):
//   - Font: Instrument Sans Bold, 96pt
//   - Color: palette.primary
//   - Accepts both "12:00" and "1:23:21" (concentrating) formats
//
// TODO: Instrument Sans is not yet bundled as a font resource. The
// `.custom` call will silently fall back to the system font if the
// family is missing, and we explicitly stack `.system(...,.bold)` under
// it via `Font.system` precedence. Once the Instrument Sans .ttf is
// added to the project and declared in Info.plist (UIAppFonts), the
// custom font will take over automatically with no code change.

struct HugeTimeDisplay: View {
    let timeString: String
    let palette: DetailPagePalette

    var body: some View {
        Text(timeString)
            .padding(.leading,-10)
            .font(
                .custom("Instrument Sans", size: 96, relativeTo: .largeTitle)
            )
            // Guarantees a bold weight whether Instrument Sans resolved
            // or SwiftUI fell back to the system font.
            .fontWeight(.black)
            .foregroundStyle(palette.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("HugeTimeDisplay variants") {
    VStack(alignment: .leading, spacing: 24) {
        HugeTimeDisplay(timeString: "12:00", palette: .green)
        HugeTimeDisplay(timeString: "19:00", palette: .orange)
        HugeTimeDisplay(timeString: "1:23:21", palette: .purple)
    }
    .padding()
}
