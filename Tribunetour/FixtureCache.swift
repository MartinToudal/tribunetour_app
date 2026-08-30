import Foundation

struct FixtureCacheSnapshot: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let version: String?
    let savedAt: Date
    let fixtures: [Fixture]

    init(version: String?, savedAt: Date = Date(), fixtures: [Fixture]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.version = version
        self.savedAt = savedAt
        self.fixtures = fixtures
    }
}

struct FixtureCacheStore {
    private let fileURL: URL

    init(fileURL: URL = Self.defaultFileURL) {
        self.fileURL = fileURL
    }

    func load() throws -> FixtureCacheSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(FixtureCacheSnapshot.self, from: data)
        guard snapshot.schemaVersion == FixtureCacheSnapshot.currentSchemaVersion else { return nil }
        return snapshot
    }

    func save(_ snapshot: FixtureCacheSnapshot) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var defaultFileURL: URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("Tribunetour", isDirectory: true)
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("denmark-last-known-good.json")
    }
}
