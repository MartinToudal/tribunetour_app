import Foundation

enum AppAuthClientError: LocalizedError {
    case notConfigured
    case missingAnonKey
    case invalidEmail
    case invalidPassword
    case invalidSupabaseURL
    case invalidResponse
    case invalidCallback
    case missingAccessToken
    case signUpRequiresConfirmation
    case invalidPasswordResetURL
    case failed(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Login er ikke konfigureret endnu."
        case .missingAnonKey:
            return "Supabase publishable/anon key mangler i Interne værktøjer."
        case .invalidEmail:
            return "Indtast en gyldig e-mailadresse."
        case .invalidPassword:
            return "Adgangskoden skal være mindst 8 tegn."
        case .invalidSupabaseURL:
            return "Supabase URL er ugyldig."
        case .invalidResponse:
            return "Login-svaret fra serveren kunne ikke forstås."
        case .invalidCallback:
            return "Login-linket kunne ikke læses i appen."
        case .missingAccessToken:
            return "Login-linket indeholdt ikke et access token."
        case .signUpRequiresConfirmation:
            return "Kontoen er oprettet, men kræver e-mailbekræftelse før du kan logge ind."
        case .invalidPasswordResetURL:
            return "Linket til at sætte adgangskode er ugyldigt."
        case .failed(let statusCode, let message):
            return message.isEmpty ? "Login fejlede med status \(statusCode)." : message
        }
    }
}

struct AppAuthCallbackResult {
    let userEmail: String?
    let accessToken: String
    let refreshToken: String?
}

struct AppAuthOTPResponse: Decodable {
    let messageId: String?

    private enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }
}

struct AppAuthSessionResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: AppAuthUserResponse?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AppAuthUserResponse: Decodable {
    let email: String?
}

final class AppAuthClient {
    private let urlSession: URLSession
    private let userDefaults: UserDefaults

    init(urlSession: URLSession = .shared, userDefaults: UserDefaults = .standard) {
        self.urlSession = urlSession
        self.userDefaults = userDefaults
    }

    func currentConfiguration() -> AppAuthConfiguration {
        AppAuthConfiguration.load(userDefaults: userDefaults)
    }

    func signIn(email: String, password: String) async throws -> AppAuthCallbackResult {
        let trimmedEmail = try validateEmail(email)
        let validatedPassword = try validatePassword(password)
        let configuration = try validatedConfiguration()
        guard let supabaseURL = configuration.supabaseURL else {
            throw AppAuthClientError.invalidSupabaseURL
        }

        var components = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let endpoint = components?.url else {
            throw AppAuthClientError.invalidSupabaseURL
        }

        var request = authorizedJSONRequest(url: endpoint, anonKey: configuration.supabaseAnonKey)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(PasswordSignInRequest(email: trimmedEmail, password: validatedPassword))

        let response: AppAuthSessionResponse = try await perform(request, decodeAs: AppAuthSessionResponse.self)
        guard let accessToken = response.accessToken else {
            throw AppAuthClientError.invalidResponse
        }

        return AppAuthCallbackResult(
            userEmail: response.user?.email ?? trimmedEmail,
            accessToken: accessToken,
            refreshToken: response.refreshToken
        )
    }

    func signUp(email: String, password: String) async throws -> AppAuthCallbackResult {
        let trimmedEmail = try validateEmail(email)
        let validatedPassword = try validatePassword(password)
        let configuration = try validatedConfiguration()
        guard let supabaseURL = configuration.supabaseURL else {
            throw AppAuthClientError.invalidSupabaseURL
        }

        let endpoint = supabaseURL.appendingPathComponent("auth/v1/signup")
        var request = authorizedJSONRequest(url: endpoint, anonKey: configuration.supabaseAnonKey)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(PasswordSignUpRequest(email: trimmedEmail, password: validatedPassword))

        let response: AppAuthSessionResponse = try await perform(request, decodeAs: AppAuthSessionResponse.self)
        guard let accessToken = response.accessToken else {
            throw AppAuthClientError.signUpRequiresConfirmation
        }

        return AppAuthCallbackResult(
            userEmail: response.user?.email ?? trimmedEmail,
            accessToken: accessToken,
            refreshToken: response.refreshToken
        )
    }

    func refreshSession(refreshToken: String) async throws -> AppAuthCallbackResult {
        let trimmedRefreshToken = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRefreshToken.isEmpty else {
            throw AppAuthClientError.invalidResponse
        }

        let configuration = try validatedConfiguration()
        guard let supabaseURL = configuration.supabaseURL else {
            throw AppAuthClientError.invalidSupabaseURL
        }

        var components = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let endpoint = components?.url else {
            throw AppAuthClientError.invalidSupabaseURL
        }

        var request = authorizedJSONRequest(url: endpoint, anonKey: configuration.supabaseAnonKey)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(RefreshSessionRequest(refreshToken: trimmedRefreshToken))

        let response: AppAuthSessionResponse = try await perform(request, decodeAs: AppAuthSessionResponse.self)
        guard let accessToken = response.accessToken else {
            throw AppAuthClientError.invalidResponse
        }

        return AppAuthCallbackResult(
            userEmail: response.user?.email,
            accessToken: accessToken,
            refreshToken: response.refreshToken ?? trimmedRefreshToken
        )
    }

