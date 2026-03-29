import Foundation

enum AppNotesSyncFactory {
    static func makeSharedBackend(authSession: AppAuthSession, authClient: AppAuthClient) -> SharedNotesSyncBackend {
        let authConfiguration = AppAuthConfiguration.load()
        return SharedNotesSyncBackend(
            configuration: SharedNotesSyncConfiguration(
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
