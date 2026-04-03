import SwiftUI

/// A circular checkbox with a text label.
/// Selected: green filled circle with white checkmark.
/// Deselected: gray-bordered hollow circle.
struct CheckItem: View {
    let text: String
    @Binding var isChecked: Bool

    // MARK: - Design tokens
    private let circleSize: CGFloat = 22
    private let accentGreen = Color(hex: "34C759")

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                // Circular checkbox
                ZStack {
                    Circle()
                        .strokeBorder(
                            isChecked ? accentGreen : Color.black.opacity(0.15),
                            lineWidth: 2
                        )
                        .frame(width: circleSize, height: circleSize)

                    Circle()
                        .fill(isChecked ? accentGreen : Color.clear)
                        .frame(width: circleSize, height: circleSize)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(isChecked ? 1.0 : 1.0) // base; animation handled by spring

                // Text label
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(isChecked ? Color.black.opacity(0.3) : Color.black.opacity(0.8))
                    .strikethrough(isChecked, color: Color.black.opacity(0.3))
                    .animation(.easeInOut(duration: 0.25), value: isChecked)

                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(CheckItemButtonStyle())
    }
}

// MARK: - Button style with tap scale animation

private struct CheckItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: // ARGB
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, (int >> 24) & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var a = false
        @State private var b = true
        @State private var c = false
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                CheckItem(text: "复习英语单词", isChecked: $a)
                CheckItem(text: "完成日报", isChecked: $b)
                CheckItem(text: "跑步 30 分钟", isChecked: $c)
            }
            .padding()
        }
    }
    return PreviewWrapper()
}
