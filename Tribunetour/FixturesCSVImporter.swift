import Foundation

enum FixturesCSVError: LocalizedError {
    case fileNotFound(String)
    case unreadable(String)
    case invalidHeader
    case invalidRow(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Kunne ikke finde fixtures CSV i app bundle: \(name)"
        case .unreadable(let msg):
            return "Kunne ikke læse fixtures CSV: \(msg)"
        case .invalidHeader:
            return "fixtures.csv header matcher ikke forventet format."
        case .invalidRow(let row):
            return "Ugyldig række i fixtures.csv:\n\(row)"
        }
    }
}

struct FixturesCSVImporter {

    /// Forventer header:
    /// id,kickoff,round,homeTeamId,awayTeamId,venueClubId,status,homeScore,awayScore
    static func loadFixturesFromBundle(csvFileName: String) throws -> [Fixture] {

        // ✅ Undgå Bundle.url(forResource:) som kan give console-støj
        guard let url = bundleCSVURL(named: csvFileName) else {
            throw FixturesCSVError.fileNotFound("\(csvFileName).csv")
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw FixturesCSVError.unreadable(error.localizedDescription)
        }

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return [] }

        let header = splitCSVLine(lines[0]).map { $0.lowercased() }
        let headerIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

        let required = ["id","kickoff","round","hometeamid","awayteamid","venueclubid","status","homescore","awayscore"]
        guard required.allSatisfy({ headerIndex[$0] != nil }) else {
            throw FixturesCSVError.invalidHeader
        }

        func value(_ row: [String], _ key: String) -> String {
            guard let idx = headerIndex[key], idx < row.count else { return "" }
            return row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // ISO8601 med timezone (fx +01:00) – med/uden fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func parseISO(_ s: String) -> Date? {
            if let d = iso.date(from: s) { return d }
            let iso2 = ISO8601DateFormatter()
            iso2.formatOptions = [.withInternetDateTime]
            return iso2.date(from: s)
        }

        var fixtures: [Fixture] = []
        fixtures.reserveCapacity(lines.count - 1)

        for i in 1..<lines.count {
            let raw = lines[i]
            let row = splitCSVLine(raw)

            let id = value(row, "id")
            let kickoffStr = value(row, "kickoff")
            let roundStr = value(row, "round")
            let home = value(row, "hometeamid")
            let away = value(row, "awayteamid")
            let venue = value(row, "venueclubid")
            let statusStr = value(row, "status")

            let homeScoreStr = value(row, "homescore")
            let awayScoreStr = value(row, "awayscore")

            guard
                !id.isEmpty,
                let kickoff = parseISO(kickoffStr),
                !home.isEmpty,
                !away.isEmpty,
                !venue.isEmpty,
                let status = MatchStatus(rawValue: statusStr.lowercased())
            else {
                throw FixturesCSVError.invalidRow(raw)
            }

            // scores kan være tomme
            let homeScore = Int(homeScoreStr.trimmingCharacters(in: .whitespacesAndNewlines))
            let awayScore = Int(awayScoreStr.trimmingCharacters(in: .whitespacesAndNewlines))

            fixtures.append(
                Fixture(
                    id: id,
                    kickoff: kickoff,
                    round: roundStr.isEmpty ? nil : roundStr,
                    homeTeamId: home,
                    awayTeamId: away,
                    venueClubId: venue,
                    status: status,
                    homeScore: homeScore,
                    awayScore: awayScore
                )
            )
        }

        fixtures.sort { $0.kickoff < $1.kickoff }
        return fixtures
    }

    // MARK: - Bundle lookup (no noisy logs)

    private static var cachedCSVURLs: [URL] = []

    private static func bundleCSVURL(named name: String) -> URL? {
        if cachedCSVURLs.isEmpty {
            cachedCSVURLs = Bundle.main.urls(forResourcesWithExtension: "csv", subdirectory: nil) ?? []
        }
        let target = (name + ".csv").lowercased()
        return cachedCSVURLs.first { $0.lastPathComponent.lowercased() == target }
    }

    // MARK: - CSV splitting

    /// Robust CSV splitter med simple quoted fields.
    private static func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]

            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }

            i = line.index(after: i)
        }

        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
