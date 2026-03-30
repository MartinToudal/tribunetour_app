import Foundation
import Combine

@MainActor
final class AppReviewsStore: ObservableObject {
    @Published private(set) var reviewsByClubId: [String: VisitedStore.StadiumReview] = [:]
    @Published private(set) var lastSyncIssue: String?

    private let visitedStore: VisitedStore
    private let syncBackend: SharedReviewsSyncBackend
    private let authSession: AppAuthSession
    private var cancellables = Set<AnyCancellable>()
    private var reviewUpdatedAtByClubId: [String: Date]
    private var pendingRemotePushClubIds = Set<String>()
    private var reviewPushDebounceTask: Task<Void, Never>?
    private var isApplyingRemote = false
    private var isPushingRemote = false

    private let syncMetadataKey = "tribunetour.reviews.syncMetadata.v1"

    init(
        visitedStore: VisitedStore,
        syncBackend: SharedReviewsSyncBackend,
        authSession: AppAuthSession
    ) {
        self.visitedStore = visitedStore
        self.syncBackend = syncBackend
        self.authSession = authSession
        self.reviewsByClubId = Self.extractReviews(from: visitedStore.records)
        self.reviewUpdatedAtByClubId = Self.loadReviewUpdatedAtByClubId(
            fallbackRecords: visitedStore.records,
            storageKey: syncMetadataKey
        )

        visitedStore.$records
            .map(Self.extractReviews)
            .removeDuplicates()
            .sink { [weak self] reviewsByClubId in
                self?.reviewsByClubId = reviewsByClubId
            }
            .store(in: &cancellables)
    }

    func review(for clubId: String) -> VisitedStore.StadiumReview? {
        reviewsByClubId[clubId]
    }

    func hasMeaningfulReview(for clubId: String) -> Bool {
        review(for: clubId)?.hasMeaningfulContent == true
    }

    func clearReview(for clubId: String) {
        visitedStore.setReview(clubId, nil)
        reviewUpdatedAtByClubId[clubId] = Date()
        persistSyncMetadata()
        scheduleRemotePush(for: clubId)
    }

    func setMatchLabel(_ matchLabel: String, for clubId: String) {
        updateReview(for: clubId) { review in
            review.matchLabel = matchLabel
        }
    }

    func setSummary(_ summary: String, for clubId: String) {
        updateReview(for: clubId) { review in
            review.summary = summary
        }
    }

    func setTags(_ tags: String, for clubId: String) {
        updateReview(for: clubId) { review in
            review.tags = tags
        }
    }

    func setScore(_ score: Int?, for category: VisitedStore.ReviewCategory, clubId: String) {
        updateReview(for: clubId) { review in
            if let score {
                review.scores[category] = min(10, max(1, score))
            } else {
                review.scores[category] = nil
            }
        }
    }

