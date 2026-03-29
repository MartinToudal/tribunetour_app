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
        notesByClubId[clubId] ?? ""
    }

    func setNote(_ note: String, for clubId: String) {
        visitedStore.setNotes(clubId, note)
        noteUpdatedAtByClubId[clubId] = Date()
        persistSyncMetadata()
        scheduleRemotePush(for: clubId)
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
        let localClubIds = Set(
            visitedStore.records.compactMap { clubId, record in
                let hasLocalTimestamp = noteUpdatedAtByClubId[clubId] != nil
                let hasNoteContent = !record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                return (hasLocalTimestamp || hasNoteContent) ? clubId : nil
            }
        )
        let allClubIds = localClubIds.union(remoteRecords.keys)

        var localPreferredWrites: [(clubId: String, note: String, updatedAt: Date)] = []
        isApplyingRemote = true

        for clubId in allClubIds {
            let localNote = visitedStore.records[clubId]?.notes ?? ""
            let localUpdatedAt = noteUpdatedAtByClubId[clubId]
            let remote = remoteRecords[clubId]

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
                    localPreferredWrites.append((clubId, localNote, updatedAt))
                }
            case .applyRemote(let remoteRecord):
                visitedStore.applySharedNote(remoteRecord.note, for: clubId, updatedAt: remoteRecord.updatedAt)
                noteUpdatedAtByClubId[clubId] = remoteRecord.updatedAt
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
            let note = visitedStore.records[clubId]?.notes ?? ""
            let updatedAt = noteUpdatedAtByClubId[clubId] ?? Date()
            do {
                try await syncBackend.upsert(userId: userId, clubId: clubId, note: note, updatedAt: updatedAt)
                lastSyncIssue = nil
            } catch {
                pendingRemotePushClubIds.insert(clubId)
                lastSyncIssue = error.localizedDescription
                dlog("Shared notes push error for \(clubId): \(error.localizedDescription)")
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
                    clubId: write.clubId,
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
