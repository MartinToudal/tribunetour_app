import Foundation

enum AppWeekendPlanSyncFactory {
    static func makeSharedBackend(authSession: AppAuthSession, authClient: AppAuthClient) -> SharedWeekendPlanSyncBackend {
        let authConfiguration = AppAuthConfiguration.load()
        return SharedWeekendPlanSyncBackend(
            configuration: SharedWeekendPlanSyncConfiguration(
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
}
