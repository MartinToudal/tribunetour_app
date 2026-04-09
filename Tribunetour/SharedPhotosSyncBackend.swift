import Foundation

enum SharedPhotosSyncBackendError: LocalizedError {
    case notConfigured
    case missingAuthToken
    case invalidHTTPStatus(Int, String?)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Shared photos sync er ikke konfigureret endnu."
        case .missingAuthToken:
            return "Shared photos sync mangler auth-token."
        case .invalidHTTPStatus(let code, let message):
            if let message, !message.isEmpty {
                return "Shared photos sync returnerede ugyldig HTTP status: \(code). \(message)"
            }
            return "Shared photos sync returnerede ugyldig HTTP status: \(code)."
        case .invalidPayload:
            return "Shared photos payload kunne ikke valideres."
        }
    }
}

struct SharedPhotosSyncConfiguration {
    let baseURL: URL?
    let apiKey: String?
    let source: String
    let bucketName: String
    let authTokenProvider: @Sendable () async -> String?
    let urlSession: URLSession

    static let placeholder = SharedPhotosSyncConfiguration(
        baseURL: nil,
        apiKey: nil,
        source: "shared",
        bucketName: "stadium-photos",
        authTokenProvider: { nil },
        urlSession: .shared
    )
}

struct SharedPhotoRecordDTO: Codable {
    let clubId: String
    let fileName: String
    let caption: String
    let createdAt: Date?
    let updatedAt: Date
    let source: String?

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case fileName = "file_name"
        case caption
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case source
    }

    init(
        clubId: String,
        fileName: String,
        caption: String,
        createdAt: Date?,
        updatedAt: Date,
        source: String?
    ) {
        self.clubId = clubId
        self.fileName = fileName
        self.caption = caption
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }

    var photoMeta: VisitedStore.Record.PhotoMeta {
        let resolvedCreatedAt = createdAt ?? updatedAt
        return VisitedStore.Record.PhotoMeta(
            caption: caption,
            createdAt: resolvedCreatedAt,
            updatedAt: updatedAt
        )
    }
}

struct SharedPhotoWriteRow: Codable {
    let userId: String
    let clubId: String
    let fileName: String
    let caption: String
    let createdAt: Date
    let updatedAt: Date
    let source: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case clubId = "club_id"
        case fileName = "file_name"
        case caption
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case source
    }
}

private struct SharedPhotoDeleteRequest: Codable {
    let prefixes: [String]
}