    func setCategoryNote(_ note: String, for category: VisitedStore.ReviewCategory, clubId: String) {
        updateReview(for: clubId) { review in
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                review.categoryNotes[category] = nil
            } else {
                review.categoryNotes[category] = note
            }
        }
    }

    private func updateReview(
        for clubId: String,
        mutate: (inout VisitedStore.StadiumReview) -> Void
    ) {
        var review = review(for: clubId) ?? VisitedStore.StadiumReview()
        mutate(&review)
        review.updatedAt = Date()
        visitedStore.setReview(clubId, review)
        reviewUpdatedAtByClubId[clubId] = review.updatedAt
        persistSyncMetadata()
        scheduleRemotePush(for: clubId)
    }

    private static func extractReviews(from records: [String: VisitedStore.Record]) -> [String: VisitedStore.StadiumReview] {
        records.reduce(into: [:]) { partialResult, entry in
            guard let review = entry.value.review, review.hasMeaningfulContent else { return }
            partialResult[entry.key] = review
        }
    }

    func refreshFromRemote() async {
        guard authSession.snapshot.isAuthenticated else { return }

        do {
            let remoteRecords = try await syncBackend.fetchAll()
            mergeRemoteReviewsIntoLocal(remoteRecords)
            lastSyncIssue = nil
        } catch {
            lastSyncIssue = error.localizedDescription
            dlog("Shared reviews remote refresh error: \(error.localizedDescription)")
        }
    }

    private func mergeRemoteReviewsIntoLocal(_ remoteRecords: [String: SharedReviewRecordDTO]) {
        let localClubIds = Set(
            visitedStore.records.compactMap { clubId, record in
                let hasLocalTimestamp = reviewUpdatedAtByClubId[clubId] != nil
                let hasReviewContent = record.review?.hasMeaningfulContent == true
                return (hasLocalTimestamp || hasReviewContent) ? clubId : nil
            }
        )
        let allClubIds = localClubIds.union(remoteRecords.keys)

        var localPreferredWrites: [(clubId: String, review: VisitedStore.StadiumReview, updatedAt: Date)] = []
        isApplyingRemote = true

        for clubId in allClubIds {
            let localReview = visitedStore.records[clubId]?.review
            let localUpdatedAt = reviewUpdatedAtByClubId[clubId]
            let remote = remoteRecords[clubId]

            switch resolveMerge(
                localReview: localReview,
                localUpdatedAt: localUpdatedAt,
                remote: remote
            ) {
            case .keepLocal(let updatedAt):
                guard let updatedAt else { continue }
                let reviewToPush = localReview ?? VisitedStore.StadiumReview(updatedAt: updatedAt)
                if let remote,
                   remote.review == reviewToPush,
                   remote.updatedAt == updatedAt {
                    continue
                }

                let shouldPush = reviewToPush.hasMeaningfulContent || remote != nil
                if shouldPush {
                    localPreferredWrites.append((clubId, reviewToPush, updatedAt))
                }
            case .applyRemote(let remoteRecord):
                visitedStore.applySharedReview(remoteRecord.review, for: clubId, updatedAt: remoteRecord.updatedAt)
                reviewUpdatedAtByClubId[clubId] = remoteRecord.updatedAt
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
        Task { [weak self] in
            await self?.flushPendingRemoteReviews()
        }
    }

    private func scheduleRemotePush(for clubId: String) {
        guard authSession.snapshot.isAuthenticated else { return }
        guard !isApplyingRemote else { return }

        pendingRemotePushClubIds.insert(clubId)
        reviewPushDebounceTask?.cancel()
        reviewPushDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
            } catch {
                return
            }
            await self?.flushPendingRemoteReviews()
        }
    }

    private func flushPendingRemoteReviews() async {
        guard authSession.snapshot.isAuthenticated else { return }
        guard !isPushingRemote else { return }
        guard let userId = authSession.snapshot.userId else {
            lastSyncIssue = "Shared reviews sync mangler bruger-id."
            return
        }

        isPushingRemote = true
        defer { isPushingRemote = false }

        while !pendingRemotePushClubIds.isEmpty {
            let clubIds = pendingRemotePushClubIds.sorted()
            pendingRemotePushClubIds.removeAll()

            for clubId in clubIds {
                let updatedAt = reviewUpdatedAtByClubId[clubId] ?? Date()
                let review = visitedStore.records[clubId]?.review ?? VisitedStore.StadiumReview(updatedAt: updatedAt)
                do {
                    try await syncBackend.upsert(userId: userId, clubId: clubId, review: review, updatedAt: updatedAt)
                    lastSyncIssue = nil
                } catch {
                    pendingRemotePushClubIds.insert(clubId)
                    lastSyncIssue = error.localizedDescription
                    dlog("Shared reviews push error for \(clubId): \(error.localizedDescription)")
                }
            }
        }
    }

    private func persistSyncMetadata() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(reviewUpdatedAtByClubId)
            UserDefaults.standard.set(data, forKey: syncMetadataKey)
        } catch {
            dlog("Reviews sync metadata save error: \(error.localizedDescription)")
        }
    }

    private static func loadReviewUpdatedAtByClubId(
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
            guard let review = entry.value.review, review.hasMeaningfulContent else { return }
            partialResult[entry.key] = review.updatedAt
        }
    }

    private enum MergeResolution {
        case keepLocal(updatedAt: Date?)
        case applyRemote(SharedReviewRecordDTO)
        case noChange
    }

    private func resolveMerge(
        localReview: VisitedStore.StadiumReview?,
        localUpdatedAt: Date?,
        remote: SharedReviewRecordDTO?
    ) -> MergeResolution {
        let localHasContent = localReview?.hasMeaningfulContent == true

        guard let remote else {
            return (localHasContent || localUpdatedAt != nil) ? .keepLocal(updatedAt: localUpdatedAt) : .noChange
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

        if localReview == remote.review {
            return .noChange
        }

        let remoteHasContent = remote.review?.hasMeaningfulContent == true
        if localHasContent != remoteHasContent {
            return localHasContent ? .keepLocal(updatedAt: localUpdatedAt) : .applyRemote(remote)
        }

        let localSummaryLength = localReview?.summary.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
        let remoteSummaryLength = remote.review?.summary.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0

        return localSummaryLength >= remoteSummaryLength
            ? .keepLocal(updatedAt: localUpdatedAt)
            : .applyRemote(remote)
    }
}
