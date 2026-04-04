import SwiftUI

// MARK: - ProfileTabView

struct ProfileTabView: View {
    // MARK: - User Profile Persistence
    @AppStorage("user_nickname") private var nickname = "用户"
    @AppStorage("user_motto") private var motto = "每天进步一点点"

    // MARK: - Animation State
    @State private var appeared = false
    @State private var showEditProfile = false
    @State private var editNickname = ""
    @State private var editMotto = ""

    // MARK: - Stats Data

    private let stats: [(label: String, value: String, sub: String)] = [
        ("已完成", "128", "任务"),
        ("连续打卡", "14", "天"),
        ("本周效率", "87", "%"),
    ]

    // MARK: - Settings Items

    private let settingsItems = ["通知提醒", "日程偏好", "AI Coach 设置", "数据同步", "关于"]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: Header "我的"
                HStack {
                    Text("我的")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 2)

                // MARK: Avatar & Name
                avatarSection

                // MARK: Stats Row
                statsRow

                // MARK: Settings List
                settingsList
            }
            .padding(.bottom, 100)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 0) {
            // Avatar circle with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "34C759"), Color(hex: "30D158")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: Color(hex: "34C759").opacity(0.3), radius: 8, x: 0, y: 4)

                Text(String(nickname.prefix(1)))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }

            // User name
            Text(nickname)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 12)

            // Motto
            Text(motto)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.top, 4)

            // Edit profile button
            Button {
                editNickname = nickname
                editMotto = motto
                showEditProfile = true
            } label: {
                Text("编辑资料")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "34C759"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .stroke(Color(hex: "34C759"), lineWidth: 1)
                    )
            }
            .padding(.top, 10)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .alert("编辑资料", isPresented: $showEditProfile) {
            TextField("昵称", text: $editNickname)
            TextField("座右铭", text: $editMotto)
            Button("取消", role: .cancel) { }
            Button("保存") {
                let trimmedNickname = editNickname.trimmingCharacters(in: .whitespaces)
                let trimmedMotto = editMotto.trimmingCharacters(in: .whitespaces)
                if !trimmedNickname.isEmpty { nickname = trimmedNickname }
                if !trimmedMotto.isEmpty { motto = trimmedMotto }
            }
        } message: {
            Text("修改你的昵称和座右铭")
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                statCard(stat: stat, index: index)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func statCard(stat: (label: String, value: String, sub: String), index: Int) -> some View {
        VStack(spacing: 6) {
            Text(stat.value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "34C759"))

            Text(stat.label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.06),
            value: appeared
        )
    }

    // MARK: - Settings List

    private var settingsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section title
            Text("设置")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.horizontal, 4)

            // Card with rows
            VStack(spacing: 0) {
                ForEach(Array(settingsItems.enumerated()), id: \.offset) { index, item in
                    settingsRow(title: item)

                    // Divider (not after the last item)
                    if index < settingsItems.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 24)
    }

    private func settingsRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.black)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "C7C7CC"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    ProfileTabView()
}
