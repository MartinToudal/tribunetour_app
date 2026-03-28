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

    static let `default` = AppAuthConfiguration(
        supabaseURLString: "",
        supabaseAnonKey: "",
        appBridgeURLString: "https://tribunetour.dk/auth/app-callback",
        redirectScheme: "tribunetour",
        redirectHost: "auth-callback"
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

    static func load(userDefaults: UserDefaults = .standard) -> AppAuthConfiguration {
        AppAuthConfiguration(
            supabaseURLString: userDefaults.string(forKey: supabaseURLKey) ?? Self.default.supabaseURLString,
            supabaseAnonKey: userDefaults.string(forKey: supabaseAnonKeyKey) ?? Self.default.supabaseAnonKey,
            appBridgeURLString: userDefaults.string(forKey: appBridgeURLKey) ?? Self.default.appBridgeURLString,
            redirectScheme: userDefaults.string(forKey: redirectSchemeKey) ?? Self.default.redirectScheme,
            redirectHost: userDefaults.string(forKey: redirectHostKey) ?? Self.default.redirectHost
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
}
