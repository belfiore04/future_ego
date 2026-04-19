import UserNotifications
import MapKit
import Foundation
import os

private let log = Logger(subsystem: "com.futureego.reminder", category: "ReminderService")

@MainActor
class ReminderService: ObservableObject {
    static let shared = ReminderService()

    // Lookup from schedule UUID → the two notification identifiers we
    // registered for that outing. Used by `cancelOutingReminders` to map
    // a ScheduleItem back to the notification requests it owns without
    // having to know the title.
    private var outingReminderIdentifiers: [UUID: OutingReminderIdentifiers] = [:]

    private struct OutingReminderIdentifiers {
        let notifyIdentifier: String   // the -15 min "准备出发" UNNotification id
        let callIdentifier: String     // the -10 min time-sensitive "该出发了" UNNotification id
    }

    // Payload key AppDelegate reads on tap to route into CallKit.
    static let outingCallReasonKey = "outing_call_reason"

    // Eat-out events don't need ETA math, so they just register a single
    // "准备出发" reminder. Tracked separately so cancellation is O(1).
    private var eatOutReminderIdentifiers: [UUID: String] = [:]

    // MARK: - Request Notification Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                log.error("requestPermission failed: \(error.localizedDescription, privacy: .public)")
            } else {
                log.info("requestPermission granted=\(granted)")
            }
        }
    }

    // MARK: - Public API (Outing)

    /// Schedule the two "time-to-leave" reminders for an outing activity.
    ///
    /// Flow:
    /// 1. Geocode `UserLocationStore.homeAddress` → start coordinate.
    /// 2. Resolve destination coordinate from `outing.destinationCoordinate`
    ///    (preferred) or geocode `outing.destination`.
    /// 3. Run two concurrent `MKDirections.calculateETA` requests
    ///    (`.automobile` + `.transit`).
    /// 4. `latestDepartureTime = arrivalTime - min(driving, transit)`.
    /// 5. Schedule a local notification at `latest - 15 min` and a CallKit
    ///    "incoming call" at `latest - 10 min`.
    ///
    /// Fallbacks (see report.md §Fallback Strategy):
    /// - If `homeAddress` is nil, or either geocode fails, we skip MapKit
    ///   entirely and treat `latestDepartureTime = arrivalTime - 30 min`
    ///   so the user still gets *some* nudge.
    /// - If only one of the two ETA queries succeeds, use whichever came back.
    /// - If both fail, same 30-min default as above.
    func scheduleOutingReminders(for outing: OutingDetail, scheduleId: UUID) async {
        // Clear any previous reminders for this schedule id so we never
        // double-schedule when a caller retries.
        cancelOutingReminders(scheduleId: scheduleId)

        let arrivalTime = outing.arrivalTime
        let title = outing.activityName.isEmpty ? outing.destination : outing.activityName

        // 1) Resolve start & destination coordinates.
        let startCoord = await resolveHomeCoordinate()
        let destCoord = await resolveDestinationCoordinate(for: outing)

        // 2) Compute minimum travel minutes (best case of driving/transit).
        //    Returns nil if we couldn't get any ETA at all.
        let travelMinutes: Int? = await {
            guard let start = startCoord, let dest = destCoord else { return nil }
            return await calculateMinTravelMinutes(from: start, to: dest)
        }()

        // 3) latestDepartureTime = arrival - min(driving, transit).
        //    When ETA is unknown, fall back to 30 min.
        let leadMinutes = travelMinutes ?? 30
        let latestDeparture = arrivalTime.addingTimeInterval(-Double(leadMinutes) * 60)

        // 4) Fire the two reminders.
        let notifyIdentifier = "outing-\(scheduleId.uuidString)-notify"
        let callIdentifier = "outing-\(scheduleId.uuidString)-call"

        let notifyTime = latestDeparture.addingTimeInterval(-15 * 60)
        let callTime = latestDeparture.addingTimeInterval(-10 * 60)

        let bodyPrefix: String = {
            if let m = travelMinutes {
                return "前往「\(title)」预计需要约 \(m) 分钟"
            } else {
                return "前往「\(title)」"
            }
        }()

        scheduleNotification(
            title: "准备出发",
            body: bodyPrefix + "，建议现在开始准备。",
            at: notifyTime,
            identifier: notifyIdentifier
        )

        scheduleCallReminderNotification(
            reason: "该出发了：\(title)",
            at: callTime,
            identifier: callIdentifier
        )

        outingReminderIdentifiers[scheduleId] = OutingReminderIdentifiers(
            notifyIdentifier: notifyIdentifier,
            callIdentifier: callIdentifier
        )
    }

    /// Cancel both reminders for a given schedule id. No-op if nothing is
    /// registered for that id.
    func cancelOutingReminders(scheduleId: UUID) {
        guard let ids = outingReminderIdentifiers.removeValue(forKey: scheduleId) else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [ids.notifyIdentifier, ids.callIdentifier]
        )
    }

    // MARK: - Public API (Eat-out)

    /// Schedule a single "准备出发" notification 30 minutes before the
    /// appointment. Eat-out doesn't run the full ETA pipeline — at dinner
    /// time users already know how long it takes to get to their regular
    /// haunts, and the main value is the nudge, not the minute-precise lead.
    func scheduleEatOutReminders(for eatOut: EatOutDetail, scheduleId: UUID) {
        cancelEatOutReminders(scheduleId: scheduleId)

        let title = eatOut.restaurantName.isEmpty ? "外食" : eatOut.restaurantName
        let reminderTime = eatOut.appointmentTime.addingTimeInterval(-30 * 60)
        let identifier = "eatout-\(scheduleId.uuidString)-notify"

        scheduleNotification(
            title: "准备出发",
            body: "30 分钟后「\(title)」见。",
            at: reminderTime,
            identifier: identifier
        )
        eatOutReminderIdentifiers[scheduleId] = identifier
    }

    func cancelEatOutReminders(scheduleId: UUID) {
        guard let id = eatOutReminderIdentifiers.removeValue(forKey: scheduleId) else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Aggregate cancel — used by `ScheduleManager.deleteSchedule` which
    /// doesn't know which reminder kind was registered for a given item.
    func cancelReminders(scheduleId: UUID) {
        cancelOutingReminders(scheduleId: scheduleId)
        cancelEatOutReminders(scheduleId: scheduleId)
    }

    // MARK: - Coordinate Resolution

    /// Resolve the starting coordinate from `UserLocationStore.homeAddress`.
    /// Returns `nil` if the user hasn't set a home address or geocoding
    /// fails — in both cases the caller will apply the 30-minute default.
    private func resolveHomeCoordinate() async -> CLLocationCoordinate2D? {
        guard let home = UserLocationStore.homeAddress else { return nil }
        return await geocode(addressString: home)
    }

    /// Prefer the OutingDetail's pre-resolved `destinationCoordinate` (if
    /// an upstream AI/search flow already cached it). Otherwise geocode
    /// the raw destination string.
    private func resolveDestinationCoordinate(for outing: OutingDetail) async -> CLLocationCoordinate2D? {
        if let geo = outing.destinationCoordinate {
            return geo.coordinate
        }
        guard !outing.destination.isEmpty else { return nil }
        return await geocode(addressString: outing.destination)
    }

    private func geocode(addressString: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(addressString)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    // MARK: - MKDirections ETA (Double Query)

    /// Fires two `MKDirections.calculateETA` requests in parallel — one
    /// `.automobile`, one `.transit` — and returns `min(driving, transit)`
    /// in minutes. Returns `nil` if both requests fail (or if neither
    /// transport type is available for this route, e.g. no transit data).
    private func calculateMinTravelMinutes(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> Int? {
        async let driving = calculateETA(from: start, to: destination, transport: .automobile)
        async let transit = calculateETA(from: start, to: destination, transport: .transit)

        let (drive, ride) = await (driving, transit)

        let candidates = [drive, ride].compactMap { $0 }
        guard let minSeconds = candidates.min() else { return nil }
        // Round up so we don't tell the user they have 4.3 minutes and
        // actually arrive late.
        return Int((minSeconds / 60).rounded(.up))
    }

    private func calculateETA(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType
    ) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transport

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculateETA()
            return response.expectedTravelTime
        } catch {
            return nil
        }
    }

    // MARK: - Local Notification

    private func scheduleNotification(title: String, body: String, at date: Date, identifier: String) {
        let interval = date.timeIntervalSinceNow
        // UN silently drops any trigger whose fire time is already past.
        guard interval > 0 else {
            log.warning("scheduleNotification dropped (past) id=\(identifier, privacy: .public) interval=\(interval)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Time-interval trigger instead of calendar trigger on purpose:
        // UNCalendarNotificationTrigger matches only year/month/day/hour/minute,
        // which silently truncates seconds. A trigger registered at 10:30:45
        // with dateMatching ymd+hm resolves to 10:30:00, which is already in
        // the past, and iOS drops it.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("add failed id=\(identifier, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
            } else {
                log.info("add OK id=\(identifier, privacy: .public) fires in \(Int(interval))s")
            }
        }
    }

    // MARK: - Call Reminder (time-sensitive notification → tap opens CallKit)
    //
    // Earlier versions of this method scheduled an in-process DispatchWorkItem
    // to fire `CallService.reportIncomingCall` at T-10min, hoping to surface
    // a CallKit-style incoming call even when the app was backgrounded. That
    // plan doesn't survive contact with iOS: the system suspends the app a
    // few seconds after backgrounding and the WorkItem's closure never runs.
    // The only supported path to wake a backgrounded app into CallKit is a
    // PushKit VoIP push from a server — which we don't have yet.
    //
    // Fallback strategy (Path A): register the T-10min reminder as a
    // **time-sensitive** local notification. It bypasses Focus mode, plays
    // the default sound, and when the user taps it, `AppDelegate.didReceive`
    // routes the `outing_call_reason` userInfo key back into
    // `CallService.reportIncomingCall`. The user has to tap, but at least
    // something surfaces reliably.
    private func scheduleCallReminderNotification(reason: String, at date: Date, identifier: String) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else {
            log.warning("scheduleCallReminderNotification dropped (past) id=\(identifier, privacy: .public) interval=\(interval)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "该出发了"
        content.body = reason
        content.sound = .default
        // Time-sensitive bypasses Focus/Do Not Disturb. Requires the
        // `com.apple.developer.usernotifications.time-sensitive` entitlement
        // (see FutureEgo.entitlements). Without the entitlement iOS silently
        // downgrades to .active — the notification still shows, just isn't
        // prioritized.
        content.interruptionLevel = .timeSensitive
        // AppDelegate reads this on tap to start a CallKit incoming call.
        content.userInfo = [Self.outingCallReasonKey: reason]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("call-reminder add failed id=\(identifier, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
            } else {
                log.info("call-reminder add OK id=\(identifier, privacy: .public) fires in \(Int(interval))s")
            }
        }
    }
}
