import Foundation

enum AppPremiumAdminPack: String, CaseIterable, Identifiable {
    case germanyTop3 = "germany_top_3"
    case englandTop4 = "england_top_4"
    case italyTop3 = "italy_top_3"
    case spainTop4 = "spain_top_4"
    case premiumFull = "premium_full"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .germanyTop3:
            return "Tyskland"
        case .englandTop4:
            return "England"
        case .italyTop3:
            return "Italien"
        case .spainTop4:
            return "Spanien"
        case .premiumFull:
            return "Alle premium-pakker"
        }
    }
}

struct PremiumAccessAdminRow: Identifiable, Decodable, Equatable {
    let email: String
    let userId: String
    let packKey: String
    let enabled: Bool
    let updatedAt: Date?

    var id: String { "\(userId)-\(packKey)" }

    var packTitle: String {
        AppPremiumAdminPack(rawValue: packKey)?.title ?? packKey
    }

    private enum CodingKeys: String, CodingKey {
        case email
        case userId = "user_id"
        case packKey = "pack_key"
        case enabled
        case updatedAt = "updated_at"
    }
}

struct PremiumAccessRequestAdminRow: Identifiable, Decodable, Equatable {
    let requestId: String
    let email: String
    let userId: String
    let packKey: String
    let status: String
    let message: String?
    let createdAt: Date?
    let updatedAt: Date?

    var id: String { requestId }

    var packTitle: String {
        AppPremiumAdminPack(rawValue: packKey)?.title ?? packKey
    }

    var isOpen: Bool { status == "open" }

    private enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case email
        case userId = "user_id"
        case packKey = "pack_key"
        case status
        case message
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PremiumAccessRequestUserRow: Identifiable, Decodable, Equatable {
    let requestId: String
    let packKey: String
    let status: String
    let message: String?
    let createdAt: Date?
    let updatedAt: Date?

    var id: String { requestId }

    var packTitle: String {
        AppPremiumAdminPack(rawValue: packKey)?.title ?? packKey
    }

    var isOpen: Bool { status == "open" }

    private enum CodingKeys: String, CodingKey {
        case requestId = "id"
        case packKey = "pack_key"
        case status
        case message
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum SharedPremiumAdminError: LocalizedError {
    case notConfigured
    case missingAuthToken
    case invalidPayload
    case invalidHTTPStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Premium admin er ikke konfigureret."
        case .missingAuthToken:
            return "Du skal være logget ind for at bruge premium admin."
        case .invalidPayload:
            return "Premium admin-svaret kunne ikke læses."
        case .invalidHTTPStatus(let code, let body):
            if body.contains("not_authorized") {
                return "Den aktuelle bruger har ikke admin-adgang."
            }
            if body.contains("auth_required") {
                return "Du skal være logget ind for at anmode om premium-adgang."
            }
            if body.contains("user_not_found") {
                return "Brugeren blev ikke fundet i Supabase Auth."
            }
            if body.contains("request_not_found") {
                return "Anmodningen blev ikke fundet."
            }
            if body.contains("invalid_pack_key") {
                return "Premium-pakken er ikke gyldig."
            }
            return body.isEmpty ? "Premium admin fejlede med status \(code)." : body
        }
    }
}

final class SharedPremiumAdminBackend {
    private let configuration: SharedLeaguePackAccessConfiguration
    private let decoder: JSONDecoder

    init(configuration: SharedLeaguePackAccessConfiguration) {
        self.configuration = configuration
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.fractionalDateFormatter.date(from: value) {
                return date
            }
            if let date = Self.dateFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
    }

    func isCurrentUserAdmin() async throws -> Bool {
        let request = try await rpcRequest(functionName: "is_current_user_admin", payload: EmptyPayload())
        return try await perform(request, decodeAs: Bool.self)
    }

    func listPremiumAccess() async throws -> [PremiumAccessAdminRow] {
        let request = try await rpcRequest(functionName: "list_premium_access", payload: EmptyPayload())
        return try await perform(request, decodeAs: [PremiumAccessAdminRow].self)
    }

    func listPremiumAccessRequests() async throws -> [PremiumAccessRequestAdminRow] {
        let request = try await rpcRequest(functionName: "list_premium_access_requests", payload: EmptyPayload())
        return try await perform(request, decodeAs: [PremiumAccessRequestAdminRow].self)
    }

