import SwiftUI
import Combine

// MARK: - ConcentratingDetailPage
//
// Redesigned detail page for a `.concentrating` activity.
// Figma: 22:2516 (note: Figma node mis-labeled `cook_step` but content is
// the concentrating layout).
//
// Page layout (inside `ActivityPageScaffold`):
//   - `LocationHeader` showing only the task name (no location subtitle).
//   - A hero elapsed timer rendered 48pt monospaced `brandGreen`, refreshed
//     once per second via `Timer.publish(...).autoconnect()`.
//   - `InspirationQuoteBlock` with a fallback copy when the detail's
//     `inspirationQuote` is nil.
//   - "一步一步来不着急" section title + a list of `CheckItemRow`s for the
//     AI-decomposed steps. Checked state is local-only (`Set<Int>` keyed
//     by step index, matching the itemsToBring pattern from task-4).
//
// Timer lifecycle:
//   - `.onAppear` seeds `timerText` immediately (so the first frame is
//     not blank) and subscribes to a fresh 1s `Timer.publish` via `.sink`.
//   - The resulting `AnyCancellable` lives in `@State`.
//   - `.onDisappear` explicitly calls `cancellable?.cancel()` so the
//     autoconnected publisher stops firing and does not leak when the
//     view is dismissed.
//
// Spec: `/home/jun/.pm/2026-04-06/task-6/spec.md`.

struct ConcentratingDetailPage: View {
    let detail: ConcentratingDetail

    @State private var timerText: String = "0:00:00"
    @State private var checkedSteps: Set<Int> = []

    // One-second heartbeat used to refresh the elapsed timer display.
    // We subscribe in `.onAppear` and store the resulting `AnyCancellable`
    // in `@State` so `.onDisappear` can explicitly cancel it — this
    // prevents the autoconnected `Timer` from continuing to fire after
    // the page is dismissed, which would otherwise be a silent leak.
    @State private var cancellable: AnyCancellable?

    var body: some View {
        ActivityPageScaffold {
            LocationHeader(
                title: detail.taskName,
                subtitle: nil
            )

            Text(timerText)
                .font(.system(size: 48, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.brandGreen)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)

            InspirationQuoteBlock(
                text: detail.inspirationQuote ?? "我们集中精力，快速把这个汇报写完。"
            )

            stepsSection
        }
        .onAppear {
            // Seed immediately so the first frame isn't blank.
            refreshTimer()
            // Subscribe to a fresh 1s heartbeat. Storing the
            // cancellable in @State keeps the subscription alive for
            // the lifetime of the view without leaking across
            // disappear/appear cycles.
            cancellable = Timer
                .publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    refreshTimer()
                }
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("一步一步来不着急")
                .font(.sectionTitle)
                .foregroundColor(.black)

            ForEach(Array(detail.steps.enumerated()), id: \.offset) { index, step in
                CheckItemRow(
                    text: step,
                    isChecked: binding(for: index)
                )
            }
        }
    }

    // MARK: - Helpers

    /// Computes a `Binding<Bool>` for a given step index against the
    /// local `checkedSteps` set. Mirrors the pattern used in task-4's
    /// `OutingDetailPage` itemsToBring list.
    private func binding(for index: Int) -> Binding<Bool> {
        Binding(
            get: { checkedSteps.contains(index) },
            set: { newValue in
                if newValue {
                    checkedSteps.insert(index)
                } else {
                    checkedSteps.remove(index)
                }
            }
        )
    }

    /// Refreshes `timerText` from the current date using the extension
    /// added in Wave 1 task-3. `elapsedFormatted` already clamps negative
    /// elapsed values to `0:00:00`, so we don't need to special-case
    /// "not started yet" here.
    private func refreshTimer() {
        timerText = detail.elapsedFormatted(at: Date())
    }
}

// MARK: - Preview

#Preview("ConcentratingDetailPage · active sample") {
    // Pull the first concentrating sample out of SampleData. The active
    // one (weekly report) sits at index 2 in the schedule and has
    // `startTime` 30 minutes in the past, so the timer should render
    // something in the "0:30:xx" range and tick forward once per second
    // in the preview.
    let sample: ConcentratingDetail = {
        for item in SampleData.schedule {
            if case .concentrating(let d) = item.detail {
                return d
            }
        }
        // Fallback that should never be reached — SampleData is
        // guaranteed to contain at least one concentrating item.
        return ConcentratingDetail(
            startTime: Date().addingTimeInterval(-60 * 30),
            endTime: Date().addingTimeInterval(60 * 90),
            taskName: "写周报",
            steps: ["整理思路", "收集数据", "制作文档"]
        )
    }()

    return ConcentratingDetailPage(detail: sample)
}
