import SwiftUI

// MARK: - OutingDetailPage
//
// Wave 2 concrete detail page for `Activity.outing`. Assembles the
// shared `DetailPageShell` (blue palette) with a `CheckListLayout`
// content slot that renders the single-title "记得要带的东西" list
// described in `.pm/2026-04-06/ground-truth.md` §1 22:1928 and §4
// "每页独有的部分".
//
// Field mapping (from `.pm/2026-04-06/existing-code-summary.md`):
//   - detail.arrivalTime   → "HH:mm" timeString
//   - detail.activityName  → first half of activity name
//   - detail.destination   → second half of activity name + location
//                            line (shell prepends "◎")
//   - detail.itemsToBring  → CheckListLayout items
//   - detail.inspirationQuote → Hero motivational copy (fallback provided)
//
// NOTE: The shell's `locationLine` contract already prepends the "◎"
// glyph, so we pass the raw destination and do NOT inject our own
// prefix.

struct OutingDetailPage: View {
    let detail: OutingDetail
    @State private var checkedStates: [Bool]

    init(detail: OutingDetail) {
        self.detail = detail
        _checkedStates = State(
            initialValue: Array(repeating: false, count: detail.itemsToBring.count)
        )
    }

    // MARK: - Derived strings

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: detail.arrivalTime)
    }

    private var activityName: String {
        detail.activityName
    }

    private var motivationalText: String {
        detail.inspirationQuote
            ?? "做了那么久的方案一定没问题的，好好表现吧！"
    }

    // MARK: - Body

    var body: some View {
        DetailPageShell(
            palette: .blue,
            timeString: timeString,
            activityName: activityName,
            locationLine: detail.destination,
            motivationalText: motivationalText,
            heroSymbolName: "figure.walk"
        ) {
            CheckListLayout(
                palette: .blue,
                secondaryTitle: nil,
                primaryTitle: "记得要带的东西",
                items: detail.itemsToBring,
                checkedStates: $checkedStates
            )
        }
    }
}

// MARK: - Preview

#Preview("OutingDetailPage — blue") {
    var mock = OutingDetail(
        arrivalTime: {
            var components = DateComponents()
            components.hour = 12
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }(),
        destination: "朝阳区798艺术区 A1座",
        activityName: "创意品牌营销会议",
        itemsToBring: ["笔记本电脑与充电器", "营销方案打印稿（5份）", "降噪耳机"]
    )
    mock.inspirationQuote = "做了那么久的营销方案一定没问题的，好好表现吧！"
    return OutingDetailPage(detail: mock)
}
