import Foundation

enum AppLeaguePackId: String, CaseIterable {
    case coreDenmark = "core_denmark"
    case germanyTop3 = "germany_top_3"
}

enum AppLeaguePackSettings {
    static let germanyTop3EnabledKey = "leaguePacks.germanyTop3.enabled"
    static let remoteEnabledLeaguePacksKey = "leaguePacks.remote.enabled"

    static var debugEnabledLeaguePacks: Set<String> {
        var ids = Set<String>()
        if UserDefaults.standard.bool(forKey: germanyTop3EnabledKey) {
            ids.insert(AppLeaguePackId.germanyTop3.rawValue)
        }
        return ids
    }

    static var remoteEnabledLeaguePacks: Set<String> {
        let values = UserDefaults.standard.array(forKey: remoteEnabledLeaguePacksKey) as? [String] ?? []
        return Set(values)
    }

    static var effectiveEnabledLeaguePacks: Set<String> {
        var ids: Set<String> = [AppLeaguePackId.coreDenmark.rawValue]
        ids.formUnion(debugEnabledLeaguePacks)
        ids.formUnion(remoteEnabledLeaguePacks)
        return ids
    }

    static var germanyTop3Enabled: Bool {
        effectiveEnabledLeaguePacks.contains(AppLeaguePackId.germanyTop3.rawValue)
    }

    static func setRemoteEnabledLeaguePacks(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids).sorted(), forKey: remoteEnabledLeaguePacksKey)
    }

    static func clearRemoteEnabledLeaguePacks() {
        UserDefaults.standard.removeObject(forKey: remoteEnabledLeaguePacksKey)
    }
}

struct SharedLeaguePackAccessConfiguration {
    let baseURL: URL?
    let apiKey: String?
    let authTokenProvider: @Sendable () async -> String?
    let urlSession: URLSession
}

enum SharedLeaguePackAccessError: LocalizedError {
    case notConfigured
    case missingAuthToken
    case invalidPayload
    case invalidHTTPStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "League pack access er ikke konfigureret."
        case .missingAuthToken:
            return "League pack access mangler auth-token."
        case .invalidPayload:
            return "League pack access-svaret kunne ikke læses."
        case .invalidHTTPStatus(let code, let body):
            return body.isEmpty ? "League pack access fejlede med status \(code)." : body
        }
    }
}

private struct SharedLeaguePackAccessRow: Decodable {
    let packKey: String
    let enabled: Bool

    private enum CodingKeys: String, CodingKey {
        case packKey = "pack_key"
        case enabled
    }
}

final class SharedLeaguePackAccessBackend {
    private let configuration: SharedLeaguePackAccessConfiguration

    init(configuration: SharedLeaguePackAccessConfiguration) {
        self.configuration = configuration
    }

