import UserNotifications
import MapKit
import Foundation

@MainActor
class ReminderService: ObservableObject {
    static let shared = ReminderService()

    /// Active call reminder work items, keyed by identifier
    private var pendingCallReminders: [String: DispatchWorkItem] = [:]

    // MARK: - Request Notification Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Calculate ETA and Schedule Reminders

    /// For a schedule event with a location, calculate travel time and set reminders
    func scheduleSmartReminders(for title: String, at address: String, eventTime: Date) {
        // 1. Geocode the address
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            guard let destination = placemarks?.first?.location?.coordinate else { return }

            Task { @MainActor in
                // 2. Calculate ETA from current location
                let eta = await self?.calculateETA(to: destination)
                let travelMinutes = Int((eta ?? 30 * 60) / 60)  // fallback 30 min

                // 3. Schedule notification: 20 min before departure time
                let departureTime = eventTime.addingTimeInterval(-Double(travelMinutes) * 60)
                let notifyTime = departureTime.addingTimeInterval(-20 * 60)
                self?.scheduleNotification(
                    title: "该准备出发了",
                    body: "前往「\(title)」预计需要 \(travelMinutes) 分钟",
                    at: notifyTime,
                    identifier: "remind-\(title)-20"
                )

                // 4. Schedule call reminder: 10 min before departure
                let callTime = departureTime.addingTimeInterval(-10 * 60)
                self?.scheduleCallReminder(
                    reason: "出发提醒：\(title)",
                    at: callTime,
                    identifier: "remind-\(title)-10"
                )
            }
        }
    }

    // MARK: - MapKit ETA

    private func calculateETA(to destination: CLLocationCoordinate2D) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

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
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
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

    // MARK: - Cancel Reminders

    func cancelReminders(for title: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["remind-\(title)-20", "remind-\(title)-10"]
        )
        // Cancel pending call reminder timer
        let callId = "remind-\(title)-10"
        pendingCallReminders[callId]?.cancel()
        pendingCallReminders.removeValue(forKey: callId)
    }
}
