import SwiftUI

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {
    @AppStorage("notify_schedule") private var notifySchedule = true
    @AppStorage("notify_ai_coach") private var notifyAICoach = true
    @AppStorage("notify_daily_review") private var notifyDailyReview = true

    var body: some View {
        Form {
            Section("提醒类型") {
                Toggle("日程提醒", isOn: $notifySchedule)
                Toggle("AI Coach 建议", isOn: $notifyAICoach)
                Toggle("每日复盘提醒", isOn: $notifyDailyReview)
            }

            Section(footer: Text("开启后将在相应时间推送通知")) {
                // Placeholder: future reminder time picker
            }
        }
        .navigationTitle("通知提醒")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - SchedulePreferencesView

struct SchedulePreferencesView: View {
    @AppStorage("schedule_start_hour") private var startHour = 8
    @AppStorage("schedule_end_hour") private var endHour = 23

    var body: some View {
        Form {
            Section("工作时间") {
                Picker("开始时间", selection: $startHour) {
                    ForEach(5..<13, id: \.self) { h in
                        Text("\(h):00").tag(h)
                    }
                }
                Picker("结束时间", selection: $endHour) {
                    ForEach(18..<25, id: \.self) { h in
                        Text("\(h):00").tag(h)
                    }
                }
            }
        }
        .navigationTitle("日程偏好")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AICoachSettingsView

struct AICoachSettingsView: View {
    @AppStorage("ai_model") private var aiModel = "qwen-plus"
    @AppStorage("ai_style") private var aiStyle = "温暖鼓励"

    private let models = ["qwen-plus", "qwen-turbo"]
    private let styles = ["温暖鼓励", "直接高效", "幽默风趣", "严格教练"]

    var body: some View {
        Form {
            Section("模型") {
                Picker("AI 模型", selection: $aiModel) {
                    ForEach(models, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
            }

            Section("对话风格") {
                Picker("风格", selection: $aiStyle) {
                    ForEach(styles, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("AI Coach 设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - DataSyncView

struct DataSyncView: View {
    @State private var cacheSize = "计算中..."
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section("存储") {
                HStack {
                    Text("缓存大小")
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("清除缓存", role: .destructive) {
                    showClearConfirm = true
                }
            }
        }
        .navigationTitle("数据同步")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { calculateCacheSize() }
        .alert("确认清除", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) { clearCache() }
        } message: {
            Text("将清除所有缓存数据，此操作不可撤销")
        }
    }

    private func calculateCacheSize() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cache = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var total: Int64 = 0
        for dir in [docs, cache] {
            if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        total += Int64(size)
                    }
                }
            }
        }
        let mb = Double(total) / 1_048_576.0
        cacheSize = String(format: "%.1f MB", mb)
    }

    private func clearCache() {
        let stickersDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("stickers")
        try? FileManager.default.removeItem(at: stickersDir)
        calculateCacheSize()
    }
}

// MARK: - AboutView

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("构建")
                    Spacer()
                    Text("2026.04")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                HStack {
                    Text("开发者")
                    Spacer()
                    Text("Jun")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview("通知提醒") {
    NavigationStack { NotificationSettingsView() }
}

#Preview("日程偏好") {
    NavigationStack { SchedulePreferencesView() }
}

#Preview("AI Coach") {
    NavigationStack { AICoachSettingsView() }
}

#Preview("数据同步") {
    NavigationStack { DataSyncView() }
}

#Preview("关于") {
    NavigationStack { AboutView() }
}
