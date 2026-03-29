import SwiftUI
import UIKit
import MessageUI

struct StatsView: View {
    let clubs: [Club]
    @ObservedObject var visitedStore: VisitedStore
    @ObservedObject var notesStore: AppNotesStore
    @ObservedObject var reviewsStore: AppReviewsStore
    @ObservedObject var authSession: AppAuthSession
    let authClient: AppAuthClient
    let bootstrapCoordinator: AppVisitedBootstrapCoordinator
    let runtimeSyncInfoMessage: String?
    @AppStorage("achievements.seenUnlockedIds") private var seenUnlockedIdsRaw: String = ""

    private struct Achievement: Identifiable {
        let id: String
        let title: String
        let description: String
        let systemImage: String
        let isUnlocked: Bool
        let progressText: String
    }

    // Superliga skal altid ligge øverst i liga-oversigter
    private func leagueSortKey(_ division: String) -> Int {
        let normalized = division.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalized.contains("superliga") { return 0 }
        return 1
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

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCount)
    }

    private var progressPercentText: String {
        let pct = Int((progress * 100.0).rounded())
        return "\(pct)%"
    }

    private var visitedByDivision: [(division: String, visited: Int, total: Int)] {
        let grouped = Dictionary(grouping: clubs) { $0.division }
        let rows = grouped.map { division, clubsInDivision in
            let v = clubsInDivision.filter { visitedStore.isVisited($0.id) }.count
            return (division: division, visited: v, total: clubsInDivision.count)
        }
        // Sortér: Superliga øverst, derefter mest total, så navn
        return rows.sorted {
            let la = leagueSortKey($0.division)
            let lb = leagueSortKey($1.division)
            if la != lb { return la < lb }

            if $0.total != $1.total { return $0.total > $1.total }
            return $0.division.localizedCaseInsensitiveCompare($1.division) == .orderedAscending
        }
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

    private var achievements: [Achievement] {
        let completeDivisions = visitedByDivision.filter { $0.total > 0 && $0.visited == $0.total }.count
        let halfThreshold = max(1, Int(ceil(Double(totalCount) * 0.5)))

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
                description: "Besøg halvdelen af alle stadions.",
                systemImage: "chart.bar.xaxis",
                isUnlocked: visitedCount >= halfThreshold,
                progressText: "\(min(visitedCount, halfThreshold))/\(halfThreshold)"
            ),
            Achievement(
                id: "league_complete",
                title: "Række-specialist",
                description: "Fuldfør alle stadions i én liga.",
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
                description: "Besøg alle stadions.",
                systemImage: "crown",
                isUnlocked: totalCount > 0 && visitedCount == totalCount,
                progressText: "\(visitedCount)/\(max(1, totalCount))"
            )
        ]
        .sorted { a, b in
            if a.isUnlocked != b.isUnlocked { return a.isUnlocked && !b.isUnlocked }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
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

    var body: some View {
        NavigationStack {
            List {
                // MARK: Overview
                Section("Overblik") {
                    HStack {
                        Text("Besøgte stadions")
                        Spacer()
                        Text("\(visitedCount) / \(totalCount)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Ikke besøgt endnu")
                        Spacer()
                        Text("\(unvisitedCount)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Noter")
                        Spacer()
                        Text("\(notesCount)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Anmeldte stadions")
                        Spacer()
                        Text("\(reviewedCount)")
                            .foregroundStyle(.secondary)
                    }

                    if let averageReviewScoreText {
                        HStack {
                            Text("Gns. anmeldelsesscore")
                            Spacer()
                            Text("\(averageReviewScoreText) / 10")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Stadions med billeder")
                        Spacer()
                        Text("\(stadiumsWithPhotosCount)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Billeder i alt")
                        Spacer()
                        Text("\(totalPhotoCount)")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fremdrift")
                            Spacer()
                            Text(progressPercentText)
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: progress)
                    }
                    .padding(.top, 4)
                }

                Section("Achievements") {
                    HStack {
                        Text("Låst op")
                        Spacer()
                        Text("\(unlockedAchievementsCount)/\(achievements.count)")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(achievements) { achievement in
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

                        Button("Log ud", role: .destructive) {
                            authSession.clearSession()
                            loginInfoMessage = nil
                            loginErrorMessage = nil
                            pendingBootstrapStatus = nil
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

                                TextField("din@email.dk", text: $loginEmail)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                SecureField("Adgangskode", text: $loginPassword)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

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
                                            Text("Log ind")
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(loginLoading)

                                    Button {
                                        Task {
                                            await signUp()
                                        }
                                    } label: {
                                        Text("Opret konto")
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(loginLoading)

                                Text("Supabase URL: \(configuration.redactedSupabaseURL)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text("Adgangskoden skal være mindst 8 tegn.")
                                    .font(.caption2)
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
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Login klargøres")
                                    .font(.headline)
                                Text("Supabase auth er ikke konfigureret i appen endnu. Når URL og anon key er sat i Interne værktøjer, kan du logge ind her.")
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

                // MARK: By division
                Section("Fordelt på liga") {
                    if visitedByDivision.isEmpty {
                        Text("Ingen data.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visitedByDivision, id: \.division) { row in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(row.division)
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
            .onChange(of: visitedStore.records) { _, _ in
                syncSeenUnlockedIds()
            }
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
            await refreshBootstrapStatusAfterLogin()
        } catch {
            loginErrorMessage = error.localizedDescription
        }
        loginLoading = false
    }

    @MainActor
    private func signUp() async {
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
            await refreshBootstrapStatusAfterLogin(isNewAccount: true)
        } catch {
            loginErrorMessage = error.localizedDescription
        }
        loginLoading = false
    }

    @MainActor
    private func sendPasswordReset() async {
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
