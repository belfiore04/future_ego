import SwiftUI

// MARK: - StepListLayout
//
// Shared step-list content block used by:
//   - CookDetailPage `.step` mode (orange palette, typically 4 steps)
//   - ConcentratingDetailPage      (purple palette, typically 3 steps)
//
// Layout (top to bottom):
//   1. Small 14pt gray section title (e.g. "平菇炒肉" / "一步一步来不着急")
//   2. 1pt palette-tinted divider line
//   3. N step rows, each a CheckItem with a tri-state indicator
//
// Ground truth anchors
// (`.pm/2026-04-06/ground-truth.md`):
//   - §1 Leaf 22:2395 eating(cook_step): 4 steps, first 2 stroke #F85509
//     (inProgress), last 2 stroke rgba(0,0,0,0.15) (notStarted)
//   - §1 Leaf 22:2516 concentrating:    3 steps, first 2 stroke #B239EA
//     (inProgress), last 1 stroke rgba(0,0,0,0.15) (notStarted)
//   - §2 Container 22:2395 / 22:2516: step rows sit at y=49, 91.5, 134,
//     177 (≈42.5pt row pitch) inside a 137.71×22.5 CheckItem container
//   - §"关键结构决策候选 #4 步骤状态标记规范": tri-state machine
//     (notStarted / inProgress / done) encoded via the check-box stroke
//     color — `palette.primary` for inProgress + done, neutral
//     rgba(0,0,0,0.15) for notStarted. `done` additionally gets an
//     inner ✓ glyph and an optional label strikethrough.
//
// Rendering contract: this layout is **stateless**. Callers own the
// `[StepItem]` array and drive state transitions externally (timer tick,
// user tap, etc). No @State, no bindings. Wire-up to CookDetailPage /
// ConcentratingDetailPage lives in Wave 2.

// MARK: Public types

/// Tri-state machine for a single cooking / task step.
///
/// - `notStarted`: neutral gray stroke, no checkmark, no strikethrough.
/// - `inProgress`: palette-tinted stroke, no checkmark. Signals the
///                 current focus row; callers may layer animation on top.
/// - `done`:       palette-tinted stroke + inner ✓ glyph + label
///                 strikethrough.
enum StepState {
    case notStarted
    case inProgress
    case done
}

/// One step in a `StepListLayout`. Labels are plain strings; no
/// markdown / rich-text handling at this layer.
struct StepItem {
    let label: String
    let state: StepState

    init(label: String, state: StepState) {
        self.label = label
        self.state = state
    }
}

// MARK: StepListLayout

struct StepListLayout: View {
    let palette: DetailPagePalette
    let title: String
    let steps: [StepItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(hex: "8E8E93"))

            Rectangle()
                .fill(palette.primary)
                .frame(height: 1)
                .padding(.vertical, 4)

            VStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    StepItemRow(
                        label: steps[index].label,
                        state: steps[index].state,
                        palette: palette
                    )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

// MARK: StepItemRow (private)

private struct StepItemRow: View {
    let label: String
    let state: StepState
    let palette: DetailPagePalette

    private var strokeColor: Color {
        switch state {
        case .notStarted:
            return Color.black.opacity(0.15)
        case .inProgress, .done:
            return palette.primary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(strokeColor, lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .overlay {
                    if state == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.primary)
                    }
                }

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.8))
                .strikethrough(state == .done, color: Color.black.opacity(0.4))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 37)
    }
}

// MARK: - Previews

#Preview("StepListLayout · orange (cook_step) + purple (concentrating)") {
    let cookSteps: [StepItem] = [
        StepItem(label: "腌肉（一勺生抽，一勺蚝油）20min", state: .done),
        StepItem(label: "平菇撕成小条，煮熟后过凉水", state: .done),
        StepItem(label: "起锅烧油，油热下肉片，炒熟", state: .inProgress),
        StepItem(label: "加入平菇丝，添加适量盐", state: .notStarted),
        StepItem(label: "出锅装盘，撒葱花", state: .notStarted)
    ]

    let concentratingSteps: [StepItem] = [
        StepItem(label: "整理思路，不如在纸上写写画画规划一下", state: .done),
        StepItem(label: "收集本周数据与想法", state: .done),
        StepItem(label: "制作文档初稿", state: .inProgress),
        StepItem(label: "核对数据并校对", state: .notStarted),
        StepItem(label: "提交汇报", state: .notStarted)
    ]

    return ScrollView {
        VStack(spacing: 32) {
            StepListLayout(
                palette: .orange,
                title: "平菇炒肉",
                steps: cookSteps
            )

            StepListLayout(
                palette: .purple,
                title: "一步一步来不着急",
                steps: concentratingSteps
            )
        }
        .padding(.vertical, 32)
    }
    .background(Color(hex: "F2F2F7"))
}
