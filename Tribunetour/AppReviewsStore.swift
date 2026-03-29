import Foundation
import Combine

@MainActor
final class AppReviewsStore: ObservableObject {
    @Published private(set) var reviewsByClubId: [String: VisitedStore.StadiumReview] = [:]

    private let visitedStore: VisitedStore
    private var cancellables = Set<AnyCancellable>()

    init(visitedStore: VisitedStore) {
        self.visitedStore = visitedStore
        self.reviewsByClubId = Self.extractReviews(from: visitedStore.records)

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
    }

    private static func extractReviews(from records: [String: VisitedStore.Record]) -> [String: VisitedStore.StadiumReview] {
        records.reduce(into: [:]) { partialResult, entry in
            guard let review = entry.value.review, review.hasMeaningfulContent else { return }
            partialResult[entry.key] = review
        }
    }
}
