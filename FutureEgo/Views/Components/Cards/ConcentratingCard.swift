import SwiftUI

// MARK: - ConcentratingCard
//
// Renders a `ConcentratingDetail` payload.
// - Big title: taskName
// - Time logic (hero element):
//     · When `now` is inside [startTime, endTime]: live per-second HH:MM:SS
//       countdown to endTime, refreshed via `TimelineView(.periodic(...))`.
//     · Otherwise: static "HH:mm - HH:mm" range.
// - Deadline badge "⏰ deadline M/d" when a deadline is set.
// - AI-decomposed step checklist (local-only, tap to toggle).
// - "延后" placeholder button, visible only when `isAISuggested == true`.
//   Taps show a "功能开发中" alert.

struct ConcentratingCard: View {
    let detail: ConcentratingDetail
    let status: EventStatus

    @State private var completedSteps: Set<Int> = []
    @State private var showPlaceholderAlert = false

    // MARK: - Design tokens
    private let grayText = Color(hex: "8E8E93")
    private let darkText = Color(hex: "3A3A3C")
    private let accentGreen = Color.brandGreen
    private let indigo = Color(hex: "5856D6")
    private let orange = Color(hex: "FF9500")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            timeOrCountdown
            if !detail.steps.isEmpty {
                stepsSection
            }
            if detail.isAISuggested {
                postponeButton
            }
        }
        .activityCardContainer(status: status)
        .placeholderFeatureAlert(isPresented: $showPlaceholderAlert)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Text(detail.taskName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let deadline = detail.deadline {
                deadlineBadge(deadline)
            }
        }
    }

    private func deadlineBadge(_ deadline: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 10))
            Text("deadline \(monthDay(deadline))")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(orange.opacity(0.1))
        )
    }

    // MARK: - Time / Countdown (hero element)

    @ViewBuilder
    private var timeOrCountdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            if now >= detail.startTime && now <= detail.endTime {
                countdownLabel(now: now)
            } else {
                staticRangeLabel
            }
        }
    }

    private func countdownLabel(now: Date) -> some View {
        let remaining = max(0, Int(detail.endTime.timeIntervalSince(now)))
        let h = remaining / 3600
        let m = (remaining % 3600) / 60
        let s = remaining % 60
        let timeString = String(format: "%02d:%02d:%02d", h, m, s)
        return HStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 16))
                .foregroundColor(accentGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("剩余时间")
                    .font(.system(size: 11))
                    .foregroundColor(grayText)
                Text(timeString)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(accentGreen)
                    .monospacedDigit()
            }
        }
    }

    private var staticRangeLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundColor(darkText)
            Text("\(hhmm(detail.startTime)) - \(hhmm(detail.endTime))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(darkText)
        }
    }

    // MARK: - Steps checklist

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI 拆解步骤")
                .font(.system(size: 12))
                .foregroundColor(grayText)
            ForEach(Array(detail.steps.enumerated()), id: \.offset) { idx, step in
                stepRow(index: idx, text: step)
            }
        }
    }

    private func stepRow(index: Int, text: String) -> some View {
        let isChecked = completedSteps.contains(index)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isChecked {
                    completedSteps.remove(index)
                } else {
                    completedSteps.insert(index)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isChecked ? accentGreen : Color.black.opacity(0.18),
                            lineWidth: 1.5
                        )
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(isChecked ? accentGreen : Color.clear)
                        .frame(width: 18, height: 18)
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 1)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(isChecked ? grayText : darkText)
                    .strikethrough(isChecked, color: grayText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Placeholder 延后 button

    private var postponeButton: some View {
        HStack {
            Spacer()
            Button {
                showPlaceholderAlert = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                    Text("延后")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(indigo)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(indigo.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func monthDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

// MARK: - Preview

#Preview("Concentrating · active · AI suggested") {
    if case .concentrating(let d) = SampleData.schedule[2].detail {
        ConcentratingCard(detail: d, status: .active)
            .padding()
    }
}

#Preview("Concentrating · upcoming · user") {
    if case .concentrating(let d) = SampleData.schedule[4].detail {
        ConcentratingCard(detail: d, status: .upcoming)
            .padding()
    }
}
