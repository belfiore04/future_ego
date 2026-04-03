import SwiftUI

/// A vertical step list with numbered circles connected by lines.
/// Tapping a circle toggles its completion state.
struct StepFlow: View {
    let steps: [String]
    @State private var doneSteps: Set<Int> = []

    // MARK: - Design tokens
    private let circleSize: CGFloat = 24
    private let lineWidth: CGFloat = 1.5
    private let lineHeight: CGFloat = 20
    private let accentGreen = Color(hex: "34C759")

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let done = doneSteps.contains(index)

                HStack(alignment: .top, spacing: 12) {
                    // Left column: circle + connector line
                    VStack(spacing: 0) {
                        // Numbered / checked circle
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                if done {
                                    doneSteps.remove(index)
                                } else {
                                    doneSteps.insert(index)
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        done ? accentGreen : Color.black.opacity(0.12),
                                        lineWidth: 2
                                    )

                                Circle()
                                    .fill(done ? accentGreen : Color.clear)

                                if done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.3))
                                }
                            }
                            .frame(width: circleSize, height: circleSize)
                        }
                        .buttonStyle(StepCircleButtonStyle())

                        // Connector line (not for the last step)
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(done ? accentGreen : Color.black.opacity(0.08))
                                .frame(width: lineWidth, height: lineHeight)
                                .animation(.easeInOut(duration: 0.25), value: done)
                        }
                    }

                    // Step text
                    Text(step)
                        .font(.system(size: 15))
                        .foregroundColor(done ? Color.black.opacity(0.3) : Color.black.opacity(0.8))
                        .strikethrough(done, color: Color.black.opacity(0.3))
                        .padding(.top, 2)
                        .padding(.bottom, 12)
                        .animation(.easeInOut(duration: 0.25), value: done)
                }
            }
        }
    }
}

// MARK: - Button style

private struct StepCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    StepFlow(steps: [
        "打开教材第三章",
        "阅读核心概念部分",
        "完成课后练习题",
        "整理笔记并复习"
    ])
    .padding()
}
