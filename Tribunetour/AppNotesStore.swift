import Foundation
import Combine

@MainActor
final class AppNotesStore: ObservableObject {
    @Published private(set) var notesByClubId: [String: String] = [:]
    @Published private(set) var lastSyncIssue: String?

    private let visitedStore: VisitedStore
    private let syncBackend: SharedNotesSyncBackend
    private let authSession: AppAuthSession
    private var cancellables = Set<AnyCancellable>()
    private var noteUpdatedAtByClubId: [String: Date]
    private var pendingRemotePushClubIds = Set<String>()
    private var remotePushTask: Task<Void, Never>?
    private var isApplyingRemote = false

    private let syncMetadataKey = "tribunetour.notes.syncMetadata.v1"

    init(
        visitedStore: VisitedStore,
        syncBackend: SharedNotesSyncBackend,
        authSession: AppAuthSession
    ) {
        self.visitedStore = visitedStore
        self.syncBackend = syncBackend
        self.authSession = authSession
        self.notesByClubId = Self.extractNotes(from: visitedStore.records)
        self.noteUpdatedAtByClubId = Self.loadNoteUpdatedAtByClubId(
            fallbackRecords: visitedStore.records,
            storageKey: syncMetadataKey
        )

        visitedStore.$records
            .map(Self.extractNotes)
            .removeDuplicates()
            .sink { [weak self] notesByClubId in
                self?.notesByClubId = notesByClubId
            }
            .store(in: &cancellables)
    }

    func note(for clubId: String) -> String {
        for candidate in ClubIdentityResolver.allKnownIds(for: clubId) {
            if let note = notesByClubId[candidate] {
                return note
            }
        }
        return ""
    }

    func setNote(_ note: String, for clubId: String) {
        let storageClubId = visitedStore.resolvedStorageClubId(for: clubId)
        visitedStore.setNotes(storageClubId, note)
        noteUpdatedAtByClubId[storageClubId] = Date()
        persistSyncMetadata()
        scheduleRemotePush(for: storageClubId)
    }

    func refreshFromRemote() async {
        guard authSession.snapshot.isAuthenticated else { return }

        do {
            let remoteRecords = try await syncBackend.fetchAll()
            mergeRemoteNotesIntoLocal(remoteRecords)
            lastSyncIssue = nil
        } catch {
            lastSyncIssue = error.localizedDescription
            dlog("Shared notes remote refresh error: \(error.localizedDescription)")
        }
    }

    private static func extractNotes(from records: [String: VisitedStore.Record]) -> [String: String] {
        records.reduce(into: [:]) { partialResult, entry in
            let trimmed = entry.value.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            partialResult[entry.key] = entry.value.notes
        }
    }

    private func mergeRemoteNotesIntoLocal(_ remoteRecords: [String: SharedNoteRecordDTO]) {
        let remoteRecordsByCanonicalId = normalizeRemoteRecords(remoteRecords)
        let localClubIds = Set(
            visitedStore.records.compactMap { clubId, record in
                let hasLocalTimestamp = noteUpdatedAtByClubId[clubId] != nil
                let hasNoteContent = !record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                return (hasLocalTimestamp || hasNoteContent) ? ClubIdentityResolver.canonicalId(for: clubId) : nil
            }
        )
        let allClubIds = localClubIds.union(remoteRecordsByCanonicalId.keys)

        var localPreferredWrites: [(clubId: String, note: String, updatedAt: Date)] = []
        isApplyingRemote = true

        for clubId in allClubIds.sorted() {
            let storageClubId = visitedStore.resolvedStorageClubId(for: clubId)
            let localNote = visitedStore.record(for: storageClubId)?.notes ?? ""
            let localUpdatedAt = noteUpdatedAt(for: storageClubId)
            let remote = remoteRecordsByCanonicalId[clubId]

            switch resolveMerge(
                localNote: localNote,
                localUpdatedAt: localUpdatedAt,
                remote: remote
            ) {
            case .keepLocal(let updatedAt):
                guard let updatedAt else { continue }
                if let remote, remote.note == localNote, remote.updatedAt == updatedAt {
                    continue
                }

                let shouldPush = !localNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || remote != nil
                if shouldPush {
                    localPreferredWrites.append((storageClubId, localNote, updatedAt))
                }
            case .applyRemote(let remoteRecord):
                visitedStore.applySharedNote(remoteRecord.note, for: storageClubId, updatedAt: remoteRecord.updatedAt)
                noteUpdatedAtByClubId[storageClubId] = remoteRecord.updatedAt
            case .noChange:
                continue
            }
        }

        isApplyingRemote = false
        persistSyncMetadata()

        guard !localPreferredWrites.isEmpty else { return }
        for write in localPreferredWrites {
            pendingRemotePushClubIds.insert(write.clubId)
        }
        remotePushTask?.cancel()
        remotePushTask = Task { [weak self] in
            await self?.pushLocalPreferredWrites(localPreferredWrites)
        }
    }

