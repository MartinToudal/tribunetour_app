import SwiftUI
import UIKit
import MessageUI

struct StatsView: View {
    private enum AuthField: Hashable {
        case email
        case password
    }

    let isActive: Bool
    let clubs: [Club]
    let clubById: [String: Club]
    let fixtures: [Fixture]
    @ObservedObject var visitedStore: VisitedStore
    @ObservedObject var photosStore: AppPhotosStore
    @ObservedObject var notesStore: AppNotesStore
    @ObservedObject var reviewsStore: AppReviewsStore
    @ObservedObject var authSession: AppAuthSession
    let authClient: AppAuthClient
    let bootstrapCoordinator: AppVisitedBootstrapCoordinator
    let runtimeSyncInfoMessage: String?
    @AppStorage("achievements.seenUnlockedIds") private var seenUnlockedIdsRaw: String = ""
    @AppStorage(AppLeaguePackSettings.preferredHomeCountryCodeKey) private var preferredHomeCountryCode: String = "dk"
    @AppStorage("stadiums.countryFilter") private var countryFilterRawValue: String = "all"
    @AppStorage("stats.accountPromptDismissed") private var accountPromptDismissed: Bool = false

    enum AchievementTrack {
        case journey
        case homeCountry
        case countries
        case international
    }

    struct Achievement: Identifiable {
        let id: String
        let title: String
        let description: String
        let systemImage: String
        let isUnlocked: Bool
        let progressText: String
        let track: AchievementTrack
    }

    private struct DivisionKey: Hashable {
        let countryCode: String
        let division: String
    }

    private struct DivisionProgressRow: Identifiable {
        let countryCode: String
        let division: String
        let visited: Int
        let total: Int

        var id: String { "\(countryCode)-\(division)" }
    }

    private struct RecentVisit: Identifiable {
        let club: Club
        let date: Date

        var id: String { club.id }
    }

    private struct LeagueMilestone {
        let countryCode: String
        let division: String
        let remaining: Int
    }

    private struct Snapshot {
        var visitedCount: Int = 0
        var totalCount: Int = 0
        var unvisitedCount: Int = 0
        var progress: Double = 0
        var progressPercentText: String = "0%"
        var notesCount: Int = 0
        var reviewedCount: Int = 0
        var averageReviewScoreText: String?
        var totalPhotoCount: Int = 0
        var stadiumsWithPhotosCount: Int = 0
        var visitedCitiesCount: Int = 0
        var visitedDivisionsCount: Int = 0
        var activeHomeCountryCode: String = "dk"
        var currentScopeLabel: String = "Alle aktive lande"
        var countryOptions: [String] = []
        var hasInternationalCountries: Bool = false
        var internationalCountryCount: Int = 0
        var shouldShowAccountPrompt: Bool = false
        var accountPromptHighlights: [String] = []
        var sortedVisitedClubs: [Club] = []
        var recentVisited: [RecentVisit] = []
        var relegatedOrHistoricalRows: [Club] = []
        var journeyAchievements: [Achievement] = []
        var homeCountryAchievements: [Achievement] = []
        var countryAchievements: [Achievement] = []
        var internationalAchievements: [Achievement] = []
        var achievements: [Achievement] = []
        var unlockedAchievementIds: Set<String> = []
        var unlockedAchievementsCount: Int = 0
        var nextLockedAchievement: Achievement?
        var nextLeagueMilestone: LeagueMilestone?
        var suggestedNextClub: Club?
        var heroSummaryText: String = "Dit scope er tomt lige nu."
        var nextMilestoneTitle: String = "Fortsæt rejsen"
        var nextMilestoneDescription: String = "Hvert nyt besøg bringer dig tættere på næste kapitel."
        var suggestionDescription: String = "Et oplagt næste stadion at sætte på ønskelisten."
        var internationalSectionDescription: String = ""
        var visitedByDivision: [DivisionProgressRow] = []
        var homeCountryVisitedByDivision: [DivisionProgressRow] = []
    }

    // Feedback / Mail
    @State private var showMailComposer = false
    @State private var mailUnavailableAlert = false
    @State private var newlyUnlockedAchievementMessage: String?
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""
    @State private var loginErrorMessage: String?
    @State private var loginInfoMessage: String?
    @State private var loginLoading: Bool = false
    @State private var pendingBootstrapStatus: AppVisitedBootstrapStatus?
    @State private var showBootstrapAlert: Bool = false
    @State private var showAuthSheet: Bool = false
    @State private var premiumRequestPack: AppPremiumAdminPack = .premiumFull
    @State private var premiumRequestMessage: String = ""
    @State private var premiumRequestInfoMessage: String?
    @State private var premiumRequestErrorMessage: String?
    @State private var premiumRequestLoading: Bool = false
    @State private var premiumRequestRows: [PremiumAccessRequestUserRow] = []
    @State private var premiumRequestRowsLoading: Bool = false
    @State private var snapshot = Snapshot()
    @FocusState private var focusedAuthField: AuthField?

    // MARK: - Derived stats

    private var visitedClubIds: Set<String> {
        Set(visitedStore.records.lazy.filter(\.value.visited).map(\.key))
    }

    private var sortedVisitedClubs: [Club] {
        visitedClubs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var enabledPackIds: Set<String> {
        AppLeaguePackSettings.effectiveEnabledLeaguePacks(
            isAuthenticated: authSession.snapshot.isAuthenticated
        )
    }

    private var accessibleClubs: [Club] {
        clubs.filter { enabledPackIds.contains($0.leaguePack) }
    }

    private var visitedClubs: [Club] {
        progressionClubs.filter { visitedClubIds.contains($0.id) }
    }

    private var unvisitedClubs: [Club] {
        progressionClubs.filter { !visitedClubIds.contains($0.id) }
    }

    private var progressionClubs: [Club] {
        accessibleClubs.filter(\.countsTowardTopSystemProgression)
    }

    private var nonProgressionVisibleClubs: [Club] {
        accessibleClubs.filter(\.shouldRemainVisibleOutsideTopSystem)
    }

    private var visitedCount: Int { visitedClubs.count }
    private var totalCount: Int { progressionClubs.count }
    private var unvisitedCount: Int { unvisitedClubs.count }
    private var homeCountryClubs: [Club] { progressionClubs.filter { $0.countryCode == activeHomeCountryCode } }
    private var internationalClubs: [Club] { progressionClubs.filter { $0.countryCode != activeHomeCountryCode } }
    private var homeCountryVisitedCount: Int { homeCountryClubs.filter { visitedClubIds.contains($0.id) }.count }
    private var homeCountryTotalCount: Int { homeCountryClubs.count }
    private var internationalVisitedCount: Int { internationalClubs.filter { visitedClubIds.contains($0.id) }.count }
    private var hasInternationalCountries: Bool { !internationalClubs.isEmpty }
    private var shouldShowAccountPrompt: Bool {
        guard !authSession.snapshot.isAuthenticated, !accountPromptDismissed else { return false }
        return visitedCount >= 3 || notesCount > 0 || reviewedCount > 0 || totalPhotoCount > 0 || hasInternationalCountries
    }

    private var accountPromptHighlights: [String] {
        var highlights: [String] = []
        if visitedCount > 0 {
            highlights.append("Gem dine \(visitedCount) markerede stadionbesøg på din konto")
        }
        if notesCount > 0 || totalPhotoCount > 0 || reviewedCount > 0 {
            highlights.append("Gem noter, anmeldelser og billeder sikkert på din konto")
        }
        if hasInternationalCountries {
            highlights.append("Få adgang til flere ligaer og stadionrejser i andre lande")
        }
        if highlights.isEmpty {
            highlights.append("Gem dine data på din konto")
            highlights.append("Få adgang til flere ligaer og stadionrejser")
        }
        return Array(highlights.prefix(3))
    }
    private var openPremiumRequestRows: [PremiumAccessRequestUserRow] { premiumRequestRows.filter(\.isOpen) }
    private var selectedPackOpenRequest: PremiumAccessRequestUserRow? {
        openPremiumRequestRows.first(where: { $0.packKey == premiumRequestPack.rawValue })
    }
    private var unlockedPremiumPackTitles: [String] {
        return AppLeaguePackCatalog.entries
            .filter { $0.isPremium && $0.id != .premiumFull && enabledPackIds.contains($0.id.rawValue) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.label)
    }
    private var lockedPremiumPackTitles: [String] {
        return AppLeaguePackCatalog.entries
            .filter { $0.isPremium && $0.id != .premiumFull && !enabledPackIds.contains($0.id.rawValue) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.label)
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCount)
    }

    private var progressPercentText: String {
        let pct = Int((progress * 100.0).rounded())
        return "\(pct)%"
    }

    private var countryOptions: [String] {
        let source = progressionClubs.isEmpty ? accessibleClubs : progressionClubs
        return Array(Set(source.map(\.countryCode))).sorted { left, right in
            if LeaguePresentation.countryRank(left) != LeaguePresentation.countryRank(right) {
                return LeaguePresentation.countryRank(left) < LeaguePresentation.countryRank(right)
            }
            return LeaguePresentation.countryLabel(left).localizedCaseInsensitiveCompare(LeaguePresentation.countryLabel(right)) == .orderedAscending
        }
    }