    func fetchEnabledLeaguePacks() async throws -> Set<String> {
        guard
            let baseURL = configuration.baseURL,
            let apiKey = configuration.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
            !apiKey.isEmpty
        else {
            throw SharedLeaguePackAccessError.notConfigured
        }

        guard let token = await configuration.authTokenProvider() else {
            throw SharedLeaguePackAccessError.missingAuthToken
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/user_league_pack_access"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "pack_key,enabled"),
            URLQueryItem(name: "enabled", value: "eq.true")
        ]

        guard let url = components?.url else {
            throw SharedLeaguePackAccessError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await configuration.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SharedLeaguePackAccessError.invalidPayload
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SharedLeaguePackAccessError.invalidHTTPStatus(http.statusCode, body)
        }

        let rows = try JSONDecoder().decode([SharedLeaguePackAccessRow].self, from: data)
        return Set(rows.filter(\.enabled).map(\.packKey))
    }
}

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
    let countryCode: String
    let leagueCode: String?
    let leaguePack: String
    let shortCode: String?

    init(
        id: String,
        name: String,
        division: String,
        stadium: Stadium,
        countryCode: String = "dk",
        leagueCode: String? = nil,
        leaguePack: String = "core_denmark",
        shortCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.division = division
        self.stadium = stadium
        self.countryCode = countryCode
        self.leagueCode = leagueCode
        self.leaguePack = leaguePack
        self.shortCode = shortCode
    }
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

        return try loadClubs(fromCSVText: text)
    }

    static func loadEnabledClubsFromBundle(csvFileName: String) throws -> [Club] {
        try loadEnabledClubsFromBundle(
            csvFileName: csvFileName,
            enabledLeaguePacks: AppLeaguePackSettings.effectiveEnabledLeaguePacks
        )
    }

    static func loadEnabledClubsFromBundle(
        csvFileName: String,
        enabledLeaguePacks: Set<String>
    ) throws -> [Club] {
        var clubs = try loadClubsFromBundle(csvFileName: csvFileName)

        if enabledLeaguePacks.contains(AppLeaguePackId.germanyTop3.rawValue) {
            clubs.append(contentsOf: try loadClubs(fromCSVText: germanyTop3CSV, defaultCountryCode: "de", defaultLeaguePack: "germany_top_3"))
        }

        return clubs
    }

    private static func loadClubs(
        fromCSVText text: String,
        defaultCountryCode: String = "dk",
        defaultLeaguePack: String = "core_denmark"
    ) throws -> [Club] {
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
            let countryCode = value(row, "country_code").nonEmpty ?? defaultCountryCode
            let leagueCode = value(row, "league_code").nonEmpty
            let leaguePack = value(row, "league_pack").nonEmpty ?? defaultLeaguePack
            let shortCode = value(row, "short_code").nonEmpty

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
                stadium: stadium,
                countryCode: countryCode,
                leagueCode: leagueCode,
                leaguePack: leaguePack,
                shortCode: shortCode
            )

            clubs.append(club)
        }

        return clubs
    }

    private static let germanyTop3CSV = """
id,name,team,league,city,lat,lon,country_code,league_code,league_pack,short_code
de-bayern-munchen,Allianz Arena,FC Bayern München,Bundesliga,München,48.2187901,11.6236227,de,de-bundesliga,germany_top_3,FCB
de-bayer-leverkusen,BayArena,Bayer 04 Leverkusen,Bundesliga,Leverkusen,51.0381439,7.0030964,de,de-bundesliga,germany_top_3,B04
de-eintracht-frankfurt,Deutsche Bank Park,Eintracht Frankfurt,Bundesliga,Frankfurt am Main,50.0686103,8.6454154,de,de-bundesliga,germany_top_3,SGE
de-borussia-dortmund,SIGNAL IDUNA PARK,Borussia Dortmund,Bundesliga,Dortmund,51.4924922,7.4518549,de,de-bundesliga,germany_top_3,BVB
de-sc-freiburg,Europa-Park Stadion,Sport-Club Freiburg,Bundesliga,Freiburg im Breisgau,48.0213778,7.829817,de,de-bundesliga,germany_top_3,SCF
de-mainz-05,MEWA ARENA,1. FSV Mainz 05,Bundesliga,Mainz,49.9839451,8.2244738,de,de-bundesliga,germany_top_3,M05
de-rb-leipzig,Red Bull Arena,RB Leipzig,Bundesliga,Leipzig,51.3457079,12.3482361,de,de-bundesliga,germany_top_3,RBL
de-werder-bremen,Weserstadion,SV Werder Bremen,Bundesliga,Bremen,53.0664479,8.8376718,de,de-bundesliga,germany_top_3,SVW
de-vfb-stuttgart,MHPArena,VfB Stuttgart,Bundesliga,Stuttgart,48.7922487,9.2320857,de,de-bundesliga,germany_top_3,VFB
de-borussia-monchengladbach,BORUSSIA-PARK,Borussia Mönchengladbach,Bundesliga,Mönchengladbach,51.174625,6.3854094,de,de-bundesliga,germany_top_3,BMG
de-vfl-wolfsburg,Volkswagen Arena,VfL Wolfsburg,Bundesliga,Wolfsburg,52.4328584,10.803104,de,de-bundesliga,germany_top_3,WOB
de-fc-augsburg,WWK ARENA,FC Augsburg,Bundesliga,Augsburg,48.3231179,10.885879,de,de-bundesliga,germany_top_3,FCA
de-union-berlin,Stadion An der Alten Försterei,1. FC Union Berlin,Bundesliga,Berlin,52.4569741,13.5680789,de,de-bundesliga,germany_top_3,FCU
de-fc-st-pauli,Millerntor-Stadion,FC St. Pauli,Bundesliga,Hamburg,53.5545567,9.9677842,de,de-bundesliga,germany_top_3,FCP
de-tsg-hoffenheim,PreZero Arena,TSG Hoffenheim,Bundesliga,Sinsheim,49.2380604,8.8876414,de,de-bundesliga,germany_top_3,TSG
de-heidenheim,Voith-Arena,1. FC Heidenheim 1846,Bundesliga,Heidenheim an der Brenz,48.6685245,10.1392963,de,de-bundesliga,germany_top_3,FCH
de-fc-koln,RheinEnergieSTADION,1. FC Köln,Bundesliga,Köln,50.9335055,6.8751167,de,de-bundesliga,germany_top_3,KOE
de-hamburger-sv,Volksparkstadion,Hamburger SV,Bundesliga,Hamburg,53.5871535,9.8987056,de,de-bundesliga,germany_top_3,HSV
de-sv-darmstadt-98,Merck-Stadion am Böllenfalltor,SV Darmstadt 98,2. Bundesliga,Darmstadt,49.85771,8.6724145,de,de-2-bundesliga,germany_top_3,D98
de-sv-elversberg,URSAPHARM-Arena,SV Elversberg,2. Bundesliga,Spiesen-Elversberg,49.3188046,7.1215724,de,de-2-bundesliga,germany_top_3,SVE
de-hannover-96,Heinz von Heiden Arena,Hannover 96,2. Bundesliga,Hannover,52.360026,9.7310161,de,de-2-bundesliga,germany_top_3,H96
de-magdeburg,Avnet Arena,1. FC Magdeburg,2. Bundesliga,Magdeburg,52.1248901,11.6706866,de,de-2-bundesliga,germany_top_3,FCM
de-sc-paderborn-07,Home Deluxe Arena,SC Paderborn 07,2. Bundesliga,Paderborn,51.7308967,8.7109633,de,de-2-bundesliga,germany_top_3,SCP
de-arminia-bielefeld,SchücoArena,DSC Arminia Bielefeld,2. Bundesliga,Bielefeld,52.0320259,8.5167762,de,de-2-bundesliga,germany_top_3,DSC
de-kaiserslautern,Fritz-Walter-Stadion,1. FC Kaiserslautern,2. Bundesliga,Kaiserslautern,49.4345765,7.7766303,de,de-2-bundesliga,germany_top_3,FCKL
de-dynamo-dresden,Rudolf-Harbig-Stadion,SG Dynamo Dresden,2. Bundesliga,Dresden,51.040849,13.7480416,de,de-2-bundesliga,germany_top_3,SGD
de-holstein-kiel,Holstein-Stadion,Holstein Kiel,2. Bundesliga,Kiel,54.3492088,10.1237559,de,de-2-bundesliga,germany_top_3,KSV
de-preussen-munster,LVM-Preußenstadion,SC Preußen Münster,2. Bundesliga,Münster,51.9318157,7.626097,de,de-2-bundesliga,germany_top_3,SCPM
de-schalke-04,VELTINS-Arena,FC Schalke 04,2. Bundesliga,Gelsenkirchen,51.5545938,7.0676001,de,de-2-bundesliga,germany_top_3,S04
de-hertha-bsc,Olympiastadion,Hertha BSC,2. Bundesliga,Berlin,52.5145846,13.2398144,de,de-2-bundesliga,germany_top_3,BSC
de-karlsruher-sc,BBBank Wildpark,Karlsruher SC,2. Bundesliga,Karlsruhe,49.0200043,8.4129879,de,de-2-bundesliga,germany_top_3,KSC
de-eintracht-braunschweig,EINTRACHT-STADION,Eintracht Braunschweig,2. Bundesliga,Braunschweig,52.2901014,10.5214686,de,de-2-bundesliga,germany_top_3,EBS
de-fortuna-dusseldorf,Merkur Spielarena,Fortuna Düsseldorf,2. Bundesliga,Düsseldorf,51.2616291,6.7331516,de,de-2-bundesliga,germany_top_3,F95
de-vfl-bochum,Vonovia Ruhrstadion,VfL Bochum 1848,2. Bundesliga,Bochum,51.4900826,7.2365091,de,de-2-bundesliga,germany_top_3,BOC
de-nurnberg,Max-Morlock-Stadion,1. FC Nürnberg,2. Bundesliga,Nürnberg,49.426257,11.1256706,de,de-2-bundesliga,germany_top_3,FCN
de-greuther-furth,Sportpark Ronhof | Thomas Sommer,SpVgg Greuther Fürth,2. Bundesliga,Fürth,49.4871453,10.9988931,de,de-2-bundesliga,germany_top_3,SGF
de-energie-cottbus,LEAG Energie Stadion,Energie Cottbus,3. Liga,Cottbus,51.7516231,14.345579,de,de-3-liga,germany_top_3,FCE
de-msv-duisburg,Schauinsland-Reisen-Arena,MSV Duisburg,3. Liga,Duisburg,51.4095005,6.7771895,de,de-3-liga,germany_top_3,MSV
de-sc-verl,Sportclub Arena,SC Verl,3. Liga,Verl,51.883499,8.5133824,de,de-3-liga,germany_top_3,SCV
de-vfl-osnabruck,Bremer Brücke,VfL Osnabrück,3. Liga,Osnabrück,52.2808323,8.0712775,de,de-3-liga,germany_top_3,OSN
de-hansa-rostock,Ostseestadion,FC Hansa Rostock,3. Liga,Rostock,54.0850095,12.0950945,de,de-3-liga,germany_top_3,FCHR
de-rot-weiss-essen,Stadion an der Hafenstraße,Rot-Weiss Essen,3. Liga,Essen,51.4868685,6.9766158,de,de-3-liga,germany_top_3,RWE
de-1860-munchen,Städtisches Stadion an der Grünwalder Straße,TSV 1860 München,3. Liga,München,48.1110013,11.5744172,de,de-3-liga,germany_top_3,TSV
de-tsg-hoffenheim-ii,Dietmar-Hopp-Stadion,TSG Hoffenheim II,3. Liga,Sinsheim,49.2782944,8.8422013,de,de-3-liga,germany_top_3,TSG2
de-waldhof-mannheim,Carl-Benz-Stadion,SV Waldhof Mannheim,3. Liga,Mannheim,49.4794201,8.5025049,de,de-3-liga,germany_top_3,SVWM
de-wehen-wiesbaden,BRITA-Arena,SV Wehen Wiesbaden,3. Liga,Wiesbaden,50.0712853,8.2566478,de,de-3-liga,germany_top_3,SVWW
de-viktoria-koln,Sportpark Höhenberg,FC Viktoria Köln,3. Liga,Köln,50.945109,7.0304736,de,de-3-liga,germany_top_3,VIK
de-vfb-stuttgart-ii,Robert-Schlienz-Stadion,VfB Stuttgart II,3. Liga,Stuttgart,48.7904688,9.2338466,de,de-3-liga,germany_top_3,VFB2
de-fc-ingolstadt-04,Audi Sportpark,FC Ingolstadt 04,3. Liga,Ingolstadt,48.7452797,11.4855268,de,de-3-liga,germany_top_3,FCI
de-saarbrucken,Ludwigsparkstadion,1. FC Saarbrücken,3. Liga,Saarbrücken,49.248083,6.9838944,de,de-3-liga,germany_top_3,FCS
de-jahn-regensburg,Jahnstadion Regensburg,SSV Jahn Regensburg,3. Liga,Regensburg,48.9908566,12.1073501,de,de-3-liga,germany_top_3,SSVJ
de-alemannia-aachen,Tivoli,Alemannia Aachen,3. Liga,Aachen,50.7931119,6.0964285,de,de-3-liga,germany_top_3,AAC
de-erzgebirge-aue,Erzgebirgsstadion,FC Erzgebirge Aue,3. Liga,Aue-Bad Schlema,50.5977903,12.7113047,de,de-3-liga,germany_top_3,AUE
de-ssv-ulm-1846,Donaustadion,SSV Ulm 1846 Fußball,3. Liga,Ulm,48.4045183,10.00939,de,de-3-liga,germany_top_3,ULM
de-tsv-havelse,Wilhelm-Langrehr-Stadion,TSV Havelse,3. Liga,Garbsen,52.4088683,9.6019752,de,de-3-liga,germany_top_3,HAV
de-schweinfurt-05,Sachs-Stadion,1. FC Schweinfurt 05,3. Liga,Schweinfurt,50.051994,10.2016834,de,de-3-liga,germany_top_3,S05
"""

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

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
