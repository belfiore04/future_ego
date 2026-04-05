import SwiftUI

// MARK: - ConcentratingDetailPage
//
// Wave 2 concrete page for `.concentrating(ConcentratingDetail)`. Wires
// the purple palette into `DetailPageShell` and fills the content slot
// with `StepListLayout`.
//
// Source-material anchors (`.pm/2026-04-06/ground-truth.md`):
//   - §1 Leaf 22:2516 concentrating: 紫色 Hero / 紫色 stroke / 96pt 紫色
//     巨型时间 "1:23:21" / 22pt 紫色任务名 / 15pt 黑色说明行 / "一步一
//     步来不着急" 14pt 灰 section 标题 + 3 步骤（前 2 步 stroke #B239EA
//     in-progress，末尾 stroke rgba(0,0,0,0.15) not-started）.
//   - §重要分歧 "concentrating 的时间格式与其他页不同": HH:MM:SS 计时
//     格式（"1:23:21"）而非 HH:MM。Figma 里呈现为静态字符串；真实倒计
//     时接 Timer 是未来迭代的工作，本页只做静态展示。
//
// Timer string policy: `timerString` computes `endTime - startTime` as
// seconds, formats via `String(format: "%d:%02d:%02d", …)` and hands
// the result to `DetailPageShell.timeString`. `HugeTimeDisplay` already
// accepts arbitrary `String` so "1:23:21" renders under the same 96pt
// Instrument Sans Bold treatment as the fixed "12:00" used by other
// pages. No `Timer.publish` / `TimelineView` here — this page is a
// static snapshot of the planned duration, not a live countdown.
//
// Step state demo: the model only ships `[String]` labels, so the
// tri-state machine from `StepListLayout` is populated with a fixed
// demo rule — first 2 rows `.inProgress`, remaining rows `.notStarted`.
// This mirrors ground-truth §1 Leaf 22:2516 ("前两个紫色 stroke / 最后
// 一个灰色 stroke") and §4 每页独有的部分 concentrating 行.
// Authoring real per-step state requires extending `ConcentratingDetail`
// with a parallel `[StepState]` or similar, which is out of scope for
// Wave 2.

struct ConcentratingDetailPage: View {
    let detail: ConcentratingDetail

    /// "H:MM:SS" formatted duration from `startTime` → `endTime`. Static
    /// — not driven by a `Timer.publish`. See file header for rationale.
    private var timerString: String {
        let interval = detail.endTime.timeIntervalSince(detail.startTime)
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    private var motivationalText: String {
        detail.inspirationQuote ?? "深呼吸，专注当下的任务。"
    }

    private var stepItems: [StepItem] {
        detail.steps.enumerated().map { idx, label in
            // Demo state: first two rows in-progress, the rest
            // not-started. See file header for why this is a fixed rule.
            let state: StepState = idx < 2 ? .inProgress : .notStarted
            return StepItem(label: label, state: state)
        }
    }

    var body: some View {
        DetailPageShell(
            palette: .purple,
            timeString: timerString,
            activityName: detail.taskName,
            // `DetailPageShell` prepends the "◎" glyph automatically
            // (see Shell line 35 / line 165). Passing a bare label here
            // avoids the double-glyph "◎ ◎ 专注时段" that the task spec
            // literally asks for. The CookDetailPage sibling (also Wave 2)
            // follows the same convention — bare label, no leading ◎.
            locationLine: "专注时段",
            motivationalText: motivationalText,
            heroSymbolName: "brain.head.profile"
        ) {
            StepListLayout(
                palette: .purple,
                title: "任务步骤",
                steps: stepItems
            )
        }
    }
}

// MARK: - Previews
//
// `ConcentratingDetail.init` does not accept `inspirationQuote` as a
// parameter (it's a stored `var` with a default nil — see
// `Models/Activity.swift` line 315). The fixture assigns the quote
// post-init so the preview exercises the non-nil branch of
// `motivationalText`.

private func concentratingDetailPreviewFixture() -> ConcentratingDetail {
    var detail = ConcentratingDetail(
        startTime: Date(timeIntervalSinceReferenceDate: 0),
        // 1h 23m 21s = 5001 seconds → `timerString` renders "1:23:21",
        // matching ground-truth §1 Leaf 22:2516.
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
    detail.inspirationQuote = "我们集中精力，快速把这个汇报写完。这是今天最后一个任务啦，写完汇报后可以看一个电影呀，享受一个美好的周末！"
    return detail
}

#Preview("ConcentratingDetailPage — 5 steps") {
    ConcentratingDetailPage(detail: concentratingDetailPreviewFixture())
}
