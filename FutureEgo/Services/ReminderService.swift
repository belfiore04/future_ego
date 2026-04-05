import UserNotifications
import MapKit
import Foundation

@MainActor
class ReminderService: ObservableObject {
    static let shared = ReminderService()

    // MARK: - Pending Reminders
    //
    // Call reminders are dispatched via in-process DispatchWorkItem timers
    // (CallKit is simulator-unfriendly, and the app may not be alive at
    // fire-time anyway — this is best-effort). We keep them keyed by their
    // notification identifier so cancellation can reach them.
    private var pendingCallReminders: [String: DispatchWorkItem] = [:]

    // Lookup from schedule UUID → the two notification identifiers we
    // registered for that outing. Used by `cancelOutingReminders` to map
    // a ScheduleItem back to the notification requests + work items it
    // owns without having to know the title.
    private var outingReminderIdentifiers: [UUID: OutingReminderIdentifiers] = [:]

    private struct OutingReminderIdentifiers {
        let notifyIdentifier: String   // the -15 min UNNotification id
        let callIdentifier: String     // the -10 min DispatchWorkItem id
    }

    // MARK: - Request Notification Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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

        scheduleCallReminder(
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
            withIdentifiers: [ids.notifyIdentifier]
        )

        if let workItem = pendingCallReminders.removeValue(forKey: ids.callIdentifier) {
            workItem.cancel()
        }
    }

    // MARK: - Deprecated Legacy API
    //
    // The old `.location` event type used a title+address+eventTime call.
    // Task-4's ScheduleManager rewrite should use `scheduleOutingReminders`
    // directly, but we keep this shim so we don't break compilation mid-
    // merge. It intentionally does nothing more than log — the old code
    // path wasn't schedule-id-keyed and has no safe route onto the new
    // cancellation machinery.

    @available(*, deprecated, message: "Use scheduleOutingReminders(for:scheduleId:) — this legacy entry point no longer schedules anything.")
    func scheduleSmartReminders(for title: String, at address: String, eventTime: Date) {
        // Intentional no-op. Kept only for source-compatibility with the
        // pre-refactor ScheduleManager until task-4 lands its rewrite.
        print("[ReminderService] scheduleSmartReminders is deprecated; title=\(title)")
    }

    @available(*, deprecated, message: "Use cancelOutingReminders(scheduleId:) — this legacy entry point no longer cancels anything.")
    func cancelReminders(for title: String) {
        // Intentional no-op. Kept only for source-compatibility with the
        // pre-refactor ScheduleManager until task-4 lands its rewrite.
        print("[ReminderService] cancelReminders is deprecated; title=\(title)")
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
        // Guard against scheduling a trigger in the past — UN would
        // silently drop it, and the user would blame us.
        guard date.timeIntervalSinceNow > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Call Reminder (triggers CallKit incoming call)

    private func scheduleCallReminder(reason: String, at date: Date, identifier: String) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            CallService.shared.reportIncomingCall(reason: reason)
            Task { @MainActor in
                self?.pendingCallReminders.removeValue(forKey: identifier)
            }
        }
        pendingCallReminders[identifier] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
    }
}
