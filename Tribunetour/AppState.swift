import Foundation
import Combine
import UIKit

@MainActor
final class AppState: ObservableObject {
    @Published var clubs: [Club] = []
    @Published private(set) var clubById: [String: Club] = [:]
    @Published var fixtures: [Fixture] = []
    @Published var loadError: String?
    @Published private(set) var syncRuntimeInfoMessage: String?
    @Published private(set) var fixturesLoadSource: FixturesLoadResult.Source?
    @Published private(set) var fixturesVersion: String?
    @Published private(set) var fixturesRemoteURL: URL?
    @Published private(set) var fixturesFallbackReason: String?
    @Published private(set) var notesSyncIssue: String?
    @Published private(set) var reviewsSyncIssue: String?

    let visitedStore: VisitedStore
    let photosStore: AppPhotosStore
    let notesStore: AppNotesStore
    let reviewsStore: AppReviewsStore
    let weekendPlanStore: AppWeekendPlanStore
    let authSession = AppAuthSession()
    let authClient = AppAuthClient()
    let adminNotificationsManager: AppAdminNotificationsManager
    let visitedSyncMode: AppVisitedSyncMode
    let visitedBootstrapCoordinator: AppVisitedBootstrapCoordinator
    let locationStore = LocationStore()
    private var cancellables = Set<AnyCancellable>()
    private let leaguePackAccessBackend: SharedLeaguePackAccessBackend
    private var previousAuthSnapshot: AppSessionSnapshot
    private var isUITesting: Bool {
        AppTestRuntime.isRunningAutomatedTests
    }

    init() {
        self.adminNotificationsManager = AppAdminNotificationsManager(
            authSession: authSession,
            authClient: authClient
        )
        self.previousAuthSnapshot = authSession.snapshot
        let sharedVisitedBackend = AppVisitedSyncFactory.makeSharedBackend(
            authSession: authSession,
            authClient: authClient
        )
        let resolvedVisitedSyncMode = AppVisitedSyncRuntimeFlags.resolvedMode(
            userEmail: authSession.snapshot.userEmail
        )
        let visitedSyncConfiguration = AppVisitedSyncFactory.makeConfiguration(
            mode: resolvedVisitedSyncMode,
            authSession: authSession,
            authClient: authClient
        )
        self.visitedSyncMode = resolvedVisitedSyncMode
        self.visitedBootstrapCoordinator = AppVisitedBootstrapCoordinator(sharedBackend: sharedVisitedBackend)
        self.visitedStore = VisitedStore(
            syncBackend: visitedSyncConfiguration.backend,
            mergePolicy: visitedSyncConfiguration.mergePolicy,
            shouldAttemptRemoteSync: { [authSession, resolvedVisitedSyncMode] in
                switch resolvedVisitedSyncMode {
                case .cloudKitPrimary:
                    return true
                case .hybridPrepared:
                    return authSession.snapshot.isAuthenticated
                }
            }
        )
        self.photosStore = AppPhotosStore(
            visitedStore: self.visitedStore,
            syncBackend: AppPhotosSyncFactory.makeSharedBackend(authSession: authSession, authClient: authClient),
            authSession: self.authSession
        )
        self.notesStore = AppNotesStore(
            visitedStore: self.visitedStore,
            syncBackend: AppNotesSyncFactory.makeSharedBackend(authSession: authSession, authClient: authClient),
            authSession: self.authSession
        )
        self.reviewsStore = AppReviewsStore(
            visitedStore: self.visitedStore,
            syncBackend: AppReviewsSyncFactory.makeSharedBackend(authSession: authSession, authClient: authClient),
            authSession: self.authSession
        )
        self.weekendPlanStore = AppWeekendPlanStore(
            syncBackend: AppWeekendPlanSyncFactory.makeSharedBackend(authSession: authSession, authClient: authClient),
            authSession: self.authSession
        )
        let authConfiguration = AppAuthConfiguration.load()
        self.leaguePackAccessBackend = SharedLeaguePackAccessBackend(
            configuration: SharedLeaguePackAccessConfiguration(
                baseURL: authConfiguration.supabaseURL,
                apiKey: authConfiguration.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : authConfiguration.supabaseAnonKey,
                authTokenProvider: authSession.authTokenProvider(using: authClient),
                urlSession: .shared
            )
        )

        visitedStore.$records
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshWeekendReminder()
            }
            .store(in: &cancellables)

