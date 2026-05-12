import SwiftUI
import CoreLocation

struct MatchesView: View {
    private struct Snapshot {
        var visibleFixtures: [Fixture] = []
        var visibleNonTopSystemFixtures: [Fixture] = []
        var distanceTextByFixtureId: [String: String] = [:]
        var resultSummaryText: String = "0 kommende kampe"
        var visibleFixtureCount: Int = 0
    }

    let isActive: Bool
    let clubs: [Club]
    let clubById: [String: Club]
    let fixtures: [Fixture]
    @ObservedObject var visitedStore: VisitedStore
    @ObservedObject var photosStore: AppPhotosStore
    @ObservedObject var notesStore: AppNotesStore
    @ObservedObject var reviewsStore: AppReviewsStore

    init(
        isActive: Bool,
        clubs: [Club],
        clubById: [String: Club]? = nil,
        fixtures: [Fixture],
        visitedStore: VisitedStore,
        photosStore: AppPhotosStore,
        notesStore: AppNotesStore,
        reviewsStore: AppReviewsStore
    ) {
        self.isActive = isActive
        self.clubs = clubs
        self.clubById = clubById ?? ClubIdentityResolver.aliasMap(
            from: Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
        )
        self.fixtures = fixtures
        self.visitedStore = visitedStore
        self.photosStore = photosStore
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

    @AppStorage(AppLeaguePackSettings.preferredHomeCountryCodeKey) private var preferredHomeCountryCode: String = "dk"
    @AppStorage("matches.timeFilter") private var timeFilterRawValue: String = TimeFilter.week.rawValue
    @AppStorage("matches.onlyUnvisitedVenues") private var onlyUnvisitedVenues: Bool = true
    @AppStorage("stadiums.countryFilter") private var countryFilterRawValue: String = "all"
    @State private var searchText = ""
    @State private var isShowingFilters = false
    @State private var snapshot = Snapshot()

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
    private var locationSnapshotToken: String {
        guard let location = locationStore.location else { return "none" }
        let roundedLatitude = String(format: "%.3f", location.coordinate.latitude)
        let roundedLongitude = String(format: "%.3f", location.coordinate.longitude)
        let roundedTimestamp = Int(location.timestamp.timeIntervalSince1970 / 60)
        return "\(roundedLatitude)|\(roundedLongitude)|\(roundedTimestamp)"
    }

    private var countryOptions: [String] {
        let source = progressionClubs.isEmpty ? clubs : progressionClubs
        return Array(Set(source.map(\.countryCode))).sorted { left, right in
            if LeaguePresentation.countryRank(left) != LeaguePresentation.countryRank(right) {
                return LeaguePresentation.countryRank(left) < LeaguePresentation.countryRank(right)
            }
            return LeaguePresentation.countryLabel(left).localizedCaseInsensitiveCompare(LeaguePresentation.countryLabel(right)) == .orderedAscending
        }
    }

    private var progressionClubs: [Club] {
        clubs.filter(\.countsTowardTopSystemProgression)
    }

    private var visitedVenueClubIds: Set<String> {
        Set(visitedStore.records.lazy.filter(\.value.visited).map(\.key))
    }

    private var shouldShowCountryFilter: Bool {
        countryOptions.count > 1
    }

    private var activeFilterCount: Int {
        var count = 0
        if onlyUnvisitedVenues { count += 1 }
        if countryFilterRawValue != "all" { count += 1 }
        if sortMode == .byDistance { count += 1 }
        return count
    }

    private var scopeLabel: String {
        countryFilterRawValue == "all" ? "Alle aktive lande" : LeaguePresentation.countryLabel(countryFilterRawValue)
    }

    private func rebuildSnapshot() {
        guard isActive else { return }

        let cal = matchCalendar
        let todayStart = cal.startOfDay(for: Date())
        let progressionClubIds = Set(
            progressionClubs.flatMap { ClubIdentityResolver.allKnownIds(for: $0.id) }
        )
        let visitedIds = visitedVenueClubIds

        let clubHasActiveMembershipInFixtureCompetition: (Club, String) -> Bool = { club, competitionId in
            club.competitionMemberships.contains { membership in
                membership.competitionId == competitionId && membership.status == .active
            }
        }

        let fixtureCountsTowardTopSystem: (Fixture) -> Bool = { fixture in
            if let competitionId = fixture.competitionId,
               CompetitionCatalog.isTrackedDomesticCompetition(competitionId) {
                let involvedClubs = [
                    clubById[fixture.venueClubId],
                    clubById[fixture.homeTeamId],
                    clubById[fixture.awayTeamId]
                ]

                return involvedClubs.allSatisfy { club in
                    guard let club else { return false }
                    return clubHasActiveMembershipInFixtureCompetition(club, competitionId)
                }
            }

            return progressionClubIds.contains(fixture.venueClubId)
                && progressionClubIds.contains(fixture.homeTeamId)
                && progressionClubIds.contains(fixture.awayTeamId)
        }

        let countryMatches: (Fixture) -> Bool = { fixture in
            if countryFilterRawValue == "all" {
                return true
            }
            return clubById[fixture.venueClubId]?.countryCode == countryFilterRawValue
        }

        let searchedMatches: (Fixture) -> Bool = { fixture in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }

            let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let home = clubById[fixture.homeTeamId]?.name ?? fixture.homeTeamId
            let away = clubById[fixture.awayTeamId]?.name ?? fixture.awayTeamId
            let venue = clubById[fixture.venueClubId]?.stadium.name ?? fixture.venueClubId
            let city = clubById[fixture.venueClubId]?.stadium.city ?? ""
            let round = fixture.round ?? ""
            let haystack = "\(home) \(away) \(venue) \(city) \(round)"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return haystack.contains(needle)
        }

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

        let scopedUpcomingFixtures = fixtures.filter { $0.kickoff >= todayStart }
        var visibleFixtures = scopedUpcomingFixtures
            .filter { fixtureCountsTowardTopSystem($0) }
            .filter { $0.kickoff < endExclusive }
            .filter(countryMatches)
            .filter(searchedMatches)

        if onlyUnvisitedVenues {
            visibleFixtures.removeAll { visitedIds.contains($0.venueClubId) }
        }

        let visibleNonTopSystemFixtures = scopedUpcomingFixtures
            .filter { !fixtureCountsTowardTopSystem($0) }
            .filter(countryMatches)
            .filter(searchedMatches)
            .sorted { $0.kickoff < $1.kickoff }

        var distanceTextByFixtureId: [String: String] = [:]
        switch sortMode {
        case .byDate:
            visibleFixtures.sort { $0.kickoff < $1.kickoff }

        case .byDistance:
            guard let here = locationStore.location else {
                visibleFixtures.sort { $0.kickoff < $1.kickoff }
                break
            }

            let distById = Dictionary(uniqueKeysWithValues: visibleFixtures.map { fixture in
                let distance = distanceMeters(for: fixture, from: here) ?? Double.greatestFiniteMagnitude
                return (fixture.id, distance)
            })
            distanceTextByFixtureId = Dictionary(uniqueKeysWithValues: visibleFixtures.map { fixture in
                let text = distanceText(for: fixture, from: here) ?? ""
                return (fixture.id, text)
            })

            visibleFixtures.sort { a, b in
                let da = distById[a.id] ?? Double.greatestFiniteMagnitude
                let db = distById[b.id] ?? Double.greatestFiniteMagnitude

                if da != db {
                    return reverseDistanceSort ? (da > db) : (da < db)
                }

                return a.kickoff < b.kickoff
            }
        }

        let visibleFixtureCount = visibleFixtures.count
        let noun = visibleFixtureCount == 1 ? "kamp" : "kampe"
        let resultSummaryText: String = {
            if activeFilterCount == 0 {
                return "\(visibleFixtureCount) kommende \(noun) i dit nuværende tidsrum"
            }
            return "\(visibleFixtureCount) kommende \(noun) med \(activeFilterCount) aktive filtre"
        }()

        snapshot = Snapshot(
            visibleFixtures: visibleFixtures,
            visibleNonTopSystemFixtures: visibleNonTopSystemFixtures,
            distanceTextByFixtureId: distanceTextByFixtureId,
            resultSummaryText: resultSummaryText,
            visibleFixtureCount: visibleFixtureCount
        )
    }

