import Foundation

enum MatchStatus: String, Codable, CaseIterable {
    case scheduled
    case live
    case finished
    case postponed
    case cancelled
}

struct Fixture: Identifiable, Codable, Hashable {
    let id: String
    let kickoff: Date
    let round: String?

    let homeTeamId: String   // Club.id
    let awayTeamId: String   // Club.id
    let venueClubId: String  // typisk homeTeamId

    let status: MatchStatus
    let homeScore: Int?
    let awayScore: Int?
}
