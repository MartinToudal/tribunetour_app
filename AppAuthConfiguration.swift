import Foundation

struct AppAuthConfiguration: Equatable {
    let supabaseURLString: String
    let supabaseAnonKey: String
    let appBridgeURLString: String
    let redirectScheme: String
    let redirectHost: String

    static let supabaseURLKey = "auth.supabase.url"
    static let supabaseAnonKeyKey = "auth.supabase.anonKey"
    static let appBridgeURLKey = "auth.app.bridgeUrl"
    static let redirectSchemeKey = "auth.redirect.scheme"
    static let redirectHostKey = "auth.redirect.host"
    static let bundleSupabaseURLKey = "TRIBUNETOUR_SUPABASE_URL"
    static let bundleSupabaseAnonKeyKey = "TRIBUNETOUR_SUPABASE_ANON_KEY"
    static let bundleAppBridgeURLKey = "TRIBUNETOUR_APP_BRIDGE_URL"
    static let bundleRedirectSchemeKey = "TRIBUNETOUR_REDIRECT_SCHEME"
    static let bundleRedirectHostKey = "TRIBUNETOUR_REDIRECT_HOST"
    static let fallbackSupabaseURLString = "https://yftbkxjutdbygwmeazau.supabase.co"
    static let fallbackSupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmdGJreGp1dGRieWd3bWVhemF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1OTE4ODcsImV4cCI6MjA3MzE2Nzg4N30.w1We52dSdkN3GWKq9oMXAa5r6AmPvz-OvlcM8Txmbds"

    static let `default` = AppAuthConfiguration(
        supabaseURLString: bundleString(for: bundleSupabaseURLKey, fallback: fallbackSupabaseURLString),
        supabaseAnonKey: bundleString(for: bundleSupabaseAnonKeyKey, fallback: fallbackSupabaseAnonKey),
        appBridgeURLString: bundleString(for: bundleAppBridgeURLKey, fallback: "https://tribunetour.dk/auth/app-callback"),
        redirectScheme: bundleString(for: bundleRedirectSchemeKey, fallback: "tribunetour"),
        redirectHost: bundleString(for: bundleRedirectHostKey, fallback: "auth-callback")
    )

    var isConfigured: Bool {
        !supabaseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAnonKey: Bool {
        !supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var supabaseURL: URL? {
        URL(string: supabaseURLString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var supabaseURLValidationMessage: String? {
        let trimmed = supabaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Supabase URL mangler." }
        guard let url = URL(string: trimmed), let host = url.host else {
            return "Supabase URL kan ikke læses."
        }
        guard url.scheme == "https" else {
            return "Supabase URL skal starte med https://"
        }
        guard host.hasSuffix(".supabase.co") else {
            return "Supabase URL skal pege på *.supabase.co og ikke dashboardet."
        }
        return nil
    }

    var callbackURL: URL? {
        var components = URLComponents()
        components.scheme = redirectScheme
        components.host = redirectHost
        return components.url
    }

    var appBridgeURL: URL? {
        URL(string: appBridgeURLString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var referenceDataBaseURL: URL? {
        guard let bridgeURL = appBridgeURL,
              var components = URLComponents(url: bridgeURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    var fixturesRemoteURL: URL? {
        referenceDataBaseURL?.appendingPathComponent("reference-data/fixtures.remote.json")
    }

    var passwordResetURL: URL? {
        guard let bridgeURL = appBridgeURL else {
            return URL(string: "https://tribunetour.dk/auth/reset-password")
        }
        guard var components = URLComponents(url: bridgeURL, resolvingAgainstBaseURL: false) else {
            return URL(string: "https://tribunetour.dk/auth/reset-password")
        }
        components.path = "/auth/reset-password"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    var premiumAccessRequestNotificationURL: URL? {
        guard let baseURL = referenceDataBaseURL else {
            return URL(string: "https://tribunetour.dk/api/premium-access-request-notification")
        }
        return baseURL.appendingPathComponent("api/premium-access-request-notification")
    }

    static func load(userDefaults: UserDefaults = .standard) -> AppAuthConfiguration {
        AppAuthConfiguration(
            supabaseURLString: resolvedValue(
                userDefaults.string(forKey: supabaseURLKey),
                fallback: Self.default.supabaseURLString
            ),
            supabaseAnonKey: resolvedValue(
                userDefaults.string(forKey: supabaseAnonKeyKey),
                fallback: Self.default.supabaseAnonKey
            ),
            appBridgeURLString: resolvedValue(
                userDefaults.string(forKey: appBridgeURLKey),
                fallback: Self.default.appBridgeURLString
            ),
            redirectScheme: resolvedValue(
                userDefaults.string(forKey: redirectSchemeKey),
                fallback: Self.default.redirectScheme
            ),
            redirectHost: resolvedValue(
                userDefaults.string(forKey: redirectHostKey),
                fallback: Self.default.redirectHost
            )
        )
    }

    var redactedSupabaseURL: String {
        supabaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var appBridgeValidationMessage: String? {
        let trimmed = appBridgeURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "App bridge URL mangler." }
        guard let url = URL(string: trimmed), let host = url.host else {
            return "App bridge URL kan ikke læses."
        }
        guard url.scheme == "https" else {
            return "App bridge URL skal starte med https://"
        }
        guard host == "tribunetour.dk" || host.hasSuffix(".tribunetour.dk") || host.contains("vercel.app") else {
            return "App bridge URL bør pege på Tribunetour-websitet."
        }
        return nil
    }

    private static func bundleString(for key: String, fallback: String = "") -> String {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func resolvedValue(_ candidate: String?, fallback: String) -> String {
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
