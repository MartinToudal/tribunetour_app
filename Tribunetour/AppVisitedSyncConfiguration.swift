import Foundation

enum AppVisitedSyncMode: String, CaseIterable, Identifiable {
    case cloudKitPrimary
    case hybridPrepared

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cloudKitPrimary:
            return "CloudKit (legacy)"
        case .hybridPrepared:
            return "Faelles visited"
        }
    }
}

struct AppVisitedSyncConfiguration {
    let backend: any VisitedSyncBackend
    let mergePolicy: AppVisitedMergePolicy
}

enum AppVisitedSyncFactory {
    static func makeSharedBackend(authSession: AppAuthSession, authClient: AppAuthClient) -> SharedVisitedSyncBackend {
        let authConfiguration = AppAuthConfiguration.load()
        return SharedVisitedSyncBackend(
            configuration: SharedVisitedSyncConfiguration(
                baseURL: authConfiguration.supabaseURL,
                apiKey: authConfiguration.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : authConfiguration.supabaseAnonKey,
                source: "ios",
                authTokenProvider: authSession.authTokenProvider(using: authClient),
                urlSession: .shared
            )
        )
    }

    static func makeConfiguration(
        mode: AppVisitedSyncMode = .cloudKitPrimary,
        authSession: AppAuthSession,
        authClient: AppAuthClient
    ) -> AppVisitedSyncConfiguration {
        switch mode {
        case .cloudKitPrimary:
            return AppVisitedSyncConfiguration(
                backend: CloudVisitedSync.shared,
                mergePolicy: .appPrimaryDuringMigration
            )
        case .hybridPrepared:
            return AppVisitedSyncConfiguration(
                backend: HybridVisitedSyncBackend(
                    configuration: HybridVisitedSyncConfiguration(
                        primaryBackend: makeSharedBackend(authSession: authSession, authClient: authClient),
                        secondaryBackend: CloudVisitedSync.shared,
                        mergePolicy: .sharedPrimarySteadyState,
                        mirrorWritesToSecondary: true
                    )
                ),
                mergePolicy: .sharedPrimarySteadyState
            )
        }
    }
}
