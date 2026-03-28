import Foundation

struct AppVisitedBootstrapStatus: Equatable {
    let bootstrapRequired: Bool
    let bootstrappedAt: Date?
    let bootstrapSource: String?
    let localVisitedCount: Int

    var shouldPromptUser: Bool {
        bootstrapRequired
    }
}

@MainActor
final class AppVisitedBootstrapCoordinator {
    private let sharedBackend: SharedVisitedSyncBackend

    init(sharedBackend: SharedVisitedSyncBackend) {
        self.sharedBackend = sharedBackend
    }

    func fetchStatus(localRecords: [String: VisitedStore.Record]) async throws -> AppVisitedBootstrapStatus {
        let state = try await sharedBackend.fetchMigrationState()
        return AppVisitedBootstrapStatus(
            bootstrapRequired: state.bootstrapRequired,
            bootstrappedAt: state.bootstrappedAt,
            bootstrapSource: state.bootstrapSource,
            localVisitedCount: localRecords.values.filter(\.visited).count
        )
    }

    func performBootstrap(localRecords: [String: VisitedStore.Record]) async throws -> SharedVisitedBootstrapResponseDTO {
        try await sharedBackend.bootstrap(records: localRecords)
    }
}
