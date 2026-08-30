import Foundation

struct FixturesLoadResult {
    enum Source: String {
        case remote
        case cachedRemote
        case localFallback
    }

    let fixtures: [Fixture]
    let source: Source
    let version: String?
    let remoteURL: URL?
    let fallbackReason: String?
}

enum RemoteFixturesProviderError: LocalizedError {
    case invalidHTTPStatus(Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let code):
            return "Ugyldig HTTP status fra fixtures endpoint: \(code)"
        case .invalidPayload:
            return "Remote fixtures payload kunne ikke valideres"
        }
    }
}

struct RemoteFixturesProvider {
    struct Scope {
        let contains: (_ homeTeamId: String, _ awayTeamId: String, _ venueClubId: String) -> Bool

        static let all = Scope { _, _, _ in true }

        static func denmark(allowedClubIds: Set<String>? = nil) -> Scope {
            Scope { homeTeamId, awayTeamId, venueClubId in
                let ids = [homeTeamId, awayTeamId, venueClubId]
                if let allowedClubIds {
                    return ids.allSatisfy(allowedClubIds.contains)
                }
                return ids.allSatisfy { clubId in
                    clubId.hasPrefix("dk-") || ClubIdentityResolver.legacyToCanonical[clubId] != nil
                }
            }
        }
    }

    typealias FetchData = (URL) async throws -> Data
    typealias LocalFallback = () throws -> [Fixture]
    typealias LoadCache = () throws -> FixtureCacheSnapshot?
    typealias SaveCache = (FixtureCacheSnapshot) throws -> Void

    static let remoteURLKey = "fixtures.remote.url"
    static var resolvedRemoteURL: URL? { remoteURLFromDefaults() }

    private let remoteURL: URL?
    private let fetchData: FetchData
    private let localFallback: LocalFallback
    private let loadCache: LoadCache
    private let saveCache: SaveCache
    private let scope: Scope

    init() {
        let cacheStore = FixtureCacheStore()
        self.remoteURL = RemoteFixturesProvider.remoteURLFromDefaults()
        self.fetchData = RemoteFixturesProvider.defaultFetch
        self.localFallback = {
            try FixturesCSVImporter.loadFixturesFromBundle(csvFileName: "fixtures_denmark")
        }
        self.loadCache = cacheStore.load
        self.saveCache = cacheStore.save
        self.scope = .denmark()
    }

    init(remoteURL: URL?, scope: Scope = .denmark()) {
        let cacheStore = FixtureCacheStore()
        self.remoteURL = remoteURL
        self.fetchData = RemoteFixturesProvider.defaultFetch
        self.localFallback = {
            try FixturesCSVImporter.loadFixturesFromBundle(csvFileName: "fixtures_denmark")
        }
        self.loadCache = cacheStore.load
        self.saveCache = cacheStore.save
        self.scope = scope
    }

    init(
        remoteURL: URL?,
        fetchData: @escaping FetchData,
        localFallback: @escaping LocalFallback,
        loadCache: @escaping LoadCache = { nil },
        saveCache: @escaping SaveCache = { _ in },
        scope: Scope = .denmark()
    ) {
        self.remoteURL = remoteURL
        self.fetchData = fetchData
        self.localFallback = localFallback
        self.loadCache = loadCache
        self.saveCache = saveCache
        self.scope = scope
    }

