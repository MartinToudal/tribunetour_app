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

    var historicalMemberships: [CompetitionMembership] {
        competitionMemberships.filter { $0.status == .historical }
    }

    var activeCompetitionIds: Set<String> {
        Set(
            competitionMemberships
                .filter { $0.status == .active }
                .map(\.competitionId)
        )
    }

    var isArchivedFromCurrentScope: Bool {
        membershipStatus != .active
    }

    var countsTowardTopSystemProgression: Bool {
        membershipStatus == .active && CompetitionCatalog.isPrimaryDomesticCompetition(primaryCompetitionId)
    }

    var shouldRemainVisibleOutsideTopSystem: Bool {
        isArchivedFromCurrentScope
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

    var archiveGroupLabel: String {
        switch membershipStatus {
        case .active:
            return "Aktiv"
        case .relegated:
            return "Ude af aktivt ligasystem"
        case .historical:
            return "Historisk klubstatus"
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

    private struct SupplementalMembershipRow {
        let clubId: String
        let competitionId: String
        let seasonId: String?
        let status: CompetitionMembershipStatus
        let isPrimary: Bool
    }

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
            clubs.append(contentsOf: try loadClubsFromBundle(csvFileName: "germany_top_3"))
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
        if enabledLeaguePacks.contains(AppLeaguePackId.netherlandsTop3.rawValue) {
            clubs.append(contentsOf: try loadClubsFromBundle(csvFileName: "netherlands_top_3"))
        }
        if enabledLeaguePacks.contains(AppLeaguePackId.belgiumTop3.rawValue) {
            clubs.append(contentsOf: try loadClubsFromBundle(csvFileName: "belgium_top_3"))
        }

        if enabledLeaguePacks.contains(AppLeaguePackId.turkeyTop3.rawValue) {
            clubs.append(contentsOf: try loadClubsFromBundle(csvFileName: "turkey_top_3"))
        }

        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: denmarkHistoricalMembershipsCSV
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: englandHistoricalMembershipsCSV
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: italyHistoricalMembershipsCSV
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromBundleCSVFileName: "spain_historical_memberships"
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: franceHistoricalMembershipsCSV
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: portugalHistoricalMembershipsCSV
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: netherlandsHistoricalMembershipsCSV
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: belgiumHistoricalMembershipsCSV
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: turkeyHistoricalMembershipsCSV
        )
        clubs = try mergeSupplementalMemberships(
            into: clubs,
            fromCSVText: germanyHistoricalMembershipsCSV
        )

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

    private static func mergeSupplementalMemberships(
        into clubs: [Club],
        fromCSVText text: String
    ) throws -> [Club] {
        let rows = try loadSupplementalMembershipRows(fromCSVText: text)
        guard !rows.isEmpty else { return clubs }

        let rowsByClubId = Dictionary(grouping: rows, by: \.clubId)

        return clubs.map { club in
            guard let extraRows = rowsByClubId[club.id], !extraRows.isEmpty else {
                return club
            }

            var mergedMemberships = club.competitionMemberships

            for row in extraRows {
                let membership = CompetitionMembership(
                    competitionId: row.competitionId,
                    seasonId: row.seasonId,
                    status: row.status,
                    isPrimary: row.isPrimary
                )

                let alreadyExists = mergedMemberships.contains {
                    $0.competitionId == membership.competitionId &&
                    $0.seasonId == membership.seasonId &&
                    $0.status == membership.status &&
                    $0.isPrimary == membership.isPrimary
                }

                if !alreadyExists {
                    mergedMemberships.append(membership)
                }
            }

            return Club(
                id: club.id,
                name: club.name,
                division: club.division,
                stadium: club.stadium,
                countryCode: club.countryCode,
                leagueCode: club.leagueCode,
                leaguePack: club.leaguePack,
                shortCode: club.shortCode,
                primaryCompetitionId: club.primaryCompetitionId,
                primarySeasonId: club.primarySeasonId,
                membershipStatus: club.membershipStatus,
                competitionMemberships: mergedMemberships
            )
        }
    }

    private static func mergeSupplementalMemberships(
        into clubs: [Club],
        fromBundleCSVFileName csvFileName: String
    ) throws -> [Club] {
        guard let url = bundleCSVURL(named: csvFileName) else {
            throw CSVImportError.fileNotFound("\(csvFileName).csv")
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CSVImportError.unreadable(error.localizedDescription)
        }

        return try mergeSupplementalMemberships(into: clubs, fromCSVText: text)
    }

    private static func loadSupplementalMembershipRows(
        fromCSVText text: String
    ) throws -> [SupplementalMembershipRow] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return [] }

        let header = splitCSVLine(lines[0]).map { $0.lowercased() }
        let headerIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })

        let required = ["club_id", "competition_id", "season_id", "membership_status", "is_primary"]
        guard required.allSatisfy({ headerIndex[$0] != nil }) else {
            throw CSVImportError.invalidHeader
        }

        func value(_ row: [String], _ key: String) -> String {
            guard let idx = headerIndex[key], idx < row.count else { return "" }
            return row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return try (1..<lines.count).map { index in
            let row = splitCSVLine(lines[index])
            let clubId = value(row, "club_id")
            let competitionId = value(row, "competition_id")
            let seasonId = value(row, "season_id").nonEmpty
            let statusRaw = value(row, "membership_status").lowercased()
            let isPrimaryRaw = value(row, "is_primary").lowercased()

            guard
                !clubId.isEmpty,
                !competitionId.isEmpty,
                let status = CompetitionMembershipStatus(rawValue: statusRaw)
            else {
                throw CSVImportError.invalidRow(lines[index])
            }

            let isPrimary = ["true", "1", "yes"].contains(isPrimaryRaw)

            return SupplementalMembershipRow(
                clubId: clubId,
                competitionId: competitionId,
                seasonId: seasonId,
                status: status,
                isPrimary: isPrimary
            )
        }
    }

    private static let denmarkHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
dk-aab,dk-1-division,2025-26,historical,false
dk-aarhus-fremad,dk-1-division,2025-26,historical,false
dk-ab,dk-2-division,2025-26,historical,false
dk-ac-horsens,dk-1-division,2025-26,historical,false
dk-agf,dk-superliga,2025-26,historical,false
dk-b-93,dk-1-division,2025-26,historical,false
dk-brondby-if,dk-superliga,2025-26,historical,false
dk-brabrand-if,dk-2-division,2025-26,historical,false
dk-bronshoj,dk-3-division,2025-26,historical,false
dk-esbjerg-fb,dk-1-division,2025-26,historical,false
dk-fa-2000,dk-3-division,2025-26,historical,false
dk-fremad-amager,dk-2-division,2025-26,historical,false
dk-fc-fredericia,dk-superliga,2025-26,historical,false
dk-fc-kobenhavn,dk-superliga,2025-26,historical,false
dk-fc-midtjylland,dk-superliga,2025-26,historical,false
dk-fc-nordsjaelland,dk-superliga,2025-26,historical,false
dk-frem,dk-3-division,2025-26,historical,false
dk-hb-koge,dk-1-division,2025-26,historical,false
dk-fc-helsingor,dk-2-division,2025-26,historical,false
dk-hik,dk-2-division,2025-26,historical,false
dk-hillerod-fodbold,dk-1-division,2025-26,historical,false
dk-hobro-ik,dk-1-division,2025-26,historical,false
dk-holbaek-bi,dk-3-division,2025-26,historical,false
dk-horsholm-usserod-ik,dk-3-division,2025-26,historical,false
dk-hvidovre-if,dk-1-division,2025-26,historical,false
dk-ishoj-if,dk-2-division,2025-26,historical,false
dk-kolding-if,dk-1-division,2025-26,historical,false
dk-lyngby-boldklub,dk-1-division,2025-26,historical,false
dk-if-lyseng,dk-3-division,2025-26,historical,false
dk-middelfart,dk-1-division,2025-26,historical,false
dk-naesby-bk,dk-3-division,2025-26,historical,false
dk-naestved,dk-2-division,2025-26,historical,false
dk-nykobing-fc,dk-3-division,2025-26,historical,false
dk-ob,dk-superliga,2025-26,historical,false
dk-odder-fodbold,dk-3-division,2025-26,historical,false
dk-randers-fc,dk-superliga,2025-26,historical,false
dk-fc-roskilde,dk-2-division,2025-26,historical,false
dk-silkeborg-if,dk-superliga,2025-26,historical,false
dk-sonderjyske,dk-superliga,2025-26,historical,false
dk-skive,dk-2-division,2025-26,historical,false
dk-sundby-bk,dk-3-division,2025-26,historical,false
dk-thisted-fc,dk-2-division,2025-26,historical,false
dk-vanlose,dk-3-division,2025-26,historical,false
dk-vejle-boldklub,dk-superliga,2025-26,historical,false
dk-vejgaard-b,dk-3-division,2025-26,historical,false
dk-vendsyssel-ff,dk-2-division,2025-26,historical,false
dk-viborg-ff,dk-superliga,2025-26,historical,false
dk-vsk-aarhus,dk-2-division,2025-26,historical,false
"""

    private static let englandTop4CSV = """
