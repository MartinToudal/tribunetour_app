import Foundation

enum LeaguePresentation {
    static func countryRank(_ countryCode: String) -> Int {
        AppLeaguePackCatalog.countryRank(countryCode)
    }

    static func countryLabel(_ countryCode: String) -> String {
        AppLeaguePackCatalog.countryLabel(countryCode)
    }

    static func normalizedDivision(_ division: String) -> String {
        CompetitionCatalog.normalizedCompetitionName(division)
    }

    static func divisionRank(_ division: String, countryCode: String) -> Int {
        CompetitionCatalog.sortOrder(
            competitionId: nil,
            leagueCode: nil,
            leagueName: division,
            countryCode: countryCode
        )
    }

    static func divisionDisplayName(_ division: String, countryCode: String) -> String {
        let canonicalDivision = CompetitionCatalog.displayName(
            competitionId: nil,
            leagueCode: nil,
            fallbackLeagueName: division,
            countryCode: countryCode
        )
        return "\(countryLabel(countryCode)) - \(canonicalDivision)"
    }

    static func resolvedHomeCountryCode(availableCountryCodes: Set<String>) -> String {
        let preferred = UserDefaults.standard.string(forKey: AppLeaguePackSettings.preferredHomeCountryCodeKey) ?? "dk"
        if availableCountryCodes.contains(preferred) {
            return preferred
        }
        if availableCountryCodes.contains("dk") {
            return "dk"
        }
        return availableCountryCodes.sorted { lhs, rhs in
            if countryRank(lhs) != countryRank(rhs) {
                return countryRank(lhs) < countryRank(rhs)
            }
            return countryLabel(lhs).localizedCaseInsensitiveCompare(countryLabel(rhs)) == .orderedAscending
        }.first ?? "all"
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
    let primaryCompetitionId: String?
    let primarySeasonId: String?
    let membershipStatus: CompetitionMembershipStatus
    let competitionMemberships: [CompetitionMembership]

    init(
        id: String,
        name: String,
        division: String,
        stadium: Stadium,
        countryCode: String = "dk",
        leagueCode: String? = nil,
        leaguePack: String = "core_denmark",
        shortCode: String? = nil,
        primaryCompetitionId: String? = nil,
        primarySeasonId: String? = nil,
        membershipStatus: CompetitionMembershipStatus = .active,
        competitionMemberships: [CompetitionMembership] = []
    ) {
        self.id = id
        self.name = name
        self.division = division
        self.stadium = stadium
        self.countryCode = countryCode
        self.leagueCode = leagueCode
        self.leaguePack = leaguePack
        self.shortCode = shortCode
        self.primaryCompetitionId = primaryCompetitionId
        self.primarySeasonId = primarySeasonId
        self.membershipStatus = membershipStatus

        if competitionMemberships.isEmpty, let primaryCompetitionId {
            self.competitionMemberships = [
                CompetitionMembership(
                    competitionId: primaryCompetitionId,
                    seasonId: primarySeasonId,
                    status: membershipStatus,
                    isPrimary: true
                )
            ]
        } else {
            self.competitionMemberships = competitionMemberships
        }
    }

    var primaryMembership: CompetitionMembership? {
        competitionMemberships.first(where: \.isPrimary)
    }

    var secondaryMemberships: [CompetitionMembership] {
        competitionMemberships.filter { !$0.isPrimary }
    }

    var countsTowardTopSystemProgression: Bool {
        membershipStatus == .active && CompetitionCatalog.isPrimaryDomesticCompetition(primaryCompetitionId)
    }

    var shouldRemainVisibleOutsideTopSystem: Bool {
        membershipStatus != .active || !secondaryMemberships.isEmpty
    }

    var membershipStatusLabel: String? {
        switch membershipStatus {
        case .active:
            return nil
        case .relegated:
            return "Nedrykket"
        case .historical:
            return "Historisk"
        }
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
        if enabledLeaguePacks.contains(AppLeaguePackId.englandTop4.rawValue) {
            clubs.append(contentsOf: try loadClubs(fromCSVText: englandTop4CSV, defaultCountryCode: "en", defaultLeaguePack: "england_top_4"))
        }
        if enabledLeaguePacks.contains(AppLeaguePackId.italyTop3.rawValue) {
            clubs.append(contentsOf: try loadClubsFromBundle(csvFileName: "italy_top_3"))
        }
        if enabledLeaguePacks.contains(AppLeaguePackId.spainTop4.rawValue) {
            clubs.append(contentsOf: try loadClubsFromBundle(csvFileName: "spain_top_4"))
        }
        if enabledLeaguePacks.contains(AppLeaguePackId.franceTop3.rawValue) {
            clubs.append(contentsOf: try loadClubsFromBundle(csvFileName: "france_top_3"))
        }
        if enabledLeaguePacks.contains(AppLeaguePackId.portugalTop3.rawValue) {
            clubs.append(contentsOf: try loadClubsFromBundle(csvFileName: "portugal_top_3"))
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

        func splitMultiValue(_ raw: String) -> [String] {
            raw
                .split(whereSeparator: { $0 == "|" || $0 == ";" || $0 == "," })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
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
            let primaryCompetitionId =
                value(row, "competition_id").nonEmpty ??
                CompetitionCatalog.inferredCompetitionId(
                    leagueCode: leagueCode,
                    leagueName: league,
                    countryCode: countryCode
                )
            let primarySeasonId = value(row, "season_id").nonEmpty
            let membershipStatus = CompetitionMembershipStatus(rawValue: value(row, "membership_status").lowercased()) ?? .active
            let secondaryCompetitionIds = splitMultiValue(value(row, "secondary_competition_ids"))

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
                shortCode: shortCode,
                primaryCompetitionId: primaryCompetitionId,
                primarySeasonId: primarySeasonId,
                membershipStatus: membershipStatus,
                competitionMemberships: {
                    var memberships: [CompetitionMembership] = []
                    if let primaryCompetitionId {
                        memberships.append(
                            CompetitionMembership(
                                competitionId: primaryCompetitionId,
                                seasonId: primarySeasonId,
                                status: membershipStatus,
                                isPrimary: true
                            )
                        )
                    }
                    memberships.append(
                        contentsOf: secondaryCompetitionIds.map {
                            CompetitionMembership(
                                competitionId: $0,
                                seasonId: primarySeasonId,
                                status: .active,
                                isPrimary: false
                            )
                        }
                    )
                    return memberships
                }()
            )

            clubs.append(club)
        }

        return clubs
    }

    private static let englandTop4CSV = """
id,name,team,league,city,lat,lon,country_code,league_code,league_pack,short_code
en-arsenal,Emirates Stadium,Arsenal,Premier League,London,51.555,-0.108333,en,en-premier-league,england_top_4,ARS
en-aston-villa,Villa Park,Aston Villa,Premier League,Birmingham,52.509112,-1.884783,en,en-premier-league,england_top_4,AVL
en-afc-bournemouth,Dean Court,AFC Bournemouth,Premier League,Bournemouth,50.747,-1.8868,en,en-premier-league,england_top_4,BOU
en-brentford,Brentford Community Stadium,Brentford,Premier League,London,51.4882,-0.3026,en,en-premier-league,england_top_4,BRE
en-brighton-and-hove-albion,Falmer Stadium,Brighton & Hove Albion,Premier League,Falmer,50.861551,-0.083624,en,en-premier-league,england_top_4,BHA
en-burnley,Turf Moor,Burnley,Premier League,Burnley,53.789,-2.248,en,en-premier-league,england_top_4,BUR
en-chelsea,Stamford Bridge,Chelsea,Premier League,London,51.481667,-0.191111,en,en-premier-league,england_top_4,CHE
en-crystal-palace,Selhurst Park,Crystal Palace,Premier League,London,51.398333,-0.085556,en,en-premier-league,england_top_4,CRY
en-everton,Hill Dickinson Stadium,Everton,Premier League,Liverpool,53.4251,-3.0028,en,en-premier-league,england_top_4,EVE
en-fulham,Craven Cottage,Fulham,Premier League,London,51.475,-0.221667,en,en-premier-league,england_top_4,FUL
en-leeds-united,Elland Road,Leeds United,Premier League,Leeds,53.7778,-1.5722,en,en-premier-league,england_top_4,LEE
en-liverpool,Anfield,Liverpool,Premier League,Liverpool,53.430845,-2.960223,en,en-premier-league,england_top_4,LIV
en-manchester-city,City of Manchester Stadium,Manchester City,Premier League,Manchester,53.483056,-2.200278,en,en-premier-league,england_top_4,MCI
en-manchester-united,Old Trafford,Manchester United,Premier League,Trafford,53.463056,-2.291389,en,en-premier-league,england_top_4,MUN
en-newcastle-united,St James' Park,Newcastle United,Premier League,Newcastle upon Tyne,54.9756,-1.621667,en,en-premier-league,england_top_4,NEW
en-nottingham-forest,City Ground,Nottingham Forest,Premier League,West Bridgford,52.9399,-1.1329,en,en-premier-league,england_top_4,NFO
en-sunderland,Stadium of Light,Sunderland,Premier League,Sunderland,54.9146,-1.3884,en,en-premier-league,england_top_4,SUN
en-tottenham-hotspur,Tottenham Hotspur Stadium,Tottenham Hotspur,Premier League,London,51.6044,-0.0664,en,en-premier-league,england_top_4,TOT
en-west-ham-united,London Stadium,West Ham United,Premier League,London,51.538611,-0.016389,en,en-premier-league,england_top_4,WHU
en-wolverhampton-wanderers,Molineux Stadium,Wolverhampton Wanderers,Premier League,Wolverhampton,52.590225,-2.130389,en,en-premier-league,england_top_4,WOL
en-birmingham-city,St Andrew's,Birmingham City,Championship,Birmingham,52.476,-1.868,en,en-championship,england_top_4,BIR
en-blackburn-rovers,Ewood Park,Blackburn Rovers,Championship,Blackburn,53.729,-2.49,en,en-championship,england_top_4,BLB
en-bristol-city,Ashton Gate,Bristol City,Championship,Bristol,51.44,-2.62,en,en-championship,england_top_4,BRC
en-charlton-athletic,The Valley,Charlton Athletic,Championship,London,51.487,0.036,en,en-championship,england_top_4,CHA
en-coventry-city,Coventry Building Society Arena,Coventry City,Championship,Coventry,52.448,-1.495,en,en-championship,england_top_4,COV
en-derby-county,Pride Park,Derby County,Championship,Derby,52.915,-1.448,en,en-championship,england_top_4,DER
en-hull-city,MKM Stadium,Hull City,Championship,Kingston upon Hull,53.746,-0.368,en,en-championship,england_top_4,HUL
en-ipswich-town,Portman Road,Ipswich Town,Championship,Ipswich,52.055,1.145,en,en-championship,england_top_4,IPS
en-leicester-city,King Power Stadium,Leicester City,Championship,Leicester,52.62,-1.142,en,en-championship,england_top_4,LEI
en-middlesbrough,Riverside Stadium,Middlesbrough,Championship,Middlesbrough,54.578,-1.217,en,en-championship,england_top_4,MID
en-millwall,The Den,Millwall,Championship,London,51.487,-0.051,en,en-championship,england_top_4,MIL
en-norwich-city,Carrow Road,Norwich City,Championship,Norwich,52.622,1.31,en,en-championship,england_top_4,NOR
en-oxford-united,Kassam Stadium,Oxford United,Championship,Oxford,51.716,-1.208,en,en-championship,england_top_4,OXF
en-portsmouth,Fratton Park,Portsmouth,Championship,Portsmouth,50.796,-1.064,en,en-championship,england_top_4,POR
en-preston-north-end,Deepdale,Preston North End,Championship,Preston,53.772,-2.688,en,en-championship,england_top_4,PNE
en-queens-park-rangers,Loftus Road,Queens Park Rangers,Championship,London,51.509,-0.232,en,en-championship,england_top_4,QPR
en-sheffield-united,Bramall Lane,Sheffield United,Championship,Sheffield,53.37,-1.47,en,en-championship,england_top_4,SHU
en-sheffield-wednesday,Hillsborough Stadium,Sheffield Wednesday,Championship,Sheffield,53.411,-1.5,en,en-championship,england_top_4,SHW
en-southampton,St Mary's Stadium,Southampton,Championship,Southampton,50.906,-1.392,en,en-championship,england_top_4,SOU
en-stoke-city,bet365 Stadium,Stoke City,Championship,Stoke-on-Trent,52.989,-2.175,en,en-championship,england_top_4,STK
en-swansea-city,Swansea.com Stadium,Swansea City,Championship,Swansea,51.643,-3.935,en,en-championship,england_top_4,SWA
en-watford,Vicarage Road,Watford,Championship,Watford,51.65,-0.402,en,en-championship,england_top_4,WAT
en-west-bromwich-albion,The Hawthorns,West Bromwich Albion,Championship,West Bromwich,52.509,-1.963,en,en-championship,england_top_4,WBA
en-wrexham,Racecourse Ground,Wrexham,Championship,Wrexham,53.052,-3.004,en,en-championship,england_top_4,WRE
en-afc-wimbledon,Plough Lane,AFC Wimbledon,League One,London,51.422,-0.208,en,en-league-one,england_top_4,AW
en-barnsley,Oakwell,Barnsley,League One,Barnsley,53.522222,-1.4675,en,en-league-one,england_top_4,BAR
en-blackpool,Bloomfield Road,Blackpool,League One,Blackpool,53.8049,-3.0481,en,en-league-one,england_top_4,BLP
en-bolton-wanderers,Toughsheet Community Stadium,Bolton Wanderers,League One,Horwich,53.580556,-2.535556,en,en-league-one,england_top_4,BOL
en-bradford-city,Valley Parade,Bradford City,League One,Bradford,53.8036,-1.76,en,en-league-one,england_top_4,BRA
en-burton-albion,Pirelli Stadium,Burton Albion,League One,Burton upon Trent,52.8216,-1.6273,en,en-league-one,england_top_4,BUA
en-cardiff-city,Cardiff City Stadium,Cardiff City,League One,Cardiff,51.473,-3.203,en,en-league-one,england_top_4,CAR
en-doncaster-rovers,Eco-Power Stadium,Doncaster Rovers,League One,Doncaster,53.5099,-1.1158,en,en-league-one,england_top_4,DON
en-exeter-city,St. James Park,Exeter City,League One,Exeter,50.7307,-3.5211,en,en-league-one,england_top_4,EXE
en-huddersfield-town,Kirklees Stadium,Huddersfield Town,League One,Huddersfield,53.6543,-1.7684,en,en-league-one,england_top_4,HUD
en-leyton-orient,Brisbane Road,Leyton Orient,League One,London,51.5602,-0.0127,en,en-league-one,england_top_4,LEY
en-lincoln-city,Sincil Bank,Lincoln City,League One,Lincoln,53.2183,-0.5408,en,en-league-one,england_top_4,LIN
en-luton-town,Kenilworth Road,Luton Town,League One,Luton,51.8841,-0.4316,en,en-league-one,england_top_4,LUT
en-mansfield-town,Field Mill,Mansfield Town,League One,Mansfield,53.13826,-1.20069,en,en-league-one,england_top_4,MAN
en-northampton-town,Sixfields Stadium,Northampton Town,League One,Northampton,52.2405,-0.9027,en,en-league-one,england_top_4,NHT
en-peterborough-united,London Road Stadium,Peterborough United,League One,Peterborough,52.5647,-0.2402,en,en-league-one,england_top_4,PET
en-plymouth-argyle,Home Park,Plymouth Argyle,League One,Plymouth,50.388,-4.1508,en,en-league-one,england_top_4,PLY
en-port-vale,Vale Park,Port Vale,League One,Stoke-on-Trent,53.0497,-2.1925,en,en-league-one,england_top_4,PVA
en-reading,Madejski Stadium,Reading,League One,Reading,51.4224,-0.9826,en,en-league-one,england_top_4,REA
en-rotherham-united,New York Stadium,Rotherham United,League One,Rotherham,53.4279,-1.362,en,en-league-one,england_top_4,ROT
en-stevenage,Broadhall Way,Stevenage,League One,Stevenage,51.89,-0.19361,en,en-league-one,england_top_4,STE
en-stockport-county,Edgeley Park,Stockport County,League One,Stockport,53.4083,-2.1494,en,en-league-one,england_top_4,STO
en-wigan-athletic,Brick Community Stadium,Wigan Athletic,League One,Wigan,53.547778,-2.653889,en,en-league-one,england_top_4,WIG
en-wycombe-wanderers,Adams Park,Wycombe Wanderers,League One,High Wycombe,51.6286,-0.7482,en,en-league-one,england_top_4,WYC
en-accrington-stanley,Crown Ground,Accrington Stanley,League Two,Accrington,53.7652,-2.3709,en,en-league-two,england_top_4,ACC
en-barnet,The Hive Stadium,Barnet,League Two,London,51.65309,-0.2002261,en,en-league-two,england_top_4,BNT
en-barrow,Holker Street,Barrow,League Two,Barrow-in-Furness,54.1233,-3.2349,en,en-league-two,england_top_4,BWR
en-bristol-rovers,Memorial Stadium,Bristol Rovers,League Two,Bristol,51.4862,-2.5831,en,en-league-two,england_top_4,BRR
en-bromley,Hayes Lane,Bromley,League Two,London,51.3901,0.0211,en,en-league-two,england_top_4,BRM
en-cambridge-united,Abbey Stadium,Cambridge United,League Two,Cambridge,52.2121,0.1541,en,en-league-two,england_top_4,CAM
en-cheltenham-town,Whaddon Road,Cheltenham Town,League Two,Cheltenham,51.9062,-2.0602,en,en-league-two,england_top_4,CHT
en-chesterfield,SMH Group Stadium,Chesterfield,League Two,Chesterfield,53.2536,-1.425,en,en-league-two,england_top_4,CHF
en-colchester-united,Colchester Community Stadium,Colchester United,League Two,Colchester,51.9229,0.897,en,en-league-two,england_top_4,COL
en-crawley-town,Broadfield Stadium,Crawley Town,League Two,Crawley,51.0997,-0.1947,en,en-league-two,england_top_4,CRW
en-crewe-alexandra,Gresty Road,Crewe Alexandra,League Two,Crewe,53.087419,-2.435747,en,en-league-two,england_top_4,CRE
en-fleetwood-town,Highbury Stadium,Fleetwood Town,League Two,Fleetwood,53.9167,-3.0248,en,en-league-two,england_top_4,FLE
en-gillingham,Priestfield Stadium,Gillingham,League Two,Gillingham,51.3843,0.5607,en,en-league-two,england_top_4,GIL
en-grimsby-town,Blundell Park,Grimsby Town,League Two,Cleethorpes,53.5702,-0.0464,en,en-league-two,england_top_4,GRI
en-harrogate-town,Wetherby Road,Harrogate Town,League Two,Harrogate,53.99166,-1.51525,en,en-league-two,england_top_4,HAR
en-milton-keynes-dons,Stadium MK,Milton Keynes Dons,League Two,Milton Keynes,52.0097,-0.7334,en,en-league-two,england_top_4,MKD
en-newport-county,Rodney Parade,Newport County,League Two,Newport,51.5882,-2.988,en,en-league-two,england_top_4,NEWP
en-notts-county,Meadow Lane,Notts County,League Two,Nottingham,52.9426,-1.1372,en,en-league-two,england_top_4,NOT
en-oldham-athletic,Boundary Park,Oldham Athletic,League Two,Oldham,53.5553,-2.1286,en,en-league-two,england_top_4,OLD
en-salford-city,Moor Lane,Salford City,League Two,Salford,53.5136,-2.2768,en,en-league-two,england_top_4,SAL
en-shrewsbury-town,New Meadow,Shrewsbury Town,League Two,Shrewsbury,52.6886,-2.7492,en,en-league-two,england_top_4,SHR
en-swindon-town,County Ground,Swindon Town,League Two,Swindon,51.5584,-1.781,en,en-league-two,england_top_4,SWI
en-tranmere-rovers,Prenton Park,Tranmere Rovers,League Two,Birkenhead,53.3738,-3.0325,en,en-league-two,england_top_4,TRA
en-walsall,Bescot Stadium,Walsall,League Two,Walsall,52.5654,-1.9907,en,en-league-two,england_top_4,WAL
"""

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
