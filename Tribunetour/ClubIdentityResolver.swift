import Foundation

enum ClubIdentityResolver {
    static let legacyToCanonical: [String: String] = [
        "aab": "dk-aab",
        "aaf": "dk-aarhus-fremad",
        "ab": "dk-ab",
        "ach": "dk-ac-horsens",
        "agf": "dk-agf",
        "b93": "dk-b-93",
        "bif": "dk-brondby-if",
        "bra": "dk-brabrand-if",
        "brø": "dk-bronshoj",
        "efb": "dk-esbjerg-fb",
        "fa2": "dk-fa-2000",
        "faa": "dk-fremad-amager",
        "fcf": "dk-fc-fredericia",
        "fck": "dk-fc-kobenhavn",
        "fcm": "dk-fc-midtjylland",
        "fcn": "dk-fc-nordsjaelland",
        "fre": "dk-frem",
        "hbk": "dk-hb-koge",
        "hel": "dk-fc-helsingor",
        "hik": "dk-hik",
        "hil": "dk-hillerod-fodbold",
        "hob": "dk-hobro-ik",
        "hol": "dk-holbaek-bi",
        "hør": "dk-horsholm-usserod-ik",
        "hvi": "dk-hvidovre-if",
        "ish": "dk-ishoj-if",
        "kol": "dk-kolding-if",
        "lyn": "dk-lyngby-boldklub",
        "lys": "dk-if-lyseng",
        "mid": "dk-middelfart",
        "næs": "dk-naesby-bk",
        "nas": "dk-naestved",
        "nyk": "dk-nykobing-fc",
        "ob": "dk-ob",
        "odd": "dk-odder-fodbold",
        "ran": "dk-randers-fc",
        "ros": "dk-fc-roskilde",
        "sif": "dk-silkeborg-if",
        "sje": "dk-sonderjyske",
        "ski": "dk-skive",
        "sun": "dk-sundby-bk",
        "thi": "dk-thisted-fc",
        "van": "dk-vanlose",
        "vb": "dk-vejle-boldklub",
        "vej": "dk-vejgaard-b",
        "ven": "dk-vendsyssel-ff",
        "vff": "dk-viborg-ff",
        "vsk": "dk-vsk-aarhus"
    ]

    static let canonicalToLegacy: [String: String] = {
        Dictionary(uniqueKeysWithValues: legacyToCanonical.map { ($1, $0) })
    }()

    static func canonicalId(for clubId: String) -> String {
        legacyToCanonical[clubId] ?? clubId
    }

    static func allKnownIds(for clubId: String) -> [String] {
        let canonical = canonicalId(for: clubId)
        var ids: [String] = [clubId]

        if canonical != clubId {
            ids.append(canonical)
        }

        if let legacy = canonicalToLegacy[canonical], legacy != clubId {
            ids.append(legacy)
        }

        return Array(NSOrderedSet(array: ids)) as? [String] ?? ids
    }

    static func aliasMap<T>(from source: [String: T]) -> [String: T] {
        var result = source

        for (id, value) in source {
            for alias in allKnownIds(for: id) where result[alias] == nil {
                result[alias] = value
            }
        }

        return result
    }
}