    private func divisionRows(from clubs: [Club]) -> [DivisionProgressRow] {
        let grouped = Dictionary(grouping: clubs) { DivisionKey(countryCode: $0.countryCode, division: $0.division) }
        let rows = grouped.map { division, clubsInDivision in
            let v = clubsInDivision.filter { visitedClubIds.contains($0.id) }.count
            return DivisionProgressRow(
                countryCode: division.countryCode,
                division: division.division,
                visited: v,
                total: clubsInDivision.count
            )
        }

        return rows.sorted {
            let countryA = LeaguePresentation.countryRank($0.countryCode)
            let countryB = LeaguePresentation.countryRank($1.countryCode)
            if countryA != countryB { return countryA < countryB }

            let leagueA = LeaguePresentation.divisionRank($0.division, countryCode: $0.countryCode)
            let leagueB = LeaguePresentation.divisionRank($1.division, countryCode: $1.countryCode)
            if leagueA != leagueB { return leagueA < leagueB }

            if $0.total != $1.total { return $0.total > $1.total }
            return $0.division.localizedCaseInsensitiveCompare($1.division) == .orderedAscending
        }
    }

    private func buildDivisionRows(from clubs: [Club], visitedIds: Set<String>) -> [DivisionProgressRow] {
        let grouped = Dictionary(grouping: clubs) { DivisionKey(countryCode: $0.countryCode, division: $0.division) }
        let rows = grouped.map { division, clubsInDivision in
            let visited = clubsInDivision.filter { visitedIds.contains($0.id) }.count
            return DivisionProgressRow(
                countryCode: division.countryCode,
                division: division.division,
                visited: visited,
                total: clubsInDivision.count
            )
        }

        return rows.sorted {
            let countryA = LeaguePresentation.countryRank($0.countryCode)
            let countryB = LeaguePresentation.countryRank($1.countryCode)
            if countryA != countryB { return countryA < countryB }

            let leagueA = LeaguePresentation.divisionRank($0.division, countryCode: $0.countryCode)
            let leagueB = LeaguePresentation.divisionRank($1.division, countryCode: $1.countryCode)
            if leagueA != leagueB { return leagueA < leagueB }

            if $0.total != $1.total { return $0.total > $1.total }
            return $0.division.localizedCaseInsensitiveCompare($1.division) == .orderedAscending
        }
    }

