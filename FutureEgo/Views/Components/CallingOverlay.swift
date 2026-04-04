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
/// Supports voice mode (default) with real-time ASR/TTS and text mode toggle.
struct CallingOverlay: View {
    let onHangUp: () -> Void

    // MARK: - State
    @State private var callTime: Int = 0
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var msgIdCounter = 0
    @State private var isThinking = false
    @State private var thinkingDotAnimation = false
    @State private var isVoiceMode = true
    @State private var micPulse = false
    @FocusState private var isInputFocused: Bool

    @StateObject private var voice = VoiceService.shared

    /// Timer publisher that fires every second for the call duration counter.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Design tokens
    private let accentGreen = Color(hex: "34C759")

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

                    if isThinking {
                        thinkingBubble
                            .id("thinking")
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
            .onChange(of: isThinking) { _, thinking in
                if thinking {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
        }
    }

    /// Three bouncing dots shown while waiting for the AI reply.
    private var thinkingBubble: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .offset(y: thinkingDotAnimation ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: thinkingDotAnimation
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.1))
            .clipShape(BubbleShape(isUser: false))
            .onAppear { thinkingDotAnimation = true }
            .onDisappear { thinkingDotAnimation = false }

            Spacer(minLength: 50)
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
            if isVoiceMode {
                voiceModeControls
            } else {
                textModeControls
            }

            // Hang up button
            Button(action: {
                voice.stopAll()
                Task { await AIService.shared.resetConversation() }
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

    // MARK: - Voice Mode Controls

    private var voiceModeControls: some View {
        VStack(spacing: 10) {
            // Real-time transcript
            if !voice.currentTranscript.isEmpty {
                Text(voice.currentTranscript)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            HStack(spacing: 24) {
                // Switch to text mode
                Button(action: switchToTextMode) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }

                // Microphone indicator
                ZStack {
                    // Outer pulse rings
                    if voice.isListening && !voice.isSpeaking {
                        Circle()
                            .stroke(accentGreen.opacity(0.3), lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .scaleEffect(micPulse ? 1.3 : 1.0)
                            .opacity(micPulse ? 0 : 0.6)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                                value: micPulse
                            )

                        Circle()
                            .stroke(accentGreen.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 80, height: 80)
                            .scaleEffect(micPulse ? 1.6 : 1.0)
                            .opacity(micPulse ? 0 : 0.4)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.3),
                                value: micPulse
                            )
                    }

                    // Main mic circle
                    Circle()
                        .fill(
                            voice.isSpeaking
                                ? Color.blue.opacity(0.3)
                                : (voice.isListening ? accentGreen.opacity(0.2) : Color.white.opacity(0.1))
                        )
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(
                                    voice.isSpeaking
                                        ? Color.blue.opacity(0.5)
                                        : (voice.isListening ? accentGreen.opacity(0.5) : Color.white.opacity(0.2)),
                                    lineWidth: 2
                                )
                        )

                    Image(systemName: voice.isSpeaking ? "speaker.wave.2.fill" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(
                            voice.isSpeaking
                                ? .blue
                                : (voice.isListening ? accentGreen : .white.opacity(0.5))
                        )
                }
                .onAppear { micPulse = true }

                // Spacer button to balance layout
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Text Mode Controls

    private var textModeControls: some View {
        HStack(spacing: 8) {
            // Switch to voice mode
            Button(action: switchToVoiceMode) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(accentGreen)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(accentGreen.opacity(0.15)))
            }

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
    }

    // MARK: - Mode Switching

    private func switchToTextMode() {
        voice.stopListening()
        withAnimation(.easeInOut(duration: 0.25)) {
            isVoiceMode = false
        }
        isInputFocused = true
    }

    private func switchToVoiceMode() {
        isInputFocused = false
        withAnimation(.easeInOut(duration: 0.25)) {
            isVoiceMode = true
        }
        voice.startListening()
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startCall() {
        // Set up voice service callbacks
        voice.onSentenceComplete = { [self] text in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                addMessage(role: .user, text: text)
                PersistenceService.shared.saveChatMessage(role: "user", text: text)
            }
            sendToAI(text)
        }

        // Start listening in voice mode
        if isVoiceMode {
            voice.startListening()
        }

        // AI greeting after 1s
        let greetingText = "你好！我是你的 AI Coach，今天想聊些什么？"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                addMessage(role: .ai, text: greetingText)
                PersistenceService.shared.saveChatMessage(role: "ai", text: greetingText)
            }
            if isVoiceMode {
                Task { await voice.speak(greetingText) }
            }
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isThinking else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            addMessage(role: .user, text: trimmed)
            PersistenceService.shared.saveChatMessage(role: "user", text: trimmed)
        }
        inputText = ""

        sendToAI(trimmed)
    }

    /// Send text to the Bailian API and append the reply as an AI message.
    /// In voice mode, also plays the reply via TTS.
    private func sendToAI(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isThinking = true
        }

        Task {
            do {
                let reply = try await AIService.shared.sendMessage(text)
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isThinking = false
                        addMessage(role: .ai, text: reply)
                        PersistenceService.shared.saveChatMessage(role: "ai", text: reply)
                    }
                }
                // Auto-play TTS in voice mode
                if isVoiceMode {
                    await voice.speak(reply)
                }
            } catch {
                let errorText = "抱歉，网络出了点问题，请稍后再试"
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isThinking = false
                        addMessage(role: .ai, text: errorText)
                        PersistenceService.shared.saveChatMessage(role: "ai", text: errorText)
                    }
                }
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