id,name,team,league,city,lat,lon,country_code,league_code,league_pack,short_code,competition_id,season_id,membership_status,secondary_competition_ids
en-afc-bournemouth,Dean Court,AFC Bournemouth,Premier League,Bournemouth,50.747,-1.8868,en,en-premier-league,england_top_4,BOU,en-premier-league,2026-27,active,
en-arsenal,Emirates Stadium,Arsenal,Premier League,London,51.555,-0.108333,en,en-premier-league,england_top_4,ARS,en-premier-league,2026-27,active,
en-aston-villa,Villa Park,Aston Villa,Premier League,Birmingham,52.509112,-1.884783,en,en-premier-league,england_top_4,AVL,en-premier-league,2026-27,active,
en-brentford,Brentford Community Stadium,Brentford,Premier League,London,51.4882,-0.3026,en,en-premier-league,england_top_4,BRE,en-premier-league,2026-27,active,
en-brighton-and-hove-albion,Falmer Stadium,Brighton & Hove Albion,Premier League,Falmer,50.861551,-0.083624,en,en-premier-league,england_top_4,BHA,en-premier-league,2026-27,active,
en-chelsea,Stamford Bridge,Chelsea,Premier League,London,51.481667,-0.191111,en,en-premier-league,england_top_4,CHE,en-premier-league,2026-27,active,
en-coventry-city,Coventry Building Society Arena,Coventry City,Premier League,Coventry,52.448,-1.495,en,en-premier-league,england_top_4,COV,en-premier-league,2026-27,active,
en-crystal-palace,Selhurst Park,Crystal Palace,Premier League,London,51.398333,-0.085556,en,en-premier-league,england_top_4,CRY,en-premier-league,2026-27,active,
en-everton,Hill Dickinson Stadium,Everton,Premier League,Liverpool,53.4251,-3.0028,en,en-premier-league,england_top_4,EVE,en-premier-league,2026-27,active,
en-fulham,Craven Cottage,Fulham,Premier League,London,51.475,-0.221667,en,en-premier-league,england_top_4,FUL,en-premier-league,2026-27,active,
en-hull-city,MKM Stadium,Hull City,Premier League,Kingston upon Hull,53.746,-0.368,en,en-premier-league,england_top_4,HUL,en-premier-league,2026-27,active,
en-ipswich-town,Portman Road,Ipswich Town,Premier League,Ipswich,52.055,1.145,en,en-premier-league,england_top_4,IPS,en-premier-league,2026-27,active,
en-leeds-united,Elland Road,Leeds United,Premier League,Leeds,53.7778,-1.5722,en,en-premier-league,england_top_4,LEE,en-premier-league,2026-27,active,
en-liverpool,Anfield,Liverpool,Premier League,Liverpool,53.430845,-2.960223,en,en-premier-league,england_top_4,LIV,en-premier-league,2026-27,active,
en-manchester-city,City of Manchester Stadium,Manchester City,Premier League,Manchester,53.483056,-2.200278,en,en-premier-league,england_top_4,MCI,en-premier-league,2026-27,active,
en-manchester-united,Old Trafford,Manchester United,Premier League,Trafford,53.463056,-2.291389,en,en-premier-league,england_top_4,MUN,en-premier-league,2026-27,active,
en-newcastle-united,St James' Park,Newcastle United,Premier League,Newcastle upon Tyne,54.9756,-1.621667,en,en-premier-league,england_top_4,NEW,en-premier-league,2026-27,active,
en-nottingham-forest,City Ground,Nottingham Forest,Premier League,West Bridgford,52.9399,-1.1329,en,en-premier-league,england_top_4,NFO,en-premier-league,2026-27,active,
en-sunderland,Stadium of Light,Sunderland,Premier League,Sunderland,54.9146,-1.3884,en,en-premier-league,england_top_4,SUN,en-premier-league,2026-27,active,
en-tottenham-hotspur,Tottenham Hotspur Stadium,Tottenham Hotspur,Premier League,London,51.6044,-0.0664,en,en-premier-league,england_top_4,TOT,en-premier-league,2026-27,active,
en-birmingham-city,St Andrew's,Birmingham City,Championship,Birmingham,52.476,-1.868,en,en-championship,england_top_4,BIR,en-championship,2026-27,active,
en-blackburn-rovers,Ewood Park,Blackburn Rovers,Championship,Blackburn,53.729,-2.49,en,en-championship,england_top_4,BLB,en-championship,2026-27,active,
en-bolton-wanderers,Toughsheet Community Stadium,Bolton Wanderers,Championship,Horwich,53.580556,-2.535556,en,en-championship,england_top_4,BOL,en-championship,2026-27,active,
en-bristol-city,Ashton Gate,Bristol City,Championship,Bristol,51.44,-2.62,en,en-championship,england_top_4,BRC,en-championship,2026-27,active,
en-burnley,Turf Moor,Burnley,Championship,Burnley,53.789,-2.248,en,en-championship,england_top_4,BUR,en-championship,2026-27,active,
en-cardiff-city,Cardiff City Stadium,Cardiff City,Championship,Cardiff,51.473,-3.203,en,en-championship,england_top_4,CAR,en-championship,2026-27,active,
en-charlton-athletic,The Valley,Charlton Athletic,Championship,London,51.487,0.036,en,en-championship,england_top_4,CHA,en-championship,2026-27,active,
en-derby-county,Pride Park,Derby County,Championship,Derby,52.915,-1.448,en,en-championship,england_top_4,DER,en-championship,2026-27,active,
en-lincoln-city,Sincil Bank,Lincoln City,Championship,Lincoln,53.2183,-0.5408,en,en-championship,england_top_4,LIN,en-championship,2026-27,active,
en-middlesbrough,Riverside Stadium,Middlesbrough,Championship,Middlesbrough,54.578,-1.217,en,en-championship,england_top_4,MID,en-championship,2026-27,active,
en-millwall,The Den,Millwall,Championship,London,51.487,-0.051,en,en-championship,england_top_4,MIL,en-championship,2026-27,active,
en-norwich-city,Carrow Road,Norwich City,Championship,Norwich,52.622,1.31,en,en-championship,england_top_4,NOR,en-championship,2026-27,active,
en-portsmouth,Fratton Park,Portsmouth,Championship,Portsmouth,50.796,-1.064,en,en-championship,england_top_4,POR,en-championship,2026-27,active,
en-preston-north-end,Deepdale,Preston North End,Championship,Preston,53.772,-2.688,en,en-championship,england_top_4,PNE,en-championship,2026-27,active,
en-queens-park-rangers,Loftus Road,Queens Park Rangers,Championship,London,51.509,-0.232,en,en-championship,england_top_4,QPR,en-championship,2026-27,active,
en-sheffield-united,Bramall Lane,Sheffield United,Championship,Sheffield,53.37,-1.47,en,en-championship,england_top_4,SHU,en-championship,2026-27,active,
en-southampton,St Mary's Stadium,Southampton,Championship,Southampton,50.906,-1.392,en,en-championship,england_top_4,SOU,en-championship,2026-27,active,
en-stoke-city,bet365 Stadium,Stoke City,Championship,Stoke-on-Trent,52.989,-2.175,en,en-championship,england_top_4,STK,en-championship,2026-27,active,
en-swansea-city,Swansea.com Stadium,Swansea City,Championship,Swansea,51.643,-3.935,en,en-championship,england_top_4,SWA,en-championship,2026-27,active,
en-watford,Vicarage Road,Watford,Championship,Watford,51.65,-0.402,en,en-championship,england_top_4,WAT,en-championship,2026-27,active,
en-west-bromwich-albion,The Hawthorns,West Bromwich Albion,Championship,West Bromwich,52.509,-1.963,en,en-championship,england_top_4,WBA,en-championship,2026-27,active,
en-west-ham-united,London Stadium,West Ham United,Championship,London,51.538611,-0.016389,en,en-championship,england_top_4,WHU,en-championship,2026-27,active,
en-wolverhampton-wanderers,Molineux Stadium,Wolverhampton Wanderers,Championship,Wolverhampton,52.590225,-2.130389,en,en-championship,england_top_4,WOL,en-championship,2026-27,active,
en-wrexham,Racecourse Ground,Wrexham,Championship,Wrexham,53.052,-3.004,en,en-championship,england_top_4,WRE,en-championship,2026-27,active,
en-afc-wimbledon,Plough Lane,AFC Wimbledon,League One,London,51.422,-0.208,en,en-league-one,england_top_4,AW,en-league-one,2026-27,active,
en-barnsley,Oakwell,Barnsley,League One,Barnsley,53.522222,-1.4675,en,en-league-one,england_top_4,BAR,en-league-one,2026-27,active,
en-blackpool,Bloomfield Road,Blackpool,League One,Blackpool,53.8049,-3.0481,en,en-league-one,england_top_4,BLP,en-league-one,2026-27,active,
en-bradford-city,Valley Parade,Bradford City,League One,Bradford,53.8036,-1.76,en,en-league-one,england_top_4,BRA,en-league-one,2026-27,active,
en-bromley,Hayes Lane,Bromley,League One,London,51.3901,0.0211,en,en-league-one,england_top_4,BRM,en-league-one,2026-27,active,
en-burton-albion,Pirelli Stadium,Burton Albion,League One,Burton upon Trent,52.8216,-1.6273,en,en-league-one,england_top_4,BUA,en-league-one,2026-27,active,
en-cambridge-united,Abbey Stadium,Cambridge United,League One,Cambridge,52.2121,0.1541,en,en-league-one,england_top_4,CAM,en-league-one,2026-27,active,
en-doncaster-rovers,Eco-Power Stadium,Doncaster Rovers,League One,Doncaster,53.5099,-1.1158,en,en-league-one,england_top_4,DON,en-league-one,2026-27,active,
en-huddersfield-town,Kirklees Stadium,Huddersfield Town,League One,Huddersfield,53.6543,-1.7684,en,en-league-one,england_top_4,HUD,en-league-one,2026-27,active,
en-leicester-city,King Power Stadium,Leicester City,League One,Leicester,52.62,-1.142,en,en-league-one,england_top_4,LEI,en-league-one,2026-27,active,
en-leyton-orient,Brisbane Road,Leyton Orient,League One,London,51.5602,-0.0127,en,en-league-one,england_top_4,LEY,en-league-one,2026-27,active,
en-luton-town,Kenilworth Road,Luton Town,League One,Luton,51.8841,-0.4316,en,en-league-one,england_top_4,LUT,en-league-one,2026-27,active,
en-mansfield-town,Field Mill,Mansfield Town,League One,Mansfield,53.13826,-1.20069,en,en-league-one,england_top_4,MAN,en-league-one,2026-27,active,
en-milton-keynes-dons,Stadium MK,Milton Keynes Dons,League One,Milton Keynes,52.0097,-0.7334,en,en-league-one,england_top_4,MKD,en-league-one,2026-27,active,
en-notts-county,Meadow Lane,Notts County,League One,Nottingham,52.9426,-1.1372,en,en-league-one,england_top_4,NOT,en-league-one,2026-27,active,
en-oxford-united,Kassam Stadium,Oxford United,League One,Oxford,51.716,-1.208,en,en-league-one,england_top_4,OXF,en-league-one,2026-27,active,
en-peterborough-united,London Road Stadium,Peterborough United,League One,Peterborough,52.5647,-0.2402,en,en-league-one,england_top_4,PET,en-league-one,2026-27,active,
en-plymouth-argyle,Home Park,Plymouth Argyle,League One,Plymouth,50.388,-4.1508,en,en-league-one,england_top_4,PLY,en-league-one,2026-27,active,
en-reading,Madejski Stadium,Reading,League One,Reading,51.4224,-0.9826,en,en-league-one,england_top_4,REA,en-league-one,2026-27,active,
en-sheffield-wednesday,Hillsborough Stadium,Sheffield Wednesday,League One,Sheffield,53.411,-1.5,en,en-league-one,england_top_4,SHW,en-league-one,2026-27,active,
en-stevenage,Broadhall Way,Stevenage,League One,Stevenage,51.89,-0.19361,en,en-league-one,england_top_4,STE,en-league-one,2026-27,active,
en-stockport-county,Edgeley Park,Stockport County,League One,Stockport,53.4083,-2.1494,en,en-league-one,england_top_4,STO,en-league-one,2026-27,active,
en-wigan-athletic,Brick Community Stadium,Wigan Athletic,League One,Wigan,53.547778,-2.653889,en,en-league-one,england_top_4,WIG,en-league-one,2026-27,active,
en-wycombe-wanderers,Adams Park,Wycombe Wanderers,League One,High Wycombe,51.6286,-0.7482,en,en-league-one,england_top_4,WYC,en-league-one,2026-27,active,
en-accrington-stanley,Crown Ground,Accrington Stanley,League Two,Accrington,53.7652,-2.3709,en,en-league-two,england_top_4,ACC,en-league-two,2026-27,active,
en-barnet,The Hive Stadium,Barnet,League Two,London,51.65309,-0.2002261,en,en-league-two,england_top_4,BNT,en-league-two,2026-27,active,
en-bristol-rovers,Memorial Stadium,Bristol Rovers,League Two,Bristol,51.4862,-2.5831,en,en-league-two,england_top_4,BRR,en-league-two,2026-27,active,
en-cheltenham-town,Whaddon Road,Cheltenham Town,League Two,Cheltenham,51.9062,-2.0602,en,en-league-two,england_top_4,CHT,en-league-two,2026-27,active,
en-chesterfield,SMH Group Stadium,Chesterfield,League Two,Chesterfield,53.2536,-1.425,en,en-league-two,england_top_4,CHF,en-league-two,2026-27,active,
en-colchester-united,Colchester Community Stadium,Colchester United,League Two,Colchester,51.9229,0.897,en,en-league-two,england_top_4,COL,en-league-two,2026-27,active,
en-crawley-town,Broadfield Stadium,Crawley Town,League Two,Crawley,51.0997,-0.1947,en,en-league-two,england_top_4,CRW,en-league-two,2026-27,active,
en-crewe-alexandra,Gresty Road,Crewe Alexandra,League Two,Crewe,53.087419,-2.435747,en,en-league-two,england_top_4,CRE,en-league-two,2026-27,active,
en-exeter-city,St. James Park,Exeter City,League Two,Exeter,50.7307,-3.5211,en,en-league-two,england_top_4,EXE,en-league-two,2026-27,active,
en-fleetwood-town,Highbury Stadium,Fleetwood Town,League Two,Fleetwood,53.9167,-3.0248,en,en-league-two,england_top_4,FLE,en-league-two,2026-27,active,
en-gillingham,Priestfield Stadium,Gillingham,League Two,Gillingham,51.3843,0.5607,en,en-league-two,england_top_4,GIL,en-league-two,2026-27,active,
en-grimsby-town,Blundell Park,Grimsby Town,League Two,Cleethorpes,53.5702,-0.0464,en,en-league-two,england_top_4,GRI,en-league-two,2026-27,active,
en-newport-county,Rodney Parade,Newport County,League Two,Newport,51.5882,-2.988,en,en-league-two,england_top_4,NEWP,en-league-two,2026-27,active,
en-northampton-town,Sixfields Stadium,Northampton Town,League Two,Northampton,52.2405,-0.9027,en,en-league-two,england_top_4,NHT,en-league-two,2026-27,active,
en-oldham-athletic,Boundary Park,Oldham Athletic,League Two,Oldham,53.5553,-2.1286,en,en-league-two,england_top_4,OLD,en-league-two,2026-27,active,
en-port-vale,Vale Park,Port Vale,League Two,Stoke-on-Trent,53.0497,-2.1925,en,en-league-two,england_top_4,PVA,en-league-two,2026-27,active,
en-rochdale,Crown Oil Arena,Rochdale,League Two,Rochdale,53.620833,-2.18,en,en-league-two,england_top_4,ROC,en-league-two,2026-27,active,
en-rotherham-united,New York Stadium,Rotherham United,League Two,Rotherham,53.4279,-1.362,en,en-league-two,england_top_4,ROT,en-league-two,2026-27,active,
en-salford-city,Moor Lane,Salford City,League Two,Salford,53.5136,-2.2768,en,en-league-two,england_top_4,SAL,en-league-two,2026-27,active,
en-shrewsbury-town,New Meadow,Shrewsbury Town,League Two,Shrewsbury,52.6886,-2.7492,en,en-league-two,england_top_4,SHR,en-league-two,2026-27,active,
en-swindon-town,County Ground,Swindon Town,League Two,Swindon,51.5584,-1.781,en,en-league-two,england_top_4,SWI,en-league-two,2026-27,active,
en-tranmere-rovers,Prenton Park,Tranmere Rovers,League Two,Birkenhead,53.3738,-3.0325,en,en-league-two,england_top_4,TRA,en-league-two,2026-27,active,
en-walsall,Bescot Stadium,Walsall,League Two,Walsall,52.5654,-1.9907,en,en-league-two,england_top_4,WAL,en-league-two,2026-27,active,
en-york-city,LNER Community Stadium,York City,League Two,York,53.984328,-1.052955,en,en-league-two,england_top_4,YOR,en-league-two,2026-27,active,
en-barrow,Holker Street,Barrow,Nedrykkere,Barrow-in-Furness,54.1233,-3.2349,en,,england_top_4,BWR,,2026-27,relegated,
en-harrogate-town,Wetherby Road,Harrogate Town,Nedrykkere,Harrogate,53.99166,-1.51525,en,,england_top_4,HAR,,2026-27,relegated,
"""

    private static let englandHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
en-arsenal,en-premier-league,2025-26,historical,false
en-aston-villa,en-premier-league,2025-26,historical,false
en-afc-bournemouth,en-premier-league,2025-26,historical,false
en-brentford,en-premier-league,2025-26,historical,false
en-brighton-and-hove-albion,en-premier-league,2025-26,historical,false
en-burnley,en-premier-league,2025-26,historical,false
en-chelsea,en-premier-league,2025-26,historical,false
en-crystal-palace,en-premier-league,2025-26,historical,false
en-everton,en-premier-league,2025-26,historical,false
en-fulham,en-premier-league,2025-26,historical,false
en-leeds-united,en-premier-league,2025-26,historical,false
en-liverpool,en-premier-league,2025-26,historical,false
en-manchester-city,en-premier-league,2025-26,historical,false
en-manchester-united,en-premier-league,2025-26,historical,false
en-newcastle-united,en-premier-league,2025-26,historical,false
en-nottingham-forest,en-premier-league,2025-26,historical,false
en-sunderland,en-premier-league,2025-26,historical,false
en-tottenham-hotspur,en-premier-league,2025-26,historical,false
en-west-ham-united,en-premier-league,2025-26,historical,false
en-wolverhampton-wanderers,en-premier-league,2025-26,historical,false
en-birmingham-city,en-championship,2025-26,historical,false
en-blackburn-rovers,en-championship,2025-26,historical,false
en-bristol-city,en-championship,2025-26,historical,false
en-charlton-athletic,en-championship,2025-26,historical,false
en-coventry-city,en-championship,2025-26,historical,false
en-derby-county,en-championship,2025-26,historical,false
en-hull-city,en-championship,2025-26,historical,false
en-ipswich-town,en-championship,2025-26,historical,false
en-leicester-city,en-championship,2025-26,historical,false
en-middlesbrough,en-championship,2025-26,historical,false
en-millwall,en-championship,2025-26,historical,false
en-norwich-city,en-championship,2025-26,historical,false
en-oxford-united,en-championship,2025-26,historical,false
en-portsmouth,en-championship,2025-26,historical,false
en-preston-north-end,en-championship,2025-26,historical,false
en-queens-park-rangers,en-championship,2025-26,historical,false
en-sheffield-united,en-championship,2025-26,historical,false
en-sheffield-wednesday,en-championship,2025-26,historical,false
en-southampton,en-championship,2025-26,historical,false
en-stoke-city,en-championship,2025-26,historical,false
en-swansea-city,en-championship,2025-26,historical,false
en-watford,en-championship,2025-26,historical,false
en-west-bromwich-albion,en-championship,2025-26,historical,false
en-wrexham,en-championship,2025-26,historical,false
en-afc-wimbledon,en-league-one,2025-26,historical,false
en-barnsley,en-league-one,2025-26,historical,false
en-blackpool,en-league-one,2025-26,historical,false
en-bolton-wanderers,en-league-one,2025-26,historical,false
en-bradford-city,en-league-one,2025-26,historical,false
en-burton-albion,en-league-one,2025-26,historical,false
en-cardiff-city,en-league-one,2025-26,historical,false
en-doncaster-rovers,en-league-one,2025-26,historical,false
en-exeter-city,en-league-one,2025-26,historical,false
en-huddersfield-town,en-league-one,2025-26,historical,false
en-leyton-orient,en-league-one,2025-26,historical,false
en-lincoln-city,en-league-one,2025-26,historical,false
en-luton-town,en-league-one,2025-26,historical,false
en-mansfield-town,en-league-one,2025-26,historical,false
en-northampton-town,en-league-one,2025-26,historical,false
en-peterborough-united,en-league-one,2025-26,historical,false
en-plymouth-argyle,en-league-one,2025-26,historical,false
en-port-vale,en-league-one,2025-26,historical,false
en-reading,en-league-one,2025-26,historical,false
en-rotherham-united,en-league-one,2025-26,historical,false
en-stevenage,en-league-one,2025-26,historical,false
en-stockport-county,en-league-one,2025-26,historical,false
en-wigan-athletic,en-league-one,2025-26,historical,false
en-wycombe-wanderers,en-league-one,2025-26,historical,false
en-accrington-stanley,en-league-two,2025-26,historical,false
en-barnet,en-league-two,2025-26,historical,false
en-barrow,en-league-two,2025-26,historical,false
en-bristol-rovers,en-league-two,2025-26,historical,false
en-bromley,en-league-two,2025-26,historical,false
en-cambridge-united,en-league-two,2025-26,historical,false
en-cheltenham-town,en-league-two,2025-26,historical,false
en-chesterfield,en-league-two,2025-26,historical,false
en-colchester-united,en-league-two,2025-26,historical,false
en-crawley-town,en-league-two,2025-26,historical,false
en-crewe-alexandra,en-league-two,2025-26,historical,false
en-fleetwood-town,en-league-two,2025-26,historical,false
en-gillingham,en-league-two,2025-26,historical,false
en-grimsby-town,en-league-two,2025-26,historical,false
en-harrogate-town,en-league-two,2025-26,historical,false
en-milton-keynes-dons,en-league-two,2025-26,historical,false
en-newport-county,en-league-two,2025-26,historical,false
en-notts-county,en-league-two,2025-26,historical,false
en-oldham-athletic,en-league-two,2025-26,historical,false
en-salford-city,en-league-two,2025-26,historical,false
en-shrewsbury-town,en-league-two,2025-26,historical,false
en-swindon-town,en-league-two,2025-26,historical,false
en-tranmere-rovers,en-league-two,2025-26,historical,false
en-walsall,en-league-two,2025-26,historical,false
"""

    private static let italyHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
