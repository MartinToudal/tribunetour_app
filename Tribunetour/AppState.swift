import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var clubs: [Club] = []
    @Published private(set) var clubById: [String: Club] = [:]
    @Published var fixtures: [Fixture] = []
    @Published var loadError: String?

    let visitedStore: VisitedStore
    let locationStore = LocationStore()
    private var cancellables = Set<AnyCancellable>()

    init() {
        let visitedSyncConfiguration = AppVisitedSyncFactory.makeConfiguration()
        self.visitedStore = VisitedStore(
            syncBackend: visitedSyncConfiguration.backend,
            mergePolicy: visitedSyncConfiguration.mergePolicy
        )

        visitedStore.$records
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshWeekendReminder()
            }
            .store(in: &cancellables)
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
                self.loadError = nil
                self.refreshWeekendReminder()
            } catch {
                self.clubById = [:]
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
}
