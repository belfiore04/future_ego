import Foundation
import UserNotifications
import SwiftUI
import os

/// Logger for scheduled call lifecycle. Use Console.app on Mac (with the
/// iPhone connected) and filter by subsystem `com.futureego.scheduledcall`
/// — these show up even when Xcode is not attached, which is essential
/// because the notification fires when the debugger is long gone.
private let log = Logger(subsystem: "com.futureego.scheduledcall", category: "ScheduledCallService")

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
        log.info("scheduleAllCalls: morningEnabled=\(self.morningCallEnabled) eveningEnabled=\(self.eveningCallEnabled)")
        cancelAllScheduledCalls()

        if morningCallEnabled {
            scheduleCall(hour: morningCallHour, minute: morningCallMinute, mode: .morning)
        }
        if eveningCallEnabled {
            scheduleCall(hour: eveningCallHour, minute: eveningCallMinute, mode: .evening)
        }
    }

    private func scheduleCall(hour: Int, minute: Int, mode: CallMode) {
        log.info("scheduleCall mode=\(mode.rawValue, privacy: .public) at \(hour):\(String(format: "%02d", minute))")
        let content = UNMutableNotificationContent()
        content.title = mode == .morning ? "早安唤醒" : "晚间复盘"
        content.body = mode == .morning ? "Future Ego 来电唤醒你" : "Future Ego 想和你聊聊今天"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("ringtone.caf"))
        content.userInfo = ["call_mode": mode.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let identifier = "scheduled-call-\(mode.rawValue)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("add notification failed id=\(identifier, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
            } else {
                log.info("add notification OK id=\(identifier, privacy: .public)")
            }
        }
    }

    func cancelAllScheduledCalls() {
        log.info("cancelAllScheduledCalls")
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["scheduled-call-morning", "scheduled-call-evening", "scheduled-call-debug"]
        )
    }

    // MARK: - Handle Notification (trigger CallKit)

    func handleScheduledCallNotification(mode: CallMode) {
        log.info("handleScheduledCallNotification mode=\(mode.rawValue, privacy: .public)")
        activeCallMode = mode
        let reason = mode == .morning ? "早安唤醒 ☀️" : "晚间复盘 🌙"
        CallService.shared.reportIncomingCall(reason: reason)
    }

    // MARK: - Debug helpers

    /// Bypass the notification path entirely and invoke the CallKit
    /// reportIncomingCall flow right now. Use this to check whether
    /// CallKit itself is functioning on this device.
    func debugTriggerNow(mode: CallMode) {
        log.info("debugTriggerNow mode=\(mode.rawValue, privacy: .public)")
        handleScheduledCallNotification(mode: mode)
    }

    /// Schedule a one-shot notification a few seconds from now so you can
    /// verify the notification-delivery path end-to-end (permission, sound,
    /// banner, and — if a UNUserNotificationCenterDelegate is installed —
    /// the handleScheduledCallNotification callback).
    func debugScheduleNotification(in seconds: TimeInterval, mode: CallMode) {
        log.info("debugScheduleNotification in=\(seconds)s mode=\(mode.rawValue, privacy: .public)")
        let content = UNMutableNotificationContent()
        content.title = "[Debug] \(mode == .morning ? "早安唤醒" : "晚间复盘")"
        content.body = "\(Int(seconds))s 后触发的调试通知"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("ringtone.caf"))
        content.userInfo = ["call_mode": mode.rawValue, "debug": true]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "scheduled-call-debug",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("debug add failed: \(error.localizedDescription, privacy: .public)")
            } else {
                log.info("debug add OK, fires in \(seconds)s")
            }
        }
    }

    /// Dump all pending notification requests to the log so you can see
    /// what iOS thinks is scheduled.
    func debugPrintPendingRequests() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            log.info("pending requests count=\(requests.count)")
            for req in requests {
                let triggerDesc: String
                if let cal = req.trigger as? UNCalendarNotificationTrigger {
                    triggerDesc = "calendar repeats=\(cal.repeats) next=\(cal.nextTriggerDate()?.description ?? "nil")"
                } else if let t = req.trigger as? UNTimeIntervalNotificationTrigger {
                    triggerDesc = "interval=\(t.timeInterval)s repeats=\(t.repeats)"
                } else {
                    triggerDesc = "other"
                }
                log.info("• id=\(req.identifier, privacy: .public) trigger=\(triggerDesc, privacy: .public)")
            }
        }
    }

    /// Check and log current notification authorization status.
    func debugCheckAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            log.info("authorizationStatus=\(settings.authorizationStatus.rawValue) alertSetting=\(settings.alertSetting.rawValue) soundSetting=\(settings.soundSetting.rawValue)")
        }
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
