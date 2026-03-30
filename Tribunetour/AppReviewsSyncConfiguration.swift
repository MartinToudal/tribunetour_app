import Foundation

enum AppReviewsSyncFactory {
    static func makeSharedBackend(authSession: AppAuthSession, authClient: AppAuthClient) -> SharedReviewsSyncBackend {
        let authConfiguration = AppAuthConfiguration.load()
        return SharedReviewsSyncBackend(
            configuration: SharedReviewsSyncConfiguration(
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
