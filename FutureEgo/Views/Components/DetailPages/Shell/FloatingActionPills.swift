import SwiftUI

// MARK: - FloatingActionPills
//
// The glassy "拍照 | AI Coach" pill that floats above the content card
// on every detail page. Ground truth:
//   - Size:       ~226 × 42.5 (`ground-truth.md` §3 浮动按钮)
//   - Shape:      Capsule (Figma corner radius 19174000 ≈ ∞)
//   - Fill:       rgba(255,255,255,0.72)
//   - Shadow:     0 0 0 0.5 rgba(0,0,0,0.06) + 0 2 20 rgba(0,0,0,0.08)
//   - Left half:  "拍照" — camera.fill SF Symbol + #3A3A3C label
//   - Divider:    0.5 × 24 rgba(0,0,0,0.1)
//   - Right half: "AI Coach" — sparkles SF Symbol + palette.primary label
//
// The view is a pure display — taps on either half currently do
// nothing. Wiring the camera and AI coach actions is the shell caller's
// responsibility (Wave 2+).

struct FloatingActionPills: View {
    let palette: DetailPagePalette
    var onTapCamera: (() -> Void)? = nil
    var onTapAICoach: (() -> Void)? = nil

    private let labelColor = Color(
        red: 0x3A / 255.0,
        green: 0x3A / 255.0,
        blue: 0x3C / 255.0
    )

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { onTapCamera?() }) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .medium))
                    Text("拍照")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(width: 0.5, height: 24)

            Button(action: { onTapAICoach?() }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .medium))
                    Text("AI Coach")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(palette.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 226, height: 42.5)
        .background(Color.white.opacity(0.72), in: Capsule())
        // Tight hairline halo first, then the wide soft drop — matches
        // the Figma `effect_M8IHNL` stack.
        .shadow(color: Color.black.opacity(0.06), radius: 0.25, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 2)
    }
}

#Preview("FloatingActionPills") {
    ZStack {
        Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)
            .ignoresSafeArea()
        VStack(spacing: 32) {
            FloatingActionPills(palette: .green)
            FloatingActionPills(palette: .blue)
            FloatingActionPills(palette: .orange)
            FloatingActionPills(palette: .purple)
        }
    }
}
