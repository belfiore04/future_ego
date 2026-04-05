import SwiftUI

// MARK: - ExercisingDetailPage
//
// Wave 2 concrete detail page for `Activity.exercising`. Assembles the
// shared `DetailPageShell` (green palette) with a `CheckListLayout`
// content slot that renders the "记得要带 / 推荐你带上" equipment list
// described in `.pm/2026-04-06/ground-truth.md` §1 21:1824 and §4
// "每页独有的部分".
//
// Field mapping (from `.pm/2026-04-06/existing-code-summary.md`):
//   - detail.time          → "HH:mm" timeString
//   - detail.exerciseType  → first half of activity name
//   - detail.venueName     → second half of activity name (" · ")
//   - detail.venueAddress  → location line (shell prepends "◎")
//   - detail.userEquipment → CheckListLayout items
//   - detail.inspirationQuote → Hero motivational copy (fallback provided)
//
// NOTE: The shell's `locationLine` contract already prepends the "◎"
// glyph, so we pass the raw address and do NOT inject our own prefix.

struct ExercisingDetailPage: View {
    let detail: ExercisingDetail
    @State private var checkedStates: [Bool]

    init(detail: ExercisingDetail) {
        self.detail = detail
        _checkedStates = State(
            initialValue: Array(repeating: false, count: detail.userEquipment.count)
        )
    }

    // MARK: - Derived strings

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: detail.time)
    }

    private var activityName: String {
        "\(detail.exerciseType) · \(detail.venueName)"
    }

    private var motivationalText: String {
        detail.inspirationQuote
            ?? "想象你已经做完了\(detail.exerciseType)，那种充实的感觉！"
    }

    // MARK: - Body

    var body: some View {
        DetailPageShell(
            palette: .green,
            timeString: timeString,
            activityName: activityName,
            locationLine: detail.venueAddress,
            motivationalText: motivationalText,
            heroSymbolName: "figure.strengthtraining.traditional"
        ) {
            CheckListLayout(
                palette: .green,
                secondaryTitle: "记得要带",
                primaryTitle: "推荐你带上",
                items: detail.userEquipment,
                checkedStates: $checkedStates
            )
        }
    }
}

// MARK: - Preview

#Preview("ExercisingDetailPage — green") {
    var mock = ExercisingDetail(
        time: {
            var components = DateComponents()
            components.hour = 12
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }(),
        exerciseType: "胸部力量训练",
        venueName: "乐刻健身房",
        venueAddress: "慧多港商场 5F",
        userEquipment: ["毛巾", "运动手表", "水杯"],
        aiSuggestedEquipment: []
    )
    mock.inspirationQuote = "想象你已经做完了胸部力量训练，胸部肌肉饱满紧致，身体也更加挺拔，你已经变得越来越自信啦！"
    return ExercisingDetailPage(detail: mock)
}
