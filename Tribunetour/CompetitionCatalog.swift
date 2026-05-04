import Foundation

enum CompetitionKind: String, Codable, Hashable {
    case domesticLeague = "domestic_league"
    case europeanCup = "european_cup"
}

enum CompetitionMembershipStatus: String, Codable, CaseIterable, Hashable {
    case active
    case relegated
    case historical
}

struct CompetitionMembership: Hashable, Codable {
    let competitionId: String
    let seasonId: String?
    let status: CompetitionMembershipStatus
    let isPrimary: Bool
}

struct CompetitionCatalogEntry: Hashable {
    let id: String
    let countryCode: String?
    let leaguePackId: String?
    let name: String
    let type: CompetitionKind
    let level: Int?
    let groupKey: String?
    let sortOrder: Int
    let isPrimaryDomestic: Bool
    let isPremiumEligible: Bool
    let aliases: [String]
}

enum CompetitionCatalog {
    static let entries: [CompetitionCatalogEntry] = [
        CompetitionCatalogEntry(id: "dk-superliga", countryCode: "dk", leaguePackId: AppLeaguePackId.coreDenmark.rawValue, name: "Superliga", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 0, isPrimaryDomestic: true, isPremiumEligible: false, aliases: ["superliga"]),
        CompetitionCatalogEntry(id: "dk-1-division", countryCode: "dk", leaguePackId: AppLeaguePackId.coreDenmark.rawValue, name: "1. division", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 1, isPrimaryDomestic: true, isPremiumEligible: false, aliases: ["1. division", "1 division"]),
        CompetitionCatalogEntry(id: "dk-2-division", countryCode: "dk", leaguePackId: AppLeaguePackId.coreDenmark.rawValue, name: "2. division", type: .domesticLeague, level: 3, groupKey: nil, sortOrder: 2, isPrimaryDomestic: true, isPremiumEligible: false, aliases: ["2. division", "2 division"]),
        CompetitionCatalogEntry(id: "dk-3-division", countryCode: "dk", leaguePackId: AppLeaguePackId.coreDenmark.rawValue, name: "3. division", type: .domesticLeague, level: 4, groupKey: nil, sortOrder: 3, isPrimaryDomestic: true, isPremiumEligible: false, aliases: ["3. division", "3 division"]),
        CompetitionCatalogEntry(id: "de-bundesliga", countryCode: "de", leaguePackId: AppLeaguePackId.germanyTop3.rawValue, name: "Bundesliga", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 10, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["bundesliga", "bundelsliga"]),
        CompetitionCatalogEntry(id: "de-2-bundesliga", countryCode: "de", leaguePackId: AppLeaguePackId.germanyTop3.rawValue, name: "2. Bundesliga", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 11, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["2. bundesliga", "2 bundesliga"]),
        CompetitionCatalogEntry(id: "de-3-liga", countryCode: "de", leaguePackId: AppLeaguePackId.germanyTop3.rawValue, name: "3. Liga", type: .domesticLeague, level: 3, groupKey: nil, sortOrder: 12, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["3. liga", "3 liga"]),
        CompetitionCatalogEntry(id: "en-premier-league", countryCode: "en", leaguePackId: AppLeaguePackId.englandTop4.rawValue, name: "Premier League", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 20, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["premier league"]),
        CompetitionCatalogEntry(id: "en-championship", countryCode: "en", leaguePackId: AppLeaguePackId.englandTop4.rawValue, name: "Championship", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 21, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["championship"]),
        CompetitionCatalogEntry(id: "en-league-one", countryCode: "en", leaguePackId: AppLeaguePackId.englandTop4.rawValue, name: "League One", type: .domesticLeague, level: 3, groupKey: nil, sortOrder: 22, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["league one"]),
        CompetitionCatalogEntry(id: "en-league-two", countryCode: "en", leaguePackId: AppLeaguePackId.englandTop4.rawValue, name: "League Two", type: .domesticLeague, level: 4, groupKey: nil, sortOrder: 23, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["league two"]),
        CompetitionCatalogEntry(id: "it-serie-a", countryCode: "it", leaguePackId: AppLeaguePackId.italyTop3.rawValue, name: "Serie A", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 30, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["serie a"]),
        CompetitionCatalogEntry(id: "it-serie-b", countryCode: "it", leaguePackId: AppLeaguePackId.italyTop3.rawValue, name: "Serie B", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 31, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["serie b"]),
        CompetitionCatalogEntry(id: "it-serie-c-gruppe-a", countryCode: "it", leaguePackId: AppLeaguePackId.italyTop3.rawValue, name: "Serie C - Gruppe A", type: .domesticLeague, level: 3, groupKey: "a", sortOrder: 32, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["serie c - gruppe a"]),
        CompetitionCatalogEntry(id: "it-serie-c-gruppe-b", countryCode: "it", leaguePackId: AppLeaguePackId.italyTop3.rawValue, name: "Serie C - Gruppe B", type: .domesticLeague, level: 3, groupKey: "b", sortOrder: 33, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["serie c - gruppe b"]),
        CompetitionCatalogEntry(id: "it-serie-c-gruppe-c", countryCode: "it", leaguePackId: AppLeaguePackId.italyTop3.rawValue, name: "Serie C - Gruppe C", type: .domesticLeague, level: 3, groupKey: "c", sortOrder: 34, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["serie c - gruppe c"]),
        CompetitionCatalogEntry(id: "es-la-liga", countryCode: "es", leaguePackId: AppLeaguePackId.spainTop4.rawValue, name: "La Liga", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 40, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["la liga"]),
        CompetitionCatalogEntry(id: "es-segunda-division", countryCode: "es", leaguePackId: AppLeaguePackId.spainTop4.rawValue, name: "Segunda División", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 41, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["segunda division", "segunda división"]),
        CompetitionCatalogEntry(id: "es-primera-federacion-gruppe-1", countryCode: "es", leaguePackId: AppLeaguePackId.spainTop4.rawValue, name: "Primera Federación - Gruppe 1", type: .domesticLeague, level: 3, groupKey: "1", sortOrder: 42, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["primera federacion - gruppe 1", "primera federación - gruppe 1"]),
        CompetitionCatalogEntry(id: "es-primera-federacion-gruppe-2", countryCode: "es", leaguePackId: AppLeaguePackId.spainTop4.rawValue, name: "Primera Federación - Gruppe 2", type: .domesticLeague, level: 3, groupKey: "2", sortOrder: 43, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["primera federacion - gruppe 2", "primera federación - gruppe 2"]),
        CompetitionCatalogEntry(id: "fr-ligue-1", countryCode: "fr", leaguePackId: AppLeaguePackId.franceTop3.rawValue, name: "Ligue 1", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 50, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["ligue 1"]),
        CompetitionCatalogEntry(id: "fr-ligue-2", countryCode: "fr", leaguePackId: AppLeaguePackId.franceTop3.rawValue, name: "Ligue 2", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 51, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["ligue 2"]),
        CompetitionCatalogEntry(id: "fr-national", countryCode: "fr", leaguePackId: AppLeaguePackId.franceTop3.rawValue, name: "National", type: .domesticLeague, level: 3, groupKey: nil, sortOrder: 52, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["national"]),
        CompetitionCatalogEntry(id: "pt-liga-portugal", countryCode: "pt", leaguePackId: AppLeaguePackId.portugalTop3.rawValue, name: "Liga Portugal", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 60, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["liga portugal", "primeira liga"]),
        CompetitionCatalogEntry(id: "pt-liga-portugal-2", countryCode: "pt", leaguePackId: AppLeaguePackId.portugalTop3.rawValue, name: "Liga Portugal 2", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 61, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["liga portugal 2", "segunda liga"]),
        CompetitionCatalogEntry(id: "pt-liga-3-oprykningsgruppe", countryCode: "pt", leaguePackId: AppLeaguePackId.portugalTop3.rawValue, name: "Liga 3 - Oprykningsgruppe", type: .domesticLeague, level: 3, groupKey: "promotion", sortOrder: 62, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["liga 3 - oprykningsgruppe", "liga 3 promotion stage", "liga 3 promotion group"]),
        CompetitionCatalogEntry(id: "nl-eredivisie", countryCode: "nl", leaguePackId: AppLeaguePackId.netherlandsTop3.rawValue, name: "Eredivisie", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 70, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["eredivisie", "aeresdivisionen", "æresdivisionen"]),
        CompetitionCatalogEntry(id: "nl-eerste-divisie", countryCode: "nl", leaguePackId: AppLeaguePackId.netherlandsTop3.rawValue, name: "Eerste Divisie", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 71, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["eerste divisie"]),
        CompetitionCatalogEntry(id: "nl-tweede-divisie", countryCode: "nl", leaguePackId: AppLeaguePackId.netherlandsTop3.rawValue, name: "Tweede Divisie", type: .domesticLeague, level: 3, groupKey: nil, sortOrder: 72, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["tweede divisie"]),
        CompetitionCatalogEntry(id: "nl-promotion-relegation-playoffs", countryCode: "nl", leaguePackId: AppLeaguePackId.netherlandsTop3.rawValue, name: "Promotie/degradatie play-offs", type: .domesticLeague, level: nil, groupKey: "playoff", sortOrder: 73, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["promotie/degradatie play-offs", "eredivisie playoffs", "promotion relegation playoffs"]),
        CompetitionCatalogEntry(id: "be-jupiler-pro-league", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "Jupiler Pro League", type: .domesticLeague, level: 1, groupKey: nil, sortOrder: 80, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["jupiler pro league", "jupiler league"]),
        CompetitionCatalogEntry(id: "be-challenger-pro-league", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "Challenger Pro League", type: .domesticLeague, level: 2, groupKey: nil, sortOrder: 81, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["challenger pro league"]),
        CompetitionCatalogEntry(id: "be-national-division-1-acff", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "National Division 1 ACFF", type: .domesticLeague, level: 3, groupKey: "acff", sortOrder: 82, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["national division 1 acff"]),
        CompetitionCatalogEntry(id: "be-national-division-1-vv", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "National Division 1 VV", type: .domesticLeague, level: 3, groupKey: "vv", sortOrder: 83, isPrimaryDomestic: true, isPremiumEligible: true, aliases: ["national division 1 vv"]),
        CompetitionCatalogEntry(id: "be-pro-league-relegation-playoffs", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "Jupiler Pro League - Nedrykningsgruppe", type: .domesticLeague, level: nil, groupKey: "relegation-playoff", sortOrder: 84, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["jupiler pro league - nedrykningsgruppe", "jupiler league - nedrykningsgruppe"]),
        CompetitionCatalogEntry(id: "be-pro-league-champions-playoffs", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "Jupiler Pro League - Mesterskabsspil", type: .domesticLeague, level: nil, groupKey: "championship-playoff", sortOrder: 85, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["jupiler pro league - mesterskabsspil", "jupiler league - mesterskabet - slutspil"]),
        CompetitionCatalogEntry(id: "be-pro-league-europe-playoffs", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "Jupiler Pro League - Conference League Gruppe", type: .domesticLeague, level: nil, groupKey: "conference-playoff", sortOrder: 86, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["jupiler pro league - conference league gruppe", "jupiler league - conference league gruppe"]),
        CompetitionCatalogEntry(id: "be-promotion-relegation-playoffs", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "Belgisk promotion/relegation playoff", type: .domesticLeague, level: nil, groupKey: "promotion-relegation-playoff", sortOrder: 87, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["belgisk promotion/relegation playoff", "jupiler league - nedrykning"]),
        CompetitionCatalogEntry(id: "be-national-division-1-acff-promotion-group", countryCode: "be", leaguePackId: AppLeaguePackId.belgiumTop3.rawValue, name: "National Division 1 ACFF - Oprykningsgruppe", type: .domesticLeague, level: nil, groupKey: "promotion-group", sortOrder: 88, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["national division 1 acff - oprykningsgruppe"]),
        CompetitionCatalogEntry(id: "uefa-champions-league", countryCode: nil, leaguePackId: nil, name: "UEFA Champions League", type: .europeanCup, level: nil, groupKey: nil, sortOrder: 900, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["champions league", "uefa champions league"]),
        CompetitionCatalogEntry(id: "uefa-europa-league", countryCode: nil, leaguePackId: nil, name: "UEFA Europa League", type: .europeanCup, level: nil, groupKey: nil, sortOrder: 910, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["europa league", "uefa europa league"]),
        CompetitionCatalogEntry(id: "uefa-conference-league", countryCode: nil, leaguePackId: nil, name: "UEFA Conference League", type: .europeanCup, level: nil, groupKey: nil, sortOrder: 920, isPrimaryDomestic: false, isPremiumEligible: true, aliases: ["conference league", "uefa conference league"])
    ]

