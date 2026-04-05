import SwiftUI

// MARK: - CheckItemRow
//
// A single checklist row used by the redesigned activity detail pages
// (bring-list on Outing, ingredient/step list on Cook, …). Owns its
// tap handling but delegates state to a `Binding<Bool>` so parent views
// can persist the checked state however they like.
//
// Visual rules come from Figma + spec:
//   - unchecked: 20pt hollow circle, stroke = `Color.divider`
//   - checked:   20pt filled circle in `Color.brandGreen` with a white
//                SF Symbol `checkmark` glyph
//   - label:     17pt regular, strike-through when checked (feels more
//                useful than the spec strictly requires and matches
//                iOS Reminders; easy to drop if designers object)
//   - row padding: 12 on all sides
//   - spacing between checkbox and label: 10

struct CheckItemRow: View {
    let text: String
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isChecked.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                checkbox
                Text(text)
                    .font(.bodyRegular)
                    .foregroundColor(.black)
                    .strikethrough(isChecked, color: .black.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Checkbox

    @ViewBuilder
    private var checkbox: some View {
        ZStack {
            if isChecked {
                Circle()
                    .fill(Color.brandGreen)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Circle()
                    .stroke(Color.divider, lineWidth: 1.5)
            }
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - Preview

#Preview("CheckItemRow") {
    StatefulPreviewWrapper()
        .padding(24)
}

private struct StatefulPreviewWrapper: View {
    @State private var first = false
    @State private var second = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CheckItemRow(text: "带钥匙", isChecked: $first)
            CheckItemRow(text: "带充电宝", isChecked: $second)
        }
    }
}
