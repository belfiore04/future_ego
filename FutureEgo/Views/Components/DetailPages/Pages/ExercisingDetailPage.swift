import SwiftUI

struct ExercisingDetailPage: View {
    let detail: ExercisingDetail
    @State private var userCheckedStates: [Bool]
    @State private var aiCheckedStates: [Bool]

    init(detail: ExercisingDetail) {
        self.detail = detail
        _userCheckedStates = State(
            initialValue: Array(repeating: false,
                                count: detail.userEquipment.count))
        _aiCheckedStates = State(
            initialValue: Array(repeating: false,
                                count: detail.aiSuggestedEquipment.count))
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: detail.time)
    }

    var body: some View {
        DetailPageShell(
            palette: .green,
            dailyProgress: 0.65,
            activityProgress: 0.3
        ) {
            // ── Info section ──
            VStack(alignment: .leading, spacing: 6) {
                HugeTimeDisplay(timeString: timeString, palette: .green)

                Text("\(detail.exerciseType) · \(detail.venueName)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DetailPagePalette.green.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom,15)
                HStack(spacing: 4) {
                    Text("◎").foregroundStyle(DetailPagePalette.green.primary)
                    Text(detail.venueAddress).foregroundStyle(.black)
                }
                .font(.system(size: 15))
                .padding(.bottom,10)
            }
        } interactiveSection: {
            // ── Interactive section ──
            VStack(alignment: .leading,
                   spacing: 0) {
                CheckListLayout(
                    palette: .green,
                    secondaryTitle: nil,
                    primaryTitle: "记得要带",
                    items: detail.userEquipment,
                    checkedStates: $userCheckedStates
                )

                if !detail.aiSuggestedEquipment.isEmpty {
                    CheckListLayout(
                        palette: .green,
                        secondaryTitle: nil,
                        primaryTitle: "推荐你带上",
                        items: detail.aiSuggestedEquipment,
                        checkedStates: $aiCheckedStates
                    )
                }
            }
        }
    }
}

#Preview("ExercisingDetailPage") {
    var mock = ExercisingDetail(
        time: {
            var c = DateComponents()
            c.hour = 12; c.minute = 0
            return Calendar.current.date(from: c) ?? Date()
        }(),
        exerciseType: "胸部力量训练",
        venueName: "乐刻健身房",
        venueAddress: "慧多港商场 5F",
        userEquipment: ["毛巾", "运动手表", "水杯"],
        aiSuggestedEquipment: ["运动耳机"]
    )
    mock.inspirationQuote = "想象你已经做完了胸部力量训练，胸部肌肉饱满紧致！"
    return ExercisingDetailPage(detail: mock)
}
