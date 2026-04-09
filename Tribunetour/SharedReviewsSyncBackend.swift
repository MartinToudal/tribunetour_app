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

    init(
        clubId: String,
        matchLabel: String,
        scores: [VisitedStore.ReviewCategory: Int],
        categoryNotes: [VisitedStore.ReviewCategory: String],
        summary: String,
        tags: String,
        updatedAt: Date,
        createdAt: Date?,
        source: String?
    ) {
        self.clubId = clubId
        self.matchLabel = matchLabel
        self.scores = scores
        self.categoryNotes = categoryNotes
        self.summary = summary
        self.tags = tags
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.clubId = try c.decode(String.self, forKey: .clubId)
        self.matchLabel = try c.decodeIfPresent(String.self, forKey: .matchLabel) ?? ""
        self.scores = Self.decodeScores(from: c)
        self.categoryNotes = Self.decodeCategoryNotes(from: c)
        self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.tags = try c.decodeIfPresent(String.self, forKey: .tags) ?? ""
        self.updatedAt = try Self.decodeDate(from: c, forKey: .updatedAt)
        self.createdAt = try Self.decodeDateIfPresent(from: c, forKey: .createdAt)
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

    private static func decodeScores(from container: KeyedDecodingContainer<CodingKeys>) -> [VisitedStore.ReviewCategory: Int] {
        if let rawScores = try? container.decodeIfPresent([String: Double].self, forKey: .scores) {
            return rawScores.reduce(into: [:]) { partialResult, entry in
                guard let category = VisitedStore.ReviewCategory(rawValue: entry.key) else { return }
                partialResult[category] = Int(entry.value.rounded())
            }
        }

        // Backward-compatibility for malformed payloads written as flat arrays:
        // ["facilities", 7, "atmosphereSound", 8]
        if let rawPairs = try? container.decodeIfPresent([JSONValue].self, forKey: .scores) {
            return decodeScorePairs(rawPairs)
        }

        return [:]
    }

    private static func decodeCategoryNotes(from container: KeyedDecodingContainer<CodingKeys>) -> [VisitedStore.ReviewCategory: String] {
        if let rawNotes = try? container.decodeIfPresent([String: String].self, forKey: .categoryNotes) {
            return rawNotes.reduce(into: [:]) { partialResult, entry in
                guard let category = VisitedStore.ReviewCategory(rawValue: entry.key) else { return }
                let trimmed = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                partialResult[category] = entry.value
            }
        }

        // Backward-compatibility for malformed payloads written as flat arrays:
        // ["facilities", "ok", "valueForMoney", "fair"]
        if let rawPairs = try? container.decodeIfPresent([JSONValue].self, forKey: .categoryNotes) {
            return decodeCategoryNotePairs(rawPairs)
        }

        return [:]
    }

    private static func decodeDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Date {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }

        let rawValue = try container.decode(String.self, forKey: key)
        if let parsed = parseDate(rawValue) {
            return parsed
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Ugyldigt datoformat: \(rawValue)"
        )
    }

    private static func decodeDateIfPresent(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Date? {
        guard let rawValue = try container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        return parseDate(rawValue)
    }

    private static func parseDate(_ rawValue: String) -> Date? {
        if let date = iso8601WithFractionalFormatter.date(from: rawValue) {
            return date
        }
        return iso8601Formatter.date(from: rawValue)
    }

    private static let iso8601WithFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func decodeScorePairs(_ values: [JSONValue]) -> [VisitedStore.ReviewCategory: Int] {
        var result: [VisitedStore.ReviewCategory: Int] = [:]
        var index = 0

        while index + 1 < values.count {
            guard
                case .string(let rawCategory) = values[index],
                let category = VisitedStore.ReviewCategory(rawValue: rawCategory),
                let score = values[index + 1].numberValue
            else {
                index += 2
                continue
            }

            result[category] = Int(score.rounded())
            index += 2
        }

        return result
    }

    private static func decodeCategoryNotePairs(_ values: [JSONValue]) -> [VisitedStore.ReviewCategory: String] {
        var result: [VisitedStore.ReviewCategory: String] = [:]
        var index = 0

        while index + 1 < values.count {
            guard
                case .string(let rawCategory) = values[index],
                let category = VisitedStore.ReviewCategory(rawValue: rawCategory),
                case .string(let note) = values[index + 1]
            else {
                index += 2
                continue
            }

            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result[category] = note
            }
            index += 2
        }

        return result
    }
}

struct SharedReviewWriteRow: Codable {
    let userId: String
    let clubId: String
    let matchLabel: String
    let scores: [String: Int]
    let categoryNotes: [String: String]
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

private enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSONValue")
            )
        }
    }

    var numberValue: Double? {
        if case .number(let number) = self {
            return number
        }
        return nil
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
        return Dictionary(
            uniqueKeysWithValues: normalizedRecords(records).map { ($0.clubId, $0) }
        )
    }

    func upsert(userId: String, clubId: String, review: VisitedStore.StadiumReview, updatedAt: Date) async throws {
        let payload = SharedReviewWriteRow(
            userId: userId,
            clubId: ClubIdentityResolver.canonicalId(for: clubId),
            matchLabel: review.matchLabel,
            scores: Dictionary(uniqueKeysWithValues: review.scores.map { ($0.key.rawValue, $0.value) }),
            categoryNotes: Dictionary(uniqueKeysWithValues: review.categoryNotes.map { ($0.key.rawValue, $0.value) }),
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

    private func normalizedRecords(_ records: [SharedReviewRecordDTO]) -> [SharedReviewRecordDTO] {
        var result: [String: SharedReviewRecordDTO] = [:]

        for record in records {
            let canonicalId = ClubIdentityResolver.canonicalId(for: record.clubId)
            let normalized = SharedReviewRecordDTO(
                clubId: canonicalId,
                matchLabel: record.matchLabel,
                scores: record.scores,
                categoryNotes: record.categoryNotes,
                summary: record.summary,
                tags: record.tags,
                updatedAt: record.updatedAt,
                createdAt: record.createdAt,
                source: record.source
            )

            if let existing = result[canonicalId], existing.updatedAt >= normalized.updatedAt {
                continue
            }

            result[canonicalId] = normalized
        }

        return Array(result.values)
    }
}
