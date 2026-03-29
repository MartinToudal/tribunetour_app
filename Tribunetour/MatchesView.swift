import SwiftUI
import CoreLocation

struct MatchesView: View {
    let clubs: [Club]
    let clubById: [String: Club]
    let fixtures: [Fixture]
    @ObservedObject var visitedStore: VisitedStore
    @ObservedObject var notesStore: AppNotesStore
    @ObservedObject var reviewsStore: AppReviewsStore

    init(
        clubs: [Club],
        clubById: [String: Club]? = nil,
        fixtures: [Fixture],
        visitedStore: VisitedStore,
        notesStore: AppNotesStore,
        reviewsStore: AppReviewsStore
    ) {
        self.clubs = clubs
        self.clubById = clubById ?? Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
        self.fixtures = fixtures
        self.visitedStore = visitedStore
        self.notesStore = notesStore
        self.reviewsStore = reviewsStore
    }

    // MARK: - Time filter chips
    enum TimeFilter: String, CaseIterable, Identifiable {
        case today = "I dag"
        case next3Days = "3 dage"
        case week = "Uge"
        case month = "Måned"
        var id: String { rawValue }
    }

    enum SortMode: String, CaseIterable, Identifiable {
        case byDate = "Dato"
        case byDistance = "Afstand"
        var id: String { rawValue }
    }

    @AppStorage("matches.timeFilter") private var timeFilterRawValue: String = TimeFilter.week.rawValue
    @AppStorage("matches.onlyUnvisitedVenues") private var onlyUnvisitedVenues: Bool = true
    @State private var searchText = ""

    // Distance sorting
    @AppStorage("matches.sortMode") private var sortModeRawValue: String = SortMode.byDate.rawValue
    @AppStorage("matches.reverseDistanceSort") private var reverseDistanceSort = false

