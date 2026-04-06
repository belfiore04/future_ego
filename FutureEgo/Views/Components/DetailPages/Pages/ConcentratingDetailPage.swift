import SwiftUI

struct ConcentratingDetailPage: View {
    let detail: ConcentratingDetail

    private var timerString: String {
        let interval = detail.endTime.timeIntervalSince(detail.startTime)
        let total = max(0, Int(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    private var deadlineString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: detail.endTime)
    }

    private var stepItems: [StepItem] {
        detail.steps.enumerated().map { idx, label in
            StepItem(label: label, state: idx < 2 ? .inProgress : .notStarted)
        }
    }

    var body: some View {
        DetailPageShell(
            palette: .purple,
            dailyProgress: 0.4,
            activityProgress: 0.55
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HugeTimeDisplay(timeString: timerString, palette: .purple)

                Text(detail.taskName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DetailPagePalette.purple.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("截止 \(deadlineString)")
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
            }
        } interactiveSection: {
            StepListLayout(
                palette: .purple,
                title: "一步一步来不着急",
                steps: stepItems
            )
        }
    }
}

#Preview("ConcentratingDetailPage") {
    var detail = ConcentratingDetail(
        startTime: Date(timeIntervalSinceReferenceDate: 0),
        endTime: Date(timeIntervalSinceReferenceDate: 5001),
        taskName: "26年个人第6周工作周报",
        steps: [
            "整理思路，不如在纸上写写画画规划一下",
            "收集本周数据与想法",
            "制作文档初稿",
            "核对数据并校对",
            "提交汇报"
        ]
    )
    detail.inspirationQuote = "集中精力，快速把这个汇报写完！"
    return ConcentratingDetailPage(detail: detail)
}
