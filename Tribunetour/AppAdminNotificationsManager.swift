import Foundation
import Combine
import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let appDidRegisterRemoteNotificationToken = Notification.Name("AppDidRegisterRemoteNotificationToken")
    static let appDidFailToRegisterRemoteNotifications = Notification.Name("AppDidFailToRegisterRemoteNotifications")
}

final class AppNotificationAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .appDidRegisterRemoteNotificationToken, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .appDidFailToRegisterRemoteNotifications, object: error)
    }
}

@MainActor
final class AppAdminNotificationsManager: ObservableObject {
    @Published private(set) var isCurrentUserAdmin: Bool = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var badgeCount: Int = 0
    @Published private(set) var lastRegistrationErrorMessage: String?

    private let authSession: AppAuthSession
    private let authClient: AppAuthClient
    private let userDefaults: UserDefaults

    private enum Keys {
        static let lastDeviceToken = "admin.notifications.lastDeviceToken"
    }

    init(
        authSession: AppAuthSession,
        authClient: AppAuthClient,
        userDefaults: UserDefaults = .standard
    ) {
        self.authSession = authSession
        self.authClient = authClient
        self.userDefaults = userDefaults
    }

    func handleRegisteredDeviceToken(_ token: String) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return }

        userDefaults.set(trimmedToken, forKey: Keys.lastDeviceToken)

        guard authSession.snapshot.isAuthenticated else { return }

        do {
            let backend = makeBackend()
            let isAdmin = try await backend.isCurrentUserAdmin()
            self.isCurrentUserAdmin = isAdmin
            if isAdmin {
                _ = try await backend.upsertAdminDeviceToken(
                    deviceToken: trimmedToken,
                    platform: "ios",
                    appBuild: Self.appBuildDescription
                )
                await refreshBadgeCount()
            }
        } catch {
            lastRegistrationErrorMessage = error.localizedDescription
        }
    }

    func handleRegistrationFailure(_ error: Error) {
        lastRegistrationErrorMessage = error.localizedDescription
    }

    func refreshForCurrentSession() async {
        guard authSession.snapshot.isAuthenticated else {
            resetState()
            return
        }

        do {
            let backend = makeBackend()
            let isAdmin = try await backend.isCurrentUserAdmin()
            self.isCurrentUserAdmin = isAdmin
            if !isAdmin {
                badgeCount = 0
                authorizationStatus = await notificationSettings().authorizationStatus
                await applyBadgeCount(0)
                return
            }

            await ensureNotificationAuthorization()
            if let token = storedDeviceToken {
                _ = try? await backend.upsertAdminDeviceToken(
                    deviceToken: token,
                    platform: "ios",
                    appBuild: Self.appBuildDescription
                )
            }
            await refreshBadgeCount()
        } catch {
            resetState()
            lastRegistrationErrorMessage = error.localizedDescription
        }
    }

    func handleSignedOut(previousSnapshot: AppSessionSnapshot) async {
        defer { resetState() }

        guard
            previousSnapshot.isAuthenticated,
            let token = storedDeviceToken
        else {
            return
        }

        do {
            let backend = makeBackend(usingBearerToken: previousSnapshot.bearerToken)
            _ = try await backend.deactivateAdminDeviceToken(deviceToken: token)
        } catch {
            // Best effort. Logout should not fail because token cleanup failed.
        }
    }

    func markNeedsRefresh() async {
        await refreshForCurrentSession()
    }

    private var storedDeviceToken: String? {
        let token = userDefaults.string(forKey: Keys.lastDeviceToken)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return token?.isEmpty == false ? token : nil
    }

    private func resetState() {
        isCurrentUserAdmin = false
        badgeCount = 0
        Task {
            await applyBadgeCount(0)
        }
    }

    private func ensureNotificationAuthorization() async {
        let settings = await notificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            await registerForRemoteNotifications()
        case .notDetermined:
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                let refreshed = await notificationSettings()
                authorizationStatus = refreshed.authorizationStatus
                if granted {
                    await registerForRemoteNotifications()
                }
            } catch {
                lastRegistrationErrorMessage = error.localizedDescription
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }

    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func refreshBadgeCount() async {
        guard authSession.snapshot.isAuthenticated, isCurrentUserAdmin else {
            badgeCount = 0
            await applyBadgeCount(0)
            return
        }

        do {
            let count = try await makeBackend().getAdminNotificationBadgeCount()
            badgeCount = count
            await applyBadgeCount(count)
        } catch {
            lastRegistrationErrorMessage = error.localizedDescription
        }
    }

    private func applyBadgeCount(_ count: Int) async {
        if #available(iOS 17.0, *) {
            await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().setBadgeCount(count) { _ in
                    continuation.resume()
                }
            }
        } else {
            await MainActor.run {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func makeBackend(usingBearerToken bearerToken: String? = nil) -> SharedPremiumAdminBackend {
        let authConfiguration = AppAuthConfiguration.load(userDefaults: userDefaults)
        let tokenProvider: @Sendable () async -> String? = {
            if let bearerToken {
                return bearerToken
            }
            return await self.authSession.validBearerToken(using: self.authClient)
        }
        return SharedPremiumAdminBackend(
            configuration: SharedLeaguePackAccessConfiguration(
                baseURL: authConfiguration.supabaseURL,
                apiKey: authConfiguration.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : authConfiguration.supabaseAnonKey,
                authTokenProvider: tokenProvider,
                urlSession: .shared
            )
        )
    }

    private static var appBuildDescription: String? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version?.trimmingCharacters(in: .whitespacesAndNewlines), build?.trimmingCharacters(in: .whitespacesAndNewlines)) {
        case let (.some(version), .some(build)) where !version.isEmpty && !build.isEmpty:
            return "\(version) (\(build))"
        case let (.some(version), _) where !version.isEmpty:
            return version
        case let (_, .some(build)) where !build.isEmpty:
            return build
        default:
            return nil
        }
    }
}
