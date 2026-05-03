import SwiftUI
import UIKit
import MessageUI

struct StatsView: View {
    private enum AuthField: Hashable {
        case email
        case password
    }

    let clubs: [Club]
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

    struct Achievement: Identifiable {
        let id: String
        let title: String
        let description: String
        let systemImage: String
        let isUnlocked: Bool
        let progressText: String
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
    @FocusState private var focusedAuthField: AuthField?

    // MARK: - Derived stats

    private var visitedClubs: [Club] {
        clubs.filter { visitedStore.isVisited($0.id) }
    }

    private var unvisitedClubs: [Club] {
        clubs.filter { !visitedStore.isVisited($0.id) }
    }

    private var visitedCount: Int { visitedClubs.count }
    private var totalCount: Int { clubs.count }
    private var unvisitedCount: Int { unvisitedClubs.count }
    private var coreClubs: [Club] { clubs.filter { $0.leaguePack == AppLeaguePackId.coreDenmark.rawValue } }
    private var premiumClubs: [Club] { clubs.filter { $0.leaguePack != AppLeaguePackId.coreDenmark.rawValue } }
    private var coreVisitedCount: Int { coreClubs.filter { visitedStore.isVisited($0.id) }.count }
    private var coreTotalCount: Int { coreClubs.count }
    private var premiumVisitedCount: Int { premiumClubs.filter { visitedStore.isVisited($0.id) }.count }
    private var premiumTotalCount: Int { premiumClubs.count }
    private var hasPremiumCountries: Bool { !premiumClubs.isEmpty }
    private var shouldShowAccountPrompt: Bool {
        guard !authSession.snapshot.isAuthenticated, !accountPromptDismissed else { return false }
        return visitedCount >= 3 || notesCount > 0 || reviewedCount > 0 || totalPhotoCount > 0 || hasPremiumCountries
    }

    private var accountPromptHighlights: [String] {
        var highlights: [String] = []
        if visitedCount > 0 {
            highlights.append("Synk dine \(visitedCount) markerede stadionbesøg mellem app og web")
        }
        if notesCount > 0 || totalPhotoCount > 0 || reviewedCount > 0 {
            highlights.append("Gem noter, anmeldelser og billeder sikkert på din konto")
        }
        if hasPremiumCountries {
            highlights.append("Få adgang til premium-funktioner og ligaer i andre lande")
        }
        if highlights.isEmpty {
            highlights.append("Synk dine data mellem app og web")
            highlights.append("Få adgang til premium-funktioner og flere ligaer")
        }
        return Array(highlights.prefix(3))
    }
    private var openPremiumRequestRows: [PremiumAccessRequestUserRow] { premiumRequestRows.filter(\.isOpen) }
    private var selectedPackOpenRequest: PremiumAccessRequestUserRow? {
        openPremiumRequestRows.first(where: { $0.packKey == premiumRequestPack.rawValue })
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
        Array(Set(clubs.map(\.countryCode))).sorted { left, right in
            if LeaguePresentation.countryRank(left) != LeaguePresentation.countryRank(right) {
                return LeaguePresentation.countryRank(left) < LeaguePresentation.countryRank(right)
            }
            return LeaguePresentation.countryLabel(left).localizedCaseInsensitiveCompare(LeaguePresentation.countryLabel(right)) == .orderedAscending
        }
    }