    func listCurrentUserAccessRequests() async throws -> [PremiumAccessRequestUserRow] {
        guard
            let baseURL = configuration.baseURL,
            let apiKey = configuration.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
            !apiKey.isEmpty
        else {
            throw SharedPremiumAdminError.notConfigured
        }

        guard let token = await configuration.authTokenProvider() else {
            throw SharedPremiumAdminError.missingAuthToken
        }

        let query = "select=id,pack_key,status,message,created_at,updated_at&order=created_at.desc"
        guard let url = URL(string: "rest/v1/premium_access_requests?\(query)", relativeTo: baseURL) else {
            throw SharedPremiumAdminError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(request, decodeAs: [PremiumAccessRequestUserRow].self)
    }

    func grant(email: String, pack: AppPremiumAdminPack) async throws -> [PremiumAccessAdminRow] {
        let payload = PremiumAccessMutationPayload(targetEmail: email, targetPackKey: pack.rawValue)
        let request = try await rpcRequest(functionName: "grant_league_pack_access_by_email", payload: payload)
        return try await perform(request, decodeAs: [PremiumAccessAdminRow].self)
    }

    func revoke(email: String, pack: AppPremiumAdminPack) async throws -> [PremiumAccessAdminRow] {
        let payload = PremiumAccessMutationPayload(targetEmail: email, targetPackKey: pack.rawValue)
        let request = try await rpcRequest(functionName: "revoke_league_pack_access_by_email", payload: payload)
        return try await perform(request, decodeAs: [PremiumAccessAdminRow].self)
    }

    func submitAccessRequest(
        pack: AppPremiumAdminPack,
        message: String?,
        submissionURL: URL? = nil,
        notificationURL: URL? = nil
    ) async throws {
        if let submissionURL {
            try await submitAccessRequestViaAPI(pack: pack, message: message, submissionURL: submissionURL)
            return
        }

        let payload = PremiumAccessRequestPayload(
            targetPackKey: pack.rawValue,
            requestMessage: message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            accessToken: nil
        )
        let request = try await rpcRequest(functionName: "submit_premium_access_request", payload: payload)
        let receipt = try await perform(request, decodeAs: [PremiumAccessRequestReceipt].self)

        if let notificationURL,
           let requestId = receipt.first?.requestId {
            await sendAccessRequestNotification(requestId: requestId, notificationURL: notificationURL)
        }
    }

    private func submitAccessRequestViaAPI(pack: AppPremiumAdminPack, message: String?, submissionURL: URL) async throws {
        guard let token = await configuration.authTokenProvider() else {
            throw SharedPremiumAdminError.missingAuthToken
        }

        var request = URLRequest(url: submissionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(PremiumAccessRequestPayload(
            targetPackKey: pack.rawValue,
            requestMessage: message?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            accessToken: token
        ))

        let (data, response) = try await configuration.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SharedPremiumAdminError.invalidPayload
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SharedPremiumAdminError.invalidHTTPStatus(http.statusCode, body)
        }
    }

    func approveAccessRequest(requestId: String) async throws -> [PremiumAccessAdminRow] {
        let payload = PremiumAccessApprovalPayload(requestId: requestId)
        let request = try await rpcRequest(functionName: "approve_premium_access_request", payload: payload)
        return try await perform(request, decodeAs: [PremiumAccessAdminRow].self)
    }

    private func rpcRequest<T: Encodable>(functionName: String, payload: T) async throws -> URLRequest {
        guard
            let baseURL = configuration.baseURL,
            let apiKey = configuration.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
            !apiKey.isEmpty
        else {
            throw SharedPremiumAdminError.notConfigured
        }

        guard let token = await configuration.authTokenProvider() else {
            throw SharedPremiumAdminError.missingAuthToken
        }

        let url = baseURL
            .appendingPathComponent("rest/v1/rpc")
            .appendingPathComponent(functionName)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, decodeAs type: T.Type) async throws -> T {
        let (data, response) = try await configuration.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SharedPremiumAdminError.invalidPayload
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SharedPremiumAdminError.invalidHTTPStatus(http.statusCode, body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SharedPremiumAdminError.invalidPayload
        }
    }

    private func sendAccessRequestNotification(requestId: String, notificationURL: URL) async {
        guard let token = await configuration.authTokenProvider() else {
            return
        }

        do {
            var request = URLRequest(url: notificationURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(PremiumAccessNotificationPayload(requestId: requestId))
            _ = try await configuration.urlSession.data(for: request)
        } catch {
            // Premium requests should still succeed even if the admin email notification cannot be sent.
        }
    }

    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct EmptyPayload: Encodable {}

private struct PremiumAccessMutationPayload: Encodable {
    let targetEmail: String
    let targetPackKey: String

    private enum CodingKeys: String, CodingKey {
        case targetEmail = "target_email"
        case targetPackKey = "target_pack_key"
    }
}

private struct PremiumAccessRequestPayload: Encodable {
    let targetPackKey: String
    let requestMessage: String?
    let accessToken: String?

    private enum CodingKeys: String, CodingKey {
        case targetPackKey = "target_pack_key"
        case requestMessage = "request_message"
        case accessToken = "access_token"
    }
}

private struct PremiumAccessApprovalPayload: Encodable {
    let requestId: String

    private enum CodingKeys: String, CodingKey {
        case requestId = "target_request_id"
    }
}

private struct PremiumAccessNotificationPayload: Encodable {
    let requestId: String

    private enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
    }
}

private struct PremiumAccessRequestReceipt: Decodable {
    let requestId: String

    private enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
