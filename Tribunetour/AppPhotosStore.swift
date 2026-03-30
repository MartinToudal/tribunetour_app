import Foundation
import Combine

@MainActor
final class AppPhotosStore: ObservableObject {
    @Published private(set) var photoFileNamesByClubId: [String: [String]] = [:]

    private let visitedStore: VisitedStore
    private var cancellables = Set<AnyCancellable>()

    init(visitedStore: VisitedStore) {
        self.visitedStore = visitedStore
        self.photoFileNamesByClubId = Self.extractPhotoFileNames(from: visitedStore.records)

        visitedStore.$records
            .map(Self.extractPhotoFileNames)
            .removeDuplicates()
            .sink { [weak self] photoFileNamesByClubId in
                self?.photoFileNamesByClubId = photoFileNamesByClubId
            }
            .store(in: &cancellables)
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
}
