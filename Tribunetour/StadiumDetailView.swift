import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct StadiumDetailView: View {
    let club: Club
    let clubById: [String: Club]
    let fixtures: [Fixture]
    @ObservedObject var visitedStore: VisitedStore
    @State private var expandedReviewCategories: Set<VisitedStore.ReviewCategory> = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotoFileName: String?
    @State private var pendingDeletePhotoFileName: String?
    @State private var photoImportError: String?
    private let matchTimeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
    private var matchCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = matchTimeZone
        return calendar
    }

    init(
        club: Club,
        visitedStore: VisitedStore,
        clubById: [String: Club] = [:],
        fixtures: [Fixture] = []
    ) {
        self.club = club
        self.visitedStore = visitedStore
        self.clubById = clubById.isEmpty ? [club.id: club] : clubById
        self.fixtures = fixtures
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(club.name)
                        .font(.title2)
                        .bold()

                    Text(club.division)
                        .foregroundStyle(.secondary)

                    Text(club.stadium.name)
                        .font(.headline)
                        .padding(.top, 8)

                    Text(club.stadium.city)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .padding(.vertical, 6)
            }

            Section("Status") {
                Toggle("Besøgt", isOn: visitedBinding)

                DatePicker(
                    "Besøgsdato",
                    selection: visitedDateBinding,
                    displayedComponents: .date
                )
                .disabled(!visitedStore.isVisited(club.id))
                .opacity(visitedStore.isVisited(club.id) ? 1 : 0.4)

                if visitedStore.isVisited(club.id) {
                    Button(role: .destructive) {
                        visitedStore.setVisitedDate(club.id, nil)
                    } label: {
                        Label("Ryd dato", systemImage: "trash")
                    }
                }
            }

            Section("Kommende kampe her") {
                if upcomingFixtures.isEmpty {
                    Text("Ingen kommende kampe fundet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(upcomingFixtures) { fixture in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(teamName(for: fixture.homeTeamId)) – \(teamName(for: fixture.awayTeamId))")
                                .font(.subheadline.weight(.semibold))
                            Text(kickoffText(for: fixture.kickoff))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Noter") {
                TextField("Skriv en note…", text: notesBinding, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityHint("Gemmer noter for dette stadion")
            }

            Section("Billeder") {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Tilføj billeder", systemImage: "photo.badge.plus")
                }

                if let photoImportError {
                    Text(photoImportError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                let photoNames = visitedStore.photoFileNames(for: club.id)
                if photoNames.isEmpty {
                    Text("Ingen billeder endnu.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(photoNames, id: \.self) { fileName in
                                VStack(alignment: .leading, spacing: 4) {
                                    ZStack(alignment: .topTrailing) {
                                        Button {
                                            selectedPhotoFileName = fileName
                                        } label: {
                                            LocalPhotoImage(
                                                fileURL: visitedStore.photoURL(fileName: fileName),
                                                contentMode: .fill,
                                                cornerRadius: 10
                                            )
                                            .frame(width: 110, height: 110)
                                            .clipped()
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            pendingDeletePhotoFileName = fileName
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white, .black.opacity(0.7))
                                                .padding(4)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Fjern billede")
                                    }

                                    let caption = visitedStore.photoCaption(for: club.id, fileName: fileName)
                                    if !caption.isEmpty {
                                        Text(caption)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .frame(width: 110, alignment: .leading)
                                    }
                                }
                                .frame(width: 110, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                TextField("Kamp (fx FCK - Brøndby)", text: reviewMatchBinding)

                if let avg = reviewAverageText {
                    LabeledContent("Samlet score") {
                        Text("\(avg) / 10")
                    }
                }

                LabeledContent("Udfyldte kategorier") {
                    Text("\(scoredCategoryCount) / \(VisitedStore.ReviewCategory.allCases.count)")
                        .foregroundStyle(.secondary)
                }

                ForEach(VisitedStore.ReviewCategory.allCases) { category in
                    DisclosureGroup(isExpanded: reviewExpansionBinding(for: category)) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    decrementScore(for: category)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)

                                Text(reviewScoreLabel(for: category))
                                    .font(.subheadline.weight(.semibold))
                                    .frame(minWidth: 70, alignment: .leading)

                                Button {
                                    incrementScore(for: category)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                if reviewScoreValue(for: category) != nil {
                                    Button("Nulstil") {
                                        setReviewScore(for: category, to: nil)
                                    }
                                    .font(.caption)
                                }
                            }

                            TextField("Valgfri note", text: reviewCategoryNoteBinding(for: category), axis: .vertical)
                                .lineLimit(1...3)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                if let notePreview = reviewNotePreview(for: category) {
                                    Text(notePreview)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Text(reviewScoreLabel(for: category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                TextField("Kort opsummering", text: reviewSummaryBinding, axis: .vertical)
                    .lineLimit(2...5)

                TextField("Tags (kommasepareret)", text: reviewTagsBinding)

                Button(role: .destructive) {
                    visitedStore.setReview(club.id, nil)
                } label: {
                    Label("Ryd anmeldelse", systemImage: "trash")
                }
                .disabled(visitedStore.review(for: club.id)?.hasMeaningfulContent != true)
            } header: {
                Text("Stadion-anmeldelse")
            } footer: {
                Text("Brug skalaen 1-10, hvor 1 er meget dårlig og 10 er fremragende.")
            }

            Section("Kort") {
                Button {
                    openInAppleMaps()
                } label: {
                    Label("Åbn i Apple Maps", systemImage: "map")
                }
                .accessibilityHint("Åbner rutevejledning til stadionet")

                HStack {
                    Text("Lat/Lon")
                    Spacer()
                    Text(String(format: "%.5f, %.5f", club.stadium.latitude, club.stadium.longitude))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle("Stadion")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await importSelectedPhotos(newItems) }
        }
        .sheet(
            isPresented: Binding(
                get: { selectedPhotoFileName != nil },
                set: { if !$0 { selectedPhotoFileName = nil } }
            )
        ) {
            if let selectedPhotoFileName {
                let photoNames = visitedStore.photoFileNames(for: club.id)
                PhotoFullscreenView(
                    photoFileNames: photoNames,
                    initialSelectedFileName: selectedPhotoFileName,
                    imageURLForFileName: { fileName in
                        visitedStore.photoURL(fileName: fileName)
                    },
                    captionForFileName: { fileName in
                        visitedStore.photoCaption(for: club.id, fileName: fileName)
                    },
                    onSaveCaption: { fileName, caption in
                        visitedStore.setPhotoCaption(caption, for: club.id, fileName: fileName)
                    },
                    onClose: { self.selectedPhotoFileName = nil }
                )
            }
        }
        .confirmationDialog(
            "Fjern billede?",
            isPresented: Binding(
                get: { pendingDeletePhotoFileName != nil },
                set: { if !$0 { pendingDeletePhotoFileName = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Slet billede", role: .destructive) {
                if let fileName = pendingDeletePhotoFileName {
                    visitedStore.removePhoto(fileName: fileName, for: club.id)
                }
                pendingDeletePhotoFileName = nil
            }
            Button("Annuller", role: .cancel) {
                pendingDeletePhotoFileName = nil
            }
        } message: {
            Text("Billedet slettes permanent fra enheden.")
        }
    }

    // MARK: - Bindings

    private var visitedBinding: Binding<Bool> {
        Binding(
            get: { visitedStore.isVisited(club.id) },
            set: { visitedStore.setVisited(club.id, $0) }
        )
    }

    private var visitedDateBinding: Binding<Date> {
        Binding(
            get: { visitedStore.visitedDate(for: club.id) ?? Date() },
            set: { newValue in
                // Hvis man sætter dato, så giver det mening at stadion også er “besøgt”
                if !visitedStore.isVisited(club.id) {
                    visitedStore.setVisited(club.id, true)
                }
                visitedStore.setVisitedDate(club.id, newValue)
            }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { visitedStore.notes(for: club.id) },
            set: { visitedStore.setNotes(club.id, $0) }
        )
    }

    private var reviewMatchBinding: Binding<String> {
        Binding(
            get: { visitedStore.review(for: club.id)?.matchLabel ?? "" },
            set: { newValue in
                var review = visitedStore.review(for: club.id) ?? VisitedStore.StadiumReview()
                review.matchLabel = newValue
                review.updatedAt = Date()
                visitedStore.setReview(club.id, review)
            }
        )
    }

    private var reviewSummaryBinding: Binding<String> {
        Binding(
            get: { visitedStore.review(for: club.id)?.summary ?? "" },
            set: { newValue in
                var review = visitedStore.review(for: club.id) ?? VisitedStore.StadiumReview()
                review.summary = newValue
                review.updatedAt = Date()
                visitedStore.setReview(club.id, review)
            }
        )
    }

    private var reviewTagsBinding: Binding<String> {
        Binding(
            get: { visitedStore.review(for: club.id)?.tags ?? "" },
            set: { newValue in
                var review = visitedStore.review(for: club.id) ?? VisitedStore.StadiumReview()
                review.tags = newValue
                review.updatedAt = Date()
                visitedStore.setReview(club.id, review)
            }
        )
    }

    private var scoredCategoryCount: Int {
        visitedStore.review(for: club.id)?.scores.count ?? 0
    }

    private func reviewScoreValue(for category: VisitedStore.ReviewCategory) -> Int? {
        visitedStore.review(for: club.id)?.score(for: category)
    }

    private func reviewScoreLabel(for category: VisitedStore.ReviewCategory) -> String {
        guard let score = reviewScoreValue(for: category) else { return "Ikke sat" }
        return "\(score)/10"
    }

    private func reviewNotePreview(for category: VisitedStore.ReviewCategory) -> String? {
        let note = visitedStore.review(for: club.id)?.note(for: category).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return note.isEmpty ? nil : note
    }

    private func setReviewScore(for category: VisitedStore.ReviewCategory, to score: Int?) {
        var review = visitedStore.review(for: club.id) ?? VisitedStore.StadiumReview()
        if let score {
            review.scores[category] = min(10, max(1, score))
        } else {
            review.scores[category] = nil
        }
        review.updatedAt = Date()
        visitedStore.setReview(club.id, review)
    }

    private func incrementScore(for category: VisitedStore.ReviewCategory) {
        let current = reviewScoreValue(for: category) ?? 4
        setReviewScore(for: category, to: current + 1)
    }

    private func decrementScore(for category: VisitedStore.ReviewCategory) {
        let current = reviewScoreValue(for: category) ?? 6
        setReviewScore(for: category, to: current - 1)
    }

    private func reviewExpansionBinding(for category: VisitedStore.ReviewCategory) -> Binding<Bool> {
        Binding(
            get: { expandedReviewCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedReviewCategories.insert(category)
                } else {
                    expandedReviewCategories.remove(category)
                }
            }
        )
    }

    private func reviewCategoryNoteBinding(for category: VisitedStore.ReviewCategory) -> Binding<String> {
        Binding(
            get: { visitedStore.review(for: club.id)?.note(for: category) ?? "" },
            set: { newValue in
                var review = visitedStore.review(for: club.id) ?? VisitedStore.StadiumReview()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    review.categoryNotes[category] = nil
                } else {
                    review.categoryNotes[category] = newValue
                }
                review.updatedAt = Date()
                visitedStore.setReview(club.id, review)
            }
        )
    }

    private var reviewAverageText: String? {
        guard let avg = visitedStore.review(for: club.id)?.averageScore else { return nil }
        return String(format: "%.1f", avg)
    }

    private var upcomingFixtures: [Fixture] {
        let now = Date()
        return fixtures
            .filter { $0.venueClubId == club.id }
            .filter { $0.kickoff >= now }
            .filter { $0.status != .cancelled && $0.status != .finished }
            .sorted { $0.kickoff < $1.kickoff }
            .prefix(5)
            .map { $0 }
    }

    private func teamName(for teamId: String) -> String {
        clubById[teamId]?.name ?? teamId
    }

    private func kickoffText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "da_DK")
        formatter.timeZone = matchTimeZone
        formatter.dateFormat = "EEE d. MMM • HH:mm"
        return formatter.string(from: date).capitalized
    }

    private func importSelectedPhotos(_ items: [PhotosPickerItem]) async {
        photoImportError = nil
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                try visitedStore.addPhotoData(data, for: club.id)
            } catch {
                photoImportError = error.localizedDescription
            }
        }
        selectedPhotoItems = []
    }

    // MARK: - Maps (iOS 26+ kompatibel)

    private func openInAppleMaps() {
        let location = CLLocation(latitude: club.stadium.latitude, longitude: club.stadium.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = "\(club.stadium.name) – \(club.name)"
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

private struct LocalPhotoImage: View {
    let fileURL: URL
    let contentMode: ContentMode
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let uiImage = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct PhotoFullscreenView: View {
    let photoFileNames: [String]
    let imageURLForFileName: (String) -> URL
    let captionForFileName: (String) -> String
    let onSaveCaption: (String, String) -> Void
    let onClose: () -> Void
    @State private var selectedFileName: String
    @State private var caption: String = ""

    init(
        photoFileNames: [String],
        initialSelectedFileName: String,
        imageURLForFileName: @escaping (String) -> URL,
        captionForFileName: @escaping (String) -> String,
        onSaveCaption: @escaping (String, String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.photoFileNames = photoFileNames
        self.imageURLForFileName = imageURLForFileName
        self.captionForFileName = captionForFileName
        self.onSaveCaption = onSaveCaption
        self.onClose = onClose

        let selected = photoFileNames.contains(initialSelectedFileName)
            ? initialSelectedFileName
            : (photoFileNames.first ?? "")
        _selectedFileName = State(initialValue: selected)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack {
                    Color.black.ignoresSafeArea()

                    TabView(selection: $selectedFileName) {
                        ForEach(photoFileNames, id: \.self) { fileName in
                            LocalPhotoImage(
                                fileURL: imageURLForFileName(fileName),
                                contentMode: .fit,
                                cornerRadius: 20
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                            .tag(fileName)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
                .frame(maxHeight: .infinity)

                TextField("Billedtekst (valgfri)", text: $caption)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button("Gem billedtekst") {
                    onSaveCaption(selectedFileName, caption)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 12)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Luk") { onClose() }
                }
            }
            .onAppear {
                caption = captionForFileName(selectedFileName)
            }
            .onChange(of: selectedFileName) { _, newValue in
                caption = captionForFileName(newValue)
            }
        }
    }
}