it-ssc-napoli,it-serie-a,2025-26,historical,false
it-cremonese,it-serie-a,2025-26,historical,false
it-parma,it-serie-a,2025-26,historical,false
it-pisa,it-serie-a,2025-26,historical,false
it-bologna,it-serie-a,2025-26,historical,false
it-roma,it-serie-a,2025-26,historical,false
it-verona,it-serie-a,2025-26,historical,false
it-lecce,it-serie-a,2025-26,historical,false
it-fiorentina,it-serie-a,2025-26,historical,false
it-sassuolo,it-serie-a,2025-26,historical,false
it-genoa,it-serie-a,2025-26,historical,false
it-como,it-serie-a,2025-26,historical,false
it-torino,it-serie-a,2025-26,historical,false
it-inter,it-serie-a,2025-26,historical,false
it-ac-milan,it-serie-a,2025-26,historical,false
it-juventus,it-serie-a,2025-26,historical,false
it-cagliari,it-serie-a,2025-26,historical,false
it-atalanta,it-serie-a,2025-26,historical,false
it-lazio,it-serie-a,2025-26,historical,false
it-udinese,it-serie-a,2025-26,historical,false
it-monza,it-serie-b,2025-26,historical,false
it-modena,it-serie-b,2025-26,historical,false
it-avellino,it-serie-b,2025-26,historical,false
it-bari,it-serie-b,2025-26,historical,false
it-catanzaro,it-serie-b,2025-26,historical,false
it-spezia,it-serie-b,2025-26,historical,false
it-virtus-entella,it-serie-b,2025-26,historical,false
it-calcio-padova,it-serie-b,2025-26,historical,false
it-frosinone,it-serie-b,2025-26,historical,false
it-carrarese,it-serie-b,2025-26,historical,false
it-pescara,it-serie-b,2025-26,historical,false
it-juve-stabia,it-serie-b,2025-26,historical,false
it-ac-reggiana,it-serie-b,2025-26,historical,false
it-palermo,it-serie-b,2025-26,historical,false
it-sudtirol,it-serie-b,2025-26,historical,false
it-mantova,it-serie-b,2025-26,historical,false
it-venezia,it-serie-b,2025-26,historical,false
it-empoli,it-serie-b,2025-26,historical,false
it-cesena,it-serie-b,2025-26,historical,false
it-sampdoria,it-serie-b,2025-26,historical,false
it-alcione-milano,it-serie-c-gruppe-a,2025-26,historical,false
it-albinoleffe,it-serie-c-gruppe-a,2025-26,historical,false
it-arzignano,it-serie-c-gruppe-a,2025-26,historical,false
it-pro-vercelli,it-serie-c-gruppe-a,2025-26,historical,false
it-cittadella,it-serie-c-gruppe-a,2025-26,historical,false
it-giana-erminio,it-serie-c-gruppe-a,2025-26,historical,false
it-dolomiti-bellunesi,it-serie-c-gruppe-a,2025-26,historical,false
it-trento,it-serie-c-gruppe-a,2025-26,historical,false
it-inter-u23,it-serie-c-gruppe-a,2025-26,historical,false
it-brescia,it-serie-c-gruppe-a,2025-26,historical,false
it-lumezzane,it-serie-c-gruppe-a,2025-26,historical,false
it-virtus-verona,it-serie-c-gruppe-a,2025-26,historical,false
it-ospitaletto,it-serie-c-gruppe-a,2025-26,historical,false
it-novara,it-serie-c-gruppe-a,2025-26,historical,false
it-pergolettese,it-serie-c-gruppe-a,2025-26,historical,false
it-lecco,it-serie-c-gruppe-a,2025-26,historical,false
it-renate,it-serie-c-gruppe-a,2025-26,historical,false
it-pro-patria,it-serie-c-gruppe-a,2025-26,historical,false
it-triestina,it-serie-c-gruppe-a,2025-26,historical,false
it-lr-vicenza,it-serie-c-gruppe-a,2025-26,historical,false
it-arezzo,it-serie-c-gruppe-b,2025-26,historical,false
it-torres,it-serie-c-gruppe-b,2025-26,historical,false
it-campobasso,it-serie-c-gruppe-b,2025-26,historical,false
it-ascoli,it-serie-c-gruppe-b,2025-26,historical,false
it-forli,it-serie-c-gruppe-b,2025-26,historical,false
it-perugia,it-serie-c-gruppe-b,2025-26,historical,false
it-gubbio,it-serie-c-gruppe-b,2025-26,historical,false
it-pineto,it-serie-c-gruppe-b,2025-26,historical,false
it-guidonia,it-serie-c-gruppe-b,2025-26,historical,false
it-carpi,it-serie-c-gruppe-b,2025-26,historical,false
it-juventus-u23,it-serie-c-gruppe-b,2025-26,historical,false
it-bra,it-serie-c-gruppe-b,2025-26,historical,false
it-pontedera,it-serie-c-gruppe-b,2025-26,historical,false
it-livorno,it-serie-c-gruppe-b,2025-26,historical,false
it-ternana,it-serie-c-gruppe-b,2025-26,historical,false
it-pianese,it-serie-c-gruppe-b,2025-26,historical,false
it-vis-pesaro,it-serie-c-gruppe-b,2025-26,historical,false
it-sambenedettese,it-serie-c-gruppe-b,2025-26,historical,false
it-ravenna,it-serie-c-gruppe-b,2025-26,historical,false
it-rimini,it-serie-c-gruppe-b,2025-26,historical,false
it-altamura,it-serie-c-gruppe-c,2025-26,historical,false
it-casarano,it-serie-c-gruppe-c,2025-26,historical,false
it-atalanta-u23,it-serie-c-gruppe-c,2025-26,historical,false
it-catania,it-serie-c-gruppe-c,2025-26,historical,false
it-benevento,it-serie-c-gruppe-c,2025-26,historical,false
it-audace-cerignola,it-serie-c-gruppe-c,2025-26,historical,false
it-casertana,it-serie-c-gruppe-c,2025-26,historical,false
it-giugliano,it-serie-c-gruppe-c,2025-26,historical,false
it-cavese,it-serie-c-gruppe-c,2025-26,historical,false
it-cosenza,it-serie-c-gruppe-c,2025-26,historical,false
it-crotone,it-serie-c-gruppe-c,2025-26,historical,false
it-latina,it-serie-c-gruppe-c,2025-26,historical,false
it-foggia,it-serie-c-gruppe-c,2025-26,historical,false
it-salernitana,it-serie-c-gruppe-c,2025-26,historical,false
it-picerno,it-serie-c-gruppe-c,2025-26,historical,false
it-sorrento,it-serie-c-gruppe-c,2025-26,historical,false
it-potenza,it-serie-c-gruppe-c,2025-26,historical,false
it-monopoli,it-serie-c-gruppe-c,2025-26,historical,false
it-trapani,it-serie-c-gruppe-c,2025-26,historical,false
it-siracusa,it-serie-c-gruppe-c,2025-26,historical,false
"""

    private static let germanyHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
de-bayern-munchen,de-bundesliga,2025-26,historical,false
de-bayer-leverkusen,de-bundesliga,2025-26,historical,false
de-eintracht-frankfurt,de-bundesliga,2025-26,historical,false
de-borussia-dortmund,de-bundesliga,2025-26,historical,false
de-sc-freiburg,de-bundesliga,2025-26,historical,false
de-mainz-05,de-bundesliga,2025-26,historical,false
de-rb-leipzig,de-bundesliga,2025-26,historical,false
de-werder-bremen,de-bundesliga,2025-26,historical,false
de-vfb-stuttgart,de-bundesliga,2025-26,historical,false
de-borussia-monchengladbach,de-bundesliga,2025-26,historical,false
de-vfl-wolfsburg,de-bundesliga,2025-26,historical,false
de-fc-augsburg,de-bundesliga,2025-26,historical,false
de-union-berlin,de-bundesliga,2025-26,historical,false
de-fc-st-pauli,de-bundesliga,2025-26,historical,false
de-tsg-hoffenheim,de-bundesliga,2025-26,historical,false
de-heidenheim,de-bundesliga,2025-26,historical,false
de-fc-koln,de-bundesliga,2025-26,historical,false
de-hamburger-sv,de-bundesliga,2025-26,historical,false
de-sv-darmstadt-98,de-2-bundesliga,2025-26,historical,false
de-sv-elversberg,de-2-bundesliga,2025-26,historical,false
de-hannover-96,de-2-bundesliga,2025-26,historical,false
de-magdeburg,de-2-bundesliga,2025-26,historical,false
de-sc-paderborn-07,de-2-bundesliga,2025-26,historical,false
de-arminia-bielefeld,de-2-bundesliga,2025-26,historical,false
de-kaiserslautern,de-2-bundesliga,2025-26,historical,false
de-dynamo-dresden,de-2-bundesliga,2025-26,historical,false
de-holstein-kiel,de-2-bundesliga,2025-26,historical,false
de-preussen-munster,de-2-bundesliga,2025-26,historical,false
de-schalke-04,de-2-bundesliga,2025-26,historical,false
de-hertha-bsc,de-2-bundesliga,2025-26,historical,false
de-karlsruher-sc,de-2-bundesliga,2025-26,historical,false
de-eintracht-braunschweig,de-2-bundesliga,2025-26,historical,false
de-fortuna-dusseldorf,de-2-bundesliga,2025-26,historical,false
de-vfl-bochum,de-2-bundesliga,2025-26,historical,false
de-nurnberg,de-2-bundesliga,2025-26,historical,false
de-greuther-furth,de-2-bundesliga,2025-26,historical,false
de-energie-cottbus,de-3-liga,2025-26,historical,false
de-msv-duisburg,de-3-liga,2025-26,historical,false
de-sc-verl,de-3-liga,2025-26,historical,false
de-vfl-osnabruck,de-3-liga,2025-26,historical,false
de-hansa-rostock,de-3-liga,2025-26,historical,false
de-rot-weiss-essen,de-3-liga,2025-26,historical,false
de-1860-munchen,de-3-liga,2025-26,historical,false
de-tsg-hoffenheim-ii,de-3-liga,2025-26,historical,false
de-waldhof-mannheim,de-3-liga,2025-26,historical,false
de-wehen-wiesbaden,de-3-liga,2025-26,historical,false
de-viktoria-koln,de-3-liga,2025-26,historical,false
de-vfb-stuttgart-ii,de-3-liga,2025-26,historical,false
de-fc-ingolstadt-04,de-3-liga,2025-26,historical,false
de-saarbrucken,de-3-liga,2025-26,historical,false
de-jahn-regensburg,de-3-liga,2025-26,historical,false
de-alemannia-aachen,de-3-liga,2025-26,historical,false
de-erzgebirge-aue,de-3-liga,2025-26,historical,false
de-ssv-ulm-1846,de-3-liga,2025-26,historical,false
de-tsv-havelse,de-3-liga,2025-26,historical,false
de-schweinfurt-05,de-3-liga,2025-26,historical,false
"""

    private static let franceHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
