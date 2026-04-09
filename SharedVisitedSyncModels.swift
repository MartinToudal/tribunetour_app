import Foundation

struct SharedVisitedMigrationStateDTO: Codable {
    let bootstrapRequired: Bool
    let bootstrappedAt: Date?
    let bootstrapSource: String?

    enum CodingKeys: String, CodingKey {
        case bootstrapRequired = "bootstrap_required"
        case bootstrappedAt = "bootstrapped_at"
        case bootstrapSource = "bootstrap_source"
    }
}

struct SharedVisitedRecordDTO: Codable {
    let clubId: String
    let visited: Bool
    let visitedDate: Date?
    let updatedAt: Date?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case visited
        case visitedDate = "visited_date"
        case updatedAt = "updated_at"
        case source
    }

    func toRecord() -> VisitedStore.Record {
        VisitedStore.Record(
            visited: visited,
            visitedDate: visitedDate,
            updatedAt: updatedAt ?? .distantPast
        )
    }

    static func fromRecord(clubId: String, record: VisitedStore.Record, source: String) -> SharedVisitedRecordDTO {
        SharedVisitedRecordDTO(
            clubId: ClubIdentityResolver.canonicalId(for: clubId),
            visited: record.visited,
            visitedDate: record.visitedDate,
            updatedAt: record.updatedAt,
            source: source
        )
    }
}

struct SharedVisitedUpsertRequest: Codable {
    let visited: Bool
    let visitedDate: Date?
    let source: String

    enum CodingKeys: String, CodingKey {
        case visited
        case visitedDate = "visited_date"
        case source
    }

    static func fromRecord(_ record: VisitedStore.Record, source: String) -> SharedVisitedUpsertRequest {
        SharedVisitedUpsertRequest(
            visited: record.visited,
            visitedDate: record.visitedDate,
            source: source
        )
    }
}

struct SharedVisitedWriteRow: Codable {
    let clubId: String
    let visited: Bool
    let visitedDate: Date?
    let source: String

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case visited
        case visitedDate = "visited_date"
        case source
    }

    static func fromRecord(clubId: String, record: VisitedStore.Record, source: String) -> SharedVisitedWriteRow {
        SharedVisitedWriteRow(
            clubId: ClubIdentityResolver.canonicalId(for: clubId),
            visited: record.visited,
            visitedDate: record.visitedDate,
            source: source
        )
    }
}

struct SharedVisitedBootstrapRequest: Codable {
    let source: String
    let replaceExisting: Bool
    let items: [Item]

    struct Item: Codable {
        let clubId: String
        let visited: Bool
        let visitedDate: Date?

        enum CodingKeys: String, CodingKey {
            case clubId = "club_id"
            case visited
            case visitedDate = "visited_date"
        }
    }

    static func fromRecords(_ records: [String: VisitedStore.Record], source: String) -> SharedVisitedBootstrapRequest {
        let items = records
            .map { clubId, record in
                Item(
                    clubId: ClubIdentityResolver.canonicalId(for: clubId),
                    visited: record.visited,
                    visitedDate: record.visitedDate
                )
            }
            .sorted { $0.clubId < $1.clubId }

        return SharedVisitedBootstrapRequest(
            source: source,
            replaceExisting: true,
            items: items
        )
    }

    enum CodingKeys: String, CodingKey {
        case source
        case replaceExisting = "replace_existing"
        case items
    }
}

struct SharedVisitedBootstrapResponseDTO: Codable {
    let bootstrapped: Bool
    let bootstrapSource: String?
    let bootstrappedAt: Date?
    let itemCount: Int?

    enum CodingKeys: String, CodingKey {
        case bootstrapped
        case bootstrapSource = "bootstrap_source"
        case bootstrappedAt = "bootstrapped_at"
        case itemCount = "item_count"
    }
}
