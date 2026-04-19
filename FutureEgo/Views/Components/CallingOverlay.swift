import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id: Int
    let role: ChatRole
    let text: String
    /// Only populated when `role == .scheduleCard` — the newly-added schedule
    /// item to render as a confirmation card inline in the chat.
    let scheduleItem: ScheduleItem?

    init(id: Int, role: ChatRole, text: String, scheduleItem: ScheduleItem? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.scheduleItem = scheduleItem
    }

    enum ChatRole {
        case user, ai, scheduleCard
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
    @ObservedObject private var scheduleManager = ScheduleManager.shared

    /// Timer publisher that fires every second for the call duration counter.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Design tokens
    private let accentGreen = Color.brandGreen

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
            .onChange(of: scheduleManager.aiAddedItemsThisCall.count) { oldCount, newCount in
                guard newCount > oldCount else { return }
                let newItems = Array(scheduleManager.aiAddedItemsThisCall[oldCount..<newCount])
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    for item in newItems {
                        msgIdCounter += 1
                        messages.append(ChatMessage(
                            id: msgIdCounter,
                            role: .scheduleCard,
                            text: "",
                            scheduleItem: item
                        ))
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
        if msg.role == .scheduleCard, let item = msg.scheduleItem {
            scheduleCardBubble(item)
        } else {
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
    }

    // MARK: - Schedule Card Bubble

    /// Renders a compact confirmation card for a schedule item the AI just
    /// added via a tool call. Shown inline in the chat area so the user gets
    /// immediate visual feedback during a voice call.
    private func scheduleCardBubble(_ item: ScheduleItem) -> some View {
        let meta = CardMeta.from(item.detail)
        return HStack {
            VStack(alignment: .leading, spacing: 8) {
                // Header: icon + tag + "已添加"
                HStack(spacing: 8) {
                    Image(systemName: meta.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(meta.color)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(meta.color.opacity(0.18)))

                    Text(meta.tag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(meta.color)

                    Spacer()

                    Text("已添加")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Title
                Text(item.title.isEmpty ? item.detail.displayTitle : item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Time
                Text(item.scheduleTime)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))

                // Type-specific details
                if !meta.details.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(meta.details, id: \.self) { line in
                            HStack(alignment: .top, spacing: 6) {
                                Text("·")
                                    .foregroundColor(.white.opacity(0.5))
                                Text(line)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(meta.color.opacity(0.35), lineWidth: 1)
                    )
            )

            Spacer(minLength: 30)
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
                ScheduledCallService.shared.activeCallMode = nil
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

        // Check if this is a scheduled call
        let greetingText: String
        if let mode = ScheduledCallService.shared.activeCallMode {
            let context = ScheduledCallService.shared.generateCallContext(mode: mode)
            Task {
                await AIService.shared.injectContext(context)
            }

            greetingText = mode == .morning
                ? "早上好！☀️ 该起床了，让我帮你看看今天的安排~"
                : "辛苦了一天！🌙 聊聊今天过得怎么样？"
        } else {
            greetingText = "你好！我是你的 AI Coach，今天想聊些什么？"
        }

        // AI greeting after 1s
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

// MARK: - Schedule Card Metadata

/// Per-activity presentation metadata used by `scheduleCardBubble`.
/// Keeps the card renderer readable by computing icon/color/tag and a short
/// list of human-readable detail lines up front.
private struct CardMeta {
    let icon: String
    let color: Color
    let tag: String
    let details: [String]

    static func from(_ activity: Activity) -> CardMeta {
        switch activity {
        case .outing(let d):
            var lines: [String] = []
            if !d.destination.isEmpty { lines.append("目的地：\(d.destination)") }
            if !d.itemsToBring.isEmpty { lines.append("带：\(d.itemsToBring.joined(separator: "、"))") }
            return CardMeta(icon: "location.fill", color: .blue, tag: "出行", details: lines)

        case .eating(.delivery(let d)):
            var lines: [String] = []
            if !d.shopName.isEmpty { lines.append("店铺：\(d.shopName)") }
            if !d.orderItems.isEmpty {
                let names = d.orderItems.prefix(3).map { "\($0.name)×\($0.quantity)" }
                lines.append(names.joined(separator: "、"))
            }
            lines.append("约 \(d.estimatedDeliveryMinutes) 分钟送达")
            if d.estimatedTotalPrice > 0 {
                let priceNum = NSDecimalNumber(decimal: d.estimatedTotalPrice)
                let nf = NumberFormatter()
                nf.numberStyle = .decimal
                nf.maximumFractionDigits = 0
                let priceStr = nf.string(from: priceNum) ?? "\(priceNum.intValue)"
                lines.append("预估 ¥\(priceStr)")
            }
            return CardMeta(icon: "bag.fill", color: .orange, tag: "外卖", details: lines)

        case .eating(.cook(let d)):
            var lines: [String] = []
            let names = d.dishes.map { $0.name }.filter { !$0.isEmpty }
            if !names.isEmpty { lines.append("菜品：\(names.joined(separator: "、"))") }
            lines.append("预计 \(d.cookDurationMinutes) 分钟")
            if !d.ingredients.isEmpty {
                let ing = d.ingredients.prefix(4).map { $0.name }.joined(separator: "、")
                lines.append("食材：\(ing)\(d.ingredients.count > 4 ? "…" : "")")
            }
            return CardMeta(icon: "fork.knife.circle.fill", color: .yellow, tag: "做饭", details: lines)

        case .eating(.eatOut(let d)):
            var lines: [String] = []
            if !d.restaurantName.isEmpty { lines.append("餐厅：\(d.restaurantName)") }
            if !d.restaurantType.isEmpty { lines.append("类型：\(d.restaurantType)") }
            if !d.companion.isEmpty { lines.append("和：\(d.companion)") }
            if !d.recommendedDishes.isEmpty {
                lines.append("推荐：\(d.recommendedDishes.prefix(3).joined(separator: "、"))")
            }
            return CardMeta(icon: "fork.knife", color: .pink, tag: "外食", details: lines)

        case .concentrating(let d):
            var lines: [String] = []
            if let dl = d.deadline {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                lines.append("DDL：\(df.string(from: dl))")
            }
            if !d.steps.isEmpty {
                lines.append(contentsOf: d.steps.prefix(3))
            }
            return CardMeta(icon: "brain.head.profile", color: .purple, tag: d.isAISuggested ? "专注 · AI 建议" : "专注", details: lines)

        case .exercising(let d):
            var lines: [String] = []
            if !d.venueName.isEmpty { lines.append("场地：\(d.venueName)") }
            if !d.aiSuggestedEquipment.isEmpty {
                lines.append("AI 建议带：\(d.aiSuggestedEquipment.joined(separator: "、"))")
            }
            if !d.userEquipment.isEmpty {
                lines.append("已备：\(d.userEquipment.joined(separator: "、"))")
            }
            return CardMeta(icon: "figure.run", color: .green, tag: "运动", details: lines)
        }
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
