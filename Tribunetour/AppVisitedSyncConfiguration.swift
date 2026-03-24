import Foundation

enum AppVisitedSyncMode {
    case cloudKitPrimary
}

struct AppVisitedSyncConfiguration {
    let backend: any VisitedSyncBackend
    let mergePolicy: AppVisitedMergePolicy
    let shouldShowSharedSyncMigrationNoticeOnFirstLogin: Bool
}

enum AppVisitedSyncFactory {
    static func makeConfiguration(mode: AppVisitedSyncMode = .cloudKitPrimary) -> AppVisitedSyncConfiguration {
        switch mode {
        case .cloudKitPrimary:
            return AppVisitedSyncConfiguration(
                backend: CloudVisitedSync.shared,
                mergePolicy: .appPrimaryDuringMigration,
                shouldShowSharedSyncMigrationNoticeOnFirstLogin: true
            )
        }
    }
}
