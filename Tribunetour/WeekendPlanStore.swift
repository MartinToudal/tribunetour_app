import Foundation
import Combine

@MainActor
final class WeekendPlanStore: ObservableObject {

    struct PlanPayload: Codable, Hashable {
        var fixtureIds: Set<String>
        var updatedAt: Date

        init(fixtureIds: Set<String> = [], updatedAt: Date = .distantPast) {
            self.fixtureIds = fixtureIds
            self.updatedAt = updatedAt
        }
    }

    private let localKey = "tribunetour.weekendplan.local.v1"

    // ✅ Startværdi så self er "klar" i init
    @Published private(set) var payload: PlanPayload = .init(fixtureIds: [], updatedAt: .distantPast)

    var selectedFixtureIds: Set<String> { payload.fixtureIds }

    private let cloud = CloudWeekendPlanSync.shared
    private var cancellables = Set<AnyCancellable>()
    private var isApplyingRemote = false

    init() {
        // Nu må vi gerne bruge self / methods
        if let local = loadFromLocal() {
            self.payload = local
        } else {
            self.payload = .init(fixtureIds: [], updatedAt: .distantPast)
        }

        // Backup: debounce-push hvis der kommer mange ændringer hurtigt
        $payload
            .dropFirst()
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard !self.isApplyingRemote else { return }
                Task { await self.pushLocalToCloud() }
            }
            .store(in: &cancellables)

        Task { await initialCloudSync() }
    }

    func contains(_ fixtureId: String) -> Bool {
        payload.fixtureIds.contains(fixtureId)
    }

    func toggle(_ fixtureId: String) {
        var p = payload
        if p.fixtureIds.contains(fixtureId) {
            p.fixtureIds.remove(fixtureId)
        } else {
            p.fixtureIds.insert(fixtureId)
        }
        p.updatedAt = Date()
        payload = p
        persist()

        // ✅ Push med det samme (så vi ikke mister data ved hurtig app-luk/slet)
        Task { await pushLocalToCloud() }
    }

    func remove(_ fixtureId: String) {
        guard payload.fixtureIds.contains(fixtureId) else { return }
        var p = payload
        p.fixtureIds.remove(fixtureId)
        p.updatedAt = Date()
        payload = p
        persist()
        Task { await pushLocalToCloud() }
    }

    func clear() {
        var p = payload
        p.fixtureIds.removeAll()
        p.updatedAt = Date()
        payload = p
        persist()
        Task { await pushLocalToCloud() }
    }

    func applySharedPayload(_ sharedPayload: PlanPayload) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        payload = sharedPayload
        persist()
    }

    // MARK: - Persistence

    private func persist() { saveToLocal(payload) }

    private func saveToLocal(_ data: PlanPayload) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(data)
            UserDefaults.standard.set(encoded, forKey: localKey)
        } catch {
            dlog("💾 WeekendPlan local save error: \(error)")
        }
    }

    private func loadFromLocal() -> PlanPayload? {
        guard let raw = UserDefaults.standard.data(forKey: localKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PlanPayload.self, from: raw)
    }

    // MARK: - Cloud Sync

    private func initialCloudSync() async {
        do {
            if let remote = try await cloud.fetch() {
                mergeRemoteIntoLocal(remote)
                persist()
            }
            await pushLocalToCloud()
        } catch {
            dlog("☁️ Plan initialCloudSync error: \(error)")
        }
    }

    private func mergeRemoteIntoLocal(_ remote: PlanPayload) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        // ✅ Reinstall-fix: tom lokal plan starter på .distantPast,
        // så remote vinder ved første sync efter reinstall.
        if remote.updatedAt > payload.updatedAt {
            payload = remote
        }
    }

    private func pushLocalToCloud() async {
        do {
            try await cloud.upsert(payload: payload)
        } catch {
            dlog("☁️ Plan push error: \(error)")
        }
    }
}
