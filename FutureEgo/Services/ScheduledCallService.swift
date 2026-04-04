import Foundation
import UserNotifications
import SwiftUI

@MainActor
class ScheduledCallService: ObservableObject {
    static let shared = ScheduledCallService()

    @AppStorage("morning_call_enabled") var morningCallEnabled = false
    @AppStorage("morning_call_hour") var morningCallHour = 7
    @AppStorage("morning_call_minute") var morningCallMinute = 0

    @AppStorage("evening_call_enabled") var eveningCallEnabled = false
    @AppStorage("evening_call_hour") var eveningCallHour = 22
    @AppStorage("evening_call_minute") var eveningCallMinute = 0

    enum CallMode: String {
        case morning, evening
    }

    /// Currently active call mode (set when a scheduled call is answered)
    @Published var activeCallMode: CallMode?

    // MARK: - Schedule Calls

    func scheduleAllCalls() {
        cancelAllScheduledCalls()

        if morningCallEnabled {
            scheduleCall(hour: morningCallHour, minute: morningCallMinute, mode: .morning)
        }
        if eveningCallEnabled {
            scheduleCall(hour: eveningCallHour, minute: eveningCallMinute, mode: .evening)
        }
    }

    private func scheduleCall(hour: Int, minute: Int, mode: CallMode) {
        let content = UNMutableNotificationContent()
        content.title = mode == .morning ? "早安唤醒" : "晚间复盘"
        content.body = mode == .morning ? "Future Ego 来电唤醒你" : "Future Ego 想和你聊聊今天"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("ringtone.caf"))
        content.userInfo = ["call_mode": mode.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "scheduled-call-\(mode.rawValue)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAllScheduledCalls() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["scheduled-call-morning", "scheduled-call-evening"]
        )
    }

    // MARK: - Handle Notification (trigger CallKit)

    func handleScheduledCallNotification(mode: CallMode) {
        activeCallMode = mode
        let reason = mode == .morning ? "早安唤醒 ☀️" : "晚间复盘 🌙"
        CallService.shared.reportIncomingCall(reason: reason)
    }

    // MARK: - Generate Context Prompt for Call

    func generateCallContext(mode: CallMode) -> String {
        let schedule = ScheduleManager.shared.schedule

        switch mode {
        case .morning:
            var context = "这是一通晨间唤醒电话。你需要：\n"
            context += "1. 温暖地唤醒用户（早上好！该起床了~）\n"
            context += "2. 播报今日日程安排：\n"
            for item in schedule {
                context += "   - \(item.scheduleTime): \(item.title)\n"
            }
            context += "3. 询问今天的饮食计划（想吃什么？点外卖还是自己做？）\n"
            context += "4. 温馨提示（天气、带物品等）\n"
            context += "5. 根据用户回答，可以调用函数修改日程\n"
            context += "回复简洁有力，像一个贴心的未来自己在打电话。"
            return context

        case .evening:
            var context = "这是一通晚间复盘电话。你需要：\n"
            context += "1. 温暖地问候（辛苦了，聊聊今天？）\n"
            context += "2. 询问明天几点起床（设置闹钟）\n"
            context += "3. 询问明天有什么安排想提前规划的\n"
            context += "4. 询问今天的感受和想法\n"
            context += "5. 帮助复盘：今天完成了什么，有什么遗憾\n"
            context += "6. 根据用户回答，可以调用函数安排明天的日程或设置提醒\n"
            context += "今日日程回顾：\n"
            for item in schedule {
                let status = item.status == .done ? "✅" : "⏳"
                context += "   \(status) \(item.scheduleTime): \(item.title)\n"
            }
            context += "回复简洁温暖，像一个贴心的未来自己在晚间电话。"
            return context
        }
    }
}
