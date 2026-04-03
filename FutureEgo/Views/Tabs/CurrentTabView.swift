import SwiftUI

// MARK: - CurrentTabView

/// The "此刻" (Now) tab — shows the current event detail with a header,
/// scrollable event content, and a native bottom toolbar.
struct CurrentTabView: View {
    let schedule: [ScheduleItem]
    let currentIndex: Int
    /// Called when the user taps the "AI Coach" toolbar button.
    var onStartCalling: (() -> Void)? = nil

    // MARK: - Design tokens
    private let accentGreen = Color(hex: "34C759")
    private let grayText = Color(hex: "8E8E93")
    private let toolbarGray = Color(hex: "3A3A3C")

    /// Current event derived from the schedule.
    private var currentEvent: CurrentEventData {
        schedule[currentIndex].detail
    }

    /// Event progress (fraction of completed items before the current one).
    private var eventProgress: Double {
        guard schedule.count > 1 else { return 0 }
        return Double(currentIndex) / Double(schedule.count - 1)
    }

    /// Day progress: simple fraction based on the current hour (8am–23pm range).
    private var dayProgress: Double {
        let hour = Calendar.current.component(.hour, from: Date())
        let clamped = min(max(Double(hour) - 8.0, 0), 15.0)
        return clamped / 15.0
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // ── Header ──
                headerView

                // ── Event content ──
                CurrentEventView(event: currentEvent)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    // TODO: camera action
                } label: {
                    Label("拍照", systemImage: "camera")
                }
                .tint(toolbarGray)

                Spacer()

                Button {
                    onStartCalling?()
                } label: {
                    Label("AI Coach", systemImage: "phone")
                }
                .tint(accentGreen)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .tracking(0.4)

                Text(formattedSubtitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }

            Spacer()

            ProgressRing(
                eventProgress: eventProgress,
                dayProgress: dayProgress
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Date helpers

    private var formattedDate: String {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        let d = cal.component(.day, from: now)
        return "\(y)/\(m)/\(d)"
    }

    private var formattedSubtitle: String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: now)
        return "\(weekday) \u{00B7} 北京 \u{00B7} 晴"
    }
}

// MARK: - Preview

#Preview {
    CurrentTabView(
        schedule: SampleData.schedule,
        currentIndex: SampleData.currentIndex
    )
}