    var body: some View {
        Group {
            if isActive {
                activeBody
            } else {
                NavigationStack {
                    Color.clear
                        .navigationTitle("Kampe")
                }
            }
        }
    }

    private var activeBody: some View {
        return NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Find næste gode kamp")
                                    .font(.headline)
                                Text(snapshot.resultSummaryText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                MatchesContextChip(text: scopeLabel, systemImage: "globe.europe.africa")
                                if onlyUnvisitedVenues {
                                    MatchesContextChip(text: "Kun ubesøgte", systemImage: "checkmark.circle")
                                }
                                if sortMode == .byDistance {
                                    MatchesContextChip(text: "Sortering: afstand", systemImage: "location")
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(TimeFilter.allCases) { f in
                                    timeFilterButton(for: f)
                                }
                            }
                        }
                        .padding(.vertical, 2)

                        if sortMode == .byDistance && locationStore.location == nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Afstandssortering kræver lokation")
                                    .font(.subheadline.weight(.semibold))
                                Text(locationHintText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }

                Section {
                    if snapshot.visibleFixtures.isEmpty {
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
                        ForEach(snapshot.visibleFixtures.prefix(maxShownFixtures)) { f in
                            matchNavigationRow(for: f)
                        }
                    }
                } header: {
                    Text("Kommende kampe (\(snapshot.visibleFixtureCount))")
                }

                if !snapshot.visibleNonTopSystemFixtures.isEmpty {
                    Section("Andre kampe") {
                        Text("Kampe her tæller ikke med i din aktuelle fremdrift, men bliver stadig bevaret i appen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(snapshot.visibleNonTopSystemFixtures.prefix(20)) { f in
                            matchNavigationRow(
                                for: f,
                                statusOverride: clubById[f.venueClubId]?.membershipStatusLabel
                            )
                        }
                    }
                }
            }
            .navigationTitle("Kampe")
            .searchable(text: $searchText, prompt: "Søg klub, stadion, by, runde…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingFilters = true
                    } label: {
                        Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Åbn filtre")
                }
            }
            .sheet(isPresented: $isShowingFilters) {
                MatchesFilterSheet(
                    sortMode: Binding(get: { sortMode }, set: { sortMode = $0 }),
                    reverseDistanceSort: $reverseDistanceSort,
                    onlyUnvisitedVenues: $onlyUnvisitedVenues,
                    countryFilterRawValue: $countryFilterRawValue,
                    shouldShowCountryFilter: shouldShowCountryFilter,
                    countryOptions: countryOptions,
                    countryLabel: { LeaguePresentation.countryLabel($0) },
                    locationHintText: locationHintText,
                    hasLocation: locationStore.location != nil,
                    requestLocation: {
                        locationStore.requestPermission()
                        locationStore.start()
                    },
                    dismiss: {
                        isShowingFilters = false
                    }
                )
            }
        }
        .onAppear {
            if sortMode == .byDistance {
                locationStore.start()
            }
            rebuildSnapshot()
        }
        .onChange(of: sortMode) { _, newValue in
            if newValue == .byDistance {
                locationStore.requestPermission()
                locationStore.start()
            }
            rebuildSnapshot()
        }
        .onAppear {
            let resolvedHomeCountry = countryOptions.contains(preferredHomeCountryCode)
                ? preferredHomeCountryCode
                : LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: Set(countryOptions))
            if countryFilterRawValue == "all" && countryOptions.contains(resolvedHomeCountry) {
                countryFilterRawValue = resolvedHomeCountry
            } else if !countryOptions.contains(countryFilterRawValue) {
                countryFilterRawValue = resolvedHomeCountry
            }
            rebuildSnapshot()
        }
        .onChange(of: isActive) { _, isActive in
            if isActive {
                rebuildSnapshot()
            }
        }
        .onChange(of: timeFilterRawValue) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: onlyUnvisitedVenues) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: countryFilterRawValue) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: searchText) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: fixtures) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: clubs) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: visitedStore.records) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: sortModeRawValue) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: reverseDistanceSort) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: locationSnapshotToken) { _, _ in
            rebuildSnapshot()
        }
    }

}

