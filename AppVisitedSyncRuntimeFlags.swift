import Foundation

enum AppVisitedSyncRuntimeFlags {
    static let visitedSyncModeKey = "visited.sync.mode"
    private static let bootstrapCompletedKeyPrefix = "visited.sync.bootstrapCompleted"
    private static let legacySharedPreparedRawValue = "sharedPrepared"

    static func resolvedMode(
        default defaultMode: AppVisitedSyncMode = .cloudKitPrimary,
        userEmail: String? = nil
    ) -> AppVisitedSyncMode {
        guard let rawValue = UserDefaults.standard.string(forKey: visitedSyncModeKey) else {
            if isBootstrapCompleted(for: userEmail) {
                return .hybridPrepared
            }
            return defaultMode
        }

        if rawValue == legacySharedPreparedRawValue {
            return .hybridPrepared
        }

        return AppVisitedSyncMode(rawValue: rawValue) ?? defaultMode
    }

    static func store(mode: AppVisitedSyncMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: visitedSyncModeKey)
    }

    static func hasStoredMode() -> Bool {
        UserDefaults.standard.string(forKey: visitedSyncModeKey) != nil
    }

    static func shouldPromoteToSharedMode(
        currentMode: AppVisitedSyncMode,
        userEmail: String?
    ) -> Bool {
        !hasStoredMode() && currentMode == .cloudKitPrimary && isBootstrapCompleted(for: userEmail)
    }

    static func promoteToSharedModeIfNeeded(
        currentMode: AppVisitedSyncMode,
        userEmail: String?
    ) -> Bool {
        markBootstrapCompleted(for: userEmail)
        guard shouldPromoteToSharedMode(currentMode: currentMode, userEmail: userEmail) else {
            return false
        }
        store(mode: .hybridPrepared)
        return true
    }

    static func markBootstrapCompleted(for userEmail: String?) {
        guard let key = bootstrapCompletedKey(for: userEmail) else { return }
        UserDefaults.standard.set(true, forKey: key)
    }

    static func clearBootstrapCompleted(for userEmail: String?) {
        guard let key = bootstrapCompletedKey(for: userEmail) else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func isBootstrapCompleted(for userEmail: String?) -> Bool {
        guard let key = bootstrapCompletedKey(for: userEmail) else { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func bootstrapCompletedKey(for userEmail: String?) -> String? {
        guard let userEmail else { return nil }
        let normalized = userEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }
        return "\(bootstrapCompletedKeyPrefix).\(normalized)"
    }
}