final class SharedPhotosSyncBackend {
    private let configuration: SharedPhotosSyncConfiguration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(configuration: SharedPhotosSyncConfiguration) {
        self.configuration = configuration
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func fetchAll() async throws -> [SharedPhotoRecordDTO] {
        let request = try await authorizedRequest(
            path: "rest/v1/photos?select=club_id,file_name,caption,created_at,updated_at,source",
            method: "GET"
        )
        let records = try await perform(request, decodeAs: [SharedPhotoRecordDTO].self)
        return normalizedRecords(records)
    }

    func downloadPhoto(userId: String, clubId: String, fileName: String) async throws -> Data {
        let candidateClubIds = ClubIdentityResolver.allKnownIds(for: clubId)

        for candidateClubId in candidateClubIds {
            let path = "storage/v1/object/authenticated/\(configuration.bucketName)/\(userId)/\(candidateClubId)/\(fileName)"
            let request = try await authorizedRequest(path: path, method: "GET")

            do {
                return try await performWithoutDecoding(request)
            } catch SharedPhotosSyncBackendError.invalidHTTPStatus(let code, _) where code == 400 || code == 404 {
                continue
            }
        }

        let canonicalClubId = ClubIdentityResolver.canonicalId(for: clubId)
        let fallbackPath = "storage/v1/object/authenticated/\(configuration.bucketName)/\(userId)/\(canonicalClubId)/\(fileName)"
        let fallbackRequest = try await authorizedRequest(path: fallbackPath, method: "GET")
        return try await performWithoutDecoding(fallbackRequest)
    }

    func uploadPhoto(
        userId: String,
        clubId: String,
        fileName: String,
        imageData: Data,
        contentType: String
    ) async throws {
        let canonicalClubId = ClubIdentityResolver.canonicalId(for: clubId)
        let path = "storage/v1/object/\(configuration.bucketName)/\(userId)/\(canonicalClubId)/\(fileName)"
        var request = try await authorizedRequest(path: path, method: "POST")
        request.httpBody = imageData
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        _ = try await performWithoutDecoding(request)
    }

    func upsertMetadata(
        userId: String,
        clubId: String,
        fileName: String,
        meta: VisitedStore.Record.PhotoMeta
    ) async throws {
        let payload = SharedPhotoWriteRow(
            userId: userId,
            clubId: ClubIdentityResolver.canonicalId(for: clubId),
            fileName: fileName,
            caption: meta.caption,
            createdAt: meta.createdAt,
            updatedAt: meta.updatedAt,
            source: configuration.source
        )
        var request = try await authorizedRequest(
            path: "rest/v1/photos?on_conflict=user_id,club_id,file_name",
            method: "POST"
        )
        request.httpBody = try encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        _ = try await performWithoutDecoding(request)
    }

    func deletePhoto(userId: String, clubId: String, fileName: String) async throws {
        let canonicalClubId = ClubIdentityResolver.canonicalId(for: clubId)
        let encodedClubId = percentEncodedPathComponent(canonicalClubId)
        let encodedFileName = percentEncodedPathComponent(fileName)
        var metadataRequest = try await authorizedRequest(
            path: "rest/v1/photos?club_id=eq.\(encodedClubId)&file_name=eq.\(encodedFileName)",
            method: "DELETE"
        )
        metadataRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await performWithoutDecoding(metadataRequest)

        let storagePaths = Array(Set(
            ClubIdentityResolver.allKnownIds(for: clubId).map { "\(userId)/\($0)/\(fileName)" }
        )).sorted()
        var storageRequest = try await authorizedRequest(
            path: "storage/v1/object/remove/\(configuration.bucketName)",
            method: "POST"
        )
        storageRequest.httpBody = try encoder.encode(
            SharedPhotoDeleteRequest(prefixes: storagePaths)
        )
        storageRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await performWithoutDecoding(storageRequest)
    }

    private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
        guard let baseURL = configuration.baseURL else {
            throw SharedPhotosSyncBackendError.notConfigured
        }
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw SharedPhotosSyncBackendError.notConfigured
        }
        guard let token = await configuration.authTokenProvider() else {
            throw SharedPhotosSyncBackendError.missingAuthToken
        }
        guard let url = resolvedURL(baseURL: baseURL, path: path) else {
            throw SharedPhotosSyncBackendError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
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

    private func percentEncodedPathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private func perform<T: Decodable>(_ request: URLRequest, decodeAs type: T.Type) async throws -> T {
        let (data, response) = try await configuration.urlSession.data(for: request)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SharedPhotosSyncBackendError.invalidPayload
        }
    }

    private func performWithoutDecoding(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await configuration.urlSession.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SharedPhotosSyncBackendError.invalidPayload
        }
        guard (200...299).contains(http.statusCode) else {
            throw SharedPhotosSyncBackendError.invalidHTTPStatus(
                http.statusCode,
                String(data: data, encoding: .utf8)
            )
        }
    }

    private func normalizedRecords(_ records: [SharedPhotoRecordDTO]) -> [SharedPhotoRecordDTO] {
        var result: [String: SharedPhotoRecordDTO] = [:]

        for record in records {
            let canonicalClubId = ClubIdentityResolver.canonicalId(for: record.clubId)
            let normalized = SharedPhotoRecordDTO(
                clubId: canonicalClubId,
                fileName: record.fileName,
                caption: record.caption,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                source: record.source
            )
            let key = "\(canonicalClubId)::\(record.fileName)"

            if let existing = result[key], existing.updatedAt >= normalized.updatedAt {
                continue
            }

            result[key] = normalized
        }

        return Array(result.values)
    }
}
