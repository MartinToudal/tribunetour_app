import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    private enum AppTab: Hashable {
        case stadiums
        case matches
        case planner
        case stats
    }

    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .stadiums

    var body: some View {
        Group {
            if let loadError = appState.loadError {
                NavigationStack {
                    ContentUnavailableView(
                        "Kunne ikke indlæse data",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                    .padding()
                    .navigationTitle("Tribunetour")
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Prøv igen") { appState.loadData() }
                        }
                    }
                }
            } else {
                TabView(selection: $selectedTab) {
                    StadiumsView(
                        isActive: selectedTab == .stadiums,
                        clubs: appState.clubs,
                        clubById: appState.clubById,
                        fixtures: appState.fixtures,
                        visitedStore: appState.visitedStore,
                        photosStore: appState.photosStore,
                        notesStore: appState.notesStore,
                        reviewsStore: appState.reviewsStore
                    )
                        .tabItem { Label("Stadions", systemImage: "map") }
                        .tag(AppTab.stadiums)

                    MatchesView(
                        isActive: selectedTab == .matches,
                        clubs: appState.clubs,
                        clubById: appState.clubById,
                        fixtures: appState.fixtures,
                        visitedStore: appState.visitedStore,
                        photosStore: appState.photosStore,
                        notesStore: appState.notesStore,
                        reviewsStore: appState.reviewsStore
                    )
                        .tabItem { Label("Kampe", systemImage: "sportscourt") }
                        .tag(AppTab.matches)

                    WeekendPlannerView(
                        isActive: selectedTab == .planner,
                        clubs: appState.clubs,
                        clubById: appState.clubById,
                        fixtures: appState.fixtures,
                        visitedStore: appState.visitedStore,
                        planStore: appState.weekendPlanStore
                    )
                        .tabItem { Label("Plan", systemImage: "calendar") }
                        .tag(AppTab.planner)

                    StatsView(
                        isActive: selectedTab == .stats,
                        clubs: appState.clubs,
                        clubById: appState.clubById,
                        visitedStore: appState.visitedStore,
                        photosStore: appState.photosStore,
                        notesStore: appState.notesStore,
                        reviewsStore: appState.reviewsStore,
                        authSession: appState.authSession,
                        authClient: appState.authClient,
                        bootstrapCoordinator: appState.visitedBootstrapCoordinator,
                        runtimeSyncInfoMessage: appState.syncRuntimeInfoMessage
                    )
                        .tabItem { Label("Min tur", systemImage: "chart.bar") }
                        .badge(
                            appState.adminNotificationsManager.badgeCount > 0
                                ? "\(appState.adminNotificationsManager.badgeCount)"
                                : nil
                        )
                        .tag(AppTab.stats)
                }
            }
        }
        .onAppear {
            appState.loadData()
        }
        .onOpenURL { url in
            appState.handleOpenURL(url)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            appState.refreshSharedVisitedFromRemote()
        }
        .environmentObject(appState)
        .environmentObject(appState.adminNotificationsManager)
        .environmentObject(appState.locationStore)
        .environmentObject(appState.authSession)
    }
}

// MARK: - Stadions tab

struct StadiumsView: View {
    private struct Snapshot {
        var visibleClubs: [Club] = []
        var displayedClubs: [Club] = []
        var visibleNonProgressionClubs: [Club] = []
        var mapPreviewClubs: [Club] = []
        var distanceTextByClubId: [String: String] = [:]
        var activeScopeLabel: String = ""
        var mapSummary: String = "0 stadions i scope • 0 ubesøgte"
        var visitedCount: Int = 0
        var scopeTotalCount: Int = 0
        var remainingClubCount: Int = 0
        var shouldPaginateClubList: Bool = false
        var shouldRenderMapForCurrentScope: Bool = true
        var mapIsTruncated: Bool = false
    }

