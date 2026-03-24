import Foundation
import UserNotifications

enum NotificationPreferenceKeys {
    static let weekendReminderEnabled = "notifications.weekendReminder.enabled"
}

final class WeekendOpportunityNotifier {
    static let shared = WeekendOpportunityNotifier()

    private let center = UNUserNotificationCenter.current()
    private let weekendReminderIdentifier = "weekend_opportunity_reminder"

    private init() {}

    func refreshWeekendReminder(fixtures: [Fixture], visitedVenueClubIds: Set<String>) async {
        let enabled = weekendReminderEnabled()
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier])
            return
        }

        let granted = await ensureAuthorizationIfNeeded()
        guard granted else {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier])
            return
        }

        guard
            let nextThursdayAt20 = nextThursdayAtEightPM(from: Date()),
            let weekendWindow = weekendWindow(after: nextThursdayAt20)
        else {
            return
        }

        let count = countUnvisitedWeekendVenues(
            fixtures: fixtures,
            visitedVenueClubIds: visitedVenueClubIds,
            start: weekendWindow.start,
            end: weekendWindow.end
        )

        // Vi sender kun besked, hvis der faktisk er muligheder.
        guard count > 0 else {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Weekendmulighed i Tribunetour"
        content.body = "I den kommende weekend fra fredag til mandag har du mulighed for at besøge ikke mindre end \(count) stadions, du endnu ikke har besøgt."
        content.sound = .default

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextThursdayAt20)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: weekendReminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier])
        do {
            try await center.add(request)
        } catch {
            dlog("🔔 Kunne ikke planlægge weekend-notifikation: \(error)")
        }
    }

    func setWeekendReminderEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: NotificationPreferenceKeys.weekendReminderEnabled)
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier])
        }
    }

    private func weekendReminderEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: NotificationPreferenceKeys.weekendReminderEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: NotificationPreferenceKeys.weekendReminderEnabled)
    }

    private func ensureAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                dlog("🔔 Kunne ikke anmode om notifikationstilladelse: \(error)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func nextThursdayAtEightPM(from date: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "da_DK")

        var targetComponents = DateComponents()
        targetComponents.weekday = 5 // torsdag
        targetComponents.hour = 20
        targetComponents.minute = 0
        targetComponents.second = 0

        return calendar.nextDate(
            after: date,
            matching: targetComponents,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func weekendWindow(after thursdayDate: Date) -> (start: Date, end: Date)? {
        let calendar = Calendar(identifier: .gregorian)
        let startOfThursday = calendar.startOfDay(for: thursdayDate)

        guard
            let fridayStart = calendar.date(byAdding: .day, value: 1, to: startOfThursday),
            let mondayStart = calendar.date(byAdding: .day, value: 4, to: startOfThursday)
        else {
            return nil
        }

        return (start: fridayStart, end: mondayStart)
    }

    private func countUnvisitedWeekendVenues(
        fixtures: [Fixture],
        visitedVenueClubIds: Set<String>,
        start: Date,
        end: Date
    ) -> Int {
        let weekendVenueIds = fixtures.compactMap { fixture -> String? in
            guard fixture.kickoff >= start, fixture.kickoff < end else { return nil }
            guard fixture.status != .cancelled, fixture.status != .finished else { return nil }
            guard !visitedVenueClubIds.contains(fixture.venueClubId) else { return nil }
            return fixture.venueClubId
        }

        return Set(weekendVenueIds).count
    }
}
