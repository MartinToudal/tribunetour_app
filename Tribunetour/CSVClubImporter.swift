import Foundation

// MARK: - Models

struct Stadium: Hashable {
    let name: String
    let city: String
    let latitude: Double
    let longitude: Double
}

struct Club: Identifiable, Hashable {
    /// Stabilt id fra CSV (ikke UUID), så listen opfører sig pænt.
    let id: String
    let name: String         // team
    let division: String     // league
    let stadium: Stadium     // name + lat/lon + city
}

// MARK: - CSV Import

enum CSVImportError: LocalizedError {
    case fileNotFound(String)
    case unreadable(String)
    case invalidHeader
    case invalidRow(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Kunne ikke finde CSV-filen i app bundle: \(name)"
        case .unreadable(let msg):
            return "Kunne ikke læse CSV-filen: \(msg)"
        case .invalidHeader:
            return "CSV header matcher ikke forventet format (mangler: id,name,team,league,city,lat,lon)."
        case .invalidRow(let row):
            return "Ugyldig række i CSV:\n\(row)"
        }
    }
}

struct CSVClubImporter {

    /// Forventer din CSV med header:
    /// id,name,team,league,city,lat,lon
    static func loadClubsFromBundle(csvFileName: String) throws -> [Club] {

        // ✅ Undgå Bundle.url(forResource:) som kan logge:
        // "Failed to locate resource named ..."
        guard let url = bundleCSVURL(named: csvFileName) else {
            throw CSVImportError.fileNotFound("\(csvFileName).csv")
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CSVImportError.unreadable(error.localizedDescription)
        }

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return [] }

        let header = splitCSVLine(lines[0]).map { $0.lowercased() }
        let headerIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

        let required = ["id", "name", "team", "league", "city", "lat", "lon"]
        guard required.allSatisfy({ headerIndex[$0] != nil }) else {
            throw CSVImportError.invalidHeader
        }

        func value(_ row: [String], _ key: String) -> String {
            guard let idx = headerIndex[key], idx < row.count else { return "" }
            return row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var clubs: [Club] = []
        clubs.reserveCapacity(lines.count - 1)

        for i in 1..<lines.count {
            let row = splitCSVLine(lines[i])

            let id = value(row, "id")
            let stadiumName = value(row, "name")
            let team = value(row, "team")
            let league = value(row, "league")
            let city = value(row, "city")

            guard
                !id.isEmpty,
                !stadiumName.isEmpty,
                !team.isEmpty,
                !league.isEmpty,
                !city.isEmpty
            else {
                throw CSVImportError.invalidRow(lines[i])
            }

            guard
                let lat = Double(value(row, "lat").replacingOccurrences(of: ",", with: ".")),
                let lon = Double(value(row, "lon").replacingOccurrences(of: ",", with: "."))
            else {
                throw CSVImportError.invalidRow(lines[i])
            }

            let stadium = Stadium(
                name: stadiumName,
                city: city,
                latitude: lat,
                longitude: lon
            )

            let club = Club(
                id: id,
                name: team,
                division: league,
                stadium: stadium
            )

            clubs.append(club)
        }

        return clubs
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

    /// Splitter en CSV-linje med støtte for simple quoted fields.
    /// Eksempel:  a,"b,c",d  -> ["a","b,c","d"]
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
