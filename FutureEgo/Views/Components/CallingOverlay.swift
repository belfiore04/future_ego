import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id: Int
    let role: ChatRole
    let text: String

    enum ChatRole {
        case user, ai
    }
}

// MARK: - CallingOverlay

/// Full-screen calling overlay with chat, timer, and hang-up button.
/// Transliterated from calling-screen.tsx.
struct CallingOverlay: View {
    let onHangUp: () -> Void

    // MARK: - State
    @State private var callTime: Int = 0
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var msgIdCounter = 0
    @State private var mockIndex = 0
    @FocusState private var isInputFocused: Bool

    /// Timer publisher that fires every second for the call duration counter.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Design tokens
    private let accentGreen = Color(hex: "34C759")

    // MARK: - Mock data
    private static let mockConversation: [(user: String, ai: String)] = [
        ("我想讨论一下最近的工作效率问题",
         "好的，能具体说说你遇到了什么挑战吗？是时间管理、注意力分散还是其他方面？"),
        ("主要是注意力很难集中，总是被各种消息打断",
         "这是很常见的问题。建议你试试「番茄工作法」——25分钟专注 + 5分钟休息，期间关闭所有通知"),
        ("听起来不错，还有其他建议吗？",
         "你可以试试「两分钟法则」：如果一件事两分钟内能做完就立刻做，否则记下来稍后处理，这样能减少心理负担。"),
        ("好的我试试看，谢谢你",
         "不客气！坚持一周你就会感受到变化，有任何问题随时找我聊")
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dark background (fullScreenCover provides its own chrome)
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Timer
                timerView

                // Name + status
                nameStatusView

                // Chat area
                chatArea

                // Input bar + hang up
                bottomControls
            }
        }
        .onReceive(timer) { _ in
            callTime += 1
        }
        .onAppear {
            startCall()
        }
    }

    // MARK: - Timer

    private var timerView: some View {
        Text(formatTime(callTime))
            .font(.system(size: 48, weight: .light))
            .tracking(-0.5)
            .foregroundColor(.white)
            .padding(.top, 24)
            .padding(.bottom, 4)
    }

    // MARK: - Name & Status

    private var nameStatusView: some View {
        VStack(spacing: 6) {
            Text("AI Coach")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                // Pulsing green dot
                Circle()
                    .fill(accentGreen)
                    .frame(width: 6, height: 6)
                    .shadow(color: accentGreen, radius: 3)
                    .modifier(PulseDotModifier())

                Text("通话中")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        chatBubble(msg)
                            .id(msg.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.96)),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chatBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 50) }

            Text(msg.text)
                .font(.system(size: 17))
                .lineSpacing(4)
                .foregroundColor(msg.role == .user ? .white : .white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    msg.role == .user
                        ? AnyShapeStyle(accentGreen)
                        : AnyShapeStyle(Color.white.opacity(0.1))
                )
                .clipShape(BubbleShape(isUser: msg.role == .user))

            if msg.role == .ai { Spacer(minLength: 50) }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Text input row
            HStack(spacing: 8) {
                TextField("输入消息...", text: $inputText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .tint(accentGreen)
                    .focused($isInputFocused)
                    .onSubmit { sendMessage() }

                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                      ? Color.white.opacity(0.08)
                                      : accentGreen)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)

            // Hang up button
            Button(action: {
                onHangUp()
            }) {
                Text("结束通话")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FF3B30"), Color(hex: "FF6B60")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "FF3B30").opacity(0.3), radius: 8, y: 4)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startCall() {
        // AI greeting after 1s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                addMessage(role: .ai, text: "你好！我是你的 AI Coach，今天想聊些什么？")
            }
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            addMessage(role: .user, text: trimmed)
        }
        inputText = ""

        // Mock AI reply
        let idx = mockIndex
        let reply: String
        if idx < Self.mockConversation.count {
            reply = Self.mockConversation[idx].ai
        } else {
            reply = "收到！让我想想怎么帮你..."
        }
        mockIndex += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                addMessage(role: .ai, text: reply)
            }
        }
    }

    private func addMessage(role: ChatMessage.ChatRole, text: String) {
        msgIdCounter += 1
        messages.append(ChatMessage(id: msgIdCounter, role: role, text: text))
    }
}

// MARK: - Bubble Shape

/// Chat bubble with one rounded corner flattened depending on sender.
struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 20
        let small: CGFloat = 4

        if isUser {
            // Top-left, top-right, bottom-right(small), bottom-left all rounded
            return RoundedCornerShape(
                topLeft: r, topRight: r,
                bottomLeft: r, bottomRight: small
            ).path(in: rect)
        } else {
            return RoundedCornerShape(
                topLeft: r, topRight: r,
                bottomLeft: small, bottomRight: r
            ).path(in: rect)
        }
    }
}

/// Custom shape with individually-specified corner radii.
struct RoundedCornerShape: Shape {
    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        // Start top-left
        path.move(to: CGPoint(x: topLeft, y: 0))
        path.addLine(to: CGPoint(x: w - topRight, y: 0))
        path.addArc(
            center: CGPoint(x: w - topRight, y: topRight),
            radius: topRight, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: w, y: h - bottomRight))
        path.addArc(
            center: CGPoint(x: w - bottomRight, y: h - bottomRight),
            radius: bottomRight, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: bottomLeft, y: h))
        path.addArc(
            center: CGPoint(x: bottomLeft, y: h - bottomLeft),
            radius: bottomLeft, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: topLeft))
        path.addArc(
            center: CGPoint(x: topLeft, y: topLeft),
            radius: topLeft, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()

        return path
    }
}

// MARK: - Pulse Dot Modifier

/// Animates a gentle pulse (opacity + scale) on the green "calling" indicator dot.
struct PulseDotModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.5 : 1.0)
            .scaleEffect(isPulsing ? 0.8 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
