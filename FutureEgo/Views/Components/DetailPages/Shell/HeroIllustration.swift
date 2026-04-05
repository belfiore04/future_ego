import SwiftUI

// MARK: - HeroIllustration
//
// White SF-Symbol hero artwork that sits inside the colored Hero card
// on every detail page. Ground truth:
//   - Size:  140 × 139 (`ground-truth.md` §2 各页 Hero Group 坐标)
//   - Fill:  #FFFFFF
//   - Source: Figma originals ship as SVG; the iOS placeholder renders a
//     white SF Symbol while real artwork is pending.

struct HeroIllustration: View {
    let symbolName: String
    let palette: DetailPagePalette

    var body: some View {
        Image(systemName: symbolName)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.white)
            .frame(width: 140, height: 139)
            // Palette is accepted for future use (tinted strokes,
            // secondary fills) — currently unused so silence the
            // unused-let warning without making the parameter optional.
            .accessibilityLabel(Text("Hero illustration"))
            .accessibilityIdentifier("hero-illustration-\(String(describing: palette))")
    }
}

#Preview("HeroIllustration") {
    HStack(spacing: 16) {
        ZStack {
            Color(red: 0x38 / 255, green: 0xB0 / 255, blue: 0x00 / 255)
            HeroIllustration(
                symbolName: "figure.strengthtraining.traditional",
                palette: .green
            )
        }
        .frame(width: 340, height: 239)
        .clipShape(RoundedRectangle(cornerRadius: 29))
    }
    .padding()
}