    func sendPasswordReset(to email: String) async throws {
        let trimmedEmail = try validateEmail(email)
        let configuration = try validatedConfiguration()
        guard let supabaseURL = configuration.supabaseURL else {
            throw AppAuthClientError.invalidSupabaseURL
        }
        guard let passwordResetURL = configuration.passwordResetURL else {
            throw AppAuthClientError.invalidPasswordResetURL
        }

        var components = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/recover"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "redirect_to", value: passwordResetURL.absoluteString)
        ]
        guard let endpoint = components?.url else {
            throw AppAuthClientError.invalidPasswordResetURL
        }

        var request = authorizedJSONRequest(url: endpoint, anonKey: configuration.supabaseAnonKey)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(PasswordResetRequest(email: trimmedEmail))

        let _: EmptyResponse = try await perform(request, decodeAs: EmptyResponse.self)
    }

    func sendMagicLink(to email: String) async throws {
        let trimmedEmail = try validateEmail(email)
        let configuration = try validatedConfiguration()
        guard let bridgeURL = configuration.appBridgeURL else {
            throw AppAuthClientError.failed(-1, "App bridge URL er ugyldig.")
        }
        guard let supabaseURL = configuration.supabaseURL else {
            throw AppAuthClientError.invalidSupabaseURL
        }

        let endpoint = supabaseURL.appendingPathComponent("auth/v1/otp")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = AuthOTPRequest(
            email: trimmedEmail,
            options: AuthOTPRequest.Options(
                shouldCreateUser: true,
                emailRedirectTo: bridgeURL.absoluteString
            )
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError where error.code == .cannotFindHost {
            throw AppAuthClientError.failed(
                error.errorCode,
                "Supabase host kunne ikke findes. Tjek at Supabase URL er den fulde projekt-URL, fx https://projekt-ref.supabase.co"
            )
        } catch {
            throw error
        }
        guard let http = response as? HTTPURLResponse else {
            throw AppAuthClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AppAuthClientError.failed(http.statusCode, message)
        }

        if !data.isEmpty {
            _ = try? JSONDecoder().decode(AppAuthOTPResponse.self, from: data)
        }
    }

    func canHandleCallbackURL(_ url: URL) -> Bool {
        let configuration = currentConfiguration()
        guard
            url.scheme?.caseInsensitiveCompare(configuration.redirectScheme) == .orderedSame,
            url.host?.caseInsensitiveCompare(configuration.redirectHost) == .orderedSame
        else {
            return false
        }
        return true
    }

    func parseCallbackURL(_ url: URL) throws -> AppAuthCallbackResult {
        guard canHandleCallbackURL(url) else {
            throw AppAuthClientError.invalidCallback
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let fragmentItems = URLComponents(string: "scheme://host?\(url.fragment ?? "")")?.queryItems ?? []
        let allItems = queryItems + fragmentItems

        func value(for name: String) -> String? {
            allItems.first(where: { $0.name == name })?.value
        }

        guard let accessToken = value(for: "access_token"), !accessToken.isEmpty else {
            throw AppAuthClientError.missingAccessToken
        }

        return AppAuthCallbackResult(
            userEmail: value(for: "email"),
            accessToken: accessToken,
            refreshToken: value(for: "refresh_token")
        )
    }

    private func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }

    private func validateEmail(_ email: String) throws -> String {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmedEmail) else {
            throw AppAuthClientError.invalidEmail
        }
        return trimmedEmail
    }

    private func validatePassword(_ password: String) throws -> String {
        guard password.count >= 8 else {
            throw AppAuthClientError.invalidPassword
        }
        return password
    }

    private func validatedConfiguration() throws -> AppAuthConfiguration {
        let configuration = currentConfiguration()
        if !configuration.hasAnonKey {
            throw AppAuthClientError.missingAnonKey
        }
        if !configuration.isConfigured {
            throw AppAuthClientError.notConfigured
        }
        if configuration.supabaseURLValidationMessage != nil {
            throw AppAuthClientError.invalidSupabaseURL
        }
        return configuration
    }

    private func authorizedJSONRequest(url: URL, anonKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, decodeAs type: T.Type) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppAuthClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AppAuthClientError.failed(http.statusCode, message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppAuthClientError.invalidResponse
        }
    }
}

private struct AuthOTPRequest: Encodable {
    let email: String
    let options: Options

    struct Options: Encodable {
        let shouldCreateUser: Bool
        let emailRedirectTo: String?

        private enum CodingKeys: String, CodingKey {
            case shouldCreateUser = "should_create_user"
            case emailRedirectTo = "email_redirect_to"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case email
        case options
    }
}

private struct PasswordSignInRequest: Encodable {
    let email: String
    let password: String
}

private struct PasswordSignUpRequest: Encodable {
    let email: String
    let password: String
}

private struct PasswordResetRequest: Encodable {
    let email: String
}

private struct RefreshSessionRequest: Encodable {
    let refreshToken: String

    private enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct EmptyResponse: Decodable {}
