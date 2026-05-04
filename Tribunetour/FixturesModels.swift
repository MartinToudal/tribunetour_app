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
    let competitionId: String?
    let seasonId: String?

    init(
        id: String,
        kickoff: Date,
        round: String?,
        homeTeamId: String,
        awayTeamId: String,
        venueClubId: String,
        status: MatchStatus,
        homeScore: Int?,
        awayScore: Int?,
        competitionId: String? = nil,
        seasonId: String? = nil
    ) {
        self.id = id
        self.kickoff = kickoff
        self.round = round
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.venueClubId = venueClubId
        self.status = status
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.competitionId = competitionId
        self.seasonId = seasonId
    }
}