        notesStore.$lastSyncIssue
            .removeDuplicates()
            .sink { [weak self] issue in
                self?.notesSyncIssue = issue
            }
            .store(in: &cancellables)

        reviewsStore.$lastSyncIssue
            .removeDuplicates()
            .sink { [weak self] issue in
                self?.reviewsSyncIssue = issue
            }
            .store(in: &cancellables)

        authSession.$snapshot
            .removeDuplicates()
            .sink { [weak self] snapshot in
                guard let self else { return }
                let previousSnapshot = self.previousAuthSnapshot
                self.previousAuthSnapshot = snapshot
                if snapshot.isAuthenticated {
                    Task {
                        await self.refreshLeaguePackAccess()
                    }
                    Task {
                        await self.adminNotificationsManager.refreshForCurrentSession()
                    }
                    self.visitedStore.clearSyncIssue()
                    self.notesSyncIssue = nil
                    self.reviewsSyncIssue = nil
                    self.syncRuntimeInfoMessage = nil
                    Task {
                        await self.visitedStore.refreshFromRemote()
                        await self.photosStore.refreshFromRemote()
                        await self.notesStore.refreshFromRemote()
                        await self.reviewsStore.refreshFromRemote()
                        await self.weekendPlanStore.refreshFromRemote()
                        await self.reconcileSharedSyncModeAfterSessionRestore(snapshot: snapshot)
                    }
                } else {
                    Task {
                        await self.adminNotificationsManager.handleSignedOut(previousSnapshot: previousSnapshot)
                    }
                    AppLeaguePackSettings.clearRemoteEnabledLeaguePacks()
                    self.loadData()
                    self.syncRuntimeInfoMessage = nil
                    self.notesSyncIssue = nil
                    self.reviewsSyncIssue = nil
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appDidRegisterRemoteNotificationToken)
            .compactMap { $0.object as? String }
            .sink { [weak self] token in
                guard let self else { return }
                Task {
                    await self.adminNotificationsManager.handleRegisteredDeviceToken(token)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .appDidFailToRegisterRemoteNotifications)
            .compactMap { $0.object as? Error }
            .sink { [weak self] error in
                self?.adminNotificationsManager.handleRegistrationFailure(error)
            }
            .store(in: &cancellables)

        if authSession.snapshot.isAuthenticated {
            Task {
                await reconcileSharedSyncModeAfterSessionRestore(snapshot: authSession.snapshot)
                await adminNotificationsManager.refreshForCurrentSession()
            }
        }

        applyUITestingStateIfNeeded()
    }

    func loadData() {
        Task { // still on MainActor because AppState is @MainActor
            do {
                let enabledLeaguePacks = AppLeaguePackSettings.effectiveEnabledLeaguePacks
                let clubs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Club], Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let result = try CSVClubImporter.loadEnabledClubsFromBundle(
                                csvFileName: "stadiums",
                                enabledLeaguePacks: enabledLeaguePacks
                            )
                            cont.resume(returning: result)
                        } catch {
                            cont.resume(throwing: error)
                        }
                    }
                }

                let fixturesResult = try await RemoteFixturesProvider().loadFixtures()
                let enabledClubLookup = ClubIdentityResolver.aliasMap(
                    from: Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
                )
                let fixtures = fixturesResult.fixtures.filter { fixture in
                    enabledClubLookup[fixture.homeTeamId] != nil &&
                    enabledClubLookup[fixture.awayTeamId] != nil &&
                    enabledClubLookup[fixture.venueClubId] != nil
                }
                dlogFixturesLoad(source: fixturesResult.source, version: fixturesResult.version)

