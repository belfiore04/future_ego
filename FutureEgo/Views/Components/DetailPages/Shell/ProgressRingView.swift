import SwiftUI

// MARK: - ProgressRingView
//
// Double concentric progress ring for the Back card of DetailPageShell.
// Outer ring (clockwise): daily activity progress.
// Inner ring (counter-clockwise): current activity progress.
// Both render in white on the palette-colored background.

struct ProgressRingView: View {
    let dailyProgress: Double
    let activityProgress: Double

    private let outerWidth: CGFloat = 10
    private let innerWidth: CGFloat = 8
    private let ringGap: CGFloat = 6

    var body: some View {
        ZStack {
            // Outer ring track
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: outerWidth)

            // Outer ring progress (clockwise from 12 o'clock)
            Circle()
                .trim(from: 0, to: dailyProgress)
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: outerWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Inner ring track
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: innerWidth)
                .padding(outerWidth / 2 + ringGap + innerWidth / 2)

            // Inner ring progress (counter-clockwise from 12 o'clock)
            Circle()
                .trim(from: 0, to: activityProgress)
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: innerWidth, lineCap: .round))
                .padding(outerWidth / 2 + ringGap + innerWidth / 2)
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: -1, y: 1)
        }
    }
}

#Preview("ProgressRingView") {
    ZStack {
        Color(red: 0x38 / 255.0, green: 0xB0 / 255.0, blue: 0)
        ProgressRingView(dailyProgress: 0.65, activityProgress: 0.4)
            .frame(width: 120, height: 120)
    }
    .frame(width: 200, height: 200)
    .clipShape(RoundedRectangle(cornerRadius: 29))
}