fr-angers,fr-ligue-1,2025-26,historical,false
fr-auxerre,fr-ligue-1,2025-26,historical,false
fr-brest,fr-ligue-1,2025-26,historical,false
fr-le-havre,fr-ligue-1,2025-26,historical,false
fr-lens,fr-ligue-1,2025-26,historical,false
fr-lille,fr-ligue-1,2025-26,historical,false
fr-lorient,fr-ligue-1,2025-26,historical,false
fr-lyon,fr-ligue-1,2025-26,historical,false
fr-marseille,fr-ligue-1,2025-26,historical,false
fr-metz,fr-ligue-1,2025-26,historical,false
fr-monaco,fr-ligue-1,2025-26,historical,false
fr-nantes,fr-ligue-1,2025-26,historical,false
fr-nice,fr-ligue-1,2025-26,historical,false
fr-psg,fr-ligue-1,2025-26,historical,false
fr-paris-fc,fr-ligue-1,2025-26,historical,false
fr-rennes,fr-ligue-1,2025-26,historical,false
fr-strasbourg,fr-ligue-1,2025-26,historical,false
fr-toulouse,fr-ligue-1,2025-26,historical,false
fr-amiens,fr-ligue-2,2025-26,historical,false
fr-annecy-fc,fr-ligue-2,2025-26,historical,false
fr-bastia,fr-ligue-2,2025-26,historical,false
fr-boulogne,fr-ligue-2,2025-26,historical,false
fr-clermont,fr-ligue-2,2025-26,historical,false
fr-grenoble,fr-ligue-2,2025-26,historical,false
fr-guingamp,fr-ligue-2,2025-26,historical,false
fr-laval,fr-ligue-2,2025-26,historical,false
fr-le-mans,fr-ligue-2,2025-26,historical,false
fr-montpellier,fr-ligue-2,2025-26,historical,false
fr-nancy,fr-ligue-2,2025-26,historical,false
fr-pau-fc,fr-ligue-2,2025-26,historical,false
fr-red-star,fr-ligue-2,2025-26,historical,false
fr-reims,fr-ligue-2,2025-26,historical,false
fr-rodez,fr-ligue-2,2025-26,historical,false
fr-st-etienne,fr-ligue-2,2025-26,historical,false
fr-troyes,fr-ligue-2,2025-26,historical,false
fr-usl-dunkerque,fr-ligue-2,2025-26,historical,false
fr-ajaccio,fr-national,2025-26,historical,false
fr-aubagne,fr-national,2025-26,historical,false
fr-bourg-en-bresse,fr-national,2025-26,historical,false
fr-caen,fr-national,2025-26,historical,false
fr-chateauroux,fr-national,2025-26,historical,false
fr-concarneau,fr-national,2025-26,historical,false
fr-dijon,fr-national,2025-26,historical,false
fr-fleury-merogis,fr-national,2025-26,historical,false
fr-le-puy,fr-national,2025-26,historical,false
fr-orleans,fr-national,2025-26,historical,false
fr-paris-13-atl,fr-national,2025-26,historical,false
fr-quevilly-rouen,fr-national,2025-26,historical,false
fr-rouen,fr-national,2025-26,historical,false
fr-sochaux,fr-national,2025-26,historical,false
fr-stade-briochin,fr-national,2025-26,historical,false
fr-valenciennes,fr-national,2025-26,historical,false
fr-versailles,fr-national,2025-26,historical,false
fr-villefranche,fr-national,2025-26,historical,false
"""

    private static let portugalHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
pt-academica,pt-liga-3-oprykningsgruppe,2025-26,historical,false
pt-amarante,pt-liga-3-oprykningsgruppe,2025-26,historical,false
pt-guimaraes-b,pt-liga-3-oprykningsgruppe,2025-26,historical,false
pt-mafra,pt-liga-3-oprykningsgruppe,2025-26,historical,false
pt-os-belenenses,pt-liga-3-oprykningsgruppe,2025-26,historical,false
pt-santarem,pt-liga-3-oprykningsgruppe,2025-26,historical,false
pt-trofense,pt-liga-3-oprykningsgruppe,2025-26,historical,false
pt-varzim,pt-liga-3-oprykningsgruppe,2025-26,historical,false
pt-afs,pt-liga-portugal,2025-26,historical,false
pt-alverca,pt-liga-portugal,2025-26,historical,false
pt-arouca,pt-liga-portugal,2025-26,historical,false
pt-benfica,pt-liga-portugal,2025-26,historical,false
pt-braga,pt-liga-portugal,2025-26,historical,false
pt-casa-pia,pt-liga-portugal,2025-26,historical,false
pt-estoril-praia,pt-liga-portugal,2025-26,historical,false
pt-estrela,pt-liga-portugal,2025-26,historical,false
pt-famalicao,pt-liga-portugal,2025-26,historical,false
pt-gil-vicente,pt-liga-portugal,2025-26,historical,false
pt-guimaraes,pt-liga-portugal,2025-26,historical,false
pt-moreirense,pt-liga-portugal,2025-26,historical,false
pt-nacional,pt-liga-portugal,2025-26,historical,false
pt-porto,pt-liga-portugal,2025-26,historical,false
pt-rio-ave,pt-liga-portugal,2025-26,historical,false
pt-santa-clara,pt-liga-portugal,2025-26,historical,false
pt-sporting,pt-liga-portugal,2025-26,historical,false
pt-tondela,pt-liga-portugal,2025-26,historical,false
pt-academico-viseu,pt-liga-portugal-2,2025-26,historical,false
pt-benfica-b,pt-liga-portugal-2,2025-26,historical,false
pt-chaves,pt-liga-portugal-2,2025-26,historical,false
pt-farense,pt-liga-portugal-2,2025-26,historical,false
pt-feirense,pt-liga-portugal-2,2025-26,historical,false
pt-felgueiras,pt-liga-portugal-2,2025-26,historical,false
pt-ferreira,pt-liga-portugal-2,2025-26,historical,false
pt-leiria,pt-liga-portugal-2,2025-26,historical,false
pt-leixoes,pt-liga-portugal-2,2025-26,historical,false
pt-lusitania-fc,pt-liga-portugal-2,2025-26,historical,false
pt-maritimo,pt-liga-portugal-2,2025-26,historical,false
pt-oliveirense,pt-liga-portugal-2,2025-26,historical,false
pt-penafiel,pt-liga-portugal-2,2025-26,historical,false
pt-portimonense,pt-liga-portugal-2,2025-26,historical,false
pt-porto-b,pt-liga-portugal-2,2025-26,historical,false
pt-sporting-b,pt-liga-portugal-2,2025-26,historical,false
pt-torreense,pt-liga-portugal-2,2025-26,historical,false
pt-vizela,pt-liga-portugal-2,2025-26,historical,false
"""

    private static let netherlandsHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