    let isActive: Bool
    let clubs: [Club]
    let clubById: [String: Club]
    let fixtures: [Fixture]
    @ObservedObject var visitedStore: VisitedStore
    @ObservedObject var photosStore: AppPhotosStore
    @ObservedObject var notesStore: AppNotesStore
    @ObservedObject var reviewsStore: AppReviewsStore

    @EnvironmentObject private var locationStore: LocationStore
    @EnvironmentObject private var authSession: AppAuthSession

    @State private var selectedClub: Club?
    @State private var detailSheetClub: Club?
    @State private var showFullscreenMap: Bool = false
    @State private var visibleClubLimit: Int = 80
    @State private var snapshot = Snapshot()
    #if DEBUG
    @State private var hiddenToolsTapCount: Int = 0
    @State private var showInternalTools: Bool = false
    #endif

    enum VisitedFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case notVisited = "Kun ikke-besøgte"
        case visited = "Kun besøgte"
        var id: String { rawValue }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case leagueThenTeam = "Liga → klub"
        case teamAZ = "Klub A–Å"
        case stadiumAZ = "Stadion A–Å"
        case visitedFirst = "Besøgt først"
        case notVisitedFirst = "Ikke-besøgte først"
        case nearest = "Tættest på mig"
        var id: String { rawValue }
    }

    @AppStorage("stadiums.visitedFilter") private var filterRawValue: String = VisitedFilter.all.rawValue
    @AppStorage("stadiums.sortOption") private var sortRawValue: String = SortOption.leagueThenTeam.rawValue
    @AppStorage("stadiums.countryFilter") private var countryFilterRawValue: String = "all"
    @State private var searchText: String = ""
    private let maxMapAnnotations = 120
    private let maxMapScopeWithoutCountrySelection = 80
    private let listPageSize = 80

    private var filter: VisitedFilter {
        get { VisitedFilter(rawValue: filterRawValue) ?? .all }
        nonmutating set { filterRawValue = newValue.rawValue }
    }

    private var sort: SortOption {
        get { SortOption(rawValue: sortRawValue) ?? .leagueThenTeam }
        nonmutating set { sortRawValue = newValue.rawValue }
    }

    private var visitedClubIds: Set<String> {
        Set(visitedStore.records.lazy.filter(\.value.visited).map(\.key))
    }

    private var reviewedClubIds: Set<String> {
        Set(reviewsStore.reviewsByClubId.keys)
    }

    private var countryOptions: [String] {
        let progressionClubs = clubs.filter(\.countsTowardTopSystemProgression)
        let source = progressionClubs.isEmpty ? clubs : progressionClubs
        return Array(Set(source.map(\.countryCode))).sorted { left, right in
            if LeaguePresentation.countryRank(left) != LeaguePresentation.countryRank(right) {
                return LeaguePresentation.countryRank(left) < LeaguePresentation.countryRank(right)
            }
            return LeaguePresentation.countryLabel(left).localizedCaseInsensitiveCompare(LeaguePresentation.countryLabel(right)) == .orderedAscending
        }
    }

    private var shouldShowCountryFilter: Bool {
        countryOptions.count > 1
    }

    private var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var unlockedPremiumTitles: [String] {
        let enabledPackIds = AppLeaguePackSettings.effectiveEnabledLeaguePacks
        return AppLeaguePackCatalog.entries
            .filter { $0.isPremium && $0.id != .premiumFull && enabledPackIds.contains($0.id.rawValue) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.label)
    }

    private var lockedPremiumTitles: [String] {
        let enabledPackIds = AppLeaguePackSettings.effectiveEnabledLeaguePacks
        return AppLeaguePackCatalog.entries
            .filter { $0.isPremium && $0.id != .premiumFull && !enabledPackIds.contains($0.id.rawValue) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.label)
    }

    private func sortComparator(_ a: Club, _ b: Club) -> Bool {
        let aVisited = visitedClubIds.contains(a.id)
        let bVisited = visitedClubIds.contains(b.id)

        switch sort {
        case .leagueThenTeam:
            let ca = LeaguePresentation.countryRank(a.countryCode)
            let cb = LeaguePresentation.countryRank(b.countryCode)
            if ca != cb { return ca < cb }

            let ra = LeaguePresentation.divisionRank(a.division, countryCode: a.countryCode)
            let rb = LeaguePresentation.divisionRank(b.division, countryCode: b.countryCode)
            if ra != rb { return ra < rb }

            // samme "rank" → fallback alfabetisk på division + klub
            if a.division != b.division {
                return a.division.localizedCaseInsensitiveCompare(b.division) == .orderedAscending
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending

        case .teamAZ:
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending

        case .stadiumAZ:
            return a.stadium.name.localizedCaseInsensitiveCompare(b.stadium.name) == .orderedAscending

        case .visitedFirst:
            if aVisited != bVisited { return aVisited && !bVisited }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending

        case .notVisitedFirst:
            if aVisited != bVisited { return !aVisited && bVisited }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending

        case .nearest:
            guard let here = locationStore.location else {
                let ra = LeaguePresentation.divisionRank(a.division, countryCode: a.countryCode)
                let rb = LeaguePresentation.divisionRank(b.division, countryCode: b.countryCode)
                if ra != rb { return ra < rb }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            let da = here.distance(from: CLLocation(latitude: a.stadium.latitude, longitude: a.stadium.longitude))
            let db = here.distance(from: CLLocation(latitude: b.stadium.latitude, longitude: b.stadium.longitude))

            if da != db { return da < db }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func distanceText(for club: Club) -> String? {
        guard let here = locationStore.location else { return nil }
        let d = here.distance(from: CLLocation(latitude: club.stadium.latitude, longitude: club.stadium.longitude))
        if d < 1000 { return "\(Int(d)) m" }
        return String(format: "%.1f km", d / 1000.0)
    }

    private func openInAppleMaps(_ club: Club) {
        let location = CLLocation(latitude: club.stadium.latitude, longitude: club.stadium.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = "\(club.stadium.name) – \(club.name)"
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func locationHintText() -> String {
        locationAuthorizationHint(locationStore.authorization)
    }

    private func resetVisibleClubLimit() {
        visibleClubLimit = listPageSize
    }

    private var locationSnapshotToken: String {
        guard let location = locationStore.location else { return "none" }
        let roundedLatitude = String(format: "%.3f", location.coordinate.latitude)
        let roundedLongitude = String(format: "%.3f", location.coordinate.longitude)
        let roundedTimestamp = Int(location.timestamp.timeIntervalSince1970 / 60)
        return "\(roundedLatitude)|\(roundedLongitude)|\(roundedTimestamp)"
    }

    private func rebuildSnapshot() {
        guard isActive else { return }

        let visitedIds = visitedClubIds
        let reviewedIds = reviewedClubIds
        let progressionClubs = clubs.filter(\.countsTowardTopSystemProgression)
        let nonProgressionVisibleClubs = clubs.filter(\.shouldRemainVisibleOutsideTopSystem)
        let sourceClubs = progressionClubs.isEmpty ? clubs : progressionClubs
        let countryFilteredClubs: [Club] = {
            guard countryFilterRawValue != "all" else { return sourceClubs }
            return sourceClubs.filter { $0.countryCode == countryFilterRawValue }
        }()
        let countryFilteredNonProgressionClubs: [Club] = {
            guard countryFilterRawValue != "all" else { return nonProgressionVisibleClubs }
            return nonProgressionVisibleClubs.filter { $0.countryCode == countryFilterRawValue }
        }()

        let baseClubs: [Club] = {
            switch filter {
            case .all:
                return countryFilteredClubs
            case .visited:
                return countryFilteredClubs.filter { visitedIds.contains($0.id) }
            case .notVisited:
                return countryFilteredClubs.filter { !visitedIds.contains($0.id) }
            }
        }()

        let searchedClubs: [Club] = {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return baseClubs }

            let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return baseClubs.filter { club in
                let haystack = [
                    club.name,
                    club.stadium.name,
                    club.stadium.city,
                    club.division
                ]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                return haystack.contains(needle)
            }
        }()

        let sortComparator: (Club, Club) -> Bool = { a, b in
            let aVisited = visitedIds.contains(a.id)
            let bVisited = visitedIds.contains(b.id)

            switch sort {
            case .leagueThenTeam:
                let ca = LeaguePresentation.countryRank(a.countryCode)
                let cb = LeaguePresentation.countryRank(b.countryCode)
                if ca != cb { return ca < cb }

                let ra = LeaguePresentation.divisionRank(a.division, countryCode: a.countryCode)
                let rb = LeaguePresentation.divisionRank(b.division, countryCode: b.countryCode)
                if ra != rb { return ra < rb }
                if a.division != b.division {
                    return a.division.localizedCaseInsensitiveCompare(b.division) == .orderedAscending
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending

            case .teamAZ:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending

            case .stadiumAZ:
                return a.stadium.name.localizedCaseInsensitiveCompare(b.stadium.name) == .orderedAscending

            case .visitedFirst:
                if aVisited != bVisited { return aVisited && !bVisited }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending

            case .notVisitedFirst:
                if aVisited != bVisited { return !aVisited && bVisited }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending

            case .nearest:
                guard let here = locationStore.location else {
                    let ra = LeaguePresentation.divisionRank(a.division, countryCode: a.countryCode)
                    let rb = LeaguePresentation.divisionRank(b.division, countryCode: b.countryCode)
                    if ra != rb { return ra < rb }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }

                let da = here.distance(from: CLLocation(latitude: a.stadium.latitude, longitude: a.stadium.longitude))
                let db = here.distance(from: CLLocation(latitude: b.stadium.latitude, longitude: b.stadium.longitude))
                if da != db { return da < db }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }

        let visibleClubs = searchedClubs.sorted(by: sortComparator)
        let visibleNonProgressionClubs = countryFilteredNonProgressionClubs.sorted(by: sortComparator)
        let shouldPaginateClubList = countryFilterRawValue == "all" && visibleClubs.count > listPageSize
        let displayedClubs = shouldPaginateClubList ? Array(visibleClubs.prefix(visibleClubLimit)) : visibleClubs
        let mapPreviewClubs = Array(visibleClubs.prefix(maxMapAnnotations))
        let shouldRenderMapForCurrentScope = !(countryFilterRawValue == "all" && visibleClubs.count > maxMapScopeWithoutCountrySelection)
        let activeScopeLabel = countryFilterRawValue == "all"
            ? (shouldShowCountryFilter ? "Alle aktive lande" : LeaguePresentation.countryLabel(countryOptions.first ?? "dk"))
            : LeaguePresentation.countryLabel(countryFilterRawValue)

        var distanceTextByClubId: [String: String] = [:]
        if sort == .nearest, let here = locationStore.location {
            distanceTextByClubId = Dictionary(uniqueKeysWithValues: displayedClubs.map { club in
                let distance = here.distance(from: CLLocation(latitude: club.stadium.latitude, longitude: club.stadium.longitude))
                let text = distance < 1000 ? "\(Int(distance)) m" : String(format: "%.1f km", distance / 1000.0)
                return (club.id, text)
            })
        }

        snapshot = Snapshot(
            visibleClubs: visibleClubs,
            displayedClubs: displayedClubs,
            visibleNonProgressionClubs: visibleNonProgressionClubs,
            mapPreviewClubs: mapPreviewClubs,
            distanceTextByClubId: distanceTextByClubId,
            activeScopeLabel: activeScopeLabel,
            mapSummary: "\(visibleClubs.count) stadions i scope • \(visibleClubs.filter { !visitedIds.contains($0.id) }.count) ubesøgte",
            visitedCount: countryFilteredClubs.filter { visitedIds.contains($0.id) }.count,
            scopeTotalCount: countryFilteredClubs.count,
            remainingClubCount: max(0, visibleClubs.count - displayedClubs.count),
            shouldPaginateClubList: shouldPaginateClubList,
            shouldRenderMapForCurrentScope: shouldRenderMapForCurrentScope,
            mapIsTruncated: visibleClubs.count > maxMapAnnotations
        )
        _ = reviewedIds
    }

    var body: some View {
        Group {
            if isActive {
                activeBody
            } else {
                NavigationStack {
                    Color.clear
                        .navigationTitle("Stadions")
                }
            }
        }
    }

    private var activeBody: some View {
        return NavigationStack {
            List {
                if sort == .nearest && locationStore.location == nil {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tættest på mig kræver lokation")
                                .font(.headline)

                            Text(locationHintText())
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("Tillad lokation") {
                                    locationStore.requestPermission()
                                    locationStore.start()
                                }
                                Spacer()
                                Button("Skift sortering") {
                                    sort = .leagueThenTeam
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Badge(text: snapshot.activeScopeLabel, icon: "globe.europe.africa")
                            Badge(text: snapshot.mapSummary, icon: "map")
                        }
                        .font(.caption2)

                        Button {
                            showFullscreenMap = true
                        } label: {
                            Label("Vis kort i fuldskærm", systemImage: "map")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if snapshot.shouldRenderMapForCurrentScope {
                            if snapshot.mapIsTruncated {
                                Text("Kortet viser de første \(maxMapAnnotations) stadions i dit nuværende filter for at holde appen hurtig.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            StadiumMapView(
                                clubs: snapshot.mapPreviewClubs,
                                visitedStore: visitedStore,
                                onSelect: { club in
                                    selectedClub = club
                                }
                            )
                            .frame(height: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            ContentUnavailableView(
                                "Kortet er bedst pr. land",
                                systemImage: "map",
                                description: Text("Vælg et enkelt land eller åbn kortet i fuldskærm for en lettere og mere brugbar visning.")
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets())

                Section {
                    PremiumAccessStatusCard(
                        isLoggedIn: authSession.snapshot.isAuthenticated,
                        unlockedPremiumTitles: unlockedPremiumTitles,
                        lockedPremiumTitles: lockedPremiumTitles,
                        title: "Adgang til stadions",
                        subtitle: authSession.snapshot.isAuthenticated
                            ? "Det her er de lande din konto aktuelt har åbnet i appen."
                            : "Du ser kun Danmark som grundpakke, indtil du logger ind og får adgang til flere lande."
                    )
                }

                if snapshot.visibleClubs.isEmpty {
                    Section {
                        ContentUnavailableView(
                            hasSearchText ? "Ingen søgeresultater" : "Ingen stadions matcher filteret",
                            systemImage: hasSearchText ? "magnifyingglass" : "line.3.horizontal.decrease.circle",
                            description: Text(hasSearchText
                                ? "Prøv et andet søgeord eller ryd filtrene."
                                : "Juster filtre eller sortering for at se stadions.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } else {
                    ForEach(snapshot.displayedClubs) { club in
                        NavigationLink {
                            StadiumDetailView(
                                club: club,
                                visitedStore: visitedStore,
                                photosStore: photosStore,
                                notesStore: notesStore,
                                reviewsStore: reviewsStore,
                                clubById: clubById,
                                fixtures: fixtures
                            )
                        } label: {
                            StadiumListRow(
                                club: club,
                                isVisited: visitedClubIds.contains(club.id),
                                isReviewed: reviewedClubIds.contains(club.id),
                                shouldShowCountryFilter: shouldShowCountryFilter,
                                countryLabel: LeaguePresentation.countryLabel(club.countryCode),
                                distanceText: sort == .nearest ? snapshot.distanceTextByClubId[club.id] : nil,
                                visitedBinding: Binding(
                                    get: { visitedClubIds.contains(club.id) },
                                    set: { visitedStore.setVisited(club.id, $0) }
                                )
                            )
                        }
                        .accessibilityIdentifier("stadium-row-\(club.id)")
                    }

                    if snapshot.shouldPaginateClubList, snapshot.remainingClubCount > 0 {
                        Section {
                            Button {
                                visibleClubLimit += listPageSize
                                rebuildSnapshot()
                            } label: {
                                Text("Vis flere stadions (\(snapshot.remainingClubCount) tilbage)")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if !snapshot.visibleNonProgressionClubs.isEmpty {
                    Section("Andre klubber") {
                        Text("Klubber her tæller ikke med i din aktuelle fremdrift, men bliver stadig bevaret i appen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(snapshot.visibleNonProgressionClubs) { club in
                            NavigationLink {
                                StadiumDetailView(
                                    club: club,
                                    visitedStore: visitedStore,
                                    photosStore: photosStore,
                                    notesStore: notesStore,
                                    reviewsStore: reviewsStore,
                                    clubById: clubById,
                                    fixtures: fixtures
                                )
                            } label: {
                                NonTopSystemStadiumRow(club: club)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stadions")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Søg klub, stadion, by eller liga"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Besøgt \(snapshot.visitedCount) / \(snapshot.scopeTotalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        #if DEBUG
                        .contentShape(Rectangle())
                        .onTapGesture {
                            hiddenToolsTapCount += 1
                            if hiddenToolsTapCount >= 4 {
                                hiddenToolsTapCount = 0
                                showInternalTools = true
                            }
                        }
                        #endif
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        if shouldShowCountryFilter {
                            Picker("Land", selection: $countryFilterRawValue) {
                                Text("Alle aktive lande").tag("all")
                                ForEach(countryOptions, id: \.self) { countryCode in
                                    Text(LeaguePresentation.countryLabel(countryCode)).tag(countryCode)
                                }
                            }

                            Divider()
                        }

                        Picker("Sortér", selection: Binding(get: { sort }, set: { sort = $0 })) {
                            ForEach(SortOption.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }

                    Menu {
                        Picker("Filter", selection: Binding(get: { filter }, set: { filter = $0 })) {
                            ForEach(VisitedFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .onAppear {
            if sort == .nearest {
                locationStore.start()
            }
            let resolvedHomeCountry = LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: Set(countryOptions))
            if !countryOptions.contains(countryFilterRawValue) {
                countryFilterRawValue = resolvedHomeCountry
            }
            rebuildSnapshot()
        }
        .onChange(of: sort) { _, newValue in
            if newValue == .nearest {
                locationStore.requestPermission()
                locationStore.start()
            }
            rebuildSnapshot()
        }
        .onChange(of: isActive) { _, isActive in
            if isActive {
                rebuildSnapshot()
            }
        }
        .onChange(of: countryFilterRawValue) { _, _ in
            resetVisibleClubLimit()
            rebuildSnapshot()
        }
        .onChange(of: filterRawValue) { _, _ in
            resetVisibleClubLimit()
            rebuildSnapshot()
        }
        .onChange(of: sortRawValue) { _, _ in
            resetVisibleClubLimit()
            rebuildSnapshot()
        }
        .onChange(of: searchText) { _, _ in
            resetVisibleClubLimit()
            rebuildSnapshot()
        }
        .onChange(of: visitedStore.records) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: reviewsStore.reviewsByClubId) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: clubs) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: locationSnapshotToken) { _, _ in
            rebuildSnapshot()
        }
        .safeAreaInset(edge: .bottom) {
            if let club = selectedClub {
                StadiumMiniCard(
                    club: club,
                    visited: visitedClubIds.contains(club.id),
                    reviewed: reviewedClubIds.contains(club.id),
                    distance: (sort == .nearest ? snapshot.distanceTextByClubId[club.id] : nil),
                    onClose: { selectedClub = nil },
                    onOpenDetails: { detailSheetClub = club },
                    onToggleVisited: { visitedStore.toggle(club.id) },
                    onOpenInMaps: { openInAppleMaps(club) }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $detailSheetClub) { club in
            NavigationStack {
                StadiumDetailView(
                    club: club,
                    visitedStore: visitedStore,
                    photosStore: photosStore,
                    notesStore: notesStore,
                    reviewsStore: reviewsStore,
                    clubById: clubById,
                    fixtures: fixtures
                )
            }
        }
        .sheet(isPresented: $showFullscreenMap) {
            NavigationStack {
                StadiumMapScreen(
                    title: snapshot.activeScopeLabel,
                    clubs: snapshot.mapPreviewClubs,
                    visitedStore: visitedStore,
                    onSelect: { club in
                        showFullscreenMap = false
                        selectedClub = nil
                        DispatchQueue.main.async {
                            detailSheetClub = club
                        }
                    }
                )
            }
        }
        #if DEBUG
        .sheet(isPresented: $showInternalTools) {
            NavigationStack {
                InternalToolsView(visitedStore: visitedStore, clubs: clubs, fixtures: fixtures)
            }
        }
        #endif
    }
}

private struct StadiumListRow: View {
    let club: Club
    let isVisited: Bool
    let isReviewed: Bool
    let shouldShowCountryFilter: Bool
    let countryLabel: String
    let distanceText: String?
    let visitedBinding: Binding<Bool>

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(club.name)
                    .font(.headline)
                    .lineLimit(2)

                if isVisited || isReviewed {
                    HStack(spacing: 6) {
                        if isVisited {
                            StatusBadge(text: "Besøgt")
                        }
                        if isReviewed {
                            StatusBadge(text: "Anmeldt")
                        }
                    }
                }

                Text(club.stadium.name)
                    .font(.subheadline)
                    .lineLimit(2)

                Text("\(club.division) • \(club.stadium.city)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if shouldShowCountryFilter {
                    Text(countryLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let distanceText {
                    Text("Afstand: \(distanceText)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: visitedBinding)
                .labelsHidden()
                .accessibilityIdentifier("stadium-toggle-\(club.id)")
                .accessibilityLabel("Markér \(club.name) som besøgt")
                .accessibilityHint("Skifter besøgt-status for stadionet")
        }
        .accessibilityElement(children: .combine)
        .padding(.vertical, 4)
    }
}

private struct NonTopSystemStadiumRow: View {
    let club: Club

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(club.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(club.stadium.name)
                    .font(.subheadline)
                    .lineLimit(2)

                Text("\(club.division) • \(club.stadium.city)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let membershipStatusLabel = club.membershipStatusLabel {
                    Text(membershipStatusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct Badge: View {
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

private struct StatusBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Mini card

struct StadiumMiniCard: View {
    let club: Club
    let visited: Bool
    let reviewed: Bool
    let distance: String?

    let onClose: () -> Void
    let onOpenDetails: () -> Void
    let onToggleVisited: () -> Void
    let onOpenInMaps: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(club.name)
                            .font(.headline)

                        if visited {
                            StadiumMiniStatePill(title: "Besøgt", systemImage: "checkmark.circle.fill", tint: .green)
                        }

                        if reviewed {
                            StadiumMiniStatePill(title: "Anmeldt", systemImage: "checkmark.circle.fill", tint: .green)
                        }
                    }

                    Text(club.stadium.name)
                        .font(.subheadline)

                    HStack(spacing: 6) {
                        Text("\(club.division) • \(club.stadium.city)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let distance {
                            Text("• \(distance)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Luk kort")
                .accessibilityHint("Skjul mini-kortet")
            }

            HStack(spacing: 10) {
                Button(action: onOpenDetails) {
                    MiniMapPrimaryButtonLabel(title: "Detaljer", systemImage: "info.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Åbn detaljer")
                .accessibilityHint("Vis detaljer for stadionet")

                Button(action: onOpenInMaps) {
                    Label("Maps", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Åbn i Maps")
                .accessibilityHint("Åbn rutevejledning i Apple Maps")

                Button(action: onToggleVisited) {
                    Label(visited ? "Fortryd" : "Besøgt", systemImage: visited ? "arrow.uturn.backward" : "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(visited ? .secondary : .green)
                .accessibilityLabel(visited ? "Fortryd besøgt" : "Markér som besøgt")
                .accessibilityHint("Skift besøgt-status")
            }
            .font(.caption)
        }
        .padding(14)
        .background(colorScheme == .dark ? Color(.secondarySystemBackground).opacity(0.96) : Color(.systemBackground).opacity(0.98))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 16, y: 8)
    }
}

private struct MiniMapPrimaryButtonLabel: View {
    let title: String
    let systemImage: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.white : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StadiumMiniStatePill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct StadiumMapScreen: View {
    let title: String
    let clubs: [Club]
    @ObservedObject var visitedStore: VisitedStore
    let onSelect: (Club) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            StadiumMapView(
                clubs: clubs,
                visitedStore: visitedStore,
                onSelect: onSelect
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Luk") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Map

struct StadiumMapView: View {
    let clubs: [Club]
    @ObservedObject var visitedStore: VisitedStore
    let onSelect: (Club) -> Void

    @State private var position: MapCameraPosition = .automatic

    private var visitedClubIds: Set<String> {
        Set(visitedStore.records.lazy.filter(\.value.visited).map(\.key))
    }

    var body: some View {
        Map(position: $position) {
            ForEach(clubs) { club in
                Annotation(
                    club.stadium.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: club.stadium.latitude,
                        longitude: club.stadium.longitude
                    )
                ) {
                    Button {
                        zoomToClub(club)
                        onSelect(club)
                    } label: {
                        StadiumMapPin(isVisited: visitedClubIds.contains(club.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(club.stadium.name), \(club.name)")
                    .accessibilityHint("Zoom til stadion og vis mini-kort")
                }
            }
        }
        .mapStyle(.standard)
        .onAppear { zoomToFitAll() }
        .onChange(of: clubs) { _, _ in zoomToFitAll() }
    }

    private func zoomToClub(_ club: Club) {
        let center = CLLocationCoordinate2D(latitude: club.stadium.latitude, longitude: club.stadium.longitude)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            position = .region(region)
        }
    }

    private func zoomToFitAll() {
        guard !clubs.isEmpty else { return }

        let lats = clubs.map { $0.stadium.latitude }
        let lons = clubs.map { $0.stadium.longitude }

        guard
            let minLat = lats.min(),
            let maxLat = lats.max(),
            let minLon = lons.min(),
            let maxLon = lons.max()
        else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latDelta = max(0.05, (maxLat - minLat) * 1.4)
        let lonDelta = max(0.05, (maxLon - minLon) * 1.4)

        position = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        )
    }
}

private struct StadiumMapPin: View {
    let isVisited: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isVisited ? Color.green : (colorScheme == .dark ? Color.white : Color.black))
                    .frame(width: 22, height: 22)

                Image(systemName: isVisited ? "checkmark" : "sportscourt")
                    .font(.caption2.bold())
                    .foregroundStyle(isVisited ? Color.white : (colorScheme == .dark ? Color.black : Color.white))
            }
            .overlay(
                Circle()
                    .stroke(Color(.systemBackground), lineWidth: 2)
            )

            Triangle()
                .fill(isVisited ? Color.green : (colorScheme == .dark ? Color.white : Color.black))
                .frame(width: 10, height: 7)
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 6, y: 3)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
