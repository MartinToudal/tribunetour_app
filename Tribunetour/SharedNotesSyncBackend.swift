import Foundation

enum SharedNotesSyncBackendError: LocalizedError {
    case notConfigured
    case missingAuthToken
    case invalidHTTPStatus(Int, String?)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Shared notes sync er ikke konfigureret endnu."
        case .missingAuthToken:
            return "Shared notes sync mangler auth-token."
        case .invalidHTTPStatus(let code, let message):
            if let message, !message.isEmpty {
                return "Shared notes sync returnerede ugyldig HTTP status: \(code). \(message)"
            }
            return "Shared notes sync returnerede ugyldig HTTP status: \(code)."
        case .invalidPayload:
            return "Shared notes payload kunne ikke valideres."
        }
    }
}

struct SharedNotesSyncConfiguration {
    let baseURL: URL?
    let apiKey: String?
    let source: String
    let authTokenProvider: @Sendable () async -> String?
    let urlSession: URLSession

    static let placeholder = SharedNotesSyncConfiguration(
        baseURL: nil,
        apiKey: nil,
        source: "shared",
        authTokenProvider: { nil },
        urlSession: .shared
    )
}

struct SharedNoteRecordDTO: Codable {
    let clubId: String
    let note: String
    let updatedAt: Date
    let createdAt: Date?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case note
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case source
    }
}

struct SharedNoteWriteRow: Codable {
    let userId: String
    let clubId: String
    let note: String
    let updatedAt: Date
    let source: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case clubId = "club_id"
        case note
        case updatedAt = "updated_at"
        case source
    }
}

final class SharedNotesSyncBackend {
    private let configuration: SharedNotesSyncConfiguration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(configuration: SharedNotesSyncConfiguration) {
        self.configuration = configuration
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func fetchAll() async throws -> [String: SharedNoteRecordDTO] {
        let request = try await authorizedRequest(
            path: "rest/v1/notes?select=club_id,note,created_at,updated_at,source",
            method: "GET"
        )
        let records: [SharedNoteRecordDTO] = try await perform(request, decodeAs: [SharedNoteRecordDTO].self)
        return Dictionary(uniqueKeysWithValues: records.map { ($0.clubId, $0) })
    }

    func upsert(userId: String, clubId: String, note: String, updatedAt: Date) async throws {
        let payload = SharedNoteWriteRow(
            userId: userId,
            clubId: clubId,
            note: note,
            updatedAt: updatedAt,
            source: configuration.source
        )
        var request = try await authorizedRequest(
            path: "rest/v1/notes?on_conflict=user_id,club_id",
            method: "POST"
        )
        request.httpBody = try encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        _ = try await performWithoutDecoding(request)
    }

    private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
        guard let baseURL = configuration.baseURL else {
            throw SharedNotesSyncBackendError.notConfigured
        }
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw SharedNotesSyncBackendError.notConfigured
        }
        guard let token = await configuration.authTokenProvider() else {
            throw SharedNotesSyncBackendError.missingAuthToken
        }
        guard let url = resolvedURL(baseURL: baseURL, path: path) else {
            throw SharedNotesSyncBackendError.invalidPayload
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
            throw SharedNotesSyncBackendError.invalidPayload
        }
    }

    private func performWithoutDecoding(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await configuration.urlSession.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SharedNotesSyncBackendError.invalidPayload
        }
        guard (200...299).contains(http.statusCode) else {
            throw SharedNotesSyncBackendError.invalidHTTPStatus(
                http.statusCode,
                String(data: data, encoding: .utf8)
            )
        }
    }
}
