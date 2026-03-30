import Foundation
import Combine

@MainActor
final class AppWeekendPlanStore: ObservableObject {
    @Published private(set) var payload: WeekendPlanStore.PlanPayload

    var selectedFixtureIds: Set<String> { payload.fixtureIds }

    private let store: WeekendPlanStore
    private var cancellables = Set<AnyCancellable>()

    init(store: WeekendPlanStore) {
        self.store = store
        self.payload = store.payload

        store.$payload
            .sink { [weak self] payload in
                self?.payload = payload
            }
            .store(in: &cancellables)
    }

    convenience init() {
        self.init(store: WeekendPlanStore())
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
}