    private func refreshSnapshot() {
        let visitedIds = Set(visitedStore.records.lazy.filter(\.value.visited).map(\.key))
        let progressionClubs = accessibleClubs.filter(\.countsTowardTopSystemProgression)
        let nonProgressionVisibleClubs = accessibleClubs.filter(\.shouldRemainVisibleOutsideTopSystem)
        let visitedClubs = progressionClubs.filter { visitedIds.contains($0.id) }
        let unvisitedClubs = progressionClubs.filter { !visitedIds.contains($0.id) }
        let visitedCount = visitedClubs.count
        let totalCount = progressionClubs.count
        let unvisitedCount = unvisitedClubs.count
        let progress = totalCount > 0 ? Double(visitedCount) / Double(totalCount) : 0
        let progressPercentText = "\(Int((progress * 100.0).rounded()))%"
        let sourceClubs = progressionClubs.isEmpty ? accessibleClubs : progressionClubs
        let countryOptions = Array(Set(sourceClubs.map(\.countryCode))).sorted { left, right in
            if LeaguePresentation.countryRank(left) != LeaguePresentation.countryRank(right) {
                return LeaguePresentation.countryRank(left) < LeaguePresentation.countryRank(right)
            }
            return LeaguePresentation.countryLabel(left).localizedCaseInsensitiveCompare(LeaguePresentation.countryLabel(right)) == .orderedAscending
        }
        let activeHomeCountryCode = LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: Set(sourceClubs.map(\.countryCode)))
        let currentScopeLabel = countryFilterRawValue == "all" ? "Alle aktive lande" : LeaguePresentation.countryLabel(countryFilterRawValue)
        let homeCountryClubs = progressionClubs.filter { $0.countryCode == activeHomeCountryCode }
        let internationalClubs = progressionClubs.filter { $0.countryCode != activeHomeCountryCode }
        let homeCountryVisitedCount = homeCountryClubs.filter { visitedIds.contains($0.id) }.count
        let homeCountryTotalCount = homeCountryClubs.count
        let internationalVisitedCount = internationalClubs.filter { visitedIds.contains($0.id) }.count
        let hasInternationalCountries = !internationalClubs.isEmpty
        let notesCount = visitedStore.records.values.reduce(0) { acc, r in
            let trimmed = r.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            return acc + (trimmed.isEmpty ? 0 : 1)
        }
        let reviewedCount = reviewsStore.reviewsByClubId.count
        let averageReviewScoreText: String? = {
            let averages = reviewsStore.reviewsByClubId.values.compactMap { $0.averageScore }
            guard !averages.isEmpty else { return nil }
            let total = averages.reduce(0, +)
            let overall = total / Double(averages.count)
            return String(format: "%.1f", overall)
        }()
        let totalPhotoCount = visitedStore.records.values.reduce(0) { acc, record in
            acc + record.photoFileNames.count
        }
        let stadiumsWithPhotosCount = visitedStore.records.values.reduce(0) { acc, record in
            acc + (record.photoFileNames.isEmpty ? 0 : 1)
        }
        let visitedCitiesCount = Set(visitedClubs.map { $0.stadium.city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count
        let visitedDivisionsCount = Set(visitedClubs.map { $0.division.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count
        let shouldShowAccountPrompt = !authSession.snapshot.isAuthenticated
            && !accountPromptDismissed
            && (visitedCount >= 3 || notesCount > 0 || reviewedCount > 0 || totalPhotoCount > 0 || hasInternationalCountries)
        let accountPromptHighlights: [String] = {
            var highlights: [String] = []
            if visitedCount > 0 {
                highlights.append("Gem dine \(visitedCount) markerede stadionbesøg på din konto")
            }
            if notesCount > 0 || totalPhotoCount > 0 || reviewedCount > 0 {
                highlights.append("Gem noter, anmeldelser og billeder sikkert på din konto")
            }
            if hasInternationalCountries {
                highlights.append("Få adgang til flere ligaer og stadionrejser i andre lande")
            }
            if highlights.isEmpty {
                highlights.append("Gem dine data på din konto")
                highlights.append("Få adgang til flere ligaer og stadionrejser")
            }
            return Array(highlights.prefix(3))
        }()
        let visitedByDivision = buildDivisionRows(from: progressionClubs, visitedIds: visitedIds)
        let homeCountryVisitedByDivision = buildDivisionRows(from: homeCountryClubs, visitedIds: visitedIds)
        let recentVisited = visitedClubs.compactMap { club -> RecentVisit? in
            if let date = visitedStore.visitedDate(for: club.id) {
                return RecentVisit(club: club, date: date)
            }
            if let rec = visitedStore.records[club.id], rec.visited {
                return RecentVisit(club: club, date: rec.updatedAt)
            }
            return nil
        }
        .sorted { $0.date > $1.date }
        let relegatedOrHistoricalRows = nonProgressionVisibleClubs.sorted { lhs, rhs in
            if lhs.countryCode != rhs.countryCode {
                return LeaguePresentation.countryRank(lhs.countryCode) < LeaguePresentation.countryRank(rhs.countryCode)
            }
            let lhsRank = LeaguePresentation.divisionRank(lhs.division, countryCode: lhs.countryCode)
            let rhsRank = LeaguePresentation.divisionRank(rhs.division, countryCode: rhs.countryCode)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let journeyAchievements = [
            Achievement(id: "first_visit", title: "Første skridt", description: "Besøg dit første stadion.", systemImage: "figure.walk", isUnlocked: visitedCount >= 1, progressText: "\(min(visitedCount, 1))/1", track: .journey),
            Achievement(id: "five_stadiums", title: "Groundhopper I", description: "Besøg 5 stadions.", systemImage: "map", isUnlocked: visitedCount >= 5, progressText: "\(min(visitedCount, 5))/5", track: .journey),
            Achievement(id: "twelve_stadiums", title: "Groundhopper II", description: "Besøg 12 stadions.", systemImage: "map.fill", isUnlocked: visitedCount >= 12, progressText: "\(min(visitedCount, 12))/12", track: .journey),
            Achievement(id: "first_review", title: "Anmelder", description: "Lav din første stadion-anmeldelse.", systemImage: "text.bubble", isUnlocked: reviewedCount >= 1, progressText: "\(min(reviewedCount, 1))/1", track: .journey),
            Achievement(id: "reviewer_level_2", title: "Anmelder II", description: "Lav anmeldelser af 5 stadions.", systemImage: "text.bubble.fill", isUnlocked: reviewedCount >= 5, progressText: "\(min(reviewedCount, 5))/5", track: .journey),
            Achievement(id: "note_writer", title: "Noteskriver", description: "Skriv noter på 5 stadions.", systemImage: "note.text", isUnlocked: notesCount >= 5, progressText: "\(min(notesCount, 5))/5", track: .journey),
            Achievement(id: "first_photo", title: "Fotograf", description: "Tilføj dit første stadionbillede.", systemImage: "camera", isUnlocked: totalPhotoCount >= 1, progressText: "\(min(totalPhotoCount, 1))/1", track: .journey),
            Achievement(id: "photo_collector", title: "Fotojæger", description: "Tilføj 10 stadionbilleder i alt.", systemImage: "camera.fill", isUnlocked: totalPhotoCount >= 10, progressText: "\(min(totalPhotoCount, 10))/10", track: .journey),
            Achievement(id: "gallery_builder", title: "Galleri-bygger", description: "Tilføj billeder på 3 forskellige stadions.", systemImage: "photo.on.rectangle", isUnlocked: stadiumsWithPhotosCount >= 3, progressText: "\(min(stadiumsWithPhotosCount, 3))/3", track: .journey),
            Achievement(id: "city_hopper", title: "Byhopper", description: "Besøg stadions i 5 forskellige byer.", systemImage: "building.2", isUnlocked: visitedCitiesCount >= 5, progressText: "\(min(visitedCitiesCount, 5))/5", track: .journey),
            Achievement(id: "league_explorer", title: "Række-rejsende", description: "Besøg stadions i 3 forskellige ligaer.", systemImage: "point.3.connected.trianglepath.dotted", isUnlocked: visitedDivisionsCount >= 3, progressText: "\(min(visitedDivisionsCount, 3))/3", track: .journey),
        ].sorted { a, b in
            if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }

        let homeCountryLabel = LeaguePresentation.countryLabel(activeHomeCountryCode)
        let completedHomeDivisions = homeCountryVisitedByDivision.filter { $0.total > 0 && $0.visited == $0.total }.count
        let halfThreshold = max(1, Int(ceil(Double(max(homeCountryTotalCount, 1)) * 0.5)))
        let homeCountryAchievements = [
            Achievement(id: "home_country_halfway", title: "Halvvejs hjemme", description: "Besøg halvdelen af stadions i \(homeCountryLabel).", systemImage: "chart.bar.xaxis", isUnlocked: homeCountryVisitedCount >= halfThreshold, progressText: "\(min(homeCountryVisitedCount, halfThreshold))/\(halfThreshold)", track: .homeCountry),
            Achievement(id: "home_country_league_complete", title: "Række-specialist", description: "Fuldfør alle stadions i én række i \(homeCountryLabel).", systemImage: "trophy", isUnlocked: completedHomeDivisions >= 1, progressText: "\(completedHomeDivisions)/1", track: .homeCountry),
            Achievement(id: "home_country_complete", title: "Tribune Tour Master", description: "Besøg alle stadions i \(homeCountryLabel).", systemImage: "crown", isUnlocked: homeCountryTotalCount > 0 && homeCountryVisitedCount == homeCountryTotalCount, progressText: "\(homeCountryVisitedCount)/\(max(1, homeCountryTotalCount))", track: .homeCountry),
        ].sorted { a, b in
            if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }

        let countryAchievements: [Achievement] = {
            let extraCountryCodes = countryOptions.filter { $0 != activeHomeCountryCode }

            let achievements = extraCountryCodes.compactMap { countryCode -> Achievement? in
                let clubsInCountry = progressionClubs.filter { $0.countryCode == countryCode }
                let total = clubsInCountry.count
                guard total > 0 else { return nil }

                let visited = clubsInCountry.filter { visitedIds.contains($0.id) }.count
                let countryLabel = LeaguePresentation.countryLabel(countryCode)

                if visited == 0 {
                    return Achievement(
                        id: "country_first_\(countryCode)",
                        title: "Første stadion i \(countryLabel)",
                        description: "Tag det første stadionbesøg i \(countryLabel).",
                        systemImage: "globe",
                        isUnlocked: false,
                        progressText: "0/1",
                        track: .countries
                    )
                }

                let threeTarget = min(3, total)
                if visited < threeTarget {
                    return Achievement(
                        id: "country_three_\(countryCode)",
                        title: "\(threeTarget) stadions i \(countryLabel)",
                        description: "Besøg \(threeTarget) stadions i \(countryLabel).",
                        systemImage: "globe.europe.africa",
                        isUnlocked: false,
                        progressText: "\(visited)/\(threeTarget)",
                        track: .countries
                    )
                }

                let halfwayTarget = max(1, Int(ceil(Double(total) * 0.5)))
                if total >= 6 && visited < halfwayTarget {
                    return Achievement(
                        id: "country_halfway_\(countryCode)",
                        title: "Halvvejs i \(countryLabel)",
                        description: "Besøg halvdelen af stadions i \(countryLabel).",
                        systemImage: "chart.bar.xaxis",
                        isUnlocked: false,
                        progressText: "\(visited)/\(halfwayTarget)",
                        track: .countries
                    )
                }

                if visited < total {
                    return Achievement(
                        id: "country_complete_\(countryCode)",
                        title: "Fuldfør \(countryLabel)",
                        description: "Besøg alle stadions i \(countryLabel).",
                        systemImage: "flag.pattern.checkered",
                        isUnlocked: false,
                        progressText: "\(visited)/\(total)",
                        track: .countries
                    )
                }

                return nil
            }

            return achievements.sorted { lhs, rhs in
                let lhsParts = lhs.progressText.split(separator: "/").compactMap { Int($0) }
                let rhsParts = rhs.progressText.split(separator: "/").compactMap { Int($0) }
                let lhsRemaining = lhsParts.count == 2 ? lhsParts[1] - lhsParts[0] : Int.max
                let rhsRemaining = rhsParts.count == 2 ? rhsParts[1] - rhsParts[0] : Int.max
                if lhsRemaining != rhsRemaining { return lhsRemaining < rhsRemaining }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }()

        let internationalAchievements: [Achievement] = {
            guard hasInternationalCountries else { return [] }
            let internationalVisitedByDivision = buildDivisionRows(from: internationalClubs, visitedIds: visitedIds)
            let completedInternationalDivisions = internationalVisitedByDivision.filter { $0.total > 0 && $0.visited == $0.total }.count
            let activeCountryCount = Set(progressionClubs.map(\.countryCode)).count
            let visitedCountryCount = Set(visitedClubs.map(\.countryCode)).count
            let crossBorderTarget = min(activeCountryCount, 2)
            return [
                Achievement(id: "international_first_visit", title: "Udebanestart", description: "Besøg dit første stadion uden for \(homeCountryLabel).", systemImage: "airplane.departure", isUnlocked: internationalVisitedCount >= 1, progressText: "\(min(internationalVisitedCount, 1))/1", track: .international),
                Achievement(id: "international_explorer", title: "International groundhopper", description: "Besøg 5 stadions uden for \(homeCountryLabel).", systemImage: "globe.europe.africa", isUnlocked: internationalVisitedCount >= 5, progressText: "\(min(internationalVisitedCount, 5))/5", track: .international),
                Achievement(id: "cross_border", title: "På tværs af grænser", description: "Besøg stadions i mindst 2 åbne lande.", systemImage: "point.topleft.down.curvedto.point.bottomright.up", isUnlocked: crossBorderTarget <= 1 || visitedCountryCount >= crossBorderTarget, progressText: "\(min(visitedCountryCount, crossBorderTarget))/\(crossBorderTarget)", track: .international),
                Achievement(id: "international_league_complete", title: "Udebanespecialist", description: "Fuldfør alle stadions i én række uden for \(homeCountryLabel).", systemImage: "flag.pattern.checkered", isUnlocked: completedInternationalDivisions >= 1, progressText: "\(completedInternationalDivisions)/1", track: .international),
            ].sorted { a, b in
                if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }()

        let nextLockedAchievement: Achievement? = {
            let lockedJourney = journeyAchievements.filter { !$0.isUnlocked }
            let lockedHome = homeCountryAchievements.filter { !$0.isUnlocked }
            let lockedCountries = countryAchievements.filter { !$0.isUnlocked }
            let lockedInternational = internationalAchievements.filter { !$0.isUnlocked }

            if visitedCount == 0 {
                return lockedJourney.first ?? lockedHome.first ?? lockedCountries.first ?? lockedInternational.first
            }

            if homeCountryVisitedCount < homeCountryTotalCount {
                return lockedHome.first ?? lockedJourney.first ?? lockedCountries.first ?? lockedInternational.first
            }

            if hasInternationalCountries {
                return lockedCountries.first ?? lockedInternational.first ?? lockedJourney.first ?? lockedHome.first
            }

            return lockedJourney.first ?? lockedHome.first
        }()

        let achievements = journeyAchievements + homeCountryAchievements + countryAchievements + internationalAchievements
        let unlockedAchievementIds = Set(achievements.filter(\.isUnlocked).map(\.id))
        let prioritizedMilestoneRows = (homeCountryVisitedByDivision.isEmpty ? visitedByDivision : homeCountryVisitedByDivision)
        let nextLeagueMilestone = prioritizedMilestoneRows
            .filter { $0.total > 0 && $0.visited < $0.total }
            .sorted { lhs, rhs in
                let lhsRemaining = lhs.total - lhs.visited
                let rhsRemaining = rhs.total - rhs.visited
                if lhsRemaining != rhsRemaining { return lhsRemaining < rhsRemaining }
                let lhsCountryRank = LeaguePresentation.countryRank(lhs.countryCode)
                let rhsCountryRank = LeaguePresentation.countryRank(rhs.countryCode)
                if lhsCountryRank != rhsCountryRank { return lhsCountryRank < rhsCountryRank }
                let lhsRank = LeaguePresentation.divisionRank(lhs.division, countryCode: lhs.countryCode)
                let rhsRank = LeaguePresentation.divisionRank(rhs.division, countryCode: rhs.countryCode)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.division.localizedCaseInsensitiveCompare(rhs.division) == .orderedAscending
            }
            .map { LeagueMilestone(countryCode: $0.countryCode, division: $0.division, remaining: $0.total - $0.visited) }
            .first

        let orderedMilestoneRows = prioritizedMilestoneRows
            .filter { $0.total > 0 && $0.visited < $0.total }
            .sorted { lhs, rhs in
                let lhsRemaining = lhs.total - lhs.visited
                let rhsRemaining = rhs.total - rhs.visited
                if lhsRemaining != rhsRemaining { return lhsRemaining < rhsRemaining }
                let lhsCountryRank = LeaguePresentation.countryRank(lhs.countryCode)
                let rhsCountryRank = LeaguePresentation.countryRank(rhs.countryCode)
                if lhsCountryRank != rhsCountryRank { return lhsCountryRank < rhsCountryRank }
                let lhsRank = LeaguePresentation.divisionRank(lhs.division, countryCode: lhs.countryCode)
                let rhsRank = LeaguePresentation.divisionRank(rhs.division, countryCode: rhs.countryCode)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.division.localizedCaseInsensitiveCompare(rhs.division) == .orderedAscending
            }

        let upcomingFixtures = fixtures
            .filter { $0.kickoff >= Date() && $0.status == .scheduled }
            .sorted { $0.kickoff < $1.kickoff }

        let suggestedNextClub: Club? = {
            for row in orderedMilestoneRows {
                let clubsInRow = unvisitedClubs.filter { $0.division == row.division && $0.countryCode == row.countryCode }
                let clubIds = Set(clubsInRow.map(\.id))
                if let fixtureClubId = upcomingFixtures.first(where: { clubIds.contains($0.venueClubId) })?.venueClubId,
                   let club = clubsInRow.first(where: { $0.id == fixtureClubId }) {
                    return club
                }
            }

            let homeCountryUnvisited = unvisitedClubs.filter { $0.countryCode == activeHomeCountryCode }
            let homeCountryIds = Set(homeCountryUnvisited.map(\.id))
            if let fixtureClubId = upcomingFixtures.first(where: { homeCountryIds.contains($0.venueClubId) })?.venueClubId,
               let club = homeCountryUnvisited.first(where: { $0.id == fixtureClubId }) {
                return club
            }

            let allUnvisitedIds = Set(unvisitedClubs.map(\.id))
            if let fixtureClubId = upcomingFixtures.first(where: { allUnvisitedIds.contains($0.venueClubId) })?.venueClubId,
               let club = unvisitedClubs.first(where: { $0.id == fixtureClubId }) {
                return club
            }

            if let nextLeagueMilestone {
                let prioritized = unvisitedClubs
                    .filter { $0.division == nextLeagueMilestone.division && $0.countryCode == nextLeagueMilestone.countryCode }
                    .sorted { lhs, rhs in
                        if lhs.countryCode != rhs.countryCode {
                            return LeaguePresentation.countryRank(lhs.countryCode) < LeaguePresentation.countryRank(rhs.countryCode)
                        }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                if let first = prioritized.first { return first }
            }

            return unvisitedClubs.sorted { lhs, rhs in
                if lhs.countryCode != rhs.countryCode {
                    return LeaguePresentation.countryRank(lhs.countryCode) < LeaguePresentation.countryRank(rhs.countryCode)
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }.first
        }()

        let heroSummaryText: String = {
            if totalCount == 0 { return "Dit scope er tomt lige nu." }
            if visitedCount == 0 { return "Din stadionrejse starter med det første besøg." }
            if visitedCount == totalCount { return "Du har besøgt alle stadions i dit nuværende scope." }
            return "\(visitedCount) af \(totalCount) stadions er allerede krydset af."
        }()

        let nextMilestoneTitle: String = {
            if let nextLeagueMilestone {
                if nextLeagueMilestone.remaining == 1 {
                    return "Du mangler 1 stadion for at fuldføre \(LeaguePresentation.divisionDisplayName(nextLeagueMilestone.division, countryCode: nextLeagueMilestone.countryCode))"
                }
                return "Du mangler \(nextLeagueMilestone.remaining) stadions for at fuldføre \(LeaguePresentation.divisionDisplayName(nextLeagueMilestone.division, countryCode: nextLeagueMilestone.countryCode))"
            }
            if let nextLockedAchievement { return nextLockedAchievement.title }
            return "Fortsæt rejsen"
        }()

        let nextMilestoneDescription: String = {
            if nextLeagueMilestone != nil { return "Det er den korteste vej til din næste store milepæl." }
            if let nextLockedAchievement { return nextLockedAchievement.description }
            return "Hvert nyt besøg bringer dig tættere på næste kapitel."
        }()

        let suggestionDescription: String = {
            if let nextLeagueMilestone {
                return "Et nyt besøg her vil bringe dig tættere på at fuldføre \(LeaguePresentation.divisionDisplayName(nextLeagueMilestone.division, countryCode: nextLeagueMilestone.countryCode))."
            }
            if let nextLockedAchievement {
                return "Et godt næste stop, hvis du vil arbejde videre mod achievementen “\(nextLockedAchievement.title)”."
            }
            return "Et oplagt næste stadion at sætte på ønskelisten."
        }()

        let internationalCountryCount = Set(internationalClubs.map(\.countryCode)).count
        let internationalSectionDescription: String = {
            let homeCountry = LeaguePresentation.countryLabel(activeHomeCountryCode)
            if internationalCountryCount <= 1 {
                return "De her mål tæller kun på åbne lande uden for \(homeCountry)."
            }
            return "De her mål tæller på dine \(internationalCountryCount) åbne lande uden for \(homeCountry)."
        }()

        snapshot = Snapshot(
            visitedCount: visitedCount,
            totalCount: totalCount,
            unvisitedCount: unvisitedCount,
            progress: progress,
            progressPercentText: progressPercentText,
            notesCount: notesCount,
            reviewedCount: reviewedCount,
            averageReviewScoreText: averageReviewScoreText,
            totalPhotoCount: totalPhotoCount,
            stadiumsWithPhotosCount: stadiumsWithPhotosCount,
            visitedCitiesCount: visitedCitiesCount,
            visitedDivisionsCount: visitedDivisionsCount,
            activeHomeCountryCode: activeHomeCountryCode,
            currentScopeLabel: currentScopeLabel,
            countryOptions: countryOptions,
            hasInternationalCountries: hasInternationalCountries,
            internationalCountryCount: internationalCountryCount,
            shouldShowAccountPrompt: shouldShowAccountPrompt,
            accountPromptHighlights: accountPromptHighlights,
            sortedVisitedClubs: visitedClubs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            recentVisited: recentVisited,
            relegatedOrHistoricalRows: relegatedOrHistoricalRows,
            journeyAchievements: journeyAchievements,
            homeCountryAchievements: homeCountryAchievements,
            countryAchievements: Array(countryAchievements.prefix(3)),
            internationalAchievements: internationalAchievements,
            achievements: achievements,
            unlockedAchievementIds: unlockedAchievementIds,
            unlockedAchievementsCount: unlockedAchievementIds.count,
            nextLockedAchievement: nextLockedAchievement,
            nextLeagueMilestone: nextLeagueMilestone,
            suggestedNextClub: suggestedNextClub,
            heroSummaryText: heroSummaryText,
            nextMilestoneTitle: nextMilestoneTitle,
            nextMilestoneDescription: nextMilestoneDescription,
            suggestionDescription: suggestionDescription,
            internationalSectionDescription: internationalSectionDescription,
            visitedByDivision: visitedByDivision,
            homeCountryVisitedByDivision: homeCountryVisitedByDivision
        )
    }

    private var visitedByDivision: [DivisionProgressRow] {
        divisionRows(from: progressionClubs)
    }

    private var homeCountryVisitedByDivision: [DivisionProgressRow] {
        divisionRows(from: homeCountryClubs)
    }

    private var activeHomeCountryCode: String {
        LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: Set((progressionClubs.isEmpty ? accessibleClubs : progressionClubs).map(\.countryCode)))
    }

    private var currentScopeLabel: String {
        countryFilterRawValue == "all" ? "Alle aktive lande" : LeaguePresentation.countryLabel(countryFilterRawValue)
    }

    private var recentVisited: [(club: Club, date: Date)] {
        // Brug visitedDate hvis sat, ellers updatedAt (kun hvis visited)
        visitedClubs.compactMap { club in
            if let d = visitedStore.visitedDate(for: club.id) {
                return (club, d)
            }
            if let rec = visitedStore.records[club.id], rec.visited {
                return (club, rec.updatedAt)
            }
            return nil
        }
        .sorted { $0.date > $1.date }
    }

    private var notesCount: Int {
        visitedStore.records.values.reduce(0) { acc, r in
            let trimmed = r.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            return acc + (trimmed.isEmpty ? 0 : 1)
        }
    }

    private var reviewedCount: Int {
        reviewsStore.reviewsByClubId.count
    }

    private var averageReviewScoreText: String? {
        let averages = reviewsStore.reviewsByClubId.values.compactMap { $0.averageScore }
        guard !averages.isEmpty else { return nil }
        let total = averages.reduce(0, +)
        let overall = total / Double(averages.count)
        return String(format: "%.1f", overall)
    }

    private var totalPhotoCount: Int {
        visitedStore.records.values.reduce(0) { acc, record in
            acc + record.photoFileNames.count
        }
    }

    private var stadiumsWithPhotosCount: Int {
        visitedStore.records.values.reduce(0) { acc, record in
            acc + (record.photoFileNames.isEmpty ? 0 : 1)
        }
    }

    private var visitedCitiesCount: Int {
        Set(visitedClubs.map { $0.stadium.city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count
    }

    private var visitedDivisionsCount: Int {
        Set(visitedClubs.map { $0.division.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count
    }

    private var relegatedOrHistoricalRows: [Club] {
        nonProgressionVisibleClubs.sorted { lhs, rhs in
            if lhs.countryCode != rhs.countryCode {
                return LeaguePresentation.countryRank(lhs.countryCode) < LeaguePresentation.countryRank(rhs.countryCode)
            }

            let lhsRank = LeaguePresentation.divisionRank(lhs.division, countryCode: lhs.countryCode)
            let rhsRank = LeaguePresentation.divisionRank(rhs.division, countryCode: rhs.countryCode)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var journeyAchievements: [Achievement] {
        return [
            Achievement(
                id: "first_visit",
                title: "Første skridt",
                description: "Besøg dit første stadion.",
                systemImage: "figure.walk",
                isUnlocked: visitedCount >= 1,
                progressText: "\(min(visitedCount, 1))/1",
                track: .journey
            ),
            Achievement(
                id: "five_stadiums",
                title: "Groundhopper I",
                description: "Besøg 5 stadions.",
                systemImage: "map",
                isUnlocked: visitedCount >= 5,
                progressText: "\(min(visitedCount, 5))/5",
                track: .journey
            ),
            Achievement(
                id: "twelve_stadiums",
                title: "Groundhopper II",
                description: "Besøg 12 stadions.",
                systemImage: "map.fill",
                isUnlocked: visitedCount >= 12,
                progressText: "\(min(visitedCount, 12))/12",
                track: .journey
            ),
            Achievement(
                id: "first_review",
                title: "Anmelder",
                description: "Lav din første stadion-anmeldelse.",
                systemImage: "text.bubble",
                isUnlocked: reviewedCount >= 1,
                progressText: "\(min(reviewedCount, 1))/1",
                track: .journey
            ),
            Achievement(
                id: "reviewer_level_2",
                title: "Anmelder II",
                description: "Lav anmeldelser af 5 stadions.",
                systemImage: "text.bubble.fill",
                isUnlocked: reviewedCount >= 5,
                progressText: "\(min(reviewedCount, 5))/5",
                track: .journey
            ),
            Achievement(
                id: "note_writer",
                title: "Noteskriver",
                description: "Skriv noter på 5 stadions.",
                systemImage: "note.text",
                isUnlocked: notesCount >= 5,
                progressText: "\(min(notesCount, 5))/5",
                track: .journey
            ),
            Achievement(
                id: "first_photo",
                title: "Fotograf",
                description: "Tilføj dit første stadionbillede.",
                systemImage: "camera",
                isUnlocked: totalPhotoCount >= 1,
                progressText: "\(min(totalPhotoCount, 1))/1",
                track: .journey
            ),
            Achievement(
                id: "photo_collector",
                title: "Fotojæger",
                description: "Tilføj 10 stadionbilleder i alt.",
                systemImage: "camera.fill",
                isUnlocked: totalPhotoCount >= 10,
                progressText: "\(min(totalPhotoCount, 10))/10",
                track: .journey
            ),
            Achievement(
                id: "gallery_builder",
                title: "Galleri-bygger",
                description: "Tilføj billeder på 3 forskellige stadions.",
                systemImage: "photo.on.rectangle",
                isUnlocked: stadiumsWithPhotosCount >= 3,
                progressText: "\(min(stadiumsWithPhotosCount, 3))/3",
                track: .journey
            ),
            Achievement(
                id: "city_hopper",
                title: "Byhopper",
                description: "Besøg stadions i 5 forskellige byer.",
                systemImage: "building.2",
                isUnlocked: visitedCitiesCount >= 5,
                progressText: "\(min(visitedCitiesCount, 5))/5",
                track: .journey
            ),
            Achievement(
                id: "league_explorer",
                title: "Række-rejsende",
                description: "Besøg stadions i 3 forskellige ligaer.",
                systemImage: "point.3.connected.trianglepath.dotted",
                isUnlocked: visitedDivisionsCount >= 3,
                progressText: "\(min(visitedDivisionsCount, 3))/3",
                track: .journey
            )
        ]
        .sorted { a, b in
            if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    private var homeCountryAchievements: [Achievement] {
        let homeCountryLabel = LeaguePresentation.countryLabel(activeHomeCountryCode)
        let completedHomeDivisions = homeCountryVisitedByDivision.filter { $0.total > 0 && $0.visited == $0.total }.count
        let halfThreshold = max(1, Int(ceil(Double(max(homeCountryTotalCount, 1)) * 0.5)))

        return [
            Achievement(
                id: "home_country_halfway",
                title: "Halvvejs hjemme",
                description: "Besøg halvdelen af stadions i \(homeCountryLabel).",
                systemImage: "chart.bar.xaxis",
                isUnlocked: homeCountryVisitedCount >= halfThreshold,
                progressText: "\(min(homeCountryVisitedCount, halfThreshold))/\(halfThreshold)",
                track: .homeCountry
            ),
            Achievement(
                id: "home_country_league_complete",
                title: "Række-specialist",
                description: "Fuldfør alle stadions i én række i \(homeCountryLabel).",
                systemImage: "trophy",
                isUnlocked: completedHomeDivisions >= 1,
                progressText: "\(completedHomeDivisions)/1",
                track: .homeCountry
            ),
            Achievement(
                id: "home_country_complete",
                title: "Tribune Tour Master",
                description: "Besøg alle stadions i \(homeCountryLabel).",
                systemImage: "crown",
                isUnlocked: homeCountryTotalCount > 0 && homeCountryVisitedCount == homeCountryTotalCount,
                progressText: "\(homeCountryVisitedCount)/\(max(1, homeCountryTotalCount))",
                track: .homeCountry
            )
        ]
        .sorted { a, b in
            if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    private var internationalAchievements: [Achievement] {
        guard hasInternationalCountries else { return [] }

        let homeCountryLabel = LeaguePresentation.countryLabel(activeHomeCountryCode)
        let internationalVisitedByDivision = divisionRows(from: internationalClubs)
        let completedInternationalDivisions = internationalVisitedByDivision.filter { $0.total > 0 && $0.visited == $0.total }.count
        let activeCountryCount = Set(progressionClubs.map(\.countryCode)).count
        let visitedCountryCount = Set(visitedClubs.map(\.countryCode)).count
        let crossBorderTarget = min(activeCountryCount, 2)

        return [
            Achievement(
                id: "international_first_visit",
                title: "Udebanestart",
                description: "Besøg dit første stadion uden for \(homeCountryLabel).",
                systemImage: "airplane.departure",
                isUnlocked: internationalVisitedCount >= 1,
                progressText: "\(min(internationalVisitedCount, 1))/1",
                track: .international
            ),
            Achievement(
                id: "international_explorer",
                title: "International groundhopper",
                description: "Besøg 5 stadions uden for \(homeCountryLabel).",
                systemImage: "globe.europe.africa",
                isUnlocked: internationalVisitedCount >= 5,
                progressText: "\(min(internationalVisitedCount, 5))/5",
                track: .international
            ),
            Achievement(
                id: "cross_border",
                title: "På tværs af grænser",
                description: "Besøg stadions i mindst 2 åbne lande.",
                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                isUnlocked: crossBorderTarget <= 1 || visitedCountryCount >= crossBorderTarget,
                progressText: "\(min(visitedCountryCount, crossBorderTarget))/\(crossBorderTarget)",
                track: .international
            ),
            Achievement(
                id: "international_league_complete",
                title: "Udebanespecialist",
                description: "Fuldfør alle stadions i én række uden for \(homeCountryLabel).",
                systemImage: "flag.pattern.checkered",
                isUnlocked: completedInternationalDivisions >= 1,
                progressText: "\(completedInternationalDivisions)/1",
                track: .international
            )
        ]
        .sorted { a, b in
            if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    private var achievements: [Achievement] {
        journeyAchievements + homeCountryAchievements + internationalAchievements
    }

    private var unlockedAchievementsCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    private var unlockedAchievementIds: Set<String> {
        Set(achievements.filter(\.isUnlocked).map(\.id))
    }

    private var seenUnlockedIds: Set<String> {
        Set(
            seenUnlockedIdsRaw
                .split(separator: ",")
                .map { String($0) }
                .filter { !$0.isEmpty }
        )
    }

    private var nextLockedAchievement: Achievement? {
        achievements.first(where: { !$0.isUnlocked })
    }

    private var nextLeagueMilestone: (countryCode: String, division: String, remaining: Int)? {
        visitedByDivision
            .filter { $0.total > 0 && $0.visited < $0.total }
            .sorted { lhs, rhs in
                let lhsRemaining = lhs.total - lhs.visited
                let rhsRemaining = rhs.total - rhs.visited
                if lhsRemaining != rhsRemaining { return lhsRemaining < rhsRemaining }

                let lhsCountryRank = LeaguePresentation.countryRank(lhs.countryCode)
                let rhsCountryRank = LeaguePresentation.countryRank(rhs.countryCode)
                if lhsCountryRank != rhsCountryRank { return lhsCountryRank < rhsCountryRank }

                let lhsRank = LeaguePresentation.divisionRank(lhs.division, countryCode: lhs.countryCode)
                let rhsRank = LeaguePresentation.divisionRank(rhs.division, countryCode: rhs.countryCode)
                if lhsRank != rhsRank { return lhsRank < rhsRank }

                return lhs.division.localizedCaseInsensitiveCompare(rhs.division) == .orderedAscending
            }
            .map { (countryCode: $0.countryCode, division: $0.division, remaining: $0.total - $0.visited) }
            .first
    }

    private var suggestedNextClub: Club? {
        if let nextLeagueMilestone {
            let prioritized = unvisitedClubs
                .filter { $0.division == nextLeagueMilestone.division && $0.countryCode == nextLeagueMilestone.countryCode }
                .sorted { lhs, rhs in
                    if lhs.countryCode != rhs.countryCode {
                        return LeaguePresentation.countryRank(lhs.countryCode) < LeaguePresentation.countryRank(rhs.countryCode)
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

            if let first = prioritized.first {
                return first
            }
        }

        return unvisitedClubs.sorted { lhs, rhs in
            if lhs.countryCode != rhs.countryCode {
                return LeaguePresentation.countryRank(lhs.countryCode) < LeaguePresentation.countryRank(rhs.countryCode)
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }.first
    }

    private var heroSummaryText: String {
        if totalCount == 0 {
            return "Dit scope er tomt lige nu."
        }

        if visitedCount == 0 {
            return "Din stadionrejse starter med det første besøg."
        }

        if visitedCount == totalCount {
            return "Du har besøgt alle stadions i dit nuværende scope."
        }

        return "\(visitedCount) af \(totalCount) stadions er allerede krydset af."
    }

    private var nextMilestoneTitle: String {
        if let nextLeagueMilestone {
            if nextLeagueMilestone.remaining == 1 {
                return "Du mangler 1 stadion for at fuldføre \(LeaguePresentation.divisionDisplayName(nextLeagueMilestone.division, countryCode: nextLeagueMilestone.countryCode))"
            }

            return "Du mangler \(nextLeagueMilestone.remaining) stadions for at fuldføre \(LeaguePresentation.divisionDisplayName(nextLeagueMilestone.division, countryCode: nextLeagueMilestone.countryCode))"
        }

        if let nextLockedAchievement {
            return nextLockedAchievement.title
        }

        return "Fortsæt rejsen"
    }

    private var nextMilestoneDescription: String {
        if nextLeagueMilestone != nil {
            return "Det er den korteste vej til din næste store milepæl."
        }

        if let nextLockedAchievement {
            return nextLockedAchievement.description
        }

        return "Hvert nyt besøg bringer dig tættere på næste kapitel."
    }

    private var suggestionDescription: String {
        if let nextLeagueMilestone {
            return "Et nyt besøg her vil bringe dig tættere på at fuldføre \(LeaguePresentation.divisionDisplayName(nextLeagueMilestone.division, countryCode: nextLeagueMilestone.countryCode))."
        }

        if let nextLockedAchievement {
            return "Et godt næste stop, hvis du vil arbejde videre mod achievementen “\(nextLockedAchievement.title)”."
        }

        return "Et oplagt næste stadion at sætte på ønskelisten."
    }

    @ViewBuilder
    private var accountAndSyncSection: some View {
        Section("Konto") {
            if authSession.snapshot.isAuthenticated {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Logget ind")
                        .font(.headline)
                    Text(authSession.snapshot.userEmail ?? "Ukendt konto")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let loginInfoMessage {
                    Text(loginInfoMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let runtimeSyncInfoMessage {
                    Text(runtimeSyncInfoMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let loginErrorMessage {
                    Text(loginErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let lastSyncIssue = visitedStore.lastSyncIssue {
                    Text(lastSyncIssue)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Flere lande")
                        .font(.headline)
                    Text("Her kan du se hvilke lande der er åbne for dig lige nu, og hvilke du stadig mangler.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    PremiumAccessStatusCard(
                        isLoggedIn: true,
                        unlockedPremiumTitles: unlockedPremiumPackTitles,
                        lockedPremiumTitles: lockedPremiumPackTitles,
                        title: "Dine lande",
                        subtitle: "Her ser du hvad du allerede kan bruge, og hvad der stadig er lukket."
                    )

                    Text("Vil du videre end Danmark, kan du bede om adgang til flere lande her.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if premiumRequestRowsLoading {
                        Text("Henter dine anmodninger...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let selectedPackOpenRequest {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Du har allerede en åben anmodning om \(selectedPackOpenRequest.packTitle).")
                                .font(.caption.weight(.semibold))
                            if let createdAt = selectedPackOpenRequest.createdAt {
                                Text("Sendt \(createdAt.formatted(date: .abbreviated, time: .shortened)).")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.secondary)
                    } else if !openPremiumRequestRows.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Åbne anmodninger")
                                .font(.caption.weight(.semibold))
                            ForEach(openPremiumRequestRows.prefix(3)) { request in
                                Text("• \(request.packTitle)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Picker("Land", selection: $premiumRequestPack) {
                        ForEach(AppPremiumAdminPack.allCases) { pack in
                            Text(pack.title).tag(pack)
                        }
                    }

                    TextField("Besked, valgfri", text: $premiumRequestMessage, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(2...4)

                    Button {
                        Task { await submitPremiumAccessRequest() }
                    } label: {
                        StatsActionButtonLabel(
                            title: premiumRequestLoading ? "Sender..." : selectedPackOpenRequest == nil ? "Anmod om adgang" : "Anmodning allerede sendt",
                            isActive: !premiumRequestLoading && selectedPackOpenRequest == nil
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(premiumRequestLoading || selectedPackOpenRequest != nil)

                    if let premiumRequestInfoMessage {
                        Text(premiumRequestInfoMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let premiumRequestErrorMessage {
                        Text(premiumRequestErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Button("Log ud", role: .destructive) {
                    authSession.clearSession()
                    loginInfoMessage = nil
                    loginErrorMessage = nil
                    pendingBootstrapStatus = nil
                    premiumRequestInfoMessage = nil
                    premiumRequestErrorMessage = nil
                }
            } else {
                let configuration = authClient.currentConfiguration()

                if configuration.isConfigured {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Log ind")
                            .font(.headline)
                        Text("Log ind for at gemme dine data og åbne resten af Tribunetour på din konto.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if snapshot.shouldShowAccountPrompt {
                            AccountPromptCard(
                                highlights: snapshot.accountPromptHighlights,
                                onDismiss: { accountPromptDismissed = true }
                            )
                        }

                        PremiumAccessStatusCard(
                            isLoggedIn: false,
                            unlockedPremiumTitles: [],
                            lockedPremiumTitles: lockedPremiumPackTitles,
                            title: "Det kan du se lige nu",
                            subtitle: "Som gæst ser du de danske rækker. Log ind for at se flere lande."
                        )

                        Button {
                            showAuthSheet = true
                        } label: {
                            StatsActionButtonLabel(
                                title: "Log ind eller opret konto",
                                isActive: true
                            )
                        }
                        .buttonStyle(.plain)

                        if let loginInfoMessage {
                            Text(loginInfoMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let loginErrorMessage {
                            Text(loginErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Login er midlertidigt utilgængeligt")
                            .font(.headline)
                        Text("Du kan stadig bruge appen lokalt. Konto er bare ikke klar i denne build endnu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let validationMessage = configuration.supabaseURLValidationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if !configuration.hasAnonKey {
                            Text("Login-konfiguration mangler stadig i denne build.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .id(authSession.snapshot.isAuthenticated ? "account-authenticated" : "account-unauthenticated")
    }

    var body: some View {
        Group {
            if isActive {
                activeBody
            } else {
                NavigationStack {
                    Color.clear
                        .navigationTitle("Min tur")
                }
            }
        }
    }

    private var activeBody: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Byg din stadionrejse")
                                .font(.headline)
                            Text(snapshot.heroSummaryText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            StatsHeroMetric(title: "Besøgte", value: "\(snapshot.visitedCount)")
                            StatsHeroMetric(title: "Mangler", value: "\(snapshot.unvisitedCount)")
                            StatsHeroMetric(title: "Fremdrift", value: snapshot.progressPercentText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Fremdrift")
                                Spacer()
                                Text("\(snapshot.visitedCount) / \(snapshot.totalCount)")
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: snapshot.progress)
                                .tint(.green)
                        }

                        HStack(spacing: 8) {
                            StatsContextChip(label: "Noter", value: snapshot.notesCount, systemImage: "note.text")
                            StatsContextChip(label: "Anmeldelser", value: snapshot.reviewedCount, systemImage: "star.bubble")
                            StatsContextChip(label: "Billeder", value: snapshot.totalPhotoCount, systemImage: "camera")
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !authSession.snapshot.isAuthenticated {
                    accountAndSyncSection
                }

                Section("Lige nu") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(snapshot.nextMilestoneTitle)
                            .font(.headline)
                        Text(snapshot.nextMilestoneDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            StatsStatusChip(title: "Hjemland", value: LeaguePresentation.countryLabel(snapshot.activeHomeCountryCode))
                            StatsStatusChip(title: "Scope", value: snapshot.currentScopeLabel)
                            StatsStatusChip(title: "Låst op", value: "\(snapshot.unlockedAchievementsCount)")
                        }

                        if let nextAchievement = snapshot.nextLockedAchievement {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Næste achievement")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(achievementTrackLabel(nextAchievement))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                Text(nextAchievement.title)
                                    .font(.headline)

                                Text(nextAchievement.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Fremdrift: \(nextAchievement.progressText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        if let suggestedNextClub = snapshot.suggestedNextClub {
                            NavigationLink {
                                StadiumDetailView(
                                    club: suggestedNextClub,
                                    visitedStore: visitedStore,
                                    photosStore: photosStore,
                                    notesStore: notesStore,
                                    reviewsStore: reviewsStore,
                                    clubById: clubById
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Næste stop")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(suggestedNextClub.name)
                                        .font(.headline)
                                    Text("\(suggestedNextClub.stadium.name) • \(suggestedNextClub.stadium.city)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(snapshot.suggestionDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Overblik") {
                    StatsOverviewRow(label: "Besøgte stadions", value: "\(snapshot.visitedCount) / \(snapshot.totalCount)")
                    StatsOverviewRow(label: "Ikke besøgt endnu", value: "\(snapshot.unvisitedCount)")
                    StatsOverviewRow(label: "Noter", value: "\(snapshot.notesCount)")
                    StatsOverviewRow(label: "Anmeldte stadions", value: "\(snapshot.reviewedCount)")

                    if let averageReviewScoreText = snapshot.averageReviewScoreText {
                        StatsOverviewRow(label: "Gns. anmeldelsesscore", value: "\(averageReviewScoreText) / 10")
                    }

                    StatsOverviewRow(label: "Stadions med billeder", value: "\(snapshot.stadiumsWithPhotosCount)")
                    StatsOverviewRow(label: "Billeder i alt", value: "\(snapshot.totalPhotoCount)")
                }

                Section("Seneste besøg") {
                    if snapshot.recentVisited.isEmpty {
                        ContentUnavailableView(
                            "Ingen besøg endnu",
                            systemImage: "checkmark.circle",
                            description: Text("Dine seneste besøg vises her, når du markerer stadions som besøgt.")
                        )
                        .padding(.vertical, 8)
                    } else {
                        ForEach(snapshot.recentVisited.prefix(10), id: \.club.id) { item in
                            NavigationLink {
                                StadiumDetailView(
                                    club: item.club,
                                    visitedStore: visitedStore,
                                    photosStore: photosStore,
                                    notesStore: notesStore,
                                    reviewsStore: reviewsStore,
                                    clubById: clubById
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.club.name)
                                        .font(.headline)
                                    Text("\(item.club.stadium.name) • \(item.club.stadium.city)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(item.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Hjemland og scope") {
                    Picker("Hjemland", selection: $preferredHomeCountryCode) {
                        ForEach(snapshot.countryOptions, id: \.self) { countryCode in
                            Text(LeaguePresentation.countryLabel(countryCode)).tag(countryCode)
                        }
                    }

                    HStack {
                        Text("Aktivt scope")
                        Spacer()
                        Text(snapshot.currentScopeLabel)
                            .foregroundStyle(.secondary)
                    }

                    Text("Dit hjemland er dit faste udgangspunkt her.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Din rejse") {
                    HStack {
                        Text("Låst op")
                        Spacer()
                        Text("\(snapshot.journeyAchievements.filter(\.isUnlocked).count)/\(snapshot.journeyAchievements.count)")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(snapshot.journeyAchievements) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }

                Section("I \(LeaguePresentation.countryLabel(snapshot.activeHomeCountryCode))") {
                    HStack {
                        Text("Låst op")
                        Spacer()
                        Text("\(snapshot.homeCountryAchievements.filter(\.isUnlocked).count)/\(snapshot.homeCountryAchievements.count)")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(snapshot.homeCountryAchievements) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }

                if !snapshot.countryAchievements.isEmpty {
                    Section("Lande i gang") {
                        Text("Her viser vi de lande, der er mest relevante for dig lige nu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(snapshot.countryAchievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }

                if !snapshot.internationalAchievements.isEmpty {
                    Section("Flere lande") {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mål uden for \(LeaguePresentation.countryLabel(snapshot.activeHomeCountryCode))")
                                    .font(.headline)
                                Text(snapshot.internationalSectionDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(snapshot.internationalAchievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }

                // MARK: By division
                Section("Så tæt er du på hver række") {
                    if snapshot.visitedByDivision.isEmpty {
                        Text("Ingen data.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.visitedByDivision) { row in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(LeaguePresentation.divisionDisplayName(row.division, countryCode: row.countryCode))
                                        .font(.headline)
                                    Spacer()
                                    Text("\(row.visited)/\(row.total)")
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: row.total == 0 ? 0 : Double(row.visited) / Double(row.total))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if !snapshot.relegatedOrHistoricalRows.isEmpty {
                    Section("Andre klubber") {
                        Text("Klubber her tæller ikke med i din aktuelle fremdrift, men bliver stadig gemt i din historik.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(snapshot.relegatedOrHistoricalRows) { club in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(club.name)
                                            .font(.headline)
                                        Text("\(club.stadium.name) • \(club.stadium.city)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if let membershipStatusLabel = club.membershipStatusLabel {
                                        Text(membershipStatusLabel)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(LeaguePresentation.divisionDisplayName(club.division, countryCode: club.countryCode))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: Visited list
                Section("Mine besøgte") {
                    if snapshot.sortedVisitedClubs.isEmpty {
                        ContentUnavailableView(
                            "Ingen besøgte stadions",
                            systemImage: "mappin.slash",
                            description: Text("Markér et stadion som besøgt for at se det her.")
                        )
                        .padding(.vertical, 8)
                    } else {
                        ForEach(snapshot.sortedVisitedClubs) { club in
                            NavigationLink {
                                StadiumDetailView(
                                    club: club,
                                    visitedStore: visitedStore,
                                    photosStore: photosStore,
                                    notesStore: notesStore,
                                    reviewsStore: reviewsStore,
                                    clubById: clubById
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(club.name)
                                        .font(.headline)
                                    Text("\(club.stadium.name) • \(club.stadium.city) • \(club.division)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                if authSession.snapshot.isAuthenticated {
                    accountAndSyncSection
                }

                // MARK: Feedback
                Section("Feedback") {
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showMailComposer = true
                        } else {
                            mailUnavailableAlert = true
                        }
                    } label: {
                        Label("Send feedback", systemImage: "envelope")
                    }
                    .accessibilityHint("Åbner mail med en feedbackskabelon")

                    Text("Brug gerne feedback til bugs, forslag og manglende data (klubber/stadions/kampe).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Min tur")
            .overlay(alignment: .top) {
                if let newlyUnlockedAchievementMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text(newlyUnlockedAchievementMessage)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    subject: "Tribunetour feedback",
                    recipients: [],
                    body: defaultFeedbackBody()
                )
            }
        .sheet(isPresented: $showAuthSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Log ind eller opret en konto for at gemme dine data og låse flere lande op.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            TextField("din@email.dk", text: $loginEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .submitLabel(.next)
                                .focused($focusedAuthField, equals: .email)
                                .onSubmit {
                                    focusedAuthField = .password
                                }

                            SecureField("Adgangskode", text: $loginPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.password)
                                .submitLabel(.go)
                                .focused($focusedAuthField, equals: .password)
                                .onSubmit {
                                    Task {
                                        await signIn()
                                    }
                                }

                            HStack(spacing: 10) {
                                Button {
                                    Task {
                                        await signIn()
                                    }
                                } label: {
                                    if loginLoading {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        StatsActionButtonLabel(
                                            title: "Log ind",
                                            isActive: true
                                        )
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(loginLoading)

                                Button {
                                    Task {
                                        await signUp()
                                    }
                                } label: {
                                    StatsActionButtonLabel(
                                        title: "Opret konto",
                                        isActive: false
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(loginLoading)
                            }

                            Text("Adgangskoden skal være mindst 8 tegn.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Har du tidligere brugt magic link på web?")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button {
                                    Task {
                                        await sendPasswordReset()
                                    }
                                } label: {
                                    Text("Send link til at sætte eller nulstille adgangskode")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .disabled(loginLoading)
                            }

                            if let loginInfoMessage {
                                Text(loginInfoMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let loginErrorMessage {
                                Text(loginErrorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Log ind")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Luk") {
                                dismissAuthKeyboard()
                                showAuthSheet = false
                            }
                        }
                    }
                }
            }
            .alert("Mail er ikke sat op", isPresented: $mailUnavailableAlert) {
                Button("OK") {}
            } message: {
                Text("Du skal have en mailkonto sat op i Mail-app’en for at sende feedback herfra.")
            }
            .alert("Gem dine nuvaerende besoeg paa kontoen?", isPresented: $showBootstrapAlert, presenting: pendingBootstrapStatus) { status in
                Button("Ikke nu", role: .cancel) {}
                Button("Gem besoeg") {
                    Task {
                        await performBootstrap(using: status)
                    }
                }
            } message: { status in
                Text("Foerste gang du logger ind, kan du gemme dine \(status.localVisitedCount) nuvaerende markeringer paa kontoen som udgangspunkt.")
            }
            .onAppear {
                refreshSnapshot()
                syncSeenUnlockedIds()
            }
            .onChange(of: authSession.snapshot.isAuthenticated) { _, isAuthenticated in
                refreshSnapshot()
                if isAuthenticated {
                    dismissAuthKeyboard()
                    showAuthSheet = false
                    loginEmail = ""
                    loginPassword = ""
                }
            }
            .onChange(of: visitedStore.records) { _, _ in
                refreshSnapshot()
                syncSeenUnlockedIds()
            }
            .onChange(of: reviewsStore.reviewsByClubId) { _, _ in
                refreshSnapshot()
                syncSeenUnlockedIds()
            }
            .onAppear {
                if !snapshot.countryOptions.isEmpty {
                    let resolvedHomeCountry = LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: Set(snapshot.countryOptions))
                    if preferredHomeCountryCode != resolvedHomeCountry {
                        preferredHomeCountryCode = resolvedHomeCountry
                    }
                }
            }
            .onChange(of: preferredHomeCountryCode) { _, newValue in
                guard snapshot.countryOptions.contains(newValue) else { return }
                countryFilterRawValue = newValue
                refreshSnapshot()
                syncSeenUnlockedIds()
            }
            .onChange(of: countryFilterRawValue) { _, _ in
                refreshSnapshot()
            }
        }
        .task(id: authSession.snapshot.isAuthenticated) {
            await refreshPremiumRequestRows()
        }
    }

    private func achievementTrackLabel(_ achievement: Achievement) -> String {
        switch achievement.track {
        case .journey:
            return "Din rejse"
        case .homeCountry:
            return LeaguePresentation.countryLabel(snapshot.activeHomeCountryCode)
        case .countries:
            return "Lande"
        case .international:
            return "Flere lande"
        }
    }

    private func defaultFeedbackBody() -> String {
        let info = appInfoString()
        return """
        Beskriv hvad du oplevede:

        (1) Hvad gjorde du?
        (2) Hvad forventede du?
        (3) Hvad skete der?

        ----
        \(info)
        """
    }

    private func appInfoString() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current.model
        let system = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        return "App version: \(version) (\(build))\nDevice: \(device)\niOS: \(system)"
    }

    private func syncSeenUnlockedIds() {
        let unlocked = snapshot.unlockedAchievementIds
        let seen = seenUnlockedIds
        let newlyUnlocked = unlocked.subtracting(seen)

        if !newlyUnlocked.isEmpty {
            let message: String
            if newlyUnlocked.count == 1,
               let firstNewId = snapshot.achievements.first(where: { newlyUnlocked.contains($0.id) })?.id,
               let title = snapshot.achievements.first(where: { $0.id == firstNewId })?.title {
                message = "Ny achievement låst op: \(title)"
            } else {
                message = "Nye achievements låst op: \(newlyUnlocked.count)"
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                newlyUnlockedAchievementMessage = message
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    newlyUnlockedAchievementMessage = nil
                }
            }
        }

        let merged = seen.union(unlocked).sorted()
        seenUnlockedIdsRaw = merged.joined(separator: ",")
    }

    @MainActor
    private func signIn() async {
        dismissAuthKeyboard()
        loginLoading = true
        loginErrorMessage = nil
        loginInfoMessage = nil
        do {
            let session = try await authClient.signIn(email: loginEmail, password: loginPassword)
            authSession.updateAuthenticatedSession(
                userEmail: session.userEmail,
                bearerToken: session.accessToken,
                refreshToken: session.refreshToken
            )
            dismissAuthKeyboard()
            await refreshBootstrapStatusAfterLogin()
        } catch {
            loginErrorMessage = error.localizedDescription
        }
        loginLoading = false
    }

    @MainActor
    private func signUp() async {
        dismissAuthKeyboard()
        loginLoading = true
        loginErrorMessage = nil
        loginInfoMessage = nil
        do {
            let session = try await authClient.signUp(email: loginEmail, password: loginPassword)
            authSession.updateAuthenticatedSession(
                userEmail: session.userEmail,
                bearerToken: session.accessToken,
                refreshToken: session.refreshToken
            )
            dismissAuthKeyboard()
            await refreshBootstrapStatusAfterLogin(isNewAccount: true)
        } catch {
            loginErrorMessage = error.localizedDescription
        }
        loginLoading = false
    }

    @MainActor
    private func sendPasswordReset() async {
        dismissAuthKeyboard()
        loginLoading = true
        loginErrorMessage = nil
        loginInfoMessage = nil
        do {
            try await authClient.sendPasswordReset(to: loginEmail)
            loginInfoMessage = "Vi har sendt et link, hvor du kan sætte eller nulstille adgangskoden for din eksisterende konto."
        } catch {
            loginErrorMessage = error.localizedDescription
        }
        loginLoading = false
    }

    @MainActor
    private func submitPremiumAccessRequest() async {
        guard !premiumRequestLoading else { return }

        premiumRequestLoading = true
        premiumRequestInfoMessage = nil
        premiumRequestErrorMessage = nil
        defer { premiumRequestLoading = false }

        do {
            let authConfiguration = AppAuthConfiguration.load()
            let backend = SharedPremiumAdminBackend(
                configuration: SharedLeaguePackAccessConfiguration(
                    baseURL: authConfiguration.supabaseURL,
                    apiKey: authConfiguration.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : authConfiguration.supabaseAnonKey,
                    authTokenProvider: authSession.authTokenProvider(using: authClient),
                    urlSession: .shared
                )
            )
            try await backend.submitAccessRequest(
                pack: premiumRequestPack,
                message: premiumRequestMessage,
                submissionURL: authConfiguration.premiumAccessRequestSubmissionURL,
                notificationURL: authConfiguration.premiumAccessRequestNotificationURL
            )
            premiumRequestInfoMessage = "Din anmodning om \(premiumRequestPack.title) er sendt."
            premiumRequestMessage = ""
            premiumRequestRows = try await backend.listCurrentUserAccessRequests()
        } catch {
            premiumRequestErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshPremiumRequestRows() async {
        guard authSession.snapshot.isAuthenticated else {
            premiumRequestRows = []
            premiumRequestRowsLoading = false
            return
        }

        premiumRequestRowsLoading = true
        defer { premiumRequestRowsLoading = false }

        do {
            let authConfiguration = AppAuthConfiguration.load()
            let backend = SharedPremiumAdminBackend(
                configuration: SharedLeaguePackAccessConfiguration(
                    baseURL: authConfiguration.supabaseURL,
                    apiKey: authConfiguration.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : authConfiguration.supabaseAnonKey,
                    authTokenProvider: authSession.authTokenProvider(using: authClient),
                    urlSession: .shared
                )
            )
            premiumRequestRows = try await backend.listCurrentUserAccessRequests()
        } catch {
            premiumRequestRows = []
        }
    }

    @MainActor
    private func refreshBootstrapStatusAfterLogin(isNewAccount: Bool = false) async {
        do {
            let status = try await bootstrapCoordinator.fetchStatus(localRecords: visitedStore.records)
            if status.shouldPromptUser {
                pendingBootstrapStatus = status
                showBootstrapAlert = true
                loginInfoMessage = "Du er logget ind. Bekraeft nu om dine nuvaerende markeringer skal gemmes paa kontoen."
            } else if isNewAccount {
                AppVisitedSyncRuntimeFlags.markBootstrapCompleted(for: authSession.snapshot.userEmail)
                loginInfoMessage = "Konto oprettet og logget ind."
            } else {
                AppVisitedSyncRuntimeFlags.markBootstrapCompleted(for: authSession.snapshot.userEmail)
                loginInfoMessage = "Du er nu logget ind."
            }
        } catch {
            if isNewAccount {
                loginInfoMessage = "Konto oprettet og logget ind."
            } else {
                loginInfoMessage = "Du er nu logget ind."
            }
            loginErrorMessage = bootstrapStatusMessage(for: error)
        }
    }

    @MainActor
    private func performBootstrap(using status: AppVisitedBootstrapStatus) async {
        loginLoading = true
        loginErrorMessage = nil
        loginInfoMessage = nil
        do {
            let response = try await bootstrapCoordinator.performBootstrap(localRecords: visitedStore.records)
            AppVisitedSyncRuntimeFlags.markBootstrapCompleted(for: authSession.snapshot.userEmail)
            pendingBootstrapStatus = nil
            loginInfoMessage = "Dine markeringer er nu gemt paa kontoen. Vi gemte \(response.itemCount ?? status.localVisitedCount) poster. Luk og aabn appen igen, hvis denne enhed ikke opdaterer med det samme."
        } catch {
            loginErrorMessage = bootstrapExecutionMessage(for: error)
        }
        loginLoading = false
    }

    private func bootstrapStatusMessage(for error: Error) -> String {
        switch error {
        case SharedVisitedSyncBackendError.notConfigured:
            return "Du er logget ind, men kontoen er ikke helt klar endnu."
        case SharedVisitedSyncBackendError.missingAuthToken:
            return "Du er logget ind, men vi kunne ikke hente dine markeringer lige nu. Proev at logge ind igen."
        case SharedVisitedSyncBackendError.invalidHTTPStatus:
            return "Du er logget ind, men vi kunne ikke hente din kontostatus lige nu. Proev igen om lidt."
        default:
            return "Du er logget ind, men vi kunne ikke hente din kontostatus lige nu."
        }
    }

    private func bootstrapExecutionMessage(for error: Error) -> String {
        switch error {
        case SharedVisitedSyncBackendError.notConfigured:
            return "Dine markeringer kan ikke gemmes paa kontoen endnu."
        case SharedVisitedSyncBackendError.missingAuthToken:
            return "Vi kunne ikke starte gemningen, fordi din session er udloeber. Proev at logge ind igen."
        case SharedVisitedSyncBackendError.bootstrapAlreadyCompleted:
            return "Din konto har allerede dine markeringer. Luk og aabn appen igen, hvis status ikke vises korrekt endnu."
        case SharedVisitedSyncBackendError.invalidHTTPStatus:
            return "Vi kunne ikke gemme dine markeringer lige nu paa grund af en serverfejl. Proev igen om lidt."
        default:
            return "Vi kunne ikke gemme dine markeringer lige nu. Proev igen om lidt."
        }
    }

    @MainActor
    private func dismissAuthKeyboard() {
        focusedAuthField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        windows.first(where: \.isKeyWindow)?.endEditing(true)

        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            windows.first(where: \.isKeyWindow)?.endEditing(true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            windows.first(where: \.isKeyWindow)?.endEditing(true)
        }
    }
}

private struct StatsHeroMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct StatsContextChip: View {
    let label: String
    let value: Int
    let systemImage: String

    var body: some View {
        Label {
            Text("\(label) \(value)")
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

private struct StatsStatusChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StatsOverviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AchievementRow: View {
    let achievement: StatsView.Achievement

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: achievement.systemImage)
                .foregroundStyle(achievement.isUnlocked ? .yellow : .secondary)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.title)
                        .font(.headline)
                    Spacer()
                    Text(achievement.progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: achievement.isUnlocked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(achievement.isUnlocked ? .green : .secondary)
                .font(.body)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct AccountPromptCard: View {
    let highlights: [String]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opret en konto og behold din fremdrift")
                        .font(.subheadline.weight(.semibold))
                    Text("Så kan du gemme dine data og åbne flere lande.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Senere", action: onDismiss)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(highlights, id: \.self) { highlight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                    Text(highlight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatsActionButtonLabel: View {
    let title: String
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        if isActive {
            return colorScheme == .dark ? Color.white : Color.black
        }

        return Color(.secondarySystemBackground)
    }

    private var foregroundColor: Color {
        if isActive {
            return colorScheme == .dark ? Color.black : Color.white
        }

        return Color.primary
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Mail composer wrapper

private struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let recipients: [String]
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(subject)
        vc.setToRecipients(recipients)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                  didFinishWith result: MFMailComposeResult,
                                  error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
