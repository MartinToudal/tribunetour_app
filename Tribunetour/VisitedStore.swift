import Foundation
import Combine
import CloudKit
import UIKit

@MainActor
final class VisitedStore: ObservableObject {

    // MARK: - Model

    enum ReviewCategory: String, CaseIterable, Codable, Hashable, Identifiable {
        case atmosphereSound
        case sightlinesSeats
        case aestheticsHistory
        case foodDrinkQuality
        case foodDrinkPrice
        case valueForMoney
        case accessTransport
        case facilities
        case matchdayOperations
        case familyFriendliness
        case awayFanConditions

        var id: String { rawValue }

        var title: String {
            switch self {
            case .atmosphereSound:
                return "Atmosfære og lyd"
            case .sightlinesSeats:
                return "Sigtlinjer og pladser"
            case .aestheticsHistory:
                return "Æstetik og historie"
            case .foodDrinkQuality:
                return "Mad og drikke - kvalitet"
            case .foodDrinkPrice:
                return "Mad og drikke - pris"
            case .valueForMoney:
                return "Værdi for pengene (billet)"
            case .accessTransport:
                return "Adgang og transport"
            case .facilities:
                return "Faciliteter"
            case .matchdayOperations:
                return "Matchday drift"
            case .familyFriendliness:
                return "Familievenlighed"
            case .awayFanConditions:
                return "Udebaneforhold"
            }
        }
    }

    struct StadiumReview: Codable, Hashable {
        var matchLabel: String
        var scores: [ReviewCategory: Int]
        var categoryNotes: [ReviewCategory: String]
        var summary: String
        var tags: String
        var updatedAt: Date

        init(
            matchLabel: String = "",
            scores: [ReviewCategory: Int] = [:],
            categoryNotes: [ReviewCategory: String] = [:],
            summary: String = "",
            tags: String = "",
            updatedAt: Date = Date()
        ) {
            self.matchLabel = matchLabel
            self.scores = scores
            self.categoryNotes = categoryNotes
            self.summary = summary
            self.tags = tags
            self.updatedAt = updatedAt
        }

        func score(for category: ReviewCategory) -> Int? {
            scores[category]
        }

        func note(for category: ReviewCategory) -> String {
            categoryNotes[category] ?? ""
        }

        var averageScore: Double? {
            let values = scores.values
            guard !values.isEmpty else { return nil }
            let sum = values.reduce(0, +)
            return Double(sum) / Double(values.count)
        }

