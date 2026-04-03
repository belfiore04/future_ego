import SwiftUI

/// A dual-ring progress indicator.
/// Outer ring = event progress; Inner ring = day progress.
/// Green theme with gray background tracks.
struct ProgressRing: View {
    /// Current event index — used by the caller to derive progress.
    /// The view accepts pre-computed progress values so it stays model-agnostic.
    let eventProgress: Double  // 0...1
    let dayProgress: Double    // 0...1

    // MARK: - Design tokens
    private let size: CGFloat = 96
    private let outerRadius: CGFloat = 38
    private let innerRadius: CGFloat = 26
    private let outerStrokeWidth: CGFloat = 7
    private let innerStrokeWidth: CGFloat = 5
    private let accentGreen = Color(hex: "34C759")
    private let accentGreenLight = Color(hex: "34C759").opacity(0.35)
    private let trackColor = Color.black.opacity(0.06)

    var body: some View {
        ZStack {
            // ── Outer ring (event progress) ──
            // Background track
            Circle()
                .stroke(trackColor, lineWidth: outerStrokeWidth)
                .frame(width: outerRadius * 2, height: outerRadius * 2)

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(clamp(eventProgress)))
                .stroke(
                    accentGreen,
                    style: StrokeStyle(lineWidth: outerStrokeWidth, lineCap: .round)
                )
                .frame(width: outerRadius * 2, height: outerRadius * 2)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: eventProgress)

            // ── Inner ring (day progress) ──
            // Background track
            Circle()
                .stroke(trackColor, lineWidth: innerStrokeWidth)
                .frame(width: innerRadius * 2, height: innerRadius * 2)

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(clamp(dayProgress)))
                .stroke(
                    accentGreenLight,
                    style: StrokeStyle(lineWidth: innerStrokeWidth, lineCap: .round)
                )
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: dayProgress)

            // ── Center label ──
            VStack(spacing: 2) {
                Text("\(Int(clamp(eventProgress) * 100))%")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(accentGreen)

                Text("全天 \(Int(clamp(dayProgress) * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.black.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Helpers

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

// MARK: - Convenience initializer from event index (placeholder logic)

extension ProgressRing {
    /// Creates a ProgressRing from an event index.
    /// The caller should compute actual progress; this is a convenience that
    /// takes pre-calculated values.
    init(eventIndex: Int, eventProgress: Double, dayProgress: Double) {
        // eventIndex reserved for future use if the ring needs to derive its own progress
        self.eventProgress = eventProgress
        self.dayProgress = dayProgress
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        ProgressRing(eventProgress: 0.65, dayProgress: 0.4)
        ProgressRing(eventProgress: 0.0, dayProgress: 0.1)
        ProgressRing(eventProgress: 1.0, dayProgress: 0.85)
    }
    .padding()
}
