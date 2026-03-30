import Foundation
import Combine

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
    let authSession = AppAuthSession()
    let authClient = AppAuthClient()
    let visitedSyncMode: AppVisitedSyncMode
    let visitedBootstrapCoordinator: AppVisitedBootstrapCoordinator
    let locationStore = LocationStore()
    private var cancellables = Set<AnyCancellable>()

    init() {
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
            mergePolicy: visitedSyncConfiguration.mergePolicy
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
                if snapshot.isAuthenticated {
                    Task {
                        await self.visitedStore.refreshFromRemote()
                        await self.photosStore.refreshFromRemote()
                        await self.notesStore.refreshFromRemote()
                        await self.reviewsStore.refreshFromRemote()
                        await self.reconcileSharedSyncModeAfterSessionRestore(snapshot: snapshot)
                    }
                } else {
                    self.syncRuntimeInfoMessage = nil
                    self.notesSyncIssue = nil
                    self.reviewsSyncIssue = nil
                }
            }
            .store(in: &cancellables)

        if authSession.snapshot.isAuthenticated {
            Task {
                await reconcileSharedSyncModeAfterSessionRestore(snapshot: authSession.snapshot)
            }
        }
    }

    func loadData() {
        Task { // still on MainActor because AppState is @MainActor
            do {
                let clubs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Club], Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let result = try CSVClubImporter.loadClubsFromBundle(csvFileName: "stadiums")
                            cont.resume(returning: result)
                        } catch {
                            cont.resume(throwing: error)
                        }
                    }
                }

                let fixturesResult = try await RemoteFixturesProvider().loadFixtures()
                let fixtures = fixturesResult.fixtures
                dlogFixturesLoad(source: fixturesResult.source, version: fixturesResult.version)

                self.clubs = clubs
                self.clubById = Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
                self.fixtures = fixtures
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

    func refreshWeekendReminder() {
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
            await reconcileSharedSyncModeAfterSessionRestore(snapshot: authSession.snapshot)
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
}
