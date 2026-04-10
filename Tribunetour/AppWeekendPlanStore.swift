import Foundation
import Combine

@MainActor
final class AppWeekendPlanStore: ObservableObject {
    @Published private(set) var payload: WeekendPlanStore.PlanPayload
    @Published private(set) var lastSyncIssue: String?

    var selectedFixtureIds: Set<String> { payload.fixtureIds }

    private let store: WeekendPlanStore
    private let syncBackend: SharedWeekendPlanSyncBackend
    private let authSession: AppAuthSession
    private var cancellables = Set<AnyCancellable>()
    private var pendingRemotePush = false
    private var remotePushDebounceTask: Task<Void, Never>?
    private var remotePushWorkerTask: Task<Void, Never>?
    private var isApplyingRemote = false
    private var isPushingRemote = false

    init(
        store: WeekendPlanStore,
        syncBackend: SharedWeekendPlanSyncBackend,
        authSession: AppAuthSession
    ) {
        self.store = store
        self.syncBackend = syncBackend
        self.authSession = authSession
        self.payload = store.payload

        store.$payload
            .sink { [weak self] payload in
                self?.payload = payload
            }
            .store(in: &cancellables)

        store.$payload
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.scheduleRemotePush()
            }
            .store(in: &cancellables)
    }

    convenience init(syncBackend: SharedWeekendPlanSyncBackend, authSession: AppAuthSession) {
        self.init(
            store: WeekendPlanStore(),
            syncBackend: syncBackend,
            authSession: authSession
        )
    }

    func contains(_ fixtureId: String) -> Bool {
        store.contains(fixtureId)
    }

    func toggle(_ fixtureId: String) {
        store.toggle(fixtureId)
    }

    func remove(_ fixtureId: String) {
        store.remove(fixtureId)
    }

    func clear() {
        store.clear()
    }

    func refreshFromRemote() async {
        guard authSession.snapshot.isAuthenticated else { return }
        guard let userId = authSession.snapshot.userId else {
            lastSyncIssue = "Shared weekend plan sync mangler bruger-id."
            return
        }

        do {
            let remote = try await syncBackend.fetch()
            try await reconcile(remote: remote, userId: userId)
            lastSyncIssue = nil
        } catch {
            lastSyncIssue = error.localizedDescription
            dlog("Shared weekend plan remote refresh error: \(error.localizedDescription)")
        }
    }

    private func scheduleRemotePush() {
        guard authSession.snapshot.isAuthenticated else { return }
        guard !isApplyingRemote else { return }

        pendingRemotePush = true
        remotePushDebounceTask?.cancel()
        remotePushDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.startRemotePushWorker()
        }
    }

    private func startRemotePushWorker() {
        guard authSession.snapshot.isAuthenticated else { return }
        guard remotePushWorkerTask == nil || remotePushWorkerTask?.isCancelled == true else { return }

        remotePushWorkerTask = Task { [weak self] in
            await self?.flushPendingRemotePush()
            await MainActor.run {
                self?.remotePushWorkerTask = nil
                if self?.pendingRemotePush == true {
                    self?.startRemotePushWorker()
                }
            }
        }
    }

    private func flushPendingRemotePush() async {
        guard authSession.snapshot.isAuthenticated else { return }
        guard !isPushingRemote else { return }
        guard let userId = authSession.snapshot.userId else {
            lastSyncIssue = "Shared weekend plan sync mangler bruger-id."
            return
        }

        isPushingRemote = true
        defer { isPushingRemote = false }

        while pendingRemotePush {
            pendingRemotePush = false
            do {
                let remote = try await syncBackend.fetch()
                try await reconcile(remote: remote, userId: userId)
                lastSyncIssue = nil
            } catch SharedWeekendPlanSyncBackendError.missingAuthToken {
                pendingRemotePush = false
                lastSyncIssue = nil
                return
            } catch {
                pendingRemotePush = true
                lastSyncIssue = error.localizedDescription
                dlog("Shared weekend plan push error: \(error.localizedDescription)")
                return
            }
        }
    }

    private func reconcile(remote: SharedWeekendPlanRecordDTO?, userId: String) async throws {
        let local = payload

        guard let remote else {
            if local.updatedAt > .distantPast || !local.fixtureIds.isEmpty {
                try await push(local: local, userId: userId)
            }
            return
        }

        let remotePayload = WeekendPlanStore.PlanPayload(
            fixtureIds: Set(remote.fixtureIds),
            updatedAt: remote.updatedAt
        )

        if remotePayload.updatedAt > local.updatedAt {
            isApplyingRemote = true
            store.applySharedPayload(remotePayload)
            isApplyingRemote = false
            return
        }

        if local.updatedAt > remotePayload.updatedAt {
            try await push(local: local, userId: userId)
            return
        }

        if local.fixtureIds != remotePayload.fixtureIds {
            try await push(local: local, userId: userId)
        }
    }

    private func push(local: WeekendPlanStore.PlanPayload, userId: String) async throws {
        try await syncBackend.upsert(
            userId: userId,
            fixtureIds: Array(local.fixtureIds),
            updatedAt: local.updatedAt
        )
    }
}