    func loadFixtures() async throws -> FixturesLoadResult {
        guard let remoteURL else {
            let local = sanitizeFixtures(try localFallback(), source: .localFallback)
            return FixturesLoadResult(
                fixtures: local,
                source: .localFallback,
                version: nil,
                remoteURL: nil,
                fallbackReason: "Ingen remote fixtures-URL er konfigureret"
            )
        }

        do {
            let raw = try await fetchData(remoteURL)
            let envelope = try decodeEnvelope(from: raw)
            let mapped = sanitizeFixtures(
                try envelope.fixtures
                    .filter { scope.contains($0.homeTeamId, $0.awayTeamId, $0.venueClubId) }
                    .map { try $0.toFixture() },
                source: .remote
            )
            guard !mapped.isEmpty else { throw RemoteFixturesProviderError.invalidPayload }

            do {
                try saveCache(FixtureCacheSnapshot(version: envelope.metadata?.version, fixtures: mapped))
            } catch {
                dlog("Fixtures cache kunne ikke gemmes: \(error.localizedDescription)")
            }

            return FixturesLoadResult(
                fixtures: mapped,
                source: .remote,
                version: envelope.metadata?.version,
                remoteURL: remoteURL,
                fallbackReason: nil
            )
        } catch {
            if let cached = loadValidCachedFixtures() {
                dlogFixturesLoad(source: .cachedRemote, version: cached.version, reason: error.localizedDescription)
                return FixturesLoadResult(
                    fixtures: cached.fixtures,
                    source: .cachedRemote,
                    version: cached.version,
                    remoteURL: remoteURL,
                    fallbackReason: error.localizedDescription
                )
            }

            dlogFixturesLoad(source: .localFallback, version: nil, reason: error.localizedDescription)
            let local = sanitizeFixtures(try localFallback(), source: .localFallback)
            return FixturesLoadResult(
                fixtures: local,
                source: .localFallback,
                version: nil,
                remoteURL: remoteURL,
                fallbackReason: error.localizedDescription
            )
        }
    }

    private func decodeEnvelope(from data: Data) throws -> RemoteDatasetEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RemoteDatasetEnvelope.self, from: data)
    }

    private func loadValidCachedFixtures() -> FixtureCacheSnapshot? {
        do {
            guard let snapshot = try loadCache() else { return nil }
            let fixtures = sanitizeFixtures(snapshot.fixtures, source: .cachedRemote)
            guard !fixtures.isEmpty else { return nil }
            return FixtureCacheSnapshot(
                version: snapshot.version,
                savedAt: snapshot.savedAt,
                fixtures: fixtures
            )
        } catch {
            dlog("Fixtures cache kunne ikke læses: \(error.localizedDescription)")
            return nil
        }
    }

    private func sanitizeFixtures(_ fixtures: [Fixture], source: FixturesLoadResult.Source) -> [Fixture] {
        let scopedFixtures = fixtures.filter {
            scope.contains($0.homeTeamId, $0.awayTeamId, $0.venueClubId)
        }
        let seasonValidFixtures = scopedFixtures.filter { FixtureSeasonGuard.contains($0) }
        let droppedCount = fixtures.count - seasonValidFixtures.count
        if droppedCount > 0 {
            dlog("Fixtures load: fjernede \(droppedCount) strukturelt ugyldige kampe fra \(source.rawValue)")
        }

        var fixturesById: [String: Fixture] = [:]
        var duplicateIds = Set<String>()
        for fixture in seasonValidFixtures {
            if fixturesById[fixture.id] == nil {
                fixturesById[fixture.id] = fixture
            } else {
                duplicateIds.insert(fixture.id)
            }
        }

        if !duplicateIds.isEmpty {
            dlog(
                "Fixtures load: ignorerede \(duplicateIds.count) dublerede fixture-ID'er fra "
                    + "\(source.rawValue): \(duplicateIds.sorted().joined(separator: ", "))"
            )
        }

        return fixturesById.values.sorted {
            if $0.kickoff != $1.kickoff {
                return $0.kickoff < $1.kickoff
            }
            return $0.id < $1.id
        }
    }

    private static func remoteURLFromDefaults() -> URL? {
        if let raw = UserDefaults.standard.string(forKey: remoteURLKey),
           let url = validatedRemoteURL(from: raw) {
            return url
        }

        return AppAuthConfiguration.load().fixturesRemoteURL
    }

    private static func validatedRemoteURL(from raw: String) -> URL? {
        guard let url = URL(string: raw),
              let scheme = url.scheme,
              ["https", "http"].contains(scheme.lowercased()) else {
            return nil
        }
        return url
    }

    private static func defaultFetch(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw RemoteFixturesProviderError.invalidHTTPStatus(http.statusCode)
        }
        return data
    }
}
