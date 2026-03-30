import Foundation

enum AppPhotosSyncFactory {
    static func makeSharedBackend(authSession: AppAuthSession, authClient: AppAuthClient) -> SharedPhotosSyncBackend {
        let authConfiguration = AppAuthConfiguration.load()
        return SharedPhotosSyncBackend(
            configuration: SharedPhotosSyncConfiguration(
                baseURL: authConfiguration.supabaseURL,
                apiKey: authConfiguration.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : authConfiguration.supabaseAnonKey,
                source: "ios",
                bucketName: "stadium-photos",
                authTokenProvider: authSession.authTokenProvider(using: authClient),
                urlSession: .shared
            )
        )
    }
}
