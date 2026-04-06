import SwiftUI

// MARK: - CheckListLayout
//
// A reusable content-card layout that renders a titled list of
// check-able items. Used by the exercising detail page (21:1824) and
// the outing detail page (22:1928); both pages share the same
// "小标题(可选) + 小标题 + 分隔线 + N 个 check row" pattern described in
// `.pm/2026-04-06/ground-truth.md` §1 (Leaf 层 exercising + outing),
// §2 (Container 层 LocationView) and §4 "每页独有的部分":
//
//   - exercising: two secondary titles ("记得要带" + "推荐你带上") +
//                 3 check rows (毛巾 / 运动手表 / 水杯)
//   - outing:     one title ("记得要带的东西") + 3 check rows
//                 (笔记本电脑与充电器 / 营销方案打印稿 / 降噪耳机)
//
// The layout is content-only. Absolute positioning inside the
// 340 × 459 content card slot is the concrete page's responsibility;
// this view just flows top-down with a standard inset.
//
// Palette drives every brand-color touchpoint: the 1pt divider under
// the titles and the stroke / checkmark tint on selected rows.

struct CheckListLayout: View {
    let palette: DetailPagePalette
    /// Optional small gray title shown above `primaryTitle`. Pass `nil`
    /// when the page only has one title (e.g. outing's "记得要带的东西").
    let secondaryTitle: String?
    /// Primary small gray title, e.g. "推荐你带上" (exercising) or
    /// "记得要带的东西" (outing). Note: per ground-truth §3 字体体系 both
    /// titles are the same 14pt / #8E8E93 gray — neither is a large
    /// headline.
    let primaryTitle: String
    let items: [String]
    @Binding var checkedStates: [Bool]

    // #8E8E93 — ground-truth §3 字体体系 small-title gray.
    private let titleGray = Color(
        red: 0x8E / 255.0,
        green: 0x8E / 255.0,
        blue: 0x93 / 255.0
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let secondaryTitle {
                Text(secondaryTitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(titleGray)
            }

            Text(primaryTitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(titleGray)

            // 1pt divider under the titles in the palette's brand color.
            // Source: `.pm/2026-04-06/ground-truth.md` §2 exercising
            // LocationView → "Line 2 分隔线" with stroke matching the
            // Hero palette.
            Rectangle()
                .fill(palette.primary)
                .frame(height: 1)
                .padding(.vertical, 4)

            ForEach(items.indices, id: \.self) { i in
                CheckItemRowView(
                    label: items[i],
                    palette: palette,
                    isChecked: bindingForRow(i)
                )
            }

        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    /// Returns a safe binding into `checkedStates` for row `i`. If the
    /// caller passes a `checkedStates` array shorter than `items` the
    /// row falls back to a read-only `false` binding rather than
    /// crashing — this keeps previews and partial-data callers alive.
    private func bindingForRow(_ i: Int) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                guard checkedStates.indices.contains(i) else { return false }
                return checkedStates[i]
            },
            set: { newValue in
                guard checkedStates.indices.contains(i) else { return }
                checkedStates[i] = newValue
            }
        )
    }
}

// MARK: - CheckItemRowView
//
// One row inside `CheckListLayout`: a 20×20 rounded-square checkbox on
// the left, a 15pt label on the right, and a full-row tap target that
// toggles the bound `isChecked`. Kept `fileprivate` so the row type
// does not leak beyond this layout — the orchestrator task for Wave 1
// asks for a single new file under `ContentLayouts/`.
//
// Ground-truth mapping (.pm/2026-04-06/ground-truth.md §1 exercising
// LocationView 按钮规格 + §3 字体体系 菜品名/check 文字):
//   - Checkbox: 20×20, 4pt corner radius, 1.5pt stroke
//   - Unchecked stroke: rgba(0,0,0,0.15)
//   - Checked stroke: palette.primary + inner SF Symbol "checkmark"
//   - Label: SF Pro 15pt weight 510 → SwiftUI `.medium`,
//            color rgba(0,0,0,0.8)

private struct CheckItemRowView: View {
    let label: String
    let palette: DetailPagePalette
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        isChecked ? palette.primary : Color.black.opacity(0.15),
                        lineWidth: 1.5
                    )
                    .frame(width: 20, height: 20)
                    .overlay {
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(palette.primary)
                        }
                    }

                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.8))

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

private struct CheckListLayoutPreviewHost: View {
    let palette: DetailPagePalette
    let secondaryTitle: String?
    let primaryTitle: String
    let items: [String]
    @State var checkedStates: [Bool]

    var body: some View {
        CheckListLayout(
            palette: palette,
            secondaryTitle: secondaryTitle,
            primaryTitle: primaryTitle,
            items: items,
            checkedStates: $checkedStates
        )
        .frame(width: 340, height: 459, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .stroke(palette.primary, lineWidth: 1)
                .background(Color.white)
        )
        .padding()
    }
}

#Preview("CheckListLayout — exercising (green, dual title)") {
    CheckListLayoutPreviewHost(
        palette: .green,
        secondaryTitle: "记得要带",
        primaryTitle: "推荐你带上",
        items: ["毛巾", "运动手表", "水杯"],
        // Mixed state: first checked, second unchecked, third checked.
        checkedStates: [true, false, true]
    )
}

#Preview("CheckListLayout — outing (blue, single title)") {
    CheckListLayoutPreviewHost(
        palette: .blue,
        secondaryTitle: nil,
        primaryTitle: "记得要带的东西",
        items: ["笔记本电脑与充电器", "营销方案打印稿（5份）", "降噪耳机"],
        // Mixed state: first unchecked, middle checked, last unchecked.
        checkedStates: [false, true, false]
    )
}