    private func scheduleRemotePush(for clubId: String) {
        guard authSession.snapshot.isAuthenticated else { return }
        guard !isApplyingRemote else { return }

        pendingRemotePushClubIds.insert(clubId)
        remotePushTask?.cancel()
        remotePushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            await self?.pushPendingRemoteNotes()
        }
    }

    private func pushPendingRemoteNotes() async {
        guard authSession.snapshot.isAuthenticated else { return }
        guard let userId = authSession.snapshot.userId else {
            lastSyncIssue = "Shared notes sync mangler bruger-id."
            return
        }
        let clubIds = pendingRemotePushClubIds.sorted()
        pendingRemotePushClubIds.removeAll()

        for clubId in clubIds {
            let storageClubId = visitedStore.resolvedStorageClubId(for: clubId)
            let note = visitedStore.record(for: storageClubId)?.notes ?? ""
            let updatedAt = noteUpdatedAtByClubId[storageClubId] ?? Date()
            do {
                try await syncBackend.upsert(userId: userId, clubId: storageClubId, note: note, updatedAt: updatedAt)
                lastSyncIssue = nil
            } catch {
                pendingRemotePushClubIds.insert(storageClubId)
                lastSyncIssue = error.localizedDescription
                dlog("Shared notes push error for \(storageClubId): \(error.localizedDescription)")
            }
        }
    }

    private func pushLocalPreferredWrites(_ writes: [(clubId: String, note: String, updatedAt: Date)]) async {
        guard authSession.snapshot.isAuthenticated else { return }
        guard let userId = authSession.snapshot.userId else {
            lastSyncIssue = "Shared notes sync mangler bruger-id."
            return
        }

        for write in writes {
            do {
                try await syncBackend.upsert(
                    userId: userId,
                    clubId: visitedStore.resolvedStorageClubId(for: write.clubId),
                    note: write.note,
                    updatedAt: write.updatedAt
                )
                lastSyncIssue = nil
            } catch {
                pendingRemotePushClubIds.insert(write.clubId)
                lastSyncIssue = error.localizedDescription
                dlog("Shared notes preferred push error for \(write.clubId): \(error.localizedDescription)")
            }
        }
    }

    private func persistSyncMetadata() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(noteUpdatedAtByClubId)
            UserDefaults.standard.set(data, forKey: syncMetadataKey)
        } catch {
            dlog("Notes sync metadata save error: \(error.localizedDescription)")
        }
    }

    private static func loadNoteUpdatedAtByClubId(
        fallbackRecords: [String: VisitedStore.Record],
        storageKey: String
    ) -> [String: Date] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? decoder.decode([String: Date].self, from: data) {
            return decoded
        }

        return fallbackRecords.reduce(into: [:]) { partialResult, entry in
            let trimmed = entry.value.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            partialResult[entry.key] = entry.value.updatedAt
        }
    }

    private func noteUpdatedAt(for clubId: String) -> Date? {
        for candidate in ClubIdentityResolver.allKnownIds(for: clubId) {
            if let updatedAt = noteUpdatedAtByClubId[candidate] {
                return updatedAt
            }
        }
        return nil
    }

    private func normalizeRemoteRecords(_ remoteRecords: [String: SharedNoteRecordDTO]) -> [String: SharedNoteRecordDTO] {
        remoteRecords.reduce(into: [:]) { partialResult, entry in
            let canonicalId = ClubIdentityResolver.canonicalId(for: entry.key)
            if let existing = partialResult[canonicalId], existing.updatedAt >= entry.value.updatedAt {
                return
            }
            partialResult[canonicalId] = entry.value
        }
    }

    private enum MergeResolution {
        case keepLocal(updatedAt: Date?)
        case applyRemote(SharedNoteRecordDTO)
        case noChange
    }

    private func resolveMerge(
        localNote: String,
        localUpdatedAt: Date?,
        remote: SharedNoteRecordDTO?
    ) -> MergeResolution {
        let localHasContent = !localNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard let remote else {
            return localHasContent ? .keepLocal(updatedAt: localUpdatedAt) : .noChange
        }

        guard let localUpdatedAt else {
            return .applyRemote(remote)
        }

        if localUpdatedAt > remote.updatedAt {
            return .keepLocal(updatedAt: localUpdatedAt)
        }

        if remote.updatedAt > localUpdatedAt {
            return .applyRemote(remote)
        }

        if localNote == remote.note {
            return .noChange
        }

        let remoteHasContent = !remote.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if localHasContent != remoteHasContent {
            return localHasContent ? .keepLocal(updatedAt: localUpdatedAt) : .applyRemote(remote)
        }

        return localNote.count >= remote.note.count
            ? .keepLocal(updatedAt: localUpdatedAt)
            : .applyRemote(remote)
    }
}
