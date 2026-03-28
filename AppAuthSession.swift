import Foundation
import Combine

struct AppSessionSnapshot: Equatable {
    let isAuthenticated: Bool
    let userEmail: String?
    let bearerToken: String?
    let refreshToken: String?
}

@MainActor
final class AppAuthSession: ObservableObject {
    @Published private(set) var snapshot: AppSessionSnapshot
    private let userDefaults: UserDefaults

    private enum Keys {
        static let userEmail = "auth.session.userEmail"
        static let bearerToken = "auth.session.bearerToken"
        static let refreshToken = "auth.session.refreshToken"
    }

    init(
        snapshot: AppSessionSnapshot? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.snapshot = snapshot ?? AppAuthSession.loadSnapshot(userDefaults: userDefaults)
    }

    func updateAuthenticatedSession(userEmail: String?, bearerToken: String?, refreshToken: String?) {
        let nextSnapshot = AppSessionSnapshot(
            isAuthenticated: bearerToken != nil,
            userEmail: userEmail,
            bearerToken: bearerToken,
            refreshToken: refreshToken
        )
        snapshot = nextSnapshot
        persist(snapshot: nextSnapshot)
    }

    func clearSession() {
        let clearedSnapshot = AppSessionSnapshot(
            isAuthenticated: false,
            userEmail: nil,
            bearerToken: nil,
            refreshToken: nil
        )
        snapshot = clearedSnapshot
        persist(snapshot: clearedSnapshot)
    }

    func validBearerToken(using authClient: AppAuthClient) async -> String? {
        let currentToken = snapshot.bearerToken
        let hasExpiredToken = currentToken.map { Self.isJWTExpired($0, leeway: 60) } ?? false

        if let token = currentToken, !hasExpiredToken {
            return token
        }

        guard let refreshToken = snapshot.refreshToken else {
            return hasExpiredToken ? nil : currentToken
        }

        do {
            let refreshedSession = try await authClient.refreshSession(refreshToken: refreshToken)
            updateAuthenticatedSession(
                userEmail: refreshedSession.userEmail ?? snapshot.userEmail,
                bearerToken: refreshedSession.accessToken,
                refreshToken: refreshedSession.refreshToken
            )
            return refreshedSession.accessToken
        } catch {
            return hasExpiredToken ? nil : currentToken
        }
    }

    nonisolated func authTokenProvider(using authClient: AppAuthClient) -> @Sendable () async -> String? {
        { [weak self] in
            guard let self else { return nil }
            return await self.validBearerToken(using: authClient)
        }
    }

    private static func loadSnapshot(userDefaults: UserDefaults) -> AppSessionSnapshot {
        let bearerToken = userDefaults.string(forKey: Keys.bearerToken)
        return AppSessionSnapshot(
            isAuthenticated: bearerToken != nil,
            userEmail: userDefaults.string(forKey: Keys.userEmail),
            bearerToken: bearerToken,
            refreshToken: userDefaults.string(forKey: Keys.refreshToken)
        )
    }

    private func persist(snapshot: AppSessionSnapshot) {
        userDefaults.set(snapshot.userEmail, forKey: Keys.userEmail)
        userDefaults.set(snapshot.bearerToken, forKey: Keys.bearerToken)
        userDefaults.set(snapshot.refreshToken, forKey: Keys.refreshToken)
    }

    private static func isJWTExpired(_ token: String, leeway: TimeInterval) -> Bool {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return false }
        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = payload.count % 4
        if remainder != 0 {
            payload.append(String(repeating: "=", count: 4 - remainder))
        }

        guard
            let data = Data(base64Encoded: payload),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let exp = object["exp"] as? TimeInterval
        else {
            return false
        }

        return Date().addingTimeInterval(leeway).timeIntervalSince1970 >= exp
    }
}