private extension MatchesView {
    @ViewBuilder
    func matchNavigationRow(for fixture: Fixture, statusOverride: String? = nil) -> some View {
        let accessibilityId = "match-row-" + fixture.id

        NavigationLink {
            MatchDetailView(
                fixture: fixture,
                clubById: clubById,
                visitedStore: visitedStore,
                photosStore: photosStore,
                notesStore: notesStore,
                reviewsStore: reviewsStore,
                fixtures: fixtures
            )
        } label: {
            MatchRow(
                fixture: fixture,
                clubById: clubById,
                venueVisited: visitedVenueClubIds.contains(fixture.venueClubId),
                distance: snapshot.distanceTextByFixtureId[fixture.id],
                statusOverride: statusOverride
            )
        }
        .accessibilityIdentifier(accessibilityId)
    }

    @ViewBuilder
    func timeFilterButton(for filter: TimeFilter) -> some View {
        Button {
            timeFilter = filter
        } label: {
            timeFilterChip(for: filter)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Vis kampe: " + filter.rawValue)
        .accessibilityHint("Sætter tidsfilter for kampoversigten")
    }

    @ViewBuilder
    func timeFilterChip(for filter: TimeFilter) -> some View {
        let isSelected = timeFilter == filter
        Text(filter.rawValue)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.black : Color(.secondarySystemBackground))
            )
    }
}

