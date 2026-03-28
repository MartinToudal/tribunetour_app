import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

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
                TabView {
                    StadiumsView(
                        clubs: appState.clubs,
                        fixtures: appState.fixtures,
                        visitedStore: appState.visitedStore,
                        notesStore: appState.notesStore
                    )
                        .tabItem { Label("Stadions", systemImage: "map") }

                    MatchesView(
                        clubs: appState.clubs,
                        fixtures: appState.fixtures,
                        visitedStore: appState.visitedStore,
                        notesStore: appState.notesStore
                    )
                        .tabItem { Label("Kampe", systemImage: "sportscourt") }

                    // ✅ Plan-fanen (WeekendPlannerView har SIN EGEN planStore internt)
                    WeekendPlannerView(clubs: appState.clubs, fixtures: appState.fixtures, visitedStore: appState.visitedStore)
                        .tabItem { Label("Plan", systemImage: "calendar") }

                    StatsView(
                        clubs: appState.clubs,
                        visitedStore: appState.visitedStore,
                        notesStore: appState.notesStore,
                        authSession: appState.authSession,
                        authClient: appState.authClient,
                        bootstrapCoordinator: appState.visitedBootstrapCoordinator,
                        runtimeSyncInfoMessage: appState.syncRuntimeInfoMessage
                    )
                        .tabItem { Label("Min tur", systemImage: "chart.bar") }
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
        .environmentObject(appState.locationStore)
        .environmentObject(appState.authSession)
    }
}

// MARK: - Stadions tab

struct StadiumsView: View {
    let clubs: [Club]
    let fixtures: [Fixture]
    @ObservedObject var visitedStore: VisitedStore
    @ObservedObject var notesStore: AppNotesStore

    @EnvironmentObject private var locationStore: LocationStore

    @State private var selectedClub: Club?
    @State private var detailSheetClub: Club?
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
    @State private var searchText: String = ""

    private var filter: VisitedFilter {
        get { VisitedFilter(rawValue: filterRawValue) ?? .all }
        nonmutating set { filterRawValue = newValue.rawValue }
    }

    private var sort: SortOption {
        get { SortOption(rawValue: sortRawValue) ?? .leagueThenTeam }
        nonmutating set { sortRawValue = newValue.rawValue }
    }

    private var visitedCount: Int {
        clubs.filter { visitedStore.isVisited($0.id) }.count
    }

    private var clubByIdMap: [String: Club] {
        Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
    }

    private func isReviewed(_ clubId: String) -> Bool {
        visitedStore.review(for: clubId)?.hasMeaningfulContent == true
    }

    private var filteredAndSortedClubs: [Club] {
        // 1) Besøgt-filter
        let base: [Club] = {
            switch filter {
            case .all:
                return clubs
            case .visited:
                return clubs.filter { visitedStore.isVisited($0.id) }
            case .notVisited:
                return clubs.filter { !visitedStore.isVisited($0.id) }
            }
        }()

        // 2) Search
        let searched: [Club] = {
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return base }

            let needle = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            return base.filter { club in
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

        // 3) Sortering
        return searched.sorted(by: sortComparator)
    }

    private var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // ✅ Sørg for Superliga øverst, derefter 1., 2., 3. division (fallback alfabetisk)
    private func divisionRank(_ division: String) -> Int {
        let d = division.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if d.contains("superliga") { return 0 }
        if d.contains("1.") || d.contains("1 division") || d.contains("1. division") { return 1 }
        if d.contains("2.") || d.contains("2 division") || d.contains("2. division") { return 2 }
        if d.contains("3.") || d.contains("3 division") || d.contains("3. division") { return 3 }

        return 99
    }

    private func sortComparator(_ a: Club, _ b: Club) -> Bool {
        let aVisited = visitedStore.isVisited(a.id)
        let bVisited = visitedStore.isVisited(b.id)

        switch sort {
        case .leagueThenTeam:
            let ra = divisionRank(a.division)
            let rb = divisionRank(b.division)
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
                let ra = divisionRank(a.division)
                let rb = divisionRank(b.division)
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

    var body: some View {
        NavigationStack {
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

                StadiumMapView(
                    clubs: filteredAndSortedClubs,
                    visitedStore: visitedStore,
                    onSelect: { club in
                        selectedClub = club
                    }
                )
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)

                if filteredAndSortedClubs.isEmpty {
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
                    ForEach(filteredAndSortedClubs) { club in
                        NavigationLink {
                            StadiumDetailView(
                                club: club,
                                visitedStore: visitedStore,
                                notesStore: notesStore,
                                clubById: clubByIdMap,
                                fixtures: fixtures
                            )
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(club.name)
                                            .font(.headline)
                                            .lineLimit(2)
                                    }

                                    if visitedStore.isVisited(club.id) || isReviewed(club.id) {
                                        HStack(spacing: 6) {
                                            if visitedStore.isVisited(club.id) {
                                                StatusBadge(text: "Besøgt")
                                            }
                                            if isReviewed(club.id) {
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

                                    if sort == .nearest, let dist = distanceText(for: club) {
                                        Text("Afstand: \(dist)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { visitedStore.isVisited(club.id) },
                                    set: { visitedStore.setVisited(club.id, $0) }
                                ))
                                .labelsHidden()
                                .accessibilityLabel("Markér \(club.name) som besøgt")
                                .accessibilityHint("Skifter besøgt-status for stadionet")
                            }
                            .accessibilityElement(children: .combine)
                            .padding(.vertical, 4)
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
                    Text("Besøgt \(visitedCount) / \(clubs.count)")
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
            locationStore.start()
        }
        .onChange(of: sort) { _, newValue in
            if newValue == .nearest {
                locationStore.requestPermission()
                locationStore.start()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let club = selectedClub {
                StadiumMiniCard(
                    club: club,
                    visited: visitedStore.isVisited(club.id),
                    reviewed: isReviewed(club.id),
                    distance: (sort == .nearest ? distanceText(for: club) : nil),
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
                    notesStore: notesStore,
                    clubById: clubByIdMap,
                    fixtures: fixtures
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

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(club.name)
                            .font(.headline)

                        if visited {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if reviewed {
                            Label("Anmeldt", systemImage: "checkmark.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.green)
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
                    Label("Detaljer", systemImage: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 8)
    }
}

// MARK: - Map

struct StadiumMapView: View {
    let clubs: [Club]
    @ObservedObject var visitedStore: VisitedStore
    let onSelect: (Club) -> Void

    @State private var position: MapCameraPosition = .automatic

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
                        VStack(spacing: 4) {
                            Image(systemName: visitedStore.isVisited(club.id) ? "checkmark.circle.fill" : "mappin.circle.fill")
                                .font(.title2)
                                .foregroundStyle(visitedStore.isVisited(club.id) ? .green : .primary)

                            Text(club.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
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
