import SwiftUI

struct ReviewTabView: View {
    // MARK: - Animation State

    @State private var appeared = false

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Icon container — 80×80 rounded rect with document icon
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.03))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(Color(hex: "C7C7CC"))
                    }

                // Title
                Text("每日复盘")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                // Description
                Text("今日尚未结束，复盘功能将在\n一天结束后自动开启")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.7),
                value: appeared
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 80) // leave room for tab bar
        .onAppear {
            appeared = true
        }
    }
}

#Preview {
    ReviewTabView()
}
