import XCTest

final class MatchesFilteringTests: XCTestCase {
    struct MockClub {
        let id: String
        let name: String
        let stadiumName: String
        let city: String
    }

    struct MockFixture {
        let id: String
        let homeTeamId: String
        let awayTeamId: String
        let venueClubId: String
        let kickoff: Date
        let round: String?
    }

    func testFilteringPipeline() throws {
        // Setup calendar and dates
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let in3Days = cal.date(byAdding: .day, value: 3, to: todayStart)!
        let in8Days = cal.date(byAdding: .day, value: 8, to: todayStart)!

        // Clubs
        let clubs: [MockClub] = [
            .init(id: "A", name: "AGF", stadiumName: "Ceres Park", city: "Aarhus"),
            .init(id: "B", name: "AaB", stadiumName: "Aalborg Portland Park", city: "Aalborg"),
        ]
        let clubById = Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })

        // Fixtures spanning inside and outside the 7-day window
        let fixtures: [MockFixture] = [
            .init(id: "1", homeTeamId: "A", awayTeamId: "B", venueClubId: "A", kickoff: in3Days, round: "R1"),
            .init(id: "2", homeTeamId: "B", awayTeamId: "A", venueClubId: "B", kickoff: in8Days, round: "R2")
        ]

        // Visited store simulation
        var visited: Set<String> = []
        func isVisited(_ clubId: String) -> Bool { visited.contains(clubId) }

        // Search helper
        func normalizedContains(_ hay: String, _ needle: String) -> Bool {
            hay.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(needle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current))
        }

        // 1) Only future fixtures within 7 days
        let endExclusive = cal.date(byAdding: .day, value: 7, to: todayStart)!
        var base = fixtures.filter { $0.kickoff >= todayStart && $0.kickoff < endExclusive }
        XCTAssertEqual(base.map { $0.id }, ["1"]) // only the in-3-days fixture

        // 2) Only unvisited venues
        visited.insert("A")
        base = base.filter { !isVisited($0.venueClubId) }
        XCTAssertEqual(base.count, 0)

        // 3) Search by city/club/stadium/round
        // Reset visited filter for this part
        base = fixtures.filter { $0.kickoff >= todayStart && $0.kickoff < endExclusive }
        let q = "aarhus"
        let filtered = base.filter { f in
            let home = clubById[f.homeTeamId]?.name ?? f.homeTeamId
            let away = clubById[f.awayTeamId]?.name ?? f.awayTeamId
            let venue = clubById[f.venueClubId]?.stadiumName ?? f.venueClubId
            let city  = clubById[f.venueClubId]?.city ?? ""
            let round = f.round ?? ""
            let hay = "\(home) \(away) \(venue) \(city) \(round)"
            return normalizedContains(hay, q)
        }
        XCTAssertEqual(filtered.map { $0.id }, ["1"]) // matches Aarhus
    }
}
