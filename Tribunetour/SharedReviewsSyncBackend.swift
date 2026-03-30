import Foundation

enum SharedReviewsSyncBackendError: LocalizedError {
    case notConfigured
    case missingAuthToken
    case invalidHTTPStatus(Int, String?)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Shared reviews sync er ikke konfigureret endnu."
        case .missingAuthToken:
            return "Shared reviews sync mangler auth-token."
        case .invalidHTTPStatus(let code, let message):
            if let message, !message.isEmpty {
                return "Shared reviews sync returnerede ugyldig HTTP status: \(code). \(message)"
            }
            return "Shared reviews sync returnerede ugyldig HTTP status: \(code)."
        case .invalidPayload:
            return "Shared reviews payload kunne ikke valideres."
        }
    }
}

struct SharedReviewsSyncConfiguration {
    let baseURL: URL?
    let apiKey: String?
    let source: String
    let authTokenProvider: @Sendable () async -> String?
    let urlSession: URLSession

    static let placeholder = SharedReviewsSyncConfiguration(
        baseURL: nil,
        apiKey: nil,
        source: "shared",
        authTokenProvider: { nil },
        urlSession: .shared
    )
}

struct SharedReviewRecordDTO: Codable {
    let clubId: String
    let matchLabel: String
    let scores: [VisitedStore.ReviewCategory: Int]
    let categoryNotes: [VisitedStore.ReviewCategory: String]
    let summary: String
    let tags: String
    let updatedAt: Date
    let createdAt: Date?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case matchLabel = "match_label"
        case scores
        case categoryNotes = "category_notes"
        case summary
        case tags
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.clubId = try c.decode(String.self, forKey: .clubId)
        self.matchLabel = try c.decodeIfPresent(String.self, forKey: .matchLabel) ?? ""
        self.scores = try c.decodeIfPresent([VisitedStore.ReviewCategory: Int].self, forKey: .scores) ?? [:]
        self.categoryNotes = try c.decodeIfPresent([VisitedStore.ReviewCategory: String].self, forKey: .categoryNotes) ?? [:]
        self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.tags = try c.decodeIfPresent(String.self, forKey: .tags) ?? ""
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
    }

    var review: VisitedStore.StadiumReview? {
        let review = VisitedStore.StadiumReview(
            matchLabel: matchLabel,
            scores: scores,
            categoryNotes: categoryNotes,
            summary: summary,
            tags: tags,
            updatedAt: updatedAt
        )
        return review.hasMeaningfulContent ? review : nil
    }
}

struct SharedReviewWriteRow: Codable {
    let userId: String
    let clubId: String
    let matchLabel: String
    let scores: [VisitedStore.ReviewCategory: Int]
    let categoryNotes: [VisitedStore.ReviewCategory: String]
    let summary: String
    let tags: String
    let updatedAt: Date
    let source: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case clubId = "club_id"
        case matchLabel = "match_label"
        case scores
        case categoryNotes = "category_notes"
        case summary
        case tags
        case updatedAt = "updated_at"
        case source
    }
}

final class SharedReviewsSyncBackend {
    private let configuration: SharedReviewsSyncConfiguration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(configuration: SharedReviewsSyncConfiguration) {
        self.configuration = configuration
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func fetchAll() async throws -> [String: SharedReviewRecordDTO] {
        let request = try await authorizedRequest(
            path: "rest/v1/reviews?select=club_id,match_label,scores,category_notes,summary,tags,created_at,updated_at,source",
            method: "GET"
        )
        let records: [SharedReviewRecordDTO] = try await perform(request, decodeAs: [SharedReviewRecordDTO].self)
        return Dictionary(uniqueKeysWithValues: records.map { ($0.clubId, $0) })
    }

    func upsert(userId: String, clubId: String, review: VisitedStore.StadiumReview, updatedAt: Date) async throws {
        let payload = SharedReviewWriteRow(
            userId: userId,
            clubId: clubId,
            matchLabel: review.matchLabel,
            scores: review.scores,
            categoryNotes: review.categoryNotes,
            summary: review.summary,
            tags: review.tags,
            updatedAt: updatedAt,
            source: configuration.source
        )
        var request = try await authorizedRequest(
            path: "rest/v1/reviews?on_conflict=user_id,club_id",
            method: "POST"
        )
        request.httpBody = try encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        _ = try await performWithoutDecoding(request)
    }

    private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
        guard let baseURL = configuration.baseURL else {
            throw SharedReviewsSyncBackendError.notConfigured
        }
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw SharedReviewsSyncBackendError.notConfigured
        }
        guard let token = await configuration.authTokenProvider() else {
            throw SharedReviewsSyncBackendError.missingAuthToken
        }
        guard let url = resolvedURL(baseURL: baseURL, path: path) else {
            throw SharedReviewsSyncBackendError.invalidPayload
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
            throw SharedReviewsSyncBackendError.invalidPayload
        }
    }

    private func performWithoutDecoding(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await configuration.urlSession.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SharedReviewsSyncBackendError.invalidPayload
        }
        guard (200...299).contains(http.statusCode) else {
            throw SharedReviewsSyncBackendError.invalidHTTPStatus(
                http.statusCode,
                String(data: data, encoding: .utf8)
            )
        }
    }
}
