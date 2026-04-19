import UIKit
import UserNotifications
import os

private let log = Logger(subsystem: "com.futureego.scheduledcall", category: "AppDelegate")

/// Concrete UIKit app delegate bridged into the SwiftUI app via
/// `@UIApplicationDelegateAdaptor`. The main reason it exists is to
/// install a `UNUserNotificationCenterDelegate` — without one, banner
/// notifications still appear but:
///   * foreground deliveries are silent and the app never hears about them,
///   * tapping a scheduled-call notification does NOT route into
///     `ScheduledCallService.handleScheduledCallNotification`, so the
///     morning/evening CallKit "incoming call" never triggers.
///
/// Anything that needs the `call_mode` payload (set in
/// `ScheduledCallService.scheduleCall`) comes through here.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        log.info("AppDelegate: UNUserNotificationCenter.delegate installed")
        return true
    }

    // Foreground delivery. For scheduled-call and outing-call notifications
    // we skip the banner and hand straight off to the overlay / CallKit so
    // the user isn't forced through a swipe before the call UI appears.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if let mode = Self.callMode(from: notification) {
            log.info("willPresent scheduled-call mode=\(mode.rawValue, privacy: .public) — routing to overlay")
            Task { @MainActor in
                ScheduledCallService.shared.handleScheduledCallNotification(mode: mode)
            }
            completionHandler([])
            return
        }
        if let reason = Self.outingCallReason(from: notification) {
            log.info("willPresent outing-call — routing to CallKit")
            Task { @MainActor in
                CallService.shared.reportIncomingCall(reason: reason)
            }
            completionHandler([])
            return
        }
        // Non-call notifications (outing -15min, eat_out -30min) get the
        // normal treatment so they show as a banner while foreground.
        completionHandler([.banner, .sound, .list])
    }

    // User tapped a notification from the notification center / lock screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let mode = Self.callMode(from: response.notification) {
            log.info("didReceive scheduled-call mode=\(mode.rawValue, privacy: .public)")
            Task { @MainActor in
                ScheduledCallService.shared.handleScheduledCallNotification(mode: mode)
            }
        } else if let reason = Self.outingCallReason(from: response.notification) {
            log.info("didReceive outing-call")
            Task { @MainActor in
                CallService.shared.reportIncomingCall(reason: reason)
            }
        }
        completionHandler()
    }

    private static func callMode(from notification: UNNotification) -> ScheduledCallService.CallMode? {
        guard
            let raw = notification.request.content.userInfo["call_mode"] as? String,
            let mode = ScheduledCallService.CallMode(rawValue: raw)
        else { return nil }
        return mode
    }

    private static func outingCallReason(from notification: UNNotification) -> String? {
        notification.request.content.userInfo[ReminderService.outingCallReasonKey] as? String
    }
}