    @EnvironmentObject private var locationStore: LocationStore
    private let maxShownFixtures = 200
    private let matchCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
        return cal
    }()

    private var timeFilter: TimeFilter {
        get { TimeFilter(rawValue: timeFilterRawValue) ?? .week }
        nonmutating set { timeFilterRawValue = newValue.rawValue }
    }

    private var sortMode: SortMode {
        get { SortMode(rawValue: sortModeRawValue) ?? .byDate }
        nonmutating set { sortModeRawValue = newValue.rawValue }
    }

    private func distanceMeters(for fixture: Fixture, from here: CLLocation) -> Double? {
        guard let venueClub = clubById[fixture.venueClubId] else { return nil }
        let venueLoc = CLLocation(latitude: venueClub.stadium.latitude, longitude: venueClub.stadium.longitude)
        return here.distance(from: venueLoc)
    }

    private func distanceText(for fixture: Fixture, from here: CLLocation) -> String? {
        guard let meters = distanceMeters(for: fixture, from: here) else { return nil }
        if meters < 1000 { return "\(Int(meters)) m" }
        return String(format: "%.1f km", meters / 1000.0)
    }

    private var locationHintText: String { locationAuthorizationHint(locationStore.authorization) }

    private var filteredFixtures: [Fixture] {
        let cal = matchCalendar
        let todayStart = cal.startOfDay(for: Date())

        // ✅ Kun kampe fra i dag og frem
        var base = fixtures.filter { $0.kickoff >= todayStart }

        // ✅ Tid-filter (endExclusive)
        let endExclusive: Date = {
            switch timeFilter {
            case .today:
                return cal.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
            case .next3Days:
                return cal.date(byAdding: .day, value: 3, to: todayStart) ?? todayStart
            case .week:
                return cal.date(byAdding: .day, value: 7, to: todayStart) ?? todayStart
            case .month:
                return cal.date(byAdding: .month, value: 1, to: todayStart) ?? todayStart
            }
        }()

        base = base.filter { $0.kickoff < endExclusive }

        // ✅ Toggle: kun ikke-besøgte stadions
        if onlyUnvisitedVenues {
            base = base.filter { !visitedStore.isVisited($0.venueClubId) }
        }

        // ✅ Search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            let needle = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            base = base.filter { f in
                let home = clubById[f.homeTeamId]?.name ?? f.homeTeamId
                let away = clubById[f.awayTeamId]?.name ?? f.awayTeamId
                let venue = clubById[f.venueClubId]?.stadium.name ?? f.venueClubId
                let city  = clubById[f.venueClubId]?.stadium.city ?? ""
                let round = f.round ?? ""

                let hay = "\(home) \(away) \(venue) \(city) \(round)"
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

                return hay.contains(needle)
            }
        }

        // ✅ Sortering
        switch sortMode {
        case .byDate:
            return base.sorted { $0.kickoff < $1.kickoff }

        case .byDistance:
            guard let here = locationStore.location else {
                // fallback hvis vi mangler lokation
                return base.sorted { $0.kickoff < $1.kickoff }
            }

            // Precompute distances for stable + hurtigere sort
            let distById: [String: Double] = Dictionary(
                uniqueKeysWithValues: base.map { f in
                    let d = distanceMeters(for: f, from: here) ?? Double.greatestFiniteMagnitude
                    return (f.id, d)
                }
            )

            return base.sorted { a, b in
                let da = distById[a.id] ?? Double.greatestFiniteMagnitude
                let db = distById[b.id] ?? Double.greatestFiniteMagnitude

                if da != db {
                    return reverseDistanceSort ? (da > db) : (da < db)
                }

                // tie-breaker: kickoff
                return a.kickoff < b.kickoff
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Controls
                Section {
                    Toggle("Kun stadions jeg ikke har besøgt", isOn: $onlyUnvisitedVenues)
                        .accessibilityHint("Filtrer kampe efter ikke-besøgte stadions")

                    // Sort controls
                    HStack(spacing: 10) {
                        Picker("Sortér", selection: Binding(get: { sortMode }, set: { sortMode = $0 })) {
                            ForEach(SortMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if sortMode == .byDistance {
                            Button {
                                reverseDistanceSort.toggle()
                            } label: {
                                Image(systemName: reverseDistanceSort ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .font(.title3)
                                    .accessibilityLabel(reverseDistanceSort ? "Længst væk først" : "Tættest på mig først")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Location hint when distance sort is selected
                    if sortMode == .byDistance && locationStore.location == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sortering efter afstand kræver lokation")
                                .font(.headline)

                            Text(locationHintText)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("Tillad lokation") {
                                    locationStore.requestPermission()
                                    locationStore.start()
                                }
                                Spacer()
                                Button("Sortér efter dato") {
                                    sortMode = .byDate
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Time filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimeFilter.allCases) { f in
                                Button {
                                    timeFilter = f
                                } label: {
                                    Text(f.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(timeFilter == f ? .white : .primary)
                                        // ✅ valgt chip = sort baggrund (dark mode-friendly)
                                        .background(
                                            Capsule()
                                                .fill(timeFilter == f ? Color.black : Color(.secondarySystemBackground))
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Vis kampe: \(f.rawValue)")
                                .accessibilityHint("Sætter tidsfilter for kampoversigten")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // List
                Section {
                    if filteredFixtures.isEmpty {
                        ContentUnavailableView(
                            "Ingen kampe matcher dit filter",
                            systemImage: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "line.3.horizontal.decrease.circle"
                                : "magnifyingglass",
                            description: Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Prøv at ændre tidsfilter, sortering eller slå filtre fra."
                                : "Prøv et andet søgeord eller ryd søgningen.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(filteredFixtures.prefix(maxShownFixtures)) { f in
                            NavigationLink {
                                MatchDetailView(
                                    fixture: f,
                                    clubById: clubById,
                                    visitedStore: visitedStore,
                                    notesStore: notesStore,
                                    reviewsStore: reviewsStore,
                                    fixtures: fixtures
                                )
                            } label: {
                                MatchRow(
                                    fixture: f,
                                    clubById: clubById,
                                    venueVisited: visitedStore.isVisited(f.venueClubId),
                                    distance: (sortMode == .byDistance)
                                        ? locationStore.location.flatMap { distanceText(for: f, from: $0) }
                                        : nil
                                )
                            }
                        }
                    }
                } header: {
                    Text("Kommende kampe (\(filteredFixtures.count))")
                }
            }
            .navigationTitle("Kampe")
            .searchable(text: $searchText, prompt: "Søg klub, stadion, by, runde…")
        }
        .onAppear {
            // Vi starter lokation “passivt” – permission popper først når du vælger afstand
            locationStore.start()
        }
        .onChange(of: sortMode) { _, newValue in
            if newValue == .byDistance {
                locationStore.requestPermission()
                locationStore.start()
            }
        }
    }
}

// MARK: - Row

private struct MatchRow: View {
    let fixture: Fixture
    let clubById: [String: Club]
    let venueVisited: Bool
    let distance: String?
    private let matchTimeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current

    private var homeName: String { clubById[fixture.homeTeamId]?.name ?? fixture.homeTeamId }
    private var awayName: String { clubById[fixture.awayTeamId]?.name ?? fixture.awayTeamId }
    private var venueName: String { clubById[fixture.venueClubId]?.stadium.name ?? fixture.venueClubId }
    private var city: String { clubById[fixture.venueClubId]?.stadium.city ?? "" }
    private var division: String? { clubById[fixture.venueClubId]?.division }
    private var kickoffDateText: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.timeZone = matchTimeZone
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: fixture.kickoff)
    }
    private var kickoffTimeText: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.timeZone = matchTimeZone
        df.dateFormat = "HH:mm"
        return df.string(from: fixture.kickoff)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(kickoffDateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(kickoffTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let distance {
                    Text("• \(distance)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(
                    venueVisited ? "Besøgt" : "Ikke besøgt",
                    systemImage: venueVisited ? "checkmark.circle.fill" : "circle"
                )
                .font(.caption2)
                .foregroundStyle(venueVisited ? .green : .secondary)
            }

            Text("\(homeName) – \(awayName)")
                .font(.headline)

            HStack {
                Text(venueName)
                    .font(.subheadline)

                if !city.isEmpty {
                    Text("• \(city)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 6) {
                if let division, !division.isEmpty {
                    MatchBadge(text: division, icon: "trophy")
                }

                if let r = fixture.round, !r.isEmpty {
                    MatchBadge(text: r, icon: "flag")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.vertical, 6)
    }
}

private struct MatchBadge: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }
}