                self.clubs = clubs
                self.clubById = ClubIdentityResolver.aliasMap(
                    from: Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
                )
                self.fixtures = fixtures
                self.applyPreferredHomeCountryIfNeeded(from: clubs)
                self.fixturesLoadSource = fixturesResult.source
                self.fixturesVersion = fixturesResult.version
                self.fixturesRemoteURL = fixturesResult.remoteURL
                self.fixturesFallbackReason = fixturesResult.fallbackReason
                self.loadError = nil
                self.refreshWeekendReminder()
            } catch {
                self.clubById = [:]
                self.fixturesLoadSource = nil
                self.fixturesVersion = nil
                self.fixturesRemoteURL = nil
                self.fixturesFallbackReason = nil
                self.loadError = error.localizedDescription
            }
        }
    }

    func refreshLeaguePackAccess() async {
        guard authSession.snapshot.isAuthenticated else {
            AppLeaguePackSettings.clearRemoteEnabledLeaguePacks()
            return
        }

        do {
            let enabledPacks = try await leaguePackAccessBackend.fetchEnabledLeaguePacks()
            let current = AppLeaguePackSettings.remoteEnabledLeaguePacks
            if current != enabledPacks {
                AppLeaguePackSettings.setRemoteEnabledLeaguePacks(enabledPacks)
                loadData()
            }
        } catch {
            dlog("League pack access kunne ikke hentes: \(error.localizedDescription)")
        }
    }

    func refreshWeekendReminder() {
        guard !isUITesting else { return }
        let visitedVenueClubIds = Set(
            visitedStore.records
                .filter { $0.value.visited }
                .map { $0.key }
        )

        let fixturesSnapshot = fixtures
        let clubByIdSnapshot = clubById
        Task {
            await WeekendOpportunityNotifier.shared.refreshWeekendReminder(
                fixtures: fixturesSnapshot,
                visitedVenueClubIds: visitedVenueClubIds,
                clubById: clubByIdSnapshot
            )
        }
    }

    func refreshSharedVisitedFromRemote() {
        guard authSession.snapshot.isAuthenticated else { return }
        Task {
            await visitedStore.refreshFromRemote()
            await photosStore.refreshFromRemote()
            await notesStore.refreshFromRemote()
            await reviewsStore.refreshFromRemote()
            await weekendPlanStore.refreshFromRemote()
            await reconcileSharedSyncModeAfterSessionRestore(snapshot: authSession.snapshot)
            await adminNotificationsManager.markNeedsRefresh()
        }
    }

    func handleOpenURL(_ url: URL) {
        guard authClient.canHandleCallbackURL(url) else { return }
        do {
            let result = try authClient.parseCallbackURL(url)
            authSession.updateAuthenticatedSession(
                userEmail: result.userEmail,
                bearerToken: result.accessToken,
                refreshToken: result.refreshToken
            )
        } catch {
            dlog("Auth callback kunne ikke behandles: \(error.localizedDescription)")
        }
    }

    private func applyPreferredHomeCountryIfNeeded(from clubs: [Club]) {
        let availableCountryCodes = Set(clubs.map(\.countryCode))
        guard !availableCountryCodes.isEmpty else { return }
        let resolvedHomeCountry = LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: availableCountryCodes)
        UserDefaults.standard.set(resolvedHomeCountry, forKey: "stadiums.countryFilter")
        UserDefaults.standard.set(resolvedHomeCountry, forKey: AppLeaguePackSettings.preferredHomeCountryCodeKey)
    }

    private func reconcileSharedSyncModeAfterSessionRestore(snapshot: AppSessionSnapshot) async {
        guard snapshot.isAuthenticated else {
            syncRuntimeInfoMessage = nil
            return
        }

        do {
            let status = try await visitedBootstrapCoordinator.fetchStatus(localRecords: visitedStore.records)
            if status.bootstrapRequired {
                AppVisitedSyncRuntimeFlags.clearBootstrapCompleted(for: snapshot.userEmail)
                syncRuntimeInfoMessage = nil
                return
            }

            if AppVisitedSyncRuntimeFlags.promoteToSharedModeIfNeeded(
                currentMode: visitedSyncMode,
                userEmail: snapshot.userEmail
            ) {
                syncRuntimeInfoMessage = "Din konto er klar til faelles visited paa tværs af app og web. Luk og aabn appen igen, hvis denne enhed ikke opdaterer med det samme."
            } else {
                syncRuntimeInfoMessage = nil
            }
        } catch {
            dlog("Kunne ikke afstemme shared sync mode ved session-gendannelse: \(error.localizedDescription)")
        }
    }

    private func applyUITestingStateIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--uitesting") else { return }

        UserDefaults.standard.set("Alle", forKey: "stadiums.visitedFilter")
        UserDefaults.standard.set("Liga → klub", forKey: "stadiums.sortOption")
        UserDefaults.standard.set("Uge", forKey: "matches.timeFilter")
        UserDefaults.standard.set(false, forKey: "matches.onlyUnvisitedVenues")
        UserDefaults.standard.set("Dato", forKey: "matches.sortMode")
        UserDefaults.standard.set(false, forKey: "matches.reverseDistanceSort")
        UserDefaults.standard.set(false, forKey: NotificationPreferenceKeys.weekendReminderEnabled)
        UserDefaults.standard.set(false, forKey: NotificationPreferenceKeys.midweekReminderEnabled)
        UserDefaults.standard.set(false, forKey: NotificationPreferenceKeys.nextMissingStadiumReminderEnabled)

        if arguments.contains("--uitesting-enable-germany") {
            AppLeaguePackSettings.setRemoteEnabledLeaguePacks([AppLeaguePackId.germanyTop3.rawValue])
            UserDefaults.standard.set(false, forKey: AppLeaguePackSettings.germanyTop3EnabledKey)
        }

        if arguments.contains("--uitesting-disable-germany") {
            AppLeaguePackSettings.clearRemoteEnabledLeaguePacks()
            UserDefaults.standard.set(false, forKey: AppLeaguePackSettings.germanyTop3EnabledKey)
        }

        if arguments.contains("--uitesting-country-de") {
            UserDefaults.standard.set("de", forKey: "stadiums.countryFilter")
        } else if arguments.contains("--uitesting-country-dk") {
            UserDefaults.standard.set("dk", forKey: "stadiums.countryFilter")
        } else if arguments.contains("--uitesting-country-all") {
            UserDefaults.standard.set("all", forKey: "stadiums.countryFilter")
        }

        if arguments.contains("--uitesting-seed-photo-agf") {
            seedUITestPhotoIfNeeded(clubId: "agf")
        }

        if arguments.contains("--uitesting-reset-review-agf") {
            visitedStore.setReview("agf", nil)
        }

        if arguments.contains("--uitesting-reset-visited-agf") {
            visitedStore.setVisited("agf", false)
            visitedStore.setVisitedDate("agf", nil)
        }
    }

    private func seedUITestPhotoIfNeeded(clubId: String) {
        let fileName = "uitest_\(clubId)_photo.jpg"
        guard !visitedStore.photoFileNames(for: clubId).contains(fileName) else { return }
        guard let imageData = Self.makeUITestPhotoJPEGData() else { return }

        do {
            try visitedStore.applySharedPhoto(
                imageData,
                for: clubId,
                fileName: fileName,
                meta: VisitedStore.Record.PhotoMeta(
                    caption: "",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
                )
            )
        } catch {
            dlog("Kunne ikke seed'e UI test-foto: \(error.localizedDescription)")
        }
    }

    private static func makeUITestPhotoJPEGData() -> Data? {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let title = "TT"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 72),
                .foregroundColor: UIColor.white
            ]
            let titleSize = title.size(withAttributes: attributes)
            let origin = CGPoint(
                x: (size.width - titleSize.width) / 2,
                y: (size.height - titleSize.height) / 2
            )
            title.draw(at: origin, withAttributes: attributes)
        }

        return image.jpegData(compressionQuality: 0.85)
    }
}
