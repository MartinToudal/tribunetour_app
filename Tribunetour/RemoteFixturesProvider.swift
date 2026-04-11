import Foundation

struct FixturesLoadResult {
    enum Source: String {
        case remote
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
    typealias FetchData = (URL) async throws -> Data
    typealias LocalFallback = () throws -> [Fixture]

    static let remoteURLKey = "fixtures.remote.url"

    private let remoteURL: URL?
    private let fetchData: FetchData
    private let localFallback: LocalFallback

    init() {
        self.remoteURL = RemoteFixturesProvider.remoteURLFromDefaults()
        self.fetchData = RemoteFixturesProvider.defaultFetch
        self.localFallback = {
            try FixturesCSVImporter.loadFixturesFromBundle(csvFileName: "fixtures")
        }
    }

    init(remoteURL: URL?) {
        self.remoteURL = remoteURL
        self.fetchData = RemoteFixturesProvider.defaultFetch
        self.localFallback = {
            try FixturesCSVImporter.loadFixturesFromBundle(csvFileName: "fixtures")
        }
    }

    init(
        remoteURL: URL?,
        fetchData: @escaping FetchData,
        localFallback: @escaping LocalFallback
    ) {
        self.remoteURL = remoteURL
        self.fetchData = fetchData
        self.localFallback = localFallback
    }

    func loadFixtures() async throws -> FixturesLoadResult {
        guard let remoteURL else {
            let local = try localFallback()
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
            let mapped = try envelope.fixtures.map { try $0.toFixture() }.sorted { $0.kickoff < $1.kickoff }
            guard !mapped.isEmpty else { throw RemoteFixturesProviderError.invalidPayload }
            let merged = mergeWithLocalLeaguePackFixturesIfNeeded(remoteFixtures: mapped)
            return FixturesLoadResult(
                fixtures: merged,
                source: .remote,
                version: envelope.metadata?.version,
                remoteURL: remoteURL,
                fallbackReason: nil
            )
        } catch {
            dlogFixturesLoad(source: .localFallback, version: nil, reason: error.localizedDescription)
            let local = try localFallback()
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

    private func mergeWithLocalLeaguePackFixturesIfNeeded(remoteFixtures: [Fixture]) -> [Fixture] {
        guard AppLeaguePackSettings.germanyTop3Enabled else {
            return remoteFixtures
        }

        guard let localFixtures = try? localFallback(), !localFixtures.isEmpty else {
            return remoteFixtures
        }

        var mergedById = Dictionary(uniqueKeysWithValues: remoteFixtures.map { ($0.id, $0) })
        for fixture in localFixtures where mergedById[fixture.id] == nil {
            mergedById[fixture.id] = fixture
        }

        return mergedById.values.sorted { $0.kickoff < $1.kickoff }
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