nl-ajax,nl-eredivisie,2025-26,historical,false
nl-alkmaar,nl-eredivisie,2025-26,historical,false
nl-breda,nl-eredivisie,2025-26,historical,false
nl-excelsior,nl-eredivisie,2025-26,historical,false
nl-feyenoord,nl-eredivisie,2025-26,historical,false
nl-ga-eagles,nl-eredivisie,2025-26,historical,false
nl-groningen,nl-eredivisie,2025-26,historical,false
nl-heerenveen,nl-eredivisie,2025-26,historical,false
nl-heracles,nl-eredivisie,2025-26,historical,false
nl-nijmegen,nl-eredivisie,2025-26,historical,false
nl-psv,nl-eredivisie,2025-26,historical,false
nl-sittard,nl-eredivisie,2025-26,historical,false
nl-sparta-rotterdam,nl-eredivisie,2025-26,historical,false
nl-telstar,nl-eredivisie,2025-26,historical,false
nl-twente,nl-eredivisie,2025-26,historical,false
nl-utrecht,nl-eredivisie,2025-26,historical,false
nl-fc-volendam,nl-eredivisie,2025-26,historical,false
nl-zwolle,nl-eredivisie,2025-26,historical,false
nl-ado-den-haag,nl-eerste-divisie,2025-26,historical,false
nl-almere-city,nl-eerste-divisie,2025-26,historical,false
nl-cambuur,nl-eerste-divisie,2025-26,historical,false
nl-de-graafschap,nl-eerste-divisie,2025-26,historical,false
nl-den-bosch,nl-eerste-divisie,2025-26,historical,false
nl-dordrecht,nl-eerste-divisie,2025-26,historical,false
nl-eindhoven,nl-eerste-divisie,2025-26,historical,false
nl-emmen,nl-eerste-divisie,2025-26,historical,false
nl-helmond-sport,nl-eerste-divisie,2025-26,historical,false
nl-jong-ajax,nl-eerste-divisie,2025-26,historical,false
nl-jong-az,nl-eerste-divisie,2025-26,historical,false
nl-jong-psv,nl-eerste-divisie,2025-26,historical,false
nl-jong-fc-utrecht,nl-eerste-divisie,2025-26,historical,false
nl-mvv-maastricht,nl-eerste-divisie,2025-26,historical,false
nl-rkc-waalwijk,nl-eerste-divisie,2025-26,historical,false
nl-roda-jc,nl-eerste-divisie,2025-26,historical,false
nl-top-oss,nl-eerste-divisie,2025-26,historical,false
nl-vitesse,nl-eerste-divisie,2025-26,historical,false
nl-vvv-venlo,nl-eerste-divisie,2025-26,historical,false
nl-willem-ii,nl-eerste-divisie,2025-26,historical,false
nl-acv-assen,nl-tweede-divisie,2025-26,historical,false
nl-afc,nl-tweede-divisie,2025-26,historical,false
nl-barendrecht,nl-tweede-divisie,2025-26,historical,false
nl-excelsior-maassluis,nl-tweede-divisie,2025-26,historical,false
nl-gvvv,nl-tweede-divisie,2025-26,historical,false
nl-hardenberg,nl-tweede-divisie,2025-26,historical,false
nl-hfc,nl-tweede-divisie,2025-26,historical,false
nl-hoek,nl-tweede-divisie,2025-26,historical,false
nl-ijsselmeervogels,nl-tweede-divisie,2025-26,historical,false
nl-jong-almere-city,nl-tweede-divisie,2025-26,historical,false
nl-jong-sparta-rotterdam,nl-tweede-divisie,2025-26,historical,false
nl-katwijk,nl-tweede-divisie,2025-26,historical,false
nl-kozakken-boys,nl-tweede-divisie,2025-26,historical,false
nl-quick-boys,nl-tweede-divisie,2025-26,historical,false
nl-rijnsburgse-boys,nl-tweede-divisie,2025-26,historical,false
nl-spakenburg,nl-tweede-divisie,2025-26,historical,false
nl-de-treffers,nl-tweede-divisie,2025-26,historical,false
nl-rkav-volendam,nl-tweede-divisie,2025-26,historical,false
"""

    private static let belgiumHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
be-anderlecht,be-jupiler-pro-league,2025-26,historical,false
be-antwerp,be-jupiler-pro-league,2025-26,historical,false
be-cercle-brugge,be-jupiler-pro-league,2025-26,historical,false
be-charleroi,be-jupiler-pro-league,2025-26,historical,false
be-club-brugge,be-jupiler-pro-league,2025-26,historical,false
be-dender,be-jupiler-pro-league,2025-26,historical,false
be-genk,be-jupiler-pro-league,2025-26,historical,false
be-gent,be-jupiler-pro-league,2025-26,historical,false
be-kv-mechelen,be-jupiler-pro-league,2025-26,historical,false
be-leuven,be-jupiler-pro-league,2025-26,historical,false
be-raal-la-louviere,be-jupiler-pro-league,2025-26,historical,false
be-royale-union-sg,be-jupiler-pro-league,2025-26,historical,false
be-st-liege,be-jupiler-pro-league,2025-26,historical,false
be-st-truiden,be-jupiler-pro-league,2025-26,historical,false
be-waregem,be-jupiler-pro-league,2025-26,historical,false
be-westerlo,be-jupiler-pro-league,2025-26,historical,false
be-beerschot-va,be-challenger-pro-league,2025-26,historical,false
be-beveren,be-challenger-pro-league,2025-26,historical,false
be-club-nxt,be-challenger-pro-league,2025-26,historical,false
be-eupen,be-challenger-pro-league,2025-26,historical,false
be-francs-borains,be-challenger-pro-league,2025-26,historical,false
be-jong-genk,be-challenger-pro-league,2025-26,historical,false
be-jong-kaa-gent,be-challenger-pro-league,2025-26,historical,false
be-kortrijk,be-challenger-pro-league,2025-26,historical,false
be-lierse,be-challenger-pro-league,2025-26,historical,false
be-lokeren,be-challenger-pro-league,2025-26,historical,false
be-lommel-sk,be-challenger-pro-league,2025-26,historical,false
be-olympic-charleroi,be-challenger-pro-league,2025-26,historical,false
be-patro-eisden,be-challenger-pro-league,2025-26,historical,false
be-rfc-liege,be-challenger-pro-league,2025-26,historical,false
be-rsca-futures,be-challenger-pro-league,2025-26,historical,false
be-rwdm-brussels,be-challenger-pro-league,2025-26,historical,false
be-seraing,be-challenger-pro-league,2025-26,historical,false
be-crossing-schaerbeek,be-national-division-1-acff,2025-26,historical,false
be-habay-la-neuve,be-national-division-1-acff,2025-26,historical,false
be-meux,be-national-division-1-acff,2025-26,historical,false
be-renaissance-mons,be-national-division-1-acff,2025-26,historical,false
be-sl16-fc,be-national-division-1-acff,2025-26,historical,false
be-stockay-warfusee,be-national-division-1-acff,2025-26,historical,false
be-tubize-braine,be-national-division-1-acff,2025-26,historical,false
be-union-namur,be-national-division-1-acff,2025-26,historical,false
be-union-rochefortoise,be-national-division-1-acff,2025-26,historical,false
be-union-sg-b,be-national-division-1-acff,2025-26,historical,false
be-virton,be-national-division-1-acff,2025-26,historical,false
be-zebra-elites,be-national-division-1-acff,2025-26,historical,false
be-belisia-bilzen,be-national-division-1-vv,2025-26,historical,false
be-dessel-sport,be-national-division-1-vv,2025-26,historical,false
be-diegem,be-national-division-1-vv,2025-26,historical,false
be-hasselt,be-national-division-1-vv,2025-26,historical,false
be-hoogstraten,be-national-division-1-vv,2025-26,historical,false
be-houtvenne,be-national-division-1-vv,2025-26,historical,false
be-jong-cercle,be-national-division-1-vv,2025-26,historical,false
be-knokke,be-national-division-1-vv,2025-26,historical,false
be-lyra-lierse-berlaar,be-national-division-1-vv,2025-26,historical,false
be-merelbeke,be-national-division-1-vv,2025-26,historical,false
be-ninove,be-national-division-1-vv,2025-26,historical,false
be-oh-leuven-u-23,be-national-division-1-vv,2025-26,historical,false
be-roeselare,be-national-division-1-vv,2025-26,historical,false
be-thes-sport,be-national-division-1-vv,2025-26,historical,false
be-tienen,be-national-division-1-vv,2025-26,historical,false
be-zelzate,be-national-division-1-vv,2025-26,historical,false
"""

    private static let turkeyHistoricalMembershipsCSV = """
club_id,competition_id,season_id,membership_status,is_primary
tr-alanyaspor,tr-super-lig,2025-26,historical,false
tr-antalyaspor,tr-super-lig,2025-26,historical,false
tr-basaksehir,tr-super-lig,2025-26,historical,false
tr-besiktas,tr-super-lig,2025-26,historical,false
tr-eyupspor,tr-super-lig,2025-26,historical,false
tr-fatih-karagumruk,tr-super-lig,2025-26,historical,false
tr-fenerbahce,tr-super-lig,2025-26,historical,false
tr-galatasaray,tr-super-lig,2025-26,historical,false
tr-gaziantep,tr-super-lig,2025-26,historical,false
tr-genclerbirligi,tr-super-lig,2025-26,historical,false
tr-goztepe,tr-super-lig,2025-26,historical,false
tr-kasimpasa,tr-super-lig,2025-26,historical,false
tr-kayserispor,tr-super-lig,2025-26,historical,false
tr-kocaelispor,tr-super-lig,2025-26,historical,false
tr-konyaspor,tr-super-lig,2025-26,historical,false
tr-rizespor,tr-super-lig,2025-26,historical,false
tr-samsunspor,tr-super-lig,2025-26,historical,false
tr-trabzonspor,tr-super-lig,2025-26,historical,false
tr-adana-demirspor,tr-1-lig,2025-26,historical,false
tr-amedspor,tr-1-lig,2025-26,historical,false
tr-bandirmaspor,tr-1-lig,2025-26,historical,false
tr-bodrumspor,tr-1-lig,2025-26,historical,false
tr-boluspor,tr-1-lig,2025-26,historical,false
tr-corum,tr-1-lig,2025-26,historical,false
tr-erzurumspor,tr-1-lig,2025-26,historical,false
tr-esenler-erokspor,tr-1-lig,2025-26,historical,false
tr-hatayspor,tr-1-lig,2025-26,historical,false
tr-igdir,tr-1-lig,2025-26,historical,false
tr-i-stanbulspor,tr-1-lig,2025-26,historical,false
tr-keciorengucu,tr-1-lig,2025-26,historical,false
tr-manisa,tr-1-lig,2025-26,historical,false
tr-pendikspor,tr-1-lig,2025-26,historical,false
tr-sakaryaspor,tr-1-lig,2025-26,historical,false
tr-sariyer,tr-1-lig,2025-26,historical,false
tr-serikspor,tr-1-lig,2025-26,historical,false
tr-sivasspor,tr-1-lig,2025-26,historical,false
tr-umraniyespor,tr-1-lig,2025-26,historical,false
tr-vanspor,tr-1-lig,2025-26,historical,false
tr-24-erzincanspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-adana-01,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-altinordu,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-ankaraspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-batman-petrolspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-beykoz-anadoluspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-beyoglu-yeni-carsi,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-bucaspor-1928,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-elazigspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-erbaaspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-i-negolspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-i-skenderunspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-karacabey-belediyespor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-karaman,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-kastamonuspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-kepezspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-mke-ankaragucu,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-muglaspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-sanliurfaspor,tr-2-lig-beyaz-grup,2025-26,historical,false
tr-1461-trabzon,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-68-aksaray-belediyespor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-adanaspor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-aliaga,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-ankara-demirspor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-arnavutkoy-belediyespor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-bursaspor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-fethiyespor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-guzide-gebzespor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-isparta-32,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-kahramanmaras-i-stiklalspor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-kirklarelispor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-mardin-1969,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-menemen,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-musspor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-somaspor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-yeni-malatyaspor,tr-2-lig-kirmizi-grup,2025-26,historical,false
tr-yeni-mersin-i-dmanyurdu,tr-2-lig-kirmizi-grup,2025-26,historical,false
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
