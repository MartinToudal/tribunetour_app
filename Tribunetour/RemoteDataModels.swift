import Foundation

struct RemoteDatasetEnvelope: Decodable {
    struct Metadata: Decodable {
        let version: String?
        let generatedAt: Date?
        let checksum: String?
        let signature: String?
    }

    let metadata: Metadata?
    let fixtures: [RemoteFixtureDTO]
}

struct RemoteFixtureDTO: Decodable {
    let id: String
    let kickoff: String
    let round: String?
    let homeTeamId: String
    let awayTeamId: String
    let venueClubId: String
    let status: String
    let homeScore: Int?
    let awayScore: Int?
    let competitionId: String?
    let seasonId: String?

    func toFixture() throws -> Fixture {
        guard let kickoffDate = Self.parseISODate(kickoff) else {
            throw RemoteFixtureError.invalidKickoff(id: id, value: kickoff)
        }
        guard let mappedStatus = MatchStatus(rawValue: status.lowercased()) else {
            throw RemoteFixtureError.invalidStatus(id: id, value: status)
        }

        return Fixture(
            id: id,
            kickoff: kickoffDate,
            round: round,
            homeTeamId: homeTeamId,
            awayTeamId: awayTeamId,
            venueClubId: venueClubId,
            status: mappedStatus,
            homeScore: homeScore,
            awayScore: awayScore,
            competitionId: competitionId,
            seasonId: seasonId
        )
    }

    private static func parseISODate(_ value: String) -> Date? {
        let primary = ISO8601DateFormatter()
        primary.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = primary.date(from: value) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
}

enum RemoteFixtureError: LocalizedError {
    case invalidKickoff(id: String, value: String)
    case invalidStatus(id: String, value: String)

    var errorDescription: String? {
        switch self {
        case .invalidKickoff(let id, let value):
            return "Ugyldigt kickoff for fixture \(id): \(value)"
        case .invalidStatus(let id, let value):
            return "Ugyldig status for fixture \(id): \(value)"
        }
    }
}
