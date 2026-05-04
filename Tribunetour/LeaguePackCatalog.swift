import Foundation

enum AppLeaguePackId: String, CaseIterable {
    case coreDenmark = "core_denmark"
    case germanyTop3 = "germany_top_3"
    case englandTop4 = "england_top_4"
    case italyTop3 = "italy_top_3"
    case spainTop4 = "spain_top_4"
    case franceTop3 = "france_top_3"
    case portugalTop3 = "portugal_top_3"
    case netherlandsTop3 = "netherlands_top_3"
    case premiumFull = "premium_full"
}

enum AppPremiumAdminPack: String, CaseIterable, Identifiable {
    case germanyTop3 = "germany_top_3"
    case englandTop4 = "england_top_4"
    case italyTop3 = "italy_top_3"
    case spainTop4 = "spain_top_4"
    case franceTop3 = "france_top_3"
    case portugalTop3 = "portugal_top_3"
    case netherlandsTop3 = "netherlands_top_3"
    case premiumFull = "premium_full"

    var id: String { rawValue }

    var title: String {
        AppLeaguePackCatalog.label(forPackId: rawValue)
    }

    var requestDescription: String {
        AppLeaguePackCatalog.requestDescription(forPackId: rawValue) ?? title
    }
}

struct AppLeaguePackCatalogEntry {
    let id: AppLeaguePackId
    let countryCode: String?
    let label: String
    let sortOrder: Int
    let levels: Int
    let isCore: Bool
    let isPremium: Bool
    let includedByPremiumFull: Bool
    let requestDescription: String?
}

enum AppLeaguePackCatalog {
    static let entries: [AppLeaguePackCatalogEntry] = [
        AppLeaguePackCatalogEntry(
            id: .coreDenmark,
            countryCode: "dk",
            label: "Danmark",
            sortOrder: 0,
            levels: 4,
            isCore: true,
            isPremium: false,
            includedByPremiumFull: false,
            requestDescription: nil
        ),
        AppLeaguePackCatalogEntry(
            id: .germanyTop3,
            countryCode: "de",
            label: "Tyskland",
            sortOrder: 10,
            levels: 3,
            isCore: false,
            isPremium: true,
            includedByPremiumFull: true,
            requestDescription: "Bundesliga, 2. Bundesliga og 3. Liga"
        ),
        AppLeaguePackCatalogEntry(
            id: .englandTop4,
            countryCode: "en",
            label: "England",
            sortOrder: 20,
            levels: 4,
            isCore: false,
            isPremium: true,
            includedByPremiumFull: true,
            requestDescription: "Premier League, Championship, League One og League Two"
        ),
        AppLeaguePackCatalogEntry(
            id: .italyTop3,
            countryCode: "it",
            label: "Italien",
            sortOrder: 30,
            levels: 3,
            isCore: false,
            isPremium: true,
            includedByPremiumFull: true,
            requestDescription: "Serie A, Serie B og Serie C"
        ),
        AppLeaguePackCatalogEntry(
            id: .spainTop4,
            countryCode: "es",
            label: "Spanien",
            sortOrder: 40,
            levels: 4,
            isCore: false,
            isPremium: true,
            includedByPremiumFull: true,
            requestDescription: "La Liga, Segunda División og Primera Federación gruppe 1-2"
        ),
        AppLeaguePackCatalogEntry(
            id: .franceTop3,
            countryCode: "fr",
            label: "Frankrig",
            sortOrder: 50,
            levels: 3,
            isCore: false,
            isPremium: true,
            includedByPremiumFull: true,
            requestDescription: "Ligue 1, Ligue 2 og National"
        ),
        AppLeaguePackCatalogEntry(
            id: .portugalTop3,
            countryCode: "pt",
            label: "Portugal",
            sortOrder: 60,
            levels: 3,
            isCore: false,
            isPremium: true,
            includedByPremiumFull: true,
            requestDescription: "Liga Portugal, Liga Portugal 2 og Liga 3 - Oprykningsgruppe"
        ),
        AppLeaguePackCatalogEntry(
            id: .netherlandsTop3,
            countryCode: "nl",
            label: "Holland",
            sortOrder: 70,
            levels: 3,
            isCore: false,
            isPremium: true,
            includedByPremiumFull: true,
            requestDescription: "Eredivisie, Eerste Divisie og Tweede Divisie"
        ),
        AppLeaguePackCatalogEntry(
            id: .premiumFull,
            countryCode: nil,
            label: "Alle premium-pakker",
            sortOrder: 1000,
            levels: 0,
            isCore: false,
            isPremium: true,
            includedByPremiumFull: false,
            requestDescription: "Adgang til alle nuværende og kommende premium-pakker"
        ),
    ]

    private static let entryById = Dictionary(uniqueKeysWithValues: entries.map { ($0.id.rawValue, $0) })
    private static let countryEntries = entries.filter { $0.countryCode != nil }

    static var premiumFullIncludedPackIds: [String] {
        entries
            .filter { $0.includedByPremiumFull }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { $0.id.rawValue }
    }

    static func label(forPackId packId: String) -> String {
        entryById[packId]?.label ?? packId
    }

    static func requestDescription(forPackId packId: String) -> String? {
        entryById[packId]?.requestDescription
    }

    static func countryRank(_ countryCode: String) -> Int {
        countryEntries.first(where: { $0.countryCode == countryCode })?.sortOrder ?? 99
    }

    static func countryLabel(_ countryCode: String) -> String {
        countryEntries.first(where: { $0.countryCode == countryCode })?.label ?? countryCode.uppercased()
    }
}

enum AppLeaguePackSettings {
    static let germanyTop3EnabledKey = "leaguePacks.germanyTop3.enabled"
    static let remoteEnabledLeaguePacksKey = "leaguePacks.remote.enabled"
    static let preferredHomeCountryCodeKey = "app.preferredHomeCountryCode"

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
        if ids.contains(AppLeaguePackId.premiumFull.rawValue) {
            ids.formUnion(AppLeaguePackCatalog.premiumFullIncludedPackIds)
        }
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
