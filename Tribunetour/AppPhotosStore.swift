import Foundation
import Combine

@MainActor
final class AppPhotosStore: ObservableObject {
    @Published private(set) var photoFileNamesByClubId: [String: [String]] = [:]
    @Published private(set) var lastSyncIssue: String?

    private let visitedStore: VisitedStore
    private let syncBackend: SharedPhotosSyncBackend
    private let authSession: AppAuthSession
    private let knownRemotePhotoKeysStorageKey = "tribunetour.photos.shared.remote-keys.v1"
    private var cancellables = Set<AnyCancellable>()
    private var remoteSyncDebounceTask: Task<Void, Never>?
    private var remoteSyncWorkerTask: Task<Void, Never>?
    private var needsRemoteSync = false
    private var isApplyingRemote = false
    private var isSyncingRemote = false
    private var knownRemotePhotoKeys = Set<String>()

    init(
        visitedStore: VisitedStore,
        syncBackend: SharedPhotosSyncBackend,
        authSession: AppAuthSession
    ) {
        self.visitedStore = visitedStore
        self.syncBackend = syncBackend
        self.authSession = authSession
        self.knownRemotePhotoKeys = Self.loadKnownRemotePhotoKeys(storageKey: knownRemotePhotoKeysStorageKey)
        self.photoFileNamesByClubId = Self.extractPhotoFileNames(from: visitedStore.records)

        visitedStore.$records
            .map(Self.extractPhotoFileNames)
            .removeDuplicates()
            .sink { [weak self] photoFileNamesByClubId in
                self?.photoFileNamesByClubId = photoFileNamesByClubId
            }
            .store(in: &cancellables)

        visitedStore.$records
            .map(Self.extractPhotoSyncSnapshot)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.scheduleRemoteSync()
            }
            .store(in: &cancellables)
    }

    func refreshFromRemote() async {
        guard authSession.snapshot.isAuthenticated else { return }
        guard let userId = authSession.snapshot.userId else {
            lastSyncIssue = "Shared photos sync mangler bruger-id."
            return
        }

        do {
            let remotePhotos = try await syncBackend.fetchAll()
            try await reconcileRemotePhotos(remotePhotos, userId: userId)
            lastSyncIssue = nil
        } catch {
            lastSyncIssue = error.localizedDescription
            dlog("Shared photos remote refresh error: \(error.localizedDescription)")
        }
    }

    func photoFileNames(for clubId: String) -> [String] {
        photoFileNamesByClubId[clubId] ?? []
    }

    func photoURL(fileName: String) -> URL {
        visitedStore.photoURL(fileName: fileName)
    }

    func addPhotoData(_ imageData: Data, for clubId: String) throws {
        try visitedStore.addPhotoData(imageData, for: clubId)
    }

    func removePhoto(fileName: String, for clubId: String) {
        visitedStore.removePhoto(fileName: fileName, for: clubId)
    }

    func photoCaption(for clubId: String, fileName: String) -> String {
        visitedStore.photoCaption(for: clubId, fileName: fileName)
    }

    func setPhotoCaption(_ caption: String, for clubId: String, fileName: String) {
        visitedStore.setPhotoCaption(caption, for: clubId, fileName: fileName)
    }

    private func scheduleRemoteSync() {
        guard authSession.snapshot.isAuthenticated else { return }
        guard !isApplyingRemote else { return }

        needsRemoteSync = true
        remoteSyncDebounceTask?.cancel()
        remoteSyncDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.startRemoteSyncWorker()
        }
    }

    private func startRemoteSyncWorker() {
        guard authSession.snapshot.isAuthenticated else { return }
        guard remoteSyncWorkerTask == nil || remoteSyncWorkerTask?.isCancelled == true else { return }

        remoteSyncWorkerTask = Task { [weak self] in
            await self?.flushRemoteSync()
            await MainActor.run {
                self?.remoteSyncWorkerTask = nil
                if self?.needsRemoteSync == true {
                    self?.startRemoteSyncWorker()
                }
            }
        }
    }

    private func flushRemoteSync() async {
        guard authSession.snapshot.isAuthenticated else { return }
        guard !isSyncingRemote else { return }
        guard let userId = authSession.snapshot.userId else {
            lastSyncIssue = "Shared photos sync mangler bruger-id."
            return
        }

        isSyncingRemote = true
        defer { isSyncingRemote = false }

        while needsRemoteSync {
            needsRemoteSync = false
            do {
                let remotePhotos = try await syncBackend.fetchAll()
                try await reconcileRemotePhotos(remotePhotos, userId: userId)
                lastSyncIssue = nil
            } catch {
                needsRemoteSync = true
                lastSyncIssue = error.localizedDescription
                dlog("Shared photos push error: \(error.localizedDescription)")
                return
            }
        }
    }

    private func reconcileRemotePhotos(_ remotePhotos: [SharedPhotoRecordDTO], userId: String) async throws {
        let remoteByKey = Dictionary(uniqueKeysWithValues: remotePhotos.map { (Self.photoKey(clubId: $0.clubId, fileName: $0.fileName), $0) })
        var localByKey = Self.extractLocalPhotoRecords(from: visitedStore.records)
        let allKeys = Set(remoteByKey.keys).union(localByKey.keys)

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let removedRemoteKeys = knownRemotePhotoKeys.subtracting(remoteByKey.keys)
        for key in removedRemoteKeys.sorted() {
            guard let localPhoto = localByKey[key] else { continue }
            visitedStore.removeSharedPhotoLocally(fileName: localPhoto.fileName, for: localPhoto.clubId)
            localByKey.removeValue(forKey: key)
        }

        for key in allKeys.sorted() {
            if removedRemoteKeys.contains(key) { continue }
            let local = localByKey[key]
            let remote = remoteByKey[key]

            switch resolveMerge(local: local, remote: remote) {
            case .downloadRemote(let remotePhoto):
                let imageData = try await syncBackend.downloadPhoto(
                    userId: userId,
                    clubId: remotePhoto.clubId,
                    fileName: remotePhoto.fileName
                )
                try visitedStore.applySharedPhoto(
                    imageData,
                    for: remotePhoto.clubId,
                    fileName: remotePhoto.fileName,
                    meta: remotePhoto.photoMeta
                )
            case .uploadLocal(let localPhoto):
                guard let imageData = try? Data(contentsOf: localPhoto.fileURL) else { continue }
                try await syncBackend.uploadPhoto(
                    userId: userId,
                    clubId: localPhoto.clubId,
                    fileName: localPhoto.fileName,
                    imageData: imageData,
                    contentType: Self.contentType(for: localPhoto.fileName)
                )
                try await syncBackend.upsertMetadata(
                    userId: userId,
                    clubId: localPhoto.clubId,
                    fileName: localPhoto.fileName,
                    meta: localPhoto.meta
                )
            case .noChange:
                continue
            }
        }

        knownRemotePhotoKeys = Set(remoteByKey.keys)
        Self.saveKnownRemotePhotoKeys(knownRemotePhotoKeys, storageKey: knownRemotePhotoKeysStorageKey)
    }

    private enum PhotoMergeResolution {
        case downloadRemote(SharedPhotoRecordDTO)
        case uploadLocal(LocalPhotoRecord)
        case noChange
    }

    private struct LocalPhotoRecord: Equatable {
        let clubId: String
        let fileName: String
        let meta: VisitedStore.Record.PhotoMeta
        let fileURL: URL
    }

    private static func extractLocalPhotoRecords(from records: [String: VisitedStore.Record]) -> [String: LocalPhotoRecord] {
        records.reduce(into: [:]) { partialResult, entry in
            for fileName in entry.value.photoFileNames {
                guard let meta = entry.value.photoMetadata[fileName] else { continue }
                partialResult[photoKey(clubId: entry.key, fileName: fileName)] = LocalPhotoRecord(
                    clubId: entry.key,
                    fileName: fileName,
                    meta: meta,
                    fileURL: visitedStorePhotoURL(fileName: fileName)
                )
            }
        }
    }

    private static func extractPhotoSyncSnapshot(from records: [String: VisitedStore.Record]) -> [String: Date] {
        records.reduce(into: [:]) { partialResult, entry in
            for fileName in entry.value.photoFileNames {
                guard let meta = entry.value.photoMetadata[fileName] else { continue }
                partialResult[photoKey(clubId: entry.key, fileName: fileName)] = meta.updatedAt
            }
        }
    }

    private func resolveMerge(local: LocalPhotoRecord?, remote: SharedPhotoRecordDTO?) -> PhotoMergeResolution {
        guard let remote else {
            return local == nil ? .noChange : .uploadLocal(local!)
        }

        guard let local else {
            return .downloadRemote(remote)
        }

        if remote.photoMeta.updatedAt > local.meta.updatedAt {
            return .downloadRemote(remote)
        }

        if local.meta.updatedAt > remote.photoMeta.updatedAt {
            return .uploadLocal(local)
        }

        if remote.photoMeta.caption != local.meta.caption {
            return local.meta.caption.count >= remote.photoMeta.caption.count
                ? .uploadLocal(local)
                : .downloadRemote(remote)
        }

        return .noChange
    }

    private static func photoKey(clubId: String, fileName: String) -> String {
        "\(clubId)::\(fileName)"
    }

    private static func contentType(for fileName: String) -> String {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".png") {
            return "image/png"
        }
        if lowercased.hasSuffix(".webp") {
            return "image/webp"
        }
        if lowercased.hasSuffix(".heic") || lowercased.hasSuffix(".heif") {
            return "image/heic"
        }
        return "image/jpeg"
    }

    private static func visitedStorePhotoURL(fileName: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("VisitedPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent(fileName)
    }

    private static func extractPhotoFileNames(from records: [String: VisitedStore.Record]) -> [String: [String]] {
        records.reduce(into: [:]) { partialResult, entry in
            let fileNames = entry.value.photoFileNames.sorted { a, b in
                let createdAtA = entry.value.photoMetadata[a]?.createdAt ?? .distantPast
                let createdAtB = entry.value.photoMetadata[b]?.createdAt ?? .distantPast
                if createdAtA != createdAtB {
                    return createdAtA > createdAtB
                }
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
            guard !fileNames.isEmpty else { return }
            partialResult[entry.key] = fileNames
        }
    }

    private static func saveKnownRemotePhotoKeys(_ keys: Set<String>, storageKey: String) {
        UserDefaults.standard.set(Array(keys).sorted(), forKey: storageKey)
    }

    private static func loadKnownRemotePhotoKeys(storageKey: String) -> Set<String> {
        let keys = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return Set(keys)
    }
}