    private static let entryById = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    private static let entryByLeagueCode = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    private static let entryByNormalizedAlias: [String: CompetitionCatalogEntry] = {
        var mapping: [String: CompetitionCatalogEntry] = [:]

        for entry in entries {
            for alias in [entry.name] + entry.aliases {
                let normalizedAlias = normalizedCompetitionName(alias)
                if mapping[normalizedAlias] == nil {
                    mapping[normalizedAlias] = entry
                }
            }
        }

        return mapping
    }()

    static func normalizedCompetitionName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "bundelsliga", with: "bundesliga")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func entry(forId id: String?) -> CompetitionCatalogEntry? {
        guard let id else { return nil }
        return entryById[id]
    }

    static func entry(forLeagueCode leagueCode: String?) -> CompetitionCatalogEntry? {
        guard let leagueCode else { return nil }
        return entryByLeagueCode[leagueCode]
    }

    static func entry(forLeagueName leagueName: String) -> CompetitionCatalogEntry? {
        entryByNormalizedAlias[normalizedCompetitionName(leagueName)]
    }

    static func resolveEntry(
        competitionId: String?,
        leagueCode: String?,
        leagueName: String,
        countryCode: String
    ) -> CompetitionCatalogEntry? {
        if let byId = entry(forId: competitionId) {
            return byId
        }
        if let byCode = entry(forLeagueCode: leagueCode) {
            return byCode
        }
        if let byName = entry(forLeagueName: leagueName), byName.countryCode == countryCode {
            return byName
        }
        return entry(forLeagueName: leagueName)
    }

    static func inferredCompetitionId(
        leagueCode: String?,
        leagueName: String,
        countryCode: String
    ) -> String? {
        resolveEntry(competitionId: nil, leagueCode: leagueCode, leagueName: leagueName, countryCode: countryCode)?.id
    }

    static func sortOrder(
        competitionId: String?,
        leagueCode: String?,
        leagueName: String,
        countryCode: String
    ) -> Int {
        resolveEntry(competitionId: competitionId, leagueCode: leagueCode, leagueName: leagueName, countryCode: countryCode)?.sortOrder ?? 99
    }

    static func displayName(
        competitionId: String?,
        leagueCode: String?,
        fallbackLeagueName: String,
        countryCode: String
    ) -> String {
        resolveEntry(competitionId: competitionId, leagueCode: leagueCode, leagueName: fallbackLeagueName, countryCode: countryCode)?.name ?? fallbackLeagueName
    }

    static func isPrimaryDomesticCompetition(_ competitionId: String?) -> Bool {
        entry(forId: competitionId)?.isPrimaryDomestic ?? false
    }

    static func displayName(for competitionId: String?, fallback: String? = nil) -> String? {
        if let name = entry(forId: competitionId)?.name {
            return name
        }
        return fallback
    }

    static func membershipStatusLabel(_ status: CompetitionMembershipStatus) -> String? {
        switch status {
        case .active:
            return nil
        case .relegated:
            return "Nedrykket"
        case .historical:
            return "Historisk"
        }
    }
}
