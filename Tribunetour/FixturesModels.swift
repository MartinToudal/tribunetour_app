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

enum FixtureSeasonGuard {
    private static let pattern = try! NSRegularExpression(pattern: #"^(\d{4})-(\d{2}|\d{4})$"#)
    private static var utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    static func contains(_ fixture: Fixture) -> Bool {
        contains(kickoff: fixture.kickoff, seasonId: fixture.seasonId)
    }

    static func contains(kickoff: Date, seasonId: String?) -> Bool {
        guard let interval = inferredInterval(for: seasonId) else {
            return true
        }
        return interval.contains(kickoff)
    }

    static func inferredInterval(for seasonId: String?) -> DateInterval? {
        guard let rawSeason = seasonId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawSeason.isEmpty else {
            return nil
        }

        let nsRange = NSRange(rawSeason.startIndex..<rawSeason.endIndex, in: rawSeason)
        guard let match = pattern.firstMatch(in: rawSeason, options: [], range: nsRange),
              match.numberOfRanges == 3,
              let startRange = Range(match.range(at: 1), in: rawSeason),
              let endRange = Range(match.range(at: 2), in: rawSeason),
              let startYear = Int(rawSeason[startRange]) else {
            return nil
        }

        let endToken = String(rawSeason[endRange])
        let endYear: Int
        if endToken.count == 2, let shortYear = Int(endToken) {
            endYear = (startYear / 100) * 100 + shortYear
        } else if let fullYear = Int(endToken) {
            endYear = fullYear
        } else {
            return nil
        }

        guard
            let start = utcCalendar.date(from: DateComponents(year: startYear, month: 7, day: 1)),
            let endExclusive = utcCalendar.date(from: DateComponents(year: endYear, month: 8, day: 1)),
            start < endExclusive
        else {
            return nil
        }

        return DateInterval(start: start, end: endExclusive)
    }
}