private struct MatchesContextChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
    }
}

private struct MatchesFilterSheet: View {
    @Binding var sortMode: MatchesView.SortMode
    @Binding var reverseDistanceSort: Bool
    @Binding var onlyUnvisitedVenues: Bool
    @Binding var countryFilterRawValue: String

    let shouldShowCountryFilter: Bool
    let countryOptions: [String]
    let countryLabel: (String) -> String
    let locationHintText: String
    let hasLocation: Bool
    let requestLocation: () -> Void
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Visning") {
                    Toggle("Kun stadions jeg ikke har besøgt", isOn: $onlyUnvisitedVenues)

                    Picker("Sortér", selection: $sortMode) {
                        ForEach(MatchesView.SortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if sortMode == .byDistance {
                        Toggle("Længst væk først", isOn: $reverseDistanceSort)

                        if !hasLocation {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Lokation mangler")
                                    .font(.subheadline.weight(.semibold))
                                Text(locationHintText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Tillad lokation", action: requestLocation)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if shouldShowCountryFilter {
                    Section("Scope") {
                        Picker("Land", selection: $countryFilterRawValue) {
                            Text("Alle aktive lande").tag("all")
                            ForEach(countryOptions, id: \.self) { countryCode in
                                Text(countryLabel(countryCode)).tag(countryCode)
                            }
                        }
                        .pickerStyle(.inline)

                        Text("Dit hjemland bruges som standard-scope, når appen åbner.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Filtre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Færdig", action: dismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Row

private struct MatchRow: View {
    let fixture: Fixture
    let clubById: [String: Club]
    let venueVisited: Bool
    let distance: String?
    let statusOverride: String?
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "da_DK")
        formatter.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "da_DK")
        formatter.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var homeName: String { clubById[fixture.homeTeamId]?.name ?? fixture.homeTeamId }
    private var awayName: String { clubById[fixture.awayTeamId]?.name ?? fixture.awayTeamId }
    private var venueName: String { clubById[fixture.venueClubId]?.stadium.name ?? fixture.venueClubId }
    private var city: String { clubById[fixture.venueClubId]?.stadium.city ?? "" }
    private var division: String? { clubById[fixture.venueClubId]?.division }
    private var kickoffDateText: String {
        Self.dateFormatter.string(from: fixture.kickoff)
    }
    private var kickoffTimeText: String {
        Self.timeFormatter.string(from: fixture.kickoff)
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

                if let statusOverride, !statusOverride.isEmpty {
                    MatchBadge(text: statusOverride, icon: "arrow.down.circle")
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
