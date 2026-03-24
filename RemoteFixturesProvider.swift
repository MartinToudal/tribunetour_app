import Foundation

struct FixturesLoadResult {
    enum Source: String {
        case remote
        case localFallback
    }

    let fixtures: [Fixture]
    let source: Source
    let version: String?
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

    private static let remoteURLKey = "fixtures.remote.url"

    private let remoteURL: URL?
    private let fetchData: FetchData
    private let localFallback: LocalFallback

    init(
        remoteURL: URL? = RemoteFixturesProvider.remoteURLFromDefaults(),
        fetchData: @escaping FetchData = RemoteFixturesProvider.defaultFetch,
        localFallback: @escaping LocalFallback = {
            try FixturesCSVImporter.loadFixturesFromBundle(csvFileName: "fixtures")
        }
    ) {
        self.remoteURL = remoteURL
        self.fetchData = fetchData
        self.localFallback = localFallback
    }

    func loadFixtures() async throws -> FixturesLoadResult {
        guard let remoteURL else {
            let local = try localFallback()
            return FixturesLoadResult(fixtures: local, source: .localFallback, version: nil)
        }

        do {
            let raw = try await fetchData(remoteURL)
            let envelope = try decodeEnvelope(from: raw)
            let mapped = try envelope.fixtures.map { try $0.toFixture() }.sorted { $0.kickoff < $1.kickoff }
            guard !mapped.isEmpty else { throw RemoteFixturesProviderError.invalidPayload }
            return FixturesLoadResult(fixtures: mapped, source: .remote, version: envelope.metadata?.version)
        } catch {
            dlogFixturesLoad(source: .localFallback, version: nil, reason: error.localizedDescription)
            let local = try localFallback()
            return FixturesLoadResult(fixtures: local, source: .localFallback, version: nil)
        }
    }

    private func decodeEnvelope(from data: Data) throws -> RemoteDatasetEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RemoteDatasetEnvelope.self, from: data)
    }

    private static func remoteURLFromDefaults() -> URL? {
        guard let raw = UserDefaults.standard.string(forKey: remoteURLKey),
              let url = URL(string: raw),
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
