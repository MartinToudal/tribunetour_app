import Foundation
import UserNotifications

enum NotificationPreferenceKeys {
    static let weekendReminderEnabled = "notifications.weekendReminder.enabled"
    static let midweekReminderEnabled = "notifications.midweekReminder.enabled"
    static let nextMissingStadiumReminderEnabled = "notifications.nextMissingStadium.enabled"
}

final class WeekendOpportunityNotifier {
    static let shared = WeekendOpportunityNotifier()

    private let center = UNUserNotificationCenter.current()
    private let appTimeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
    private let weekendReminderIdentifier = "weekend_opportunity_reminder"
    private let midweekReminderIdentifier = "midweek_opportunity_reminder"
    private let nextMissingStadiumIdentifier = "next_missing_stadium_reminder"
    private let weekendReminderTestIdentifier = "weekend_opportunity_reminder_test"
    private let midweekReminderTestIdentifier = "midweek_opportunity_reminder_test"
    private let nextMissingStadiumTestIdentifier = "next_missing_stadium_reminder_test"

    private init() {}

    nonisolated static func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "da_DK")
        calendar.timeZone = timeZone
        return calendar
    }

    nonisolated static func upcomingWeekendWindow(from date: Date, timeZone: TimeZone) -> (start: Date, end: Date)? {
        let calendar = calendar(for: timeZone)
        let startOfToday = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfToday)

        // Calendar weekday: 1=søndag ... 6=fredag ... 2=mandag
        let daysUntilFriday = (6 - weekday + 7) % 7
        guard let fridayStart = calendar.date(byAdding: .day, value: daysUntilFriday, to: startOfToday),
              let mondayStart = calendar.date(byAdding: .day, value: 3, to: fridayStart) else {
            return nil
        }
        return (start: fridayStart, end: mondayStart)
    }

    nonisolated static func upcomingMidweekWindow(from date: Date, timeZone: TimeZone) -> (start: Date, end: Date)? {
        let calendar = calendar(for: timeZone)
        let startOfToday = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfToday)

        // Calendar weekday: 1=søndag ... 3=tirsdag
        let daysUntilTuesday = (3 - weekday + 7) % 7
        guard let tuesdayStart = calendar.date(byAdding: .day, value: daysUntilTuesday, to: startOfToday),
              let fridayStart = calendar.date(byAdding: .day, value: 3, to: tuesdayStart) else {
            return nil
        }
        return (start: tuesdayStart, end: fridayStart)
    }

    nonisolated static func countUnvisitedVenues(
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

    private func dkCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "da_DK")
        calendar.timeZone = appTimeZone
        return calendar
    }

    func refreshWeekendReminder(
        fixtures: [Fixture],
        visitedVenueClubIds: Set<String>,
        clubById: [String: Club] = [:]
    ) async {
        let weekendEnabled = weekendReminderEnabled()
        let midweekEnabled = midweekReminderEnabled()
        let nextMissingEnabled = nextMissingStadiumReminderEnabled()
        if !weekendEnabled && !midweekEnabled && !nextMissingEnabled {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier, midweekReminderIdentifier, nextMissingStadiumIdentifier])
            return
        }

        let granted = await ensureAuthorizationIfNeeded()
        guard granted else {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier, midweekReminderIdentifier, nextMissingStadiumIdentifier])
            return
        }

        if weekendEnabled {
            await scheduleWeekendReminder(fixtures: fixtures, visitedVenueClubIds: visitedVenueClubIds)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier])
        }

        if midweekEnabled {
            await scheduleMidweekReminder(fixtures: fixtures, visitedVenueClubIds: visitedVenueClubIds)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [midweekReminderIdentifier])
        }

        if nextMissingEnabled {
            await scheduleNextMissingStadiumReminder(
                fixtures: fixtures,
                visitedVenueClubIds: visitedVenueClubIds,
                clubById: clubById
            )
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [nextMissingStadiumIdentifier])
        }
    }

    func setWeekendReminderEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: NotificationPreferenceKeys.weekendReminderEnabled)
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier])
        }
    }

    func setMidweekReminderEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: NotificationPreferenceKeys.midweekReminderEnabled)
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: [midweekReminderIdentifier])
        }
    }

    func setNextMissingStadiumReminderEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: NotificationPreferenceKeys.nextMissingStadiumReminderEnabled)
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: [nextMissingStadiumIdentifier])
        }
    }

    func sendTestNotificationInFiveSeconds(fixtures: [Fixture], visitedVenueClubIds: Set<String>) async {
        let granted = await ensureAuthorizationIfNeeded()
        guard granted else { return }

        guard let weekendWindow = upcomingWeekendWindow(from: Date()) else { return }
        let count = countUnvisitedWeekendVenues(
            fixtures: fixtures,
            visitedVenueClubIds: visitedVenueClubIds,
            start: weekendWindow.start,
            end: weekendWindow.end
        )

        let content = UNMutableNotificationContent()
        content.title = "Test: Weekendmulighed i Tribunetour"
        content.body = "Simulation: Du har \(count) ikke-besøgte stadions med kamp i det kommende weekendvindue."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: weekendReminderTestIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [weekendReminderTestIdentifier])
        do {
            try await center.add(request)
        } catch {
            dlog("🔔 Kunne ikke planlægge test-notifikation: \(error)")
        }
    }

    func sendMidweekTestNotificationInFiveSeconds(fixtures: [Fixture], visitedVenueClubIds: Set<String>) async {
        let granted = await ensureAuthorizationIfNeeded()
        guard granted else { return }

        guard let midweekWindow = upcomingMidweekWindow(from: Date()) else { return }
        let count = countUnvisitedVenues(
            fixtures: fixtures,
            visitedVenueClubIds: visitedVenueClubIds,
            start: midweekWindow.start,
            end: midweekWindow.end
        )

        let content = UNMutableNotificationContent()
        content.title = "Test: Midtugeforslag i Tribunetour"
        content.body = "Simulation: Fra tirsdag til torsdag kan du nå op til \(count) nye stadions."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: midweekReminderTestIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [midweekReminderTestIdentifier])
        do {
            try await center.add(request)
        } catch {
            dlog("🔔 Kunne ikke planlægge midtuge test-notifikation: \(error)")
        }
    }

    func sendNextMissingStadiumTestNotificationInFiveSeconds(
        fixtures: [Fixture],
        visitedVenueClubIds: Set<String>,
        clubById: [String: Club]
    ) async {
        let granted = await ensureAuthorizationIfNeeded()
        guard granted else { return }

        guard let fixture = nextUnvisitedFixture(fixtures: fixtures, visitedVenueClubIds: visitedVenueClubIds, now: Date()) else { return }
        let venueName = clubById[fixture.venueClubId]?.stadium.name ?? fixture.venueClubId
        let kickoffText = kickoffText(for: fixture.kickoff)

        let content = UNMutableNotificationContent()
        content.title = "Test: Næste stadionmulighed"
        content.body = "Simulation: Din næste mulighed er \(venueName) (\(kickoffText))."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: nextMissingStadiumTestIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [nextMissingStadiumTestIdentifier])
        do {
            try await center.add(request)
        } catch {
            dlog("🔔 Kunne ikke planlægge 'næste stadion' test-notifikation: \(error)")
        }
    }

    private func weekendReminderEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: NotificationPreferenceKeys.weekendReminderEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: NotificationPreferenceKeys.weekendReminderEnabled)
    }

    private func midweekReminderEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: NotificationPreferenceKeys.midweekReminderEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: NotificationPreferenceKeys.midweekReminderEnabled)
    }

    private func nextMissingStadiumReminderEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: NotificationPreferenceKeys.nextMissingStadiumReminderEnabled) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: NotificationPreferenceKeys.nextMissingStadiumReminderEnabled)
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
        let calendar = dkCalendar()

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
        let calendar = dkCalendar()
        let startOfThursday = calendar.startOfDay(for: thursdayDate)

        guard
            let fridayStart = calendar.date(byAdding: .day, value: 1, to: startOfThursday),
            let mondayStart = calendar.date(byAdding: .day, value: 4, to: startOfThursday)
        else {
            return nil
        }

        return (start: fridayStart, end: mondayStart)
    }

    private func upcomingWeekendWindow(from date: Date) -> (start: Date, end: Date)? {
        Self.upcomingWeekendWindow(from: date, timeZone: appTimeZone)
    }

    private func upcomingMidweekWindow(from date: Date) -> (start: Date, end: Date)? {
        Self.upcomingMidweekWindow(from: date, timeZone: appTimeZone)
    }

    private func countUnvisitedWeekendVenues(
        fixtures: [Fixture],
        visitedVenueClubIds: Set<String>,
        start: Date,
        end: Date
    ) -> Int {
        countUnvisitedVenues(
            fixtures: fixtures,
            visitedVenueClubIds: visitedVenueClubIds,
            start: start,
            end: end
        )
    }

    private func countUnvisitedVenues(
        fixtures: [Fixture],
        visitedVenueClubIds: Set<String>,
        start: Date,
        end: Date
    ) -> Int {
        Self.countUnvisitedVenues(
            fixtures: fixtures,
            visitedVenueClubIds: visitedVenueClubIds,
            start: start,
            end: end
        )
    }

    private func scheduleWeekendReminder(fixtures: [Fixture], visitedVenueClubIds: Set<String>) async {
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

        guard count > 0 else {
            center.removePendingNotificationRequests(withIdentifiers: [weekendReminderIdentifier])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Weekendmulighed i Tribunetour"
        content.body = "I den kommende weekend fra fredag til mandag har du mulighed for at besøge ikke mindre end \(count) stadions, du endnu ikke har besøgt."
        content.sound = .default

        let calendar = dkCalendar()
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

    private func scheduleMidweekReminder(fixtures: [Fixture], visitedVenueClubIds: Set<String>) async {
        guard
            let nextMondayAt20 = nextMondayAtEightPM(from: Date()),
            let midweekWindow = midweekWindow(after: nextMondayAt20)
        else {
            return
        }

        let count = countUnvisitedVenues(
            fixtures: fixtures,
            visitedVenueClubIds: visitedVenueClubIds,
            start: midweekWindow.start,
            end: midweekWindow.end
        )

        guard count > 0 else {
            center.removePendingNotificationRequests(withIdentifiers: [midweekReminderIdentifier])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Midtugeforslag i Tribunetour"
        content.body = "Vidste du, at du kan opleve nye stadions i midtugen? Fra tirsdag til torsdag har du mulighed for at besøge \(count) forskellige stadions, du endnu ikke har besøgt."
        content.sound = .default

        let calendar = dkCalendar()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextMondayAt20)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: midweekReminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [midweekReminderIdentifier])
        do {
            try await center.add(request)
        } catch {
            dlog("🔔 Kunne ikke planlægge midtuge-notifikation: \(error)")
        }
    }

    private func nextMondayAtEightPM(from date: Date) -> Date? {
        let calendar = dkCalendar()

        var targetComponents = DateComponents()
        targetComponents.weekday = 2 // mandag
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

    private func midweekWindow(after mondayDate: Date) -> (start: Date, end: Date)? {
        let calendar = dkCalendar()
        let startOfMonday = calendar.startOfDay(for: mondayDate)
        guard
            let tuesdayStart = calendar.date(byAdding: .day, value: 1, to: startOfMonday),
            let fridayStart = calendar.date(byAdding: .day, value: 4, to: startOfMonday)
        else {
            return nil
        }
        return (start: tuesdayStart, end: fridayStart)
    }

    private func scheduleNextMissingStadiumReminder(
        fixtures: [Fixture],
        visitedVenueClubIds: Set<String>,
        clubById: [String: Club]
    ) async {
        let now = Date()
        guard let fixture = nextUnvisitedFixture(fixtures: fixtures, visitedVenueClubIds: visitedVenueClubIds, now: now) else {
            center.removePendingNotificationRequests(withIdentifiers: [nextMissingStadiumIdentifier])
            return
        }

        let triggerDate: Date
        let oneDayBefore = fixture.kickoff.addingTimeInterval(-24 * 60 * 60)
        if oneDayBefore > now {
            triggerDate = oneDayBefore
        } else {
            // Hvis kampen er tæt på, send en nær-fremtidig reminder i stedet.
            let fallback = now.addingTimeInterval(5 * 60)
            guard fallback < fixture.kickoff else {
                center.removePendingNotificationRequests(withIdentifiers: [nextMissingStadiumIdentifier])
                return
            }
            triggerDate = fallback
        }

        let venueName = clubById[fixture.venueClubId]?.stadium.name ?? fixture.venueClubId
        let kickoffText = kickoffText(for: fixture.kickoff)

        let content = UNMutableNotificationContent()
        content.title = "Næste kamp på stadion du mangler"
        content.body = "Din næste mulighed er \(venueName) (\(kickoffText)). Skal den med i planerne?"
        content.sound = .default

        let components = dkCalendar().dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: nextMissingStadiumIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [nextMissingStadiumIdentifier])
        do {
            try await center.add(request)
        } catch {
            dlog("🔔 Kunne ikke planlægge 'næste stadion' notifikation: \(error)")
        }
    }

    private func nextUnvisitedFixture(fixtures: [Fixture], visitedVenueClubIds: Set<String>, now: Date) -> Fixture? {
        fixtures
            .filter { $0.status == .scheduled }
            .filter { $0.kickoff > now }
            .filter { !visitedVenueClubIds.contains($0.venueClubId) }
            .sorted { $0.kickoff < $1.kickoff }
            .first
    }

    private func kickoffText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "da_DK")
        formatter.timeZone = appTimeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
