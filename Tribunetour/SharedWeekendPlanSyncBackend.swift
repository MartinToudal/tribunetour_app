import Foundation

enum SharedWeekendPlanSyncBackendError: LocalizedError {
    case notConfigured
    case missingAuthToken
    case invalidHTTPStatus(Int, String?)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Shared weekend plan sync er ikke konfigureret endnu."
        case .missingAuthToken:
            return "Shared weekend plan sync mangler auth-token."
        case .invalidHTTPStatus(let code, let message):
            if let message, !message.isEmpty {
                return "Shared weekend plan sync returnerede ugyldig HTTP status: \(code). \(message)"
            }
            return "Shared weekend plan sync returnerede ugyldig HTTP status: \(code)."
        case .invalidPayload:
            return "Shared weekend plan payload kunne ikke valideres."
        }
    }
}

struct SharedWeekendPlanSyncConfiguration {
    let baseURL: URL?
    let apiKey: String?
    let source: String
    let authTokenProvider: @Sendable () async -> String?
    let urlSession: URLSession
}

struct SharedWeekendPlanRecordDTO: Codable, Equatable {
    let fixtureIds: [String]
    let updatedAt: Date
    let source: String?

    enum CodingKeys: String, CodingKey {
        case fixtureIds = "fixture_ids"
        case updatedAt = "updated_at"
        case source
    }
}

struct SharedWeekendPlanWriteRow: Codable {
    let userId: String
    let fixtureIds: [String]
    let updatedAt: Date
    let source: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fixtureIds = "fixture_ids"
        case updatedAt = "updated_at"
        case source
    }
}

final class SharedWeekendPlanSyncBackend {
    private let configuration: SharedWeekendPlanSyncConfiguration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(configuration: SharedWeekendPlanSyncConfiguration) {
        self.configuration = configuration
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func fetch() async throws -> SharedWeekendPlanRecordDTO? {
        let request = try await authorizedRequest(
            path: "rest/v1/weekend_plans?select=fixture_ids,updated_at,source",
            method: "GET"
        )
        let records: [SharedWeekendPlanRecordDTO] = try await perform(request, decodeAs: [SharedWeekendPlanRecordDTO].self)
        return records.first
    }

    func upsert(userId: String, fixtureIds: [String], updatedAt: Date) async throws {
        let payload = SharedWeekendPlanWriteRow(
            userId: userId,
            fixtureIds: Array(Set(fixtureIds)).sorted(),
            updatedAt: updatedAt,
            source: configuration.source
        )
        var request = try await authorizedRequest(
            path: "rest/v1/weekend_plans?on_conflict=user_id",
            method: "POST"
        )
        request.httpBody = try encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        _ = try await performWithoutDecoding(request)
    }

    private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
        guard let baseURL = configuration.baseURL else {
            throw SharedWeekendPlanSyncBackendError.notConfigured
        }
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw SharedWeekendPlanSyncBackendError.notConfigured
        }
        guard let token = await configuration.authTokenProvider() else {
            throw SharedWeekendPlanSyncBackendError.missingAuthToken
        }
        guard let url = resolvedURL(baseURL: baseURL, path: path) else {
            throw SharedWeekendPlanSyncBackendError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func resolvedURL(baseURL: URL, path: String) -> URL? {
        if let components = URLComponents(string: path), components.scheme != nil {
            return components.url
        }

        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let baseComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let parts = trimmedPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let relativePath = String(parts[0])

        var components = baseComponents
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = "\(basePath)/\(relativePath)"
        components.percentEncodedQuery = parts.count > 1 ? String(parts[1]) : nil
        return components.url
    }

    private func perform<T: Decodable>(_ request: URLRequest, decodeAs type: T.Type) async throws -> T {
        let (data, response) = try await configuration.urlSession.data(for: request)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SharedWeekendPlanSyncBackendError.invalidPayload
        }
    }

    private func performWithoutDecoding(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await configuration.urlSession.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SharedWeekendPlanSyncBackendError.invalidPayload
        }
        guard (200...299).contains(http.statusCode) else {
            throw SharedWeekendPlanSyncBackendError.invalidHTTPStatus(
                http.statusCode,
                String(data: data, encoding: .utf8)
            )
        }
    }
}
