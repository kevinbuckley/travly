import UserNotifications
import Foundation

/// Schedules and manages local push notifications for trip reminders.
/// Uses `DataManager.computeReminders` for the business logic; this service
/// owns the UNUserNotificationCenter interaction.
enum NotificationScheduler {

    // MARK: - Category & Action IDs

    static let categoryID          = "com.kevinbuckley.travelplanner.tripReminder"
    static let markVisitedActionID = "MARK_VISITED"
    static let viewTripActionID    = "VIEW_TRIP"

    // MARK: - Permission

    /// Request notification authorisation. Returns true if granted.
    static func requestAuthorisation() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Register notification categories with interactive actions.
    static func registerCategories() {
        let markVisited = UNNotificationAction(
            identifier: markVisitedActionID,
            title: "Mark Visited",
            options: []
        )
        let viewTrip = UNNotificationAction(
            identifier: viewTripActionID,
            title: "Open Trip",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [markVisited, viewTrip],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Scheduling

    /// Schedule all reminders for the given trip, replacing any existing ones.
    static func scheduleReminders(for trip: TripEntity) async {
        guard let tripID = trip.id else { return }

        // Remove existing notifications for this trip
        await removeReminders(forTripID: tripID)

        let reminders = DataManager.computeReminders(for: trip)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title         = reminder.title
            content.body          = reminder.body
            content.sound         = .default
            content.categoryIdentifier = categoryID
            content.userInfo      = [
                "tripID":        tripID.uuidString,
                "reminderType":  reminder.type.rawValue,
            ]

            let comps   = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id      = notificationID(tripID: tripID, reminderType: reminder.type.rawValue)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Remove all scheduled notifications for a trip.
    static func removeReminders(forTripID tripID: UUID) async {
        let center    = UNUserNotificationCenter.current()
        let pending   = await center.pendingNotificationRequests()
        let toRemove  = pending
            .filter { $0.content.userInfo["tripID"] as? String == tripID.uuidString }
            .map    { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: toRemove)
    }

    // MARK: - Identifier Helpers

    /// Deterministic notification ID for a (trip, reminderType) pair.
    static func notificationID(tripID: UUID, reminderType: String) -> String {
        "tripwit.\(tripID.uuidString).\(reminderType)"
    }

    /// Parse a tripID from a notification's userInfo dictionary.
    static func tripID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let str = userInfo["tripID"] as? String else { return nil }
        return UUID(uuidString: str)
    }

    /// Parse a reminderType string from a notification's userInfo dictionary.
    static func reminderType(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo["reminderType"] as? String
    }
}