    private func divisionRows(from clubs: [Club]) -> [DivisionProgressRow] {
        let grouped = Dictionary(grouping: clubs) { DivisionKey(countryCode: $0.countryCode, division: $0.division) }
        let rows = grouped.map { division, clubsInDivision in
            let v = clubsInDivision.filter { visitedStore.isVisited($0.id) }.count
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

    private var visitedByDivision: [DivisionProgressRow] {
        divisionRows(from: clubs)
    }

    private var coreVisitedByDivision: [DivisionProgressRow] {
        divisionRows(from: coreClubs)
    }

    private var activeHomeCountryCode: String {
        LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: Set(clubs.map(\.countryCode)))
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

    private var coreAchievements: [Achievement] {
        let completeDivisions = coreVisitedByDivision.filter { $0.total > 0 && $0.visited == $0.total }.count
        let halfThreshold = max(1, Int(ceil(Double(max(coreTotalCount, 1)) * 0.5)))

        return [
            Achievement(
                id: "first_visit",
                title: "Første skridt",
                description: "Besøg dit første stadion.",
                systemImage: "figure.walk",
                isUnlocked: visitedCount >= 1,
                progressText: "\(min(visitedCount, 1))/1"
            ),
            Achievement(
                id: "five_stadiums",
                title: "Groundhopper I",
                description: "Besøg 5 stadions.",
                systemImage: "map",
                isUnlocked: visitedCount >= 5,
                progressText: "\(min(visitedCount, 5))/5"
            ),
            Achievement(
                id: "twelve_stadiums",
                title: "Groundhopper II",
                description: "Besøg 12 stadions.",
                systemImage: "map.fill",
                isUnlocked: visitedCount >= 12,
                progressText: "\(min(visitedCount, 12))/12"
            ),
            Achievement(
                id: "halfway",
                title: "Halvvejs",
                description: "Besøg halvdelen af de danske stadions i grundpakken.",
                systemImage: "chart.bar.xaxis",
                isUnlocked: coreVisitedCount >= halfThreshold,
                progressText: "\(min(coreVisitedCount, halfThreshold))/\(halfThreshold)"
            ),
            Achievement(
                id: "league_complete",
                title: "Række-specialist",
                description: "Fuldfør alle stadions i én dansk række.",
                systemImage: "trophy",
                isUnlocked: completeDivisions >= 1,
                progressText: "\(completeDivisions)/1"
            ),
            Achievement(
                id: "first_review",
                title: "Anmelder",
                description: "Lav din første stadion-anmeldelse.",
                systemImage: "text.bubble",
                isUnlocked: reviewedCount >= 1,
                progressText: "\(min(reviewedCount, 1))/1"
            ),
            Achievement(
                id: "reviewer_level_2",
                title: "Anmelder II",
                description: "Lav anmeldelser af 5 stadions.",
                systemImage: "text.bubble.fill",
                isUnlocked: reviewedCount >= 5,
                progressText: "\(min(reviewedCount, 5))/5"
            ),
            Achievement(
                id: "note_writer",
                title: "Noteskriver",
                description: "Skriv noter på 5 stadions.",
                systemImage: "note.text",
                isUnlocked: notesCount >= 5,
                progressText: "\(min(notesCount, 5))/5"
            ),
            Achievement(
                id: "first_photo",
                title: "Fotograf",
                description: "Tilføj dit første stadionbillede.",
                systemImage: "camera",
                isUnlocked: totalPhotoCount >= 1,
                progressText: "\(min(totalPhotoCount, 1))/1"
            ),
            Achievement(
                id: "photo_collector",
                title: "Fotojæger",
                description: "Tilføj 10 stadionbilleder i alt.",
                systemImage: "camera.fill",
                isUnlocked: totalPhotoCount >= 10,
                progressText: "\(min(totalPhotoCount, 10))/10"
            ),
            Achievement(
                id: "gallery_builder",
                title: "Galleri-bygger",
                description: "Tilføj billeder på 3 forskellige stadions.",
                systemImage: "photo.on.rectangle",
                isUnlocked: stadiumsWithPhotosCount >= 3,
                progressText: "\(min(stadiumsWithPhotosCount, 3))/3"
            ),
            Achievement(
                id: "city_hopper",
                title: "Byhopper",
                description: "Besøg stadions i 5 forskellige byer.",
                systemImage: "building.2",
                isUnlocked: visitedCitiesCount >= 5,
                progressText: "\(min(visitedCitiesCount, 5))/5"
            ),
            Achievement(
                id: "league_explorer",
                title: "Række-rejsende",
                description: "Besøg stadions i 3 forskellige ligaer.",
                systemImage: "point.3.connected.trianglepath.dotted",
                isUnlocked: visitedDivisionsCount >= 3,
                progressText: "\(min(visitedDivisionsCount, 3))/3"
            ),
            Achievement(
                id: "all_stadiums",
                title: "Tribune Tour Master",
                description: "Besøg alle stadions i grundpakken for Danmark.",
                systemImage: "crown",
                isUnlocked: coreTotalCount > 0 && coreVisitedCount == coreTotalCount,
                progressText: "\(coreVisitedCount)/\(max(1, coreTotalCount))"
            )
        ]
        .sorted { a, b in
            if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    private var premiumAchievements: [Achievement] {
        guard hasPremiumCountries else { return [] }

        let premiumVisitedByDivision = divisionRows(from: premiumClubs)
        let completePremiumDivisions = premiumVisitedByDivision.filter { $0.total > 0 && $0.visited == $0.total }.count
        let crossBorderTarget = min(Set(clubs.map(\.countryCode)).count, 2)

        return [
            Achievement(
                id: "premium_first_visit",
                title: "Udebanestart",
                description: "Besøg dit første premium-stadion.",
                systemImage: "airplane.departure",
                isUnlocked: premiumVisitedCount >= 1,
                progressText: "\(min(premiumVisitedCount, 1))/1"
            ),
            Achievement(
                id: "premium_explorer",
                title: "International groundhopper",
                description: "Besøg 5 premium-stadions.",
                systemImage: "globe.europe.africa",
                isUnlocked: premiumVisitedCount >= 5,
                progressText: "\(min(premiumVisitedCount, 5))/5"
            ),
            Achievement(
                id: "cross_border",
                title: "På tværs af grænser",
                description: "Besøg stadions i mindst 2 aktive lande.",
                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                isUnlocked: crossBorderTarget <= 1 || Set(visitedClubs.map(\.countryCode)).count >= crossBorderTarget,
                progressText: "\(min(Set(visitedClubs.map(\.countryCode)).count, crossBorderTarget))/\(crossBorderTarget)"
            ),
            Achievement(
                id: "premium_league_complete",
                title: "Premium-specialist",
                description: "Fuldfør alle stadions i én premium-række.",
                systemImage: "flag.pattern.checkered",
                isUnlocked: completePremiumDivisions >= 1,
                progressText: "\(completePremiumDivisions)/1"
            )
        ]
        .sorted { a, b in
            if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    private var achievements: [Achievement] {
        coreAchievements + premiumAchievements
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
        Section("Konto og sync") {
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
                    Text("Premium-adgang")
                        .font(.headline)
                    Text("Anmod om adgang til ligaer i andre lande. Vi behandler anmodningen manuelt og åbner for pakken på din konto.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if premiumRequestRowsLoading {
                        Text("Henter dine premium-anmodninger...")
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

                    Picker("Pakke", selection: $premiumRequestPack) {
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
                            title: premiumRequestLoading ? "Sender..." : selectedPackOpenRequest == nil ? "Anmod om premium-adgang" : "Anmodning allerede sendt",
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
                        Text("Brug samme konto som på web. I appen logger vi nu ind direkte med e-mail og adgangskode.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if shouldShowAccountPrompt {
                            AccountPromptCard(
                                highlights: accountPromptHighlights,
                                onDismiss: { accountPromptDismissed = true }
                            )
                        }

                        Button {
                            showAuthSheet = true
                        } label: {
                            StatsActionButtonLabel(
                                title: "Log ind eller opret konto",
                                isActive: true
                            )
                        }
                        .buttonStyle(.plain)

                        Text("Supabase URL: \(configuration.redactedSupabaseURL)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

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
                        Text("Login klargøres")
                            .font(.headline)
                        Text("Appen mangler stadig sin standard auth-konfiguration. Når Supabase URL og publishable key er indbygget i appen, kan du logge ind her uden Interne værktøjer.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let validationMessage = configuration.supabaseURLValidationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if !configuration.hasAnonKey {
                            Text("Supabase anon/publishable key mangler.")
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
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Byg din stadionrejse")
                                .font(.headline)
                            Text(heroSummaryText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            StatsHeroMetric(title: "Besøgte", value: "\(visitedCount)")
                            StatsHeroMetric(title: "Mangler", value: "\(unvisitedCount)")
                            StatsHeroMetric(title: "Fremdrift", value: progressPercentText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Fremdrift")
                                Spacer()
                                Text("\(visitedCount) / \(totalCount)")
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: progress)
                                .tint(.green)
                        }

                        HStack(spacing: 8) {
                            StatsContextChip(label: "Noter", value: notesCount, systemImage: "note.text")
                            StatsContextChip(label: "Anmeldelser", value: reviewedCount, systemImage: "star.bubble")
                            StatsContextChip(label: "Billeder", value: totalPhotoCount, systemImage: "camera")
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Næste milepæl") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(nextMilestoneTitle)
                            .font(.headline)
                        Text(nextMilestoneDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if let suggestedNextClub {
                    Section("Næste oplagte stadion") {
                        NavigationLink {
                            StadiumDetailView(
                                club: suggestedNextClub,
                                visitedStore: visitedStore,
                                photosStore: photosStore,
                                notesStore: notesStore,
                                reviewsStore: reviewsStore,
                                clubById: Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(suggestedNextClub.name)
                                    .font(.headline)
                                Text("\(suggestedNextClub.stadium.name) • \(suggestedNextClub.stadium.city)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(suggestionDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Overblik") {
                    StatsOverviewRow(label: "Besøgte stadions", value: "\(visitedCount) / \(totalCount)")
                    StatsOverviewRow(label: "Ikke besøgt endnu", value: "\(unvisitedCount)")
                    StatsOverviewRow(label: "Noter", value: "\(notesCount)")
                    StatsOverviewRow(label: "Anmeldte stadions", value: "\(reviewedCount)")

                    if let averageReviewScoreText {
                        StatsOverviewRow(label: "Gns. anmeldelsesscore", value: "\(averageReviewScoreText) / 10")
                    }

                    StatsOverviewRow(label: "Stadions med billeder", value: "\(stadiumsWithPhotosCount)")
                    StatsOverviewRow(label: "Billeder i alt", value: "\(totalPhotoCount)")
                }

                Section("Hjemland og scope") {
                    Picker("Hjemland", selection: $preferredHomeCountryCode) {
                        ForEach(countryOptions, id: \.self) { countryCode in
                            Text(LeaguePresentation.countryLabel(countryCode)).tag(countryCode)
                        }
                    }

                    HStack {
                        Text("Aktivt scope")
                        Spacer()
                        Text(currentScopeLabel)
                            .foregroundStyle(.secondary)
                    }

                    Text("Når appen åbner, vælger vi automatisk dit hjemland som aktivt scope.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Grundachievements") {
                    HStack {
                        Text("Låst op")
                        Spacer()
                        Text("\(coreAchievements.filter(\.isUnlocked).count)/\(coreAchievements.count)")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(coreAchievements) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }

                if !premiumAchievements.isEmpty {
                    Section("Premium achievements") {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ekstra mål for aktive premium-lande")
                                    .font(.headline)
                                Text("Grundachievements kan stadig fuldføres uanset om du har flere lande aktive. De ekstra achievements her bliver synlige, når du har premium-indhold i dit scope.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(premiumAchievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }

                // MARK: By division
                Section("Fordelt på liga") {
                    if visitedByDivision.isEmpty {
                        Text("Ingen data.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visitedByDivision) { row in
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

                // MARK: Recent visits
                Section("Seneste besøg") {
                    if recentVisited.isEmpty {
                        ContentUnavailableView(
                            "Ingen besøg endnu",
                            systemImage: "checkmark.circle",
                            description: Text("Dine seneste besøg vises her, når du markerer stadions som besøgt.")
                        )
                        .padding(.vertical, 8)
                    } else {
                        ForEach(recentVisited.prefix(10), id: \.club.id) { item in
                            NavigationLink {
                                StadiumDetailView(
                                    club: item.club,
                                    visitedStore: visitedStore,
                                    photosStore: photosStore,
                                    notesStore: notesStore,
                                    reviewsStore: reviewsStore,
                                    clubById: Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
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

                // MARK: Visited list
                Section("Mine besøgte") {
                    if visitedClubs.isEmpty {
                        ContentUnavailableView(
                            "Ingen besøgte stadions",
                            systemImage: "mappin.slash",
                            description: Text("Markér et stadion som besøgt for at se det her.")
                        )
                        .padding(.vertical, 8)
                    } else {
                        ForEach(visitedClubs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { club in
                            NavigationLink {
                                StadiumDetailView(
                                    club: club,
                                    visitedStore: visitedStore,
                                    photosStore: photosStore,
                                    notesStore: notesStore,
                                    reviewsStore: reviewsStore,
                                    clubById: Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
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

                accountAndSyncSection

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
                            Text("Brug samme konto som på web. Du kan logge ind, oprette en konto eller sende dig selv et link til at sætte eller nulstille adgangskoden.")
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
            .alert("Brug appens nuvaerende besoeg som udgangspunkt?", isPresented: $showBootstrapAlert, presenting: pendingBootstrapStatus) { status in
                Button("Ikke nu", role: .cancel) {}
                Button("Brug appens data") {
                    Task {
                        await performBootstrap(using: status)
                    }
                }
            } message: { status in
                Text("Foerste gang du logger ind, bruger vi dine \(status.localVisitedCount) registreringer i appen til at oprette din samlede visited-status. Hvis du allerede har markeret noget paa web, bliver appens nuvaerende registreringer brugt som udgangspunkt.")
            }
            .onAppear {
                syncSeenUnlockedIds()
            }
            .onChange(of: authSession.snapshot.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    dismissAuthKeyboard()
                    showAuthSheet = false
                    loginEmail = ""
                    loginPassword = ""
                }
            }
            .onChange(of: visitedStore.records) { _, _ in
                syncSeenUnlockedIds()
            }
            .onAppear {
                if !countryOptions.isEmpty {
                    let resolvedHomeCountry = LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: Set(countryOptions))
                    if preferredHomeCountryCode != resolvedHomeCountry {
                        preferredHomeCountryCode = resolvedHomeCountry
                    }
                }
            }
            .onChange(of: preferredHomeCountryCode) { _, newValue in
                guard countryOptions.contains(newValue) else { return }
                countryFilterRawValue = newValue
            }
        }
        .task(id: authSession.snapshot.isAuthenticated) {
            await refreshPremiumRequestRows()
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
        let unlocked = unlockedAchievementIds
        let seen = seenUnlockedIds
        let newlyUnlocked = unlocked.subtracting(seen)

        if !newlyUnlocked.isEmpty {
            let message: String
            if newlyUnlocked.count == 1,
               let firstNewId = achievements.first(where: { newlyUnlocked.contains($0.id) })?.id,
               let title = achievements.first(where: { $0.id == firstNewId })?.title {
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
                loginInfoMessage = "Du er logget ind. Bekraeft nu om appens nuvaerende registreringer skal oprette din samlede visited-status."
            } else if isNewAccount {
                AppVisitedSyncRuntimeFlags.markBootstrapCompleted(for: authSession.snapshot.userEmail)
                loginInfoMessage = "Konto oprettet og logget ind."
            } else {
                AppVisitedSyncRuntimeFlags.markBootstrapCompleted(for: authSession.snapshot.userEmail)
                loginInfoMessage = "Du er nu logget ind, og din konto bruger samme visited-status paa tværs af app og web."
            }
        } catch {
            if isNewAccount {
                loginInfoMessage = "Konto oprettet og logget ind."
            } else {
                loginInfoMessage = "Du er nu logget ind i appen."
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
            loginInfoMessage = "Din samlede visited-status er nu oprettet ud fra appens registreringer. Vi gemte \(response.itemCount ?? status.localVisitedCount) poster. Luk og aabn appen igen, hvis denne enhed ikke opdaterer med det samme."
        } catch {
            loginErrorMessage = bootstrapExecutionMessage(for: error)
        }
        loginLoading = false
    }

    private func bootstrapStatusMessage(for error: Error) -> String {
        switch error {
        case SharedVisitedSyncBackendError.notConfigured:
            return "Du er logget ind, men delt visited-sync er ikke sat helt op endnu."
        case SharedVisitedSyncBackendError.missingAuthToken:
            return "Du er logget ind, men appen mangler en gyldig session til at hente din visited-status. Proev at logge ind igen."
        case SharedVisitedSyncBackendError.invalidHTTPStatus:
            return "Du er logget ind, men vi kunne ikke hente status for din faelles visited-model lige nu. Proev igen om lidt."
        default:
            return "Du er logget ind, men vi kunne ikke hente status for din faelles visited-model lige nu."
        }
    }

    private func bootstrapExecutionMessage(for error: Error) -> String {
        switch error {
        case SharedVisitedSyncBackendError.notConfigured:
            return "Bootstrap kan ikke gennemfoeres endnu, fordi delt visited-sync ikke er sat helt op."
        case SharedVisitedSyncBackendError.missingAuthToken:
            return "Bootstrap kunne ikke starte, fordi appen mangler en gyldig session. Proev at logge ind igen."
        case SharedVisitedSyncBackendError.bootstrapAlreadyCompleted:
            return "Din konto har allerede en samlet visited-status. Luk og aabn appen igen, hvis status ikke vises korrekt endnu."
        case SharedVisitedSyncBackendError.invalidHTTPStatus:
            return "Bootstrap kunne ikke gennemfoeres lige nu paa grund af en serverfejl. Proev igen om lidt."
        default:
            return "Bootstrap kunne ikke gennemfoeres lige nu. Proev igen om lidt."
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
                    Text("Det gør det lettere at få adgang til premium og fortsætte på tværs af app og web.")
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
