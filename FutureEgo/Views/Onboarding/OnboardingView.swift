import SwiftUI

// MARK: - OnboardingView

/// 4-page onboarding flow: Welcome -> Vision Input -> Generating -> Reveal.
/// Shown on first launch; sets `onboarding_completed` when finished.
struct OnboardingView: View {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    @AppStorage("future_ego_persona") private var futureEgoPersona = ""
    @AppStorage("future_ego_traits") private var futureEgoTraits = ""
    @AppStorage("future_ego_greeting") private var futureEgoGreeting = ""

    @State private var currentPage = 0
    @State private var userVision = ""
    @State private var isGenerating = false
    @State private var generatedTraits: [String] = []
    @State private var generatedGreeting = ""
    @State private var generationStep = 0
    @FocusState private var isVisionEditorFocused: Bool

    // MARK: - Design Tokens

    private let accentGreen = Color.brandGreen
    private let subtitleGray = Color(hex: "8E8E93")

    // MARK: - Body

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            visionInputPage.tag(1)
            generatingPage.tag(2)
            revealPage.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("跳过") {
                    onboardingCompleted = true
                }
                .font(.system(size: 16))
                .foregroundColor(subtitleGray)
                .padding(.trailing, 24)
                .padding(.top, 16)
            }

            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentGreen.opacity(0.3), accentGreen.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "person.crop.circle.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(accentGreen)
            }
            .padding(.bottom, 32)

            // Title
            Text("遇见未来的自己")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 12)

            // Subtitle
            Text("交联将为你创造一个 Future Ego\n来自未来的你，陪伴现在的你\n规划生活、提醒日程、复盘成长")
                .font(.system(size: 16))
                .foregroundColor(subtitleGray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            Spacer()

            // Bottom: page indicator + button
            VStack(spacing: 20) {
                pageIndicator(current: 0)

                Button {
                    withAnimation { currentPage = 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text("开始设定")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(accentGreen)
                    )
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Page 1: Vision Input

    private var visionInputPage: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation { currentPage = 0 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.leading, 24)
                .padding(.top, 16)

                Spacer()
            }

            // Title
            Text("你希望未来的自己\n是什么样的？")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8)

            // Subtitle
            Text("描述你理想中的 Future Ego，TA 会成为你的专属 AI 教练")
                .font(.system(size: 16))
                .foregroundColor(subtitleGray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            // Text editor with placeholder
            ZStack(alignment: .topLeading) {
                if userVision.isEmpty {
                    Text("例如：我希望未来的自己是一个自律、高效、热爱生活的人。每天坚持运动，工作有条理，能平衡工作与生活...")
                        .font(.system(size: 16))
                        .foregroundColor(subtitleGray.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }

                TextEditor(text: $userVision)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .focused($isVisionEditorFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isVisionEditorFocused = false }
                        .foregroundColor(accentGreen)
                        .fontWeight(.semibold)
                }
            }

            // Hint
            Text("💡 可以描述性格、习惯、生活方式、职业目标")
                .font(.system(size: 14))
                .foregroundColor(subtitleGray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            // Bottom: page indicator + button
            VStack(spacing: 20) {
                pageIndicator(current: 1)

                Button {
                    generatePersona()
                } label: {
                    Text("生成 Future Ego")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    userVision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color(.systemGray4)
                                        : accentGreen
                                )
                        )
                }
                .disabled(userVision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 24)
            }
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Page 2: Generating

    private var generatingPage: some View {
        let stepTexts = [
            "理解你的愿景...",
            "构建 TA 的性格...",
            "设定 TA 的说话方式..."
        ]

        return VStack(spacing: 0) {
            Spacer()

            // Pulsing dots animation
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accentGreen.opacity(0.8))
                        .frame(width: 14, height: 14)
                        .scaleEffect(isGenerating ? 1.0 : 0.5)
                        .opacity(isGenerating ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: isGenerating
                        )
                }
            }
            .padding(.bottom, 32)

            // Title
            Text("正在生成你的 Future Ego")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 24)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentGreen)
                        .frame(
                            width: geo.size.width * progressFraction,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.8), value: generationStep)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 48)
            .padding(.bottom, 24)

            // Step text
            Text(stepTexts[min(generationStep, stepTexts.count - 1)])
                .font(.system(size: 16))
                .foregroundColor(subtitleGray)
                .animation(.easeInOut(duration: 0.3), value: generationStep)

            Spacer()

            // Page indicator (no button on this page)
            pageIndicator(current: 2)
                .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
        .allowsHitTesting(false) // Prevent manual swiping
    }

    private var progressFraction: CGFloat {
        switch generationStep {
        case 0: return 0.2
        case 1: return 0.5
        case 2: return 0.8
        default: return 1.0
        }
    }

    // MARK: - Page 3: Reveal

    private var revealPage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Avatar icon
            ZStack {
                Circle()
                    .fill(accentGreen.opacity(0.15))
                    .frame(width: 90, height: 90)

                Image(systemName: "face.smiling")
                    .font(.system(size: 44))
                    .foregroundStyle(accentGreen)
            }
            .padding(.bottom, 20)

            // Title
            Text("你好，我是未来的你")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 24)

            // Traits card
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(generatedTraits.enumerated()), id: \.offset) { _, trait in
                    traitRow(trait)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(accentGreen.opacity(0.08))
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Greeting quote
            if !generatedGreeting.isEmpty {
                Text("「\(generatedGreeting)」")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }

            Spacer()

            // Bottom: page indicator + button
            VStack(spacing: 20) {
                pageIndicator(current: 3)

                Button {
                    saveAndFinish()
                } label: {
                    HStack(spacing: 6) {
                        Text("开始旅程")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(accentGreen)
                    )
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Trait Row

    @ViewBuilder
    private func traitRow(_ trait: String) -> some View {
        let parts = trait.split(separator: "\n", maxSplits: 1)
        let title = parts.first.map(String.init) ?? trait
        let detail = parts.count > 1 ? String(parts[1]) : nil

        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            if let detail {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(subtitleGray)
            }
        }
    }

    // MARK: - Page Indicator

    private func pageIndicator(current: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i == current ? accentGreen : Color(.systemGray4))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Generate Persona

    private func generatePersona() {
        isGenerating = true
        generationStep = 0
        withAnimation { currentPage = 2 }

        Task {
            // Animated step progression
            for step in 0..<3 {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    withAnimation { generationStep = step }
                }
            }

            do {
                let prompt = """
                用户描述了他们理想中未来自己的样子：
                「\(userVision)」

                请根据这段描述，生成这个 Future Ego 的人设。返回 JSON 格式：
                {
                  "traits": ["特征1: 描述", "特征2: 描述", "特征3: 描述"],
                  "greeting": "以这个人设的口吻说的第一句话（30字以内）",
                  "persona_prompt": "一段完整的系统提示词，定义这个AI的性格、说话风格、关注领域（200字以内）"
                }

                要求：
                - traits 每条格式为 "emoji 关键词\\n详细描述"
                - greeting 要温暖、自信、有感染力
                - persona_prompt 要足够详细，能让 AI 始终保持这个人设
                - 全部中文
                """

                let reply = try await callAPI(
                    systemPrompt: "你是一个角色设定专家。只返回 JSON，不加其他文字。",
                    userMessage: prompt
                )

                // Strip markdown code fences if present
                let cleaned = reply
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let data = cleaned.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let traits = json["traits"] as? [String] ?? []
                    let greeting = json["greeting"] as? String ?? "你好，我是未来的你。"
                    let persona = json["persona_prompt"] as? String ?? ""

                    await MainActor.run {
                        generatedTraits = traits
                        generatedGreeting = greeting
                        futureEgoPersona = persona
                        withAnimation { currentPage = 3 }
                        isGenerating = false
                    }
                } else {
                    // JSON parse failed — use fallback
                    await MainActor.run {
                        applyFallbackPersona()
                    }
                }
            } catch {
                // Network or other error — use fallback
                await MainActor.run {
                    applyFallbackPersona()
                }
            }
        }
    }

    private func applyFallbackPersona() {
        generatedTraits = [
            "\u{1F9E0} 理性而高效\n做事有条理，时间管理佳",
            "\u{1F4AA} 自律且坚持\n每日运动，健康饮食",
            "\u{1F331} 温暖有洞察力\n关注成长，善于复盘"
        ]
        generatedGreeting = "你好，我是未来的你。准备好了吗？"
        futureEgoPersona = "你是用户的未来自我，温暖、自信、有洞察力。你帮助用户规划日程、提升效率、保持健康的生活习惯。"
        withAnimation { currentPage = 3 }
        isGenerating = false
    }

    // MARK: - Save & Finish

    private func saveAndFinish() {
        // Persist traits as JSON array
        if let traitsData = try? JSONSerialization.data(withJSONObject: generatedTraits),
           let traitsString = String(data: traitsData, encoding: .utf8) {
            futureEgoTraits = traitsString
        }
        futureEgoGreeting = generatedGreeting
        // futureEgoPersona was already saved during generation
        onboardingCompleted = true
    }

    // MARK: - API Call

    /// Direct API call for one-time persona generation (bypasses AIService actor).
    private func callAPI(systemPrompt: String, userMessage: String) async throws -> String {
        let url = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer sk-a80c8b8cfc0049f49a8213120f0bd6c8", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "qwen-plus",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "temperature": 0.8
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let content = (choices?.first?["message"] as? [String: Any])?["content"] as? String
        return content ?? ""
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
