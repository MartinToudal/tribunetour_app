import Foundation
import Combine

@MainActor
final class AppNotesStore: ObservableObject {
    @Published private(set) var notesByClubId: [String: String] = [:]

    private let visitedStore: VisitedStore
    private var cancellables = Set<AnyCancellable>()

    init(visitedStore: VisitedStore) {
        self.visitedStore = visitedStore
        self.notesByClubId = Self.extractNotes(from: visitedStore.records)

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
    }

    private static func extractNotes(from records: [String: VisitedStore.Record]) -> [String: String] {
        records.reduce(into: [:]) { partialResult, entry in
            let trimmed = entry.value.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            partialResult[entry.key] = entry.value.notes
        }
    }
}
