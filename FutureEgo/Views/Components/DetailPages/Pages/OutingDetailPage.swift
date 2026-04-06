import SwiftUI

struct OutingDetailPage: View {
    let detail: OutingDetail
    @State private var checkedStates: [Bool]

    init(detail: OutingDetail) {
        self.detail = detail
        _checkedStates = State(
            initialValue: Array(repeating: false,
                                count: detail.itemsToBring.count))
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: detail.arrivalTime)
    }

    var body: some View {
        DetailPageShell(
            palette: .blue,
            dailyProgress: 0.5,
            activityProgress: 0.6
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HugeTimeDisplay(timeString: timeString, palette: .blue)

                Text(detail.activityName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DetailPagePalette.blue.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 4) {
                    Text("◎").foregroundStyle(DetailPagePalette.blue.primary)
                    Text(detail.destination).foregroundStyle(.black)
                }
                .font(.system(size: 15))
            }
        } interactiveSection: {
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

#Preview("OutingDetailPage") {
    var mock = OutingDetail(
        arrivalTime: {
            var c = DateComponents()
            c.hour = 12; c.minute = 0
            return Calendar.current.date(from: c) ?? Date()
        }(),
        destination: "朝阳区798艺术区 A1座",
        activityName: "创意品牌营销会议",
        itemsToBring: ["笔记本电脑与充电器", "营销方案打印稿（5份）", "降噪耳机"]
    )
    mock.inspirationQuote = "做了那么久的营销方案一定没问题的，好好表现吧！"
    return OutingDetailPage(detail: mock)
}
