import Foundation

enum SharedVisitedSyncBackendError: LocalizedError {
    case notConfigured
    case missingAuthToken
    case invalidHTTPStatus(Int, String?)
    case invalidPayload
    case unsupportedPhotos
    case bootstrapAlreadyCompleted

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Shared visited sync er ikke konfigureret endnu."
        case .missingAuthToken:
            return "Shared visited sync mangler auth-token."
        case .invalidHTTPStatus(let code, let message):
            if let message, !message.isEmpty {
                return "Shared visited sync returnerede ugyldig HTTP status: \(code). \(message)"
            }
            return "Shared visited sync returnerede ugyldig HTTP status: \(code)."
        case .invalidPayload:
            return "Shared visited payload kunne ikke valideres."
        case .unsupportedPhotos:
            return "Shared visited backend understøtter ikke fotos endnu."
        case .bootstrapAlreadyCompleted:
            return "Visited-bootstrap er allerede gennemført for denne bruger."
        }
    }
}

struct SharedVisitedSyncConfiguration {
    let baseURL: URL?
    let apiKey: String?
    let source: String
    let authTokenProvider: @Sendable () async -> String?
    let urlSession: URLSession

    static let placeholder = SharedVisitedSyncConfiguration(
        baseURL: nil,
        apiKey: nil,
        source: "shared",
        authTokenProvider: { nil },
        urlSession: .shared
    )
}

final class SharedVisitedSyncBackend: VisitedSyncBackend {
    private let configuration: SharedVisitedSyncConfiguration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(configuration: SharedVisitedSyncConfiguration) {
        self.configuration = configuration
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func debugAccountStatus() async {
        guard configuration.baseURL != nil else {
            dlog("Shared visited sync er ikke konfigureret endnu")
            return
        }

        let token = await configuration.authTokenProvider()
        if token == nil {
            dlog("Shared visited sync mangler auth-token")
        }
    }

    func fetchAll() async throws -> [String: VisitedStore.Record] {
        let request = try await authorizedRequest(
            path: "rest/v1/visited?select=club_id,visited,visited_date,updated_at,source",
            method: "GET"
        )
        let records: [SharedVisitedRecordDTO] = try await perform(request, decodeAs: [SharedVisitedRecordDTO].self)
        var mapped: [String: VisitedStore.Record] = [:]
        for record in records {
            mapped[record.clubId] = record.toRecord()
        }
        return mapped
    }

    func fetchMigrationState() async throws -> SharedVisitedMigrationStateDTO {
        var request = try await authorizedRequest(
            path: "rest/v1/rpc/get_visited_migration_state",
            method: "POST"
        )
        request.httpBody = try encoder.encode(EmptyRequest())
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request, decodeAs: SharedVisitedMigrationStateDTO.self)
    }

    func bootstrap(records: [String: VisitedStore.Record]) async throws -> SharedVisitedBootstrapResponseDTO {
        let payload = SharedVisitedBootstrapRequest.fromRecords(records, source: configuration.source)
        var request = try await authorizedRequest(
            path: "rest/v1/rpc/bootstrap_visited_from_app",
            method: "POST"
        )
        request.httpBody = try encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request, decodeAs: SharedVisitedBootstrapResponseDTO.self)
    }

    func upsert(clubId: String, record: VisitedStore.Record) async throws {
        let payload = SharedVisitedWriteRow.fromRecord(clubId: clubId, record: record, source: configuration.source)
        var request = try await authorizedRequest(
            path: "rest/v1/visited?on_conflict=user_id,club_id",
            method: "POST"
        )
        request.httpBody = try encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        _ = try await performWithoutDecoding(request)
    }

    func delete(clubId: String) async throws {
        let payload = SharedVisitedWriteRow(
            clubId: clubId,
            visited: false,
            visitedDate: nil,
            source: configuration.source
        )
        var request = try await authorizedRequest(
            path: "rest/v1/visited?on_conflict=user_id,club_id",
            method: "POST"
        )
        request.httpBody = try encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        _ = try await performWithoutDecoding(request)
    }

    func fetchAllPhotos() async throws -> [VisitedRemotePhotoPayload] {
        throw SharedVisitedSyncBackendError.unsupportedPhotos
    }

    func fetchPhotoMetadata(for clubId: String) async throws -> [String: VisitedStore.Record.PhotoMeta] {
        throw SharedVisitedSyncBackendError.unsupportedPhotos
    }

    func upsertPhoto(
        clubId: String,
        fileName: String,
        imageData: Data,
        meta: VisitedStore.Record.PhotoMeta
    ) async throws {
        throw SharedVisitedSyncBackendError.unsupportedPhotos
    }

    func deletePhoto(fileName: String) async throws {
        throw SharedVisitedSyncBackendError.unsupportedPhotos
    }

    private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
        guard let baseURL = configuration.baseURL else {
            throw SharedVisitedSyncBackendError.notConfigured
        }
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw SharedVisitedSyncBackendError.notConfigured
        }
        guard let token = await configuration.authTokenProvider() else {
            throw SharedVisitedSyncBackendError.missingAuthToken
        }

        guard let url = resolvedURL(baseURL: baseURL, path: path) else {
            throw SharedVisitedSyncBackendError.invalidPayload
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
            throw SharedVisitedSyncBackendError.invalidPayload
        }
    }

    private func performWithoutDecoding(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await configuration.urlSession.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SharedVisitedSyncBackendError.invalidPayload
        }
        if http.statusCode == 409 {
            throw SharedVisitedSyncBackendError.bootstrapAlreadyCompleted
        }
        guard (200...299).contains(http.statusCode) else {
            throw SharedVisitedSyncBackendError.invalidHTTPStatus(
                http.statusCode,
                String(data: data, encoding: .utf8)
            )
        }
    }
}

private struct EmptyRequest: Encodable {}