        var hasMeaningfulContent: Bool {
            if !scores.isEmpty { return true }
            if categoryNotes.values.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return true }
            if !matchLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            if !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            if !tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            return false
        }
    }

    struct Record: Codable, Hashable {
        struct PhotoMeta: Codable, Hashable {
            var caption: String
            var createdAt: Date
            var updatedAt: Date

            init(caption: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
                self.caption = caption
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }

            private enum CodingKeys: String, CodingKey {
                case caption
                case createdAt
                case updatedAt
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                self.caption = try c.decodeIfPresent(String.self, forKey: .caption) ?? ""
                self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date.distantPast
                self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? self.createdAt
            }
        }

        var visited: Bool
        var visitedDate: Date?
        var notes: String
        var review: StadiumReview?
        var photoFileNames: [String]
        var photoMetadata: [String: PhotoMeta]
        var updatedAt: Date

        init(
            visited: Bool,
            visitedDate: Date? = nil,
            notes: String = "",
            review: StadiumReview? = nil,
            photoFileNames: [String] = [],
            photoMetadata: [String: PhotoMeta] = [:],
            updatedAt: Date = Date()
        ) {
            self.visited = visited
            self.visitedDate = visitedDate
            self.notes = notes
            self.review = review
            self.photoFileNames = photoFileNames
            self.photoMetadata = photoMetadata
            self.updatedAt = updatedAt
        }

        var isEmptyMeaningfulState: Bool {
            !visited
                && visitedDate == nil
                && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !(review?.hasMeaningfulContent ?? false)
                && photoFileNames.isEmpty
        }

        private enum CodingKeys: String, CodingKey {
            case visited
            case visitedDate
            case notes
            case review
            case photoFileNames
            case photoMetadata
            case updatedAt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.visited = try c.decode(Bool.self, forKey: .visited)
            self.visitedDate = try c.decodeIfPresent(Date.self, forKey: .visitedDate)
            self.notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
            self.review = try c.decodeIfPresent(StadiumReview.self, forKey: .review)
            self.photoFileNames = try c.decodeIfPresent([String].self, forKey: .photoFileNames) ?? []
            self.photoMetadata = try c.decodeIfPresent([String: PhotoMeta].self, forKey: .photoMetadata) ?? [:]
            self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        }
    }

    // MARK: - Backup/Restore

    enum BackupError: LocalizedError {
        case emptyInput
        case decodeFailed

        var errorDescription: String? {
            switch self {
            case .emptyInput:
                return "Der var ingen tekst at importere."
            case .decodeFailed:
                return "Kunne ikke læse JSON. Tjek at du har kopieret hele teksten."
            }
        }
    }

    enum PhotoError: LocalizedError {
        case invalidImageData
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Billedet kunne ikke læses."
            case .writeFailed:
                return "Billedet kunne ikke gemmes lokalt."
            }
        }
    }

    // MARK: - Storage

    private let localKey = "tribunetour.visited.local.v1"
    private let sharedRemoteClubIdsKey = "tribunetour.visited.shared.remote-club-ids.v1"
    private let remoteWriteSnapshotsKey = "tribunetour.visited.remote-write-snapshots.v1"
    private let photoDirectoryName = "VisitedPhotos"
    private let maxPhotoPixelDimension: CGFloat = 2200
    private let photoJPEGQuality: CGFloat = 0.82

    // MARK: - State

    @Published private(set) var records: [String: Record] = [:] // key = Club.id (String)
    @Published private(set) var lastSyncIssue: String?

    // MARK: - Cloud sync

    private let syncBackend: any VisitedSyncBackend
    private let mergePolicy: AppVisitedMergePolicy
    private let shouldAttemptRemoteSync: @MainActor () -> Bool
    private var cancellables = Set<AnyCancellable>()
    private var isApplyingRemote = false
    private var isPushingToCloud = false
    private var pendingCloudPush = false
    private var cloudPhotoQueriesAvailable = true
    private var loggedPhotoQueryWarning = false
    private var knownSharedRemoteClubIds = Set<String>()
    private var remoteWriteSnapshotByClubId: [String: String] = [:]

    // MARK: - Init

    init(
        syncBackend: any VisitedSyncBackend,
        mergePolicy: AppVisitedMergePolicy,
        shouldAttemptRemoteSync: @escaping @MainActor () -> Bool = { true }
    ) {
        self.syncBackend = syncBackend
        self.mergePolicy = mergePolicy
        self.shouldAttemptRemoteSync = shouldAttemptRemoteSync
        self.records = loadFromLocal() ?? [:]
        self.knownSharedRemoteClubIds = loadKnownSharedRemoteClubIds()
        self.remoteWriteSnapshotByClubId = loadRemoteWriteSnapshots()

        // Debug: se om iCloud konto er tilgængelig
        Task {
            guard shouldAttemptRemoteSync() else { return }
            await syncBackend.debugAccountStatus()
        }

        // Push lokale ændringer til iCloud (debounced)
        $records
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard !self.isApplyingRemote else { return }
                self.scheduleCloudPush()
            }
            .store(in: &cancellables)

        // Initial sync: pull remote -> merge -> push
        Task { await initialCloudSync() }
    }

    // MARK: - Public API

    func isVisited(_ clubId: String) -> Bool {
        record(for: clubId)?.visited ?? false
    }

    func setVisited(_ clubId: String, _ visited: Bool) {
        let storageClubId = resolvedStorageClubId(for: clubId)
        var r = records[storageClubId] ?? Record(visited: false)
        r.visited = visited
        r.updatedAt = Date()

        // Sæt besøgsdato automatisk første gang man markerer besøgt
        if visited && r.visitedDate == nil {
            r.visitedDate = Date()
        }

        records[storageClubId] = r
        persist()
    }

    func toggle(_ clubId: String) {
        setVisited(clubId, !isVisited(clubId))
    }

    func visitedDate(for clubId: String) -> Date? {
        record(for: clubId)?.visitedDate
    }

    func setVisitedDate(_ clubId: String, _ date: Date?) {
        let storageClubId = resolvedStorageClubId(for: clubId)
        var r = records[storageClubId] ?? Record(visited: false)
        r.visitedDate = date
        r.updatedAt = Date()
        records[storageClubId] = r
        persist()
    }

    func notes(for clubId: String) -> String {
        record(for: clubId)?.notes ?? ""
    }

    func setNotes(_ clubId: String, _ notes: String) {
        let storageClubId = resolvedStorageClubId(for: clubId)
        var r = records[storageClubId] ?? Record(visited: false)
        r.notes = notes
        r.updatedAt = Date()
        records[storageClubId] = r
        persist()
    }

    func applySharedNote(_ note: String, for clubId: String, updatedAt: Date) {
        let storageClubId = resolvedStorageClubId(for: clubId)
        var record = records[storageClubId] ?? Record(visited: false)
        record.notes = note
        record.updatedAt = max(record.updatedAt, updatedAt)
        records[storageClubId] = record
        persist()
    }

    func applySharedReview(_ review: StadiumReview?, for clubId: String, updatedAt: Date) {
        let storageClubId = resolvedStorageClubId(for: clubId)
        var record = records[storageClubId] ?? Record(visited: false)
        record.review = review
        record.updatedAt = max(record.updatedAt, updatedAt)
        if let review, review.hasMeaningfulContent {
            record.visited = true
            if record.visitedDate == nil {
                record.visitedDate = Date()
            }
        }
        records[storageClubId] = record
        persist()
    }

    func review(for clubId: String) -> StadiumReview? {
        record(for: clubId)?.review
    }

    func setReview(_ clubId: String, _ review: StadiumReview?) {
        let storageClubId = resolvedStorageClubId(for: clubId)
        var r = records[storageClubId] ?? Record(visited: false)
        r.review = review
        r.updatedAt = Date()
        if let review, review.hasMeaningfulContent {
            r.visited = true
            if r.visitedDate == nil {
                r.visitedDate = Date()
            }
        }
        records[storageClubId] = r
        persist()
    }

    func photoFileNames(for clubId: String) -> [String] {
        guard let record = record(for: clubId) else { return [] }
        return record.photoFileNames.sorted { a, b in
            let da = record.photoMetadata[a]?.createdAt ?? .distantPast
            let db = record.photoMetadata[b]?.createdAt ?? .distantPast
            if da != db { return da > db }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    func photoURL(fileName: String) -> URL {
        photosDirectoryURL().appendingPathComponent(fileName)
    }

    func addPhotoData(_ imageData: Data, for clubId: String) throws {
        guard !imageData.isEmpty else { throw PhotoError.invalidImageData }
        guard let normalizedData = normalizedJPEGData(from: imageData) else { throw PhotoError.invalidImageData }

        let storageClubId = resolvedStorageClubId(for: clubId)
        let fileName = "\(storageClubId)_\(UUID().uuidString).jpg"
        let url = photoURL(fileName: fileName)

        do {
            try normalizedData.write(to: url, options: .atomic)
        } catch {
            throw PhotoError.writeFailed
        }

        var record = records[storageClubId] ?? Record(visited: false)
        record.photoFileNames.append(fileName)
        let now = Date()
        record.photoMetadata[fileName] = Record.PhotoMeta(createdAt: now, updatedAt: now)
        record.updatedAt = Date()
        if !record.visited {
            record.visited = true
            if record.visitedDate == nil {
                record.visitedDate = Date()
            }
        }
        records[storageClubId] = record
        persist()
        scheduleCloudPush()
    }

    func removePhoto(fileName: String, for clubId: String) {
        removePhotoLocally(fileName: fileName, for: clubId, scheduleRemotePush: true)
        deletePhotoFromVisitedSync(fileName: fileName)
    }

    func removeSharedPhotoLocally(fileName: String, for clubId: String) {
        removePhotoLocally(fileName: fileName, for: clubId, scheduleRemotePush: false)
    }

    func removePhotoLocally(fileName: String, for clubId: String, scheduleRemotePush: Bool) {
        var record = records[clubId] ?? Record(visited: false)
        record.photoFileNames.removeAll { $0 == fileName }
        record.photoMetadata[fileName] = nil
        record.updatedAt = Date()

        let trimmedNotes = record.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasReview = record.review?.hasMeaningfulContent ?? false
        if !record.visited && trimmedNotes.isEmpty && !hasReview && record.photoFileNames.isEmpty {
            records.removeValue(forKey: clubId)
        } else {
            records[clubId] = record
        }

        persist()

        if scheduleRemotePush {
            scheduleCloudPush()
        }

        let url = photoURL(fileName: fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func deletePhotoFromVisitedSync(fileName: String) {
        Task {
            guard shouldAttemptRemoteSync() else { return }
            do {
                try await syncBackend.deletePhoto(fileName: fileName)
            } catch {
                dlog("☁️ Photo delete error for \(fileName): \(error)")
            }
        }
    }

    func photoCaption(for clubId: String, fileName: String) -> String {
        record(for: clubId)?.photoMetadata[fileName]?.caption ?? ""
    }

    func setPhotoCaption(_ caption: String, for clubId: String, fileName: String) {
        let storageClubId = resolvedStorageClubId(for: clubId)
        var record = records[storageClubId] ?? Record(visited: false)
        let existing = record.photoMetadata[fileName] ?? Record.PhotoMeta(createdAt: Date(), updatedAt: Date())
        let now = Date()
        record.photoMetadata[fileName] = Record.PhotoMeta(
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: existing.createdAt,
            updatedAt: now
        )
        record.updatedAt = now
        records[storageClubId] = record
        persist()
        scheduleCloudPush()
    }

    func applySharedPhoto(
        _ imageData: Data,
        for clubId: String,
        fileName: String,
        meta: Record.PhotoMeta
    ) throws {
        guard !imageData.isEmpty else { throw PhotoError.invalidImageData }

        let url = photoURL(fileName: fileName)
        do {
            try imageData.write(to: url, options: .atomic)
        } catch {
            throw PhotoError.writeFailed
        }

        let storageClubId = resolvedStorageClubId(for: clubId)
        var record = records[storageClubId] ?? Record(visited: false)
        if !record.photoFileNames.contains(fileName) {
            record.photoFileNames.append(fileName)
        }
        record.photoMetadata[fileName] = meta
        record.updatedAt = max(record.updatedAt, meta.updatedAt)
        if !record.visited {
            record.visited = true
        }
        if let existingVisitedDate = record.visitedDate {
            record.visitedDate = min(existingVisitedDate, meta.createdAt)
        } else {
            record.visitedDate = meta.createdAt
        }
        records[storageClubId] = record
        persist()
    }

    func record(for clubId: String) -> Record? {
        let storageClubId = resolvedStorageClubId(for: clubId)
        return records[storageClubId]
    }

    func resolvedStorageClubId(for clubId: String) -> String {
        for candidate in ClubIdentityResolver.allKnownIds(for: clubId) {
            if records[candidate] != nil {
                return candidate
            }
        }
        return clubId
    }

    // MARK: - Backup / Restore

    func exportJSON(pretty: Bool = true) -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(records),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    func importJSON(_ json: String) throws {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BackupError.emptyInput }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = trimmed.data(using: .utf8),
              let decoded = try? decoder.decode([String: Record].self, from: data) else {
            throw BackupError.decodeFailed
        }

        self.records = decoded
        persist()

        // Push import til iCloud
        scheduleCloudPush()
    }

    func retrySyncNow() {
        scheduleCloudPush()
    }

    func clearSyncIssue() {
        lastSyncIssue = nil
    }

    func refreshFromRemote() async {
        guard shouldAttemptRemoteSync() else {
            lastSyncIssue = nil
            return
        }

        do {
            let remote = try await syncBackend.fetchAll()
            mergeRemoteIntoLocal(remote)
            persist()
            lastSyncIssue = nil
        } catch {
            dlog("☁️ Visited remote refresh error: \(error)")
            lastSyncIssue = syncIssueMessage(for: error)
        }

        do {
            let remotePhotos = try await syncBackend.fetchAllPhotos()
            mergeRemotePhotosIntoLocal(remotePhotos)
            persist()
        } catch {
            if isPhotoQueryIndexError(error) {
                disablePhotoQueriesIfNeeded(reason: "CloudKit photo type mangler query-index")
            } else {
                dlog("☁️ Photo remote refresh error: \(error)")
            }
        }
    }

    // MARK: - Persistence

    private func persist() {
        saveToLocal(records)
    }

    private func saveToLocal(_ data: [String: Record]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(data)
            UserDefaults.standard.set(encoded, forKey: localKey)
        } catch {
            dlog("💾 VisitedStore local save error: \(error)")
        }
    }

    private func loadFromLocal() -> [String: Record]? {
        guard let raw = UserDefaults.standard.data(forKey: localKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([String: Record].self, from: raw)
    }

    private func saveKnownSharedRemoteClubIds() {
        let ids = Array(knownSharedRemoteClubIds).sorted()
        UserDefaults.standard.set(ids, forKey: sharedRemoteClubIdsKey)
    }

    private func loadKnownSharedRemoteClubIds() -> Set<String> {
        let ids = UserDefaults.standard.stringArray(forKey: sharedRemoteClubIdsKey) ?? []
        return Set(ids)
    }

    private func saveRemoteWriteSnapshots() {
        UserDefaults.standard.set(remoteWriteSnapshotByClubId, forKey: remoteWriteSnapshotsKey)
    }

    private func loadRemoteWriteSnapshots() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: remoteWriteSnapshotsKey) as? [String: String] ?? [:]
    }

    private static func remoteWriteSnapshot(for record: Record) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(record) else {
            return "\(record.visited)|\(record.visitedDate?.timeIntervalSince1970 ?? 0)|\(record.updatedAt.timeIntervalSince1970)"
        }
        return data.base64EncodedString()
    }

    private func photosDirectoryURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent(photoDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func normalizedJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let longestSide = max(sourceSize.width, sourceSize.height)
        let scale = min(1.0, maxPhotoPixelDimension / longestSide)
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)

        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return rendered.jpegData(compressionQuality: photoJPEGQuality)
    }

    // MARK: - Cloud Sync (local-first)

    private func initialCloudSync() async {
        guard shouldAttemptRemoteSync() else { return }

        do {
            let remote = try await syncBackend.fetchAll()
            mergeRemoteIntoLocal(remote)
            persist()
        } catch {
            dlog("☁️ Visited initialCloudSync error: \(error)")
        }

        do {
            let remotePhotos = try await syncBackend.fetchAllPhotos()
            mergeRemotePhotosIntoLocal(remotePhotos)
            persist()
        } catch {
            if isPhotoQueryIndexError(error) {
                disablePhotoQueriesIfNeeded(reason: "CloudKit photo type mangler query-index")
            } else {
                dlog("☁️ Photo initialCloudSync error: \(error)")
            }
        }

    }

    private func scheduleCloudPush() {
        guard shouldAttemptRemoteSync() else {
            lastSyncIssue = nil
            return
        }

        pendingCloudPush = true
        guard !isPushingToCloud else { return }

        Task { [weak self] in
            await self?.runCloudPushLoop()
        }
    }

    private func runCloudPushLoop() async {
        guard !isPushingToCloud else { return }
        isPushingToCloud = true
        defer { isPushingToCloud = false }

        while pendingCloudPush {
            pendingCloudPush = false
            await pushLocalChangesToCloud()
        }
    }

    private func mergeRemoteIntoLocal(_ remote: [String: Record]) {
        // Merge-regler på feltniveau (deterministisk):
        // - visited: true vinder
        // - visitedDate: tidligste dato vinder
        // - notes: nyeste record.updatedAt vinder
        // - review: nyeste review.updatedAt vinder
        // - photos: union + nyeste metadata.updatedAt pr. fil
        // - updatedAt: max(local, remote)
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        var merged = records

        for (clubId, remoteRec) in remote {
            if let localRec = merged[clubId] {
                merged[clubId] = mergePolicy.merge(local: localRec, remote: remoteRec)
            } else {
                merged[clubId] = remoteRec
            }
        }

        if mergePolicy.isSharedPrimarySteadyState {
            let remoteClubIds = Set(remote.keys)
            let removedClubIds = knownSharedRemoteClubIds.subtracting(remoteClubIds)
            for clubId in removedClubIds {
                guard let localRecord = merged.removeValue(forKey: clubId) else { continue }
                for fileName in localRecord.photoFileNames {
                    try? FileManager.default.removeItem(at: photoURL(fileName: fileName))
                }
            }
            knownSharedRemoteClubIds = remoteClubIds
            saveKnownSharedRemoteClubIds()
        }

        records = merged
        for clubId in remote.keys {
            if let mergedRecord = merged[clubId] {
                remoteWriteSnapshotByClubId[clubId] = Self.remoteWriteSnapshot(for: mergedRecord)
            }
        }
        saveRemoteWriteSnapshots()
    }

    private func mergeRemotePhotosIntoLocal(_ remotePhotos: [VisitedRemotePhotoPayload]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        var merged = records

        for payload in remotePhotos {
            var record = merged[payload.clubId] ?? Record(visited: false)
            let localMeta = record.photoMetadata[payload.fileName]
            let shouldApply: Bool
            if let localMeta {
                shouldApply = payload.meta.updatedAt > localMeta.updatedAt
            } else {
                shouldApply = true
            }
            guard shouldApply else { continue }

            let url = photoURL(fileName: payload.fileName)
            do {
                try payload.imageData.write(to: url, options: .atomic)
            } catch {
                dlog("💾 Photo write error for \(payload.fileName): \(error)")
                continue
            }

            if !record.photoFileNames.contains(payload.fileName) {
                record.photoFileNames.append(payload.fileName)
            }
            record.photoMetadata[payload.fileName] = payload.meta
            record.updatedAt = max(record.updatedAt, payload.meta.updatedAt)
            if !record.visited {
                record.visited = true
                if record.visitedDate == nil {
                    record.visitedDate = payload.meta.createdAt
                } else if let existing = record.visitedDate {
                    record.visitedDate = min(existing, payload.meta.createdAt)
                }
            }

            merged[payload.clubId] = record
        }

        records = merged
    }

    private func pushLocalChangesToCloud() async {
        let snapshot = records
        var latestSyncIssue: String?

        for (clubId, rec) in snapshot {
            let remoteWriteSnapshot = Self.remoteWriteSnapshot(for: rec)
            let shouldWriteVisitedRecord = remoteWriteSnapshotByClubId[clubId] != remoteWriteSnapshot

            if shouldWriteVisitedRecord {
                do {
                    if rec.isEmptyMeaningfulState {
                        try await syncBackend.delete(clubId: clubId)
                    } else {
                        try await syncBackend.upsert(clubId: clubId, record: rec)
                    }
                    remoteWriteSnapshotByClubId[clubId] = remoteWriteSnapshot
                } catch {
                    dlog("☁️ Visited push error for \(clubId): \(error)")
                    latestSyncIssue = syncIssueMessage(for: error)
                }
            }

            guard !rec.photoFileNames.isEmpty else { continue }
            do {
                try await syncPhotosForClub(clubId: clubId, record: rec)
            } catch {
                if isPhotoQueryIndexError(error) {
                    disablePhotoQueriesIfNeeded(reason: "CloudKit photo type er ikke markeret indexable endnu")
                    await uploadAllLocalPhotosForClub(clubId: clubId, record: rec)
                } else {
                    dlog("☁️ Photo sync error for \(clubId): \(error)")
                }
            }
        }

        saveRemoteWriteSnapshots()
        lastSyncIssue = latestSyncIssue
    }

    private func syncIssueMessage(for error: Error) -> String {
        switch error {
        case SharedVisitedSyncBackendError.missingAuthToken:
            return "Vi kunne ikke synkronisere din visited-status, fordi din session er udloebet. Log ind igen for at fortsaette."
        case SharedVisitedSyncBackendError.notConfigured:
            return "Delt visited-sync er ikke sat helt op endnu paa denne enhed."
        case SharedVisitedSyncBackendError.invalidHTTPStatus:
            return "Vi kunne ikke gemme din visited-status paa serveren lige nu. Proev igen om lidt."
        default:
            return "Vi kunne ikke synkronisere din visited-status lige nu. Proev igen om lidt."
        }
    }

    private func syncPhotosForClub(clubId: String, record: Record) async throws {
        if !cloudPhotoQueriesAvailable {
            await uploadAllLocalPhotosForClub(clubId: clubId, record: record)
            return
        }

        let remote = try await syncBackend.fetchPhotoMetadata(for: clubId)
        let localNames = Set(record.photoFileNames)

        var uploadCount = 0
        var uploadErrorCount = 0
        for fileName in localNames {
            let localURL = photoURL(fileName: fileName)
            guard let imageData = try? Data(contentsOf: localURL) else { continue }
            let localMeta = record.photoMetadata[fileName]
                ?? Record.PhotoMeta(createdAt: record.updatedAt, updatedAt: record.updatedAt)
            let remoteMeta = remote[fileName]
            let shouldUpload = remoteMeta == nil || localMeta.updatedAt > remoteMeta!.updatedAt
            if shouldUpload {
                do {
                    try await syncBackend.upsertPhoto(
                        clubId: clubId,
                        fileName: fileName,
                        imageData: imageData,
                        meta: localMeta
                    )
                    uploadCount += 1
                } catch {
                    uploadErrorCount += 1
                    dlog("☁️ Photo upload error for \(clubId)/\(fileName): \(error)")
                }
            }
        }

        let namesToDelete = Set(remote.keys).subtracting(localNames)
        var deleteErrorCount = 0
        for fileName in namesToDelete {
            do {
                try await syncBackend.deletePhoto(fileName: fileName)
            } catch {
                deleteErrorCount += 1
                dlog("☁️ Photo delete reconcile error for \(clubId)/\(fileName): \(error)")
            }
        }

        if uploadCount > 0 || uploadErrorCount > 0 || deleteErrorCount > 0 {
            dlog("☁️ Photo sync \(clubId): uploaded=\(uploadCount), uploadErrors=\(uploadErrorCount), deleteErrors=\(deleteErrorCount)")
        }
    }

    private func uploadAllLocalPhotosForClub(clubId: String, record: Record) async {
        var uploadCount = 0
        var uploadErrorCount = 0
        for fileName in record.photoFileNames {
            let localURL = photoURL(fileName: fileName)
            guard let imageData = try? Data(contentsOf: localURL) else { continue }
            let localMeta = record.photoMetadata[fileName]
                ?? Record.PhotoMeta(createdAt: record.updatedAt, updatedAt: record.updatedAt)
            do {
                try await syncBackend.upsertPhoto(
                    clubId: clubId,
                    fileName: fileName,
                    imageData: imageData,
                    meta: localMeta
                )
                uploadCount += 1
            } catch {
                uploadErrorCount += 1
                dlog("☁️ Photo fallback upload error for \(clubId)/\(fileName): \(error)")
            }
        }

        if uploadCount > 0 || uploadErrorCount > 0 {
            dlog("☁️ Photo fallback sync \(clubId): uploaded=\(uploadCount), uploadErrors=\(uploadErrorCount)")
        }
    }

    private func isPhotoQueryIndexError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain != CKError.errorDomain { return false }
        let message = ns.localizedDescription.lowercased()
        return message.contains("not marked indexable") || message.contains("invalid arguments")
    }

    private func disablePhotoQueriesIfNeeded(reason: String) {
        cloudPhotoQueriesAvailable = false
        guard !loggedPhotoQueryWarning else { return }
        loggedPhotoQueryWarning = true
        dlog("☁️ Photo query sync midlertidigt deaktiveret: \(reason)")
    }

    private func mergeRecord(local: Record, remote: Record) -> Record {
        mergePolicy.merge(local: local, remote: remote)
    }
}
