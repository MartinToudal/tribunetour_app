import SwiftUI

struct WeekendPlannerView: View {
    let clubs: [Club]
    let fixtures: [Fixture]
    @ObservedObject var visitedStore: VisitedStore
    @ObservedObject var planStore: AppWeekendPlanStore
    private let matchTimeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
    private var matchCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = matchTimeZone
        return cal
    }

    @State private var startDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
        return cal.startOfDay(for: Date())
    }()
    @State private var endDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current
        let start = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: 2, to: start) ?? start
    }()

    @State private var showPicker = false
    @State private var pickerMode: PickerMode = .start
    @AppStorage("stadiums.countryFilter") private var countryFilterRawValue: String = "all"
    private let isUITestingWeekendDefault = ProcessInfo.processInfo.arguments.contains("--uitesting-plan-weekend")

    private var clubById: [String: Club] {
        ClubIdentityResolver.aliasMap(
            from: Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
        )
    }

    enum PickerMode {
        case start
        case end
    }

    // MARK: - Helpers

    private var range: (start: Date, endExclusive: Date) {
        let cal = matchCalendar
        let start = cal.startOfDay(for: startDate)
        let end = cal.startOfDay(for: endDate)
        let endExclusive = cal.date(byAdding: .day, value: 1, to: end) ?? end
        return (start: start, endExclusive: endExclusive)
    }

    private var fixturesInRange: [Fixture] {
        fixtures
            .filter { $0.kickoff >= range.start && $0.kickoff < range.endExclusive }
            .filter { fixtureMatchesSelectedCountry($0) }
            .sorted { $0.kickoff < $1.kickoff }
    }

    private var selectedFixtures: [Fixture] {
        let ids = planStore.selectedFixtureIds
        return fixtures
            .filter { ids.contains($0.id) }
            .filter { fixtureMatchesSelectedCountry($0) }
            .sorted { $0.kickoff < $1.kickoff }
    }

    private func fixtureMatchesSelectedCountry(_ fixture: Fixture) -> Bool {
        guard countryFilterRawValue != "all" else { return true }
        return clubById[fixture.venueClubId]?.countryCode == countryFilterRawValue
    }

    private func clubName(_ id: String) -> String {
        clubById[id]?.name ?? id
    }

    private func stadiumLine(for fixture: Fixture) -> String {
        if let club = clubById[fixture.venueClubId] {
            return club.stadium.name
        }
        return "Ukendt stadion"
    }

    private func dayTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.timeZone = matchTimeZone
        df.dateFormat = "EEEE d. MMMM"
        return df.string(from: date).capitalized
    }

    private func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.timeZone = matchTimeZone
        df.dateFormat = "d/M"
        return df.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.timeZone = matchTimeZone
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }

    private func intervalText() -> String {
        "\(shortDate(startDate)) – \(shortDate(endDate))"
    }

    private var planSummaryText: String {
        let count = selectedFixtures.count
        let noun = count == 1 ? "kamp" : "kampe"
        return "\(count) \(noun) valgt i perioden \(intervalText())"
    }

    private var recommendedFixture: Fixture? {
        fixturesInRange.sorted { lhs, rhs in
            let lhsVisited = visitedStore.isVisited(lhs.venueClubId)
            let rhsVisited = visitedStore.isVisited(rhs.venueClubId)
            if lhsVisited != rhsVisited {
                return !lhsVisited && rhsVisited
            }
            let lhsSelected = planStore.contains(lhs.id)
            let rhsSelected = planStore.contains(rhs.id)
            if lhsSelected != rhsSelected {
                return !lhsSelected && rhsSelected
            }
            return lhs.kickoff < rhs.kickoff
        }.first
    }

    private var suggestedFixtures: [Fixture] {
        let recommendedId = recommendedFixture?.id
        return fixturesInRange.filter { $0.id != recommendedId }.prefix(3).map { $0 }
    }

    private func recommendationReasons(for fixture: Fixture) -> [String] {
        var reasons: [String] = []
        if !visitedStore.isVisited(fixture.venueClubId) {
            reasons.append("nyt stadion")
        }
        if matchCalendar.isDateInToday(fixture.kickoff) {
            reasons.append("i dag")
        } else if matchCalendar.isDate(fixture.kickoff, inSameDayAs: startDate) {
            reasons.append("tidligt i perioden")
        }
        if planStore.contains(fixture.id) {
            reasons.append("allerede i din plan")
        }
        if let division = clubById[fixture.venueClubId]?.division, !division.isEmpty {
            reasons.append(division)
        }
        return Array(reasons.prefix(2))
    }

    private func copyPlanText() {
        let df = DateFormatter()
        df.locale = Locale(identifier: "da_DK")
        df.timeZone = matchTimeZone
        df.dateFormat = "EEE d/M HH:mm"

        let lines = selectedFixtures.map { f in
            let home = clubName(f.homeTeamId)
            let away = clubName(f.awayTeamId)
            let t = df.string(from: f.kickoff)
            let venue = stadiumLine(for: f)
            return "\(t) • \(home) – \(away) • \(venue)"
        }

        let header = "Min tur (\(dayTitle(startDate)) → \(dayTitle(endDate)))"
        UIPasteboard.general.string = ([header, ""] + lines).joined(separator: "\n")
    }

    private func setWeekendFrom(_ anchor: Date) {
        let cal = matchCalendar
        let startOfDay = cal.startOfDay(for: anchor)

        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
        let weekAnchor = cal.date(from: comps) ?? startOfDay

        let friday = 6 // 1=Sun ... 6=Fri
        var fridayDate = weekAnchor
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i, to: weekAnchor) ?? weekAnchor
            if cal.component(.weekday, from: d) == friday {
                fridayDate = d
                break
            }
        }

        startDate = fridayDate
        endDate = cal.date(byAdding: .day, value: 2, to: fridayDate) ?? fridayDate
    }

    // MARK: - UI

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Planlæg næste stadiontur")
                            .font(.headline)
                        Text(selectedFixtures.isEmpty ? "Vælg et interval og få forslag til din næste tur." : planSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Button {
                                pickerMode = .start
                                showPicker = true
                            } label: {
                                Label(intervalText(), systemImage: "calendar")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                setWeekendFrom(startDate)
                            } label: {
                                Label("Weekend", systemImage: "calendar.badge.clock")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let recommendedFixture {
                    Section("Bedste mulighed lige nu") {
                        VStack(alignment: .leading, spacing: 10) {
                            MatchRecommendationCard(
                                fixture: recommendedFixture,
                                title: "\(clubName(recommendedFixture.homeTeamId)) – \(clubName(recommendedFixture.awayTeamId))",
                                subtitle: "\(dayTitle(recommendedFixture.kickoff)) • \(timeString(recommendedFixture.kickoff))",
                                detail: stadiumLine(for: recommendedFixture),
                                reasons: recommendationReasons(for: recommendedFixture),
                                isSelected: planStore.contains(recommendedFixture.id)
                            )

                            Button {
                                planStore.toggle(recommendedFixture.id)
                            } label: {
                                PlanActionButtonLabel(
                                    title: planStore.contains(recommendedFixture.id) ? "Fjern fra plan" : "Tilføj til plan",
                                    systemImage: planStore.contains(recommendedFixture.id) ? "checkmark.circle.fill" : "plus.circle.fill",
                                    isSelected: planStore.contains(recommendedFixture.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !suggestedFixtures.isEmpty {
                    Section("Gode muligheder") {
                        ForEach(suggestedFixtures) { fixture in
                            Button {
                                planStore.toggle(fixture.id)
                            } label: {
                                MatchRecommendationCard(
                                    fixture: fixture,
                                    title: "\(clubName(fixture.homeTeamId)) – \(clubName(fixture.awayTeamId))",
                                    subtitle: "\(dayTitle(fixture.kickoff)) • \(timeString(fixture.kickoff))",
                                    detail: stadiumLine(for: fixture),
                                    reasons: recommendationReasons(for: fixture),
                                    isSelected: planStore.contains(fixture.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("weekend-fixture-\(fixture.id)")
                            .accessibilityValue(planStore.contains(fixture.id) ? "valgt" : "ikke valgt")
                        }
                    }
                }

                if fixturesInRange.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Ingen kampe i intervallet",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Prøv at vælge et andet interval.")
                        )
                        .padding(.vertical, 8)
                    }
                } else {
                    let grouped = Dictionary(grouping: fixturesInRange) { matchCalendar.startOfDay(for: $0.kickoff) }
                    let days = grouped.keys.sorted()

                    Section(
                        header: Text("Alle muligheder"),
                        footer: Text("Vælg startdato – så hopper vi automatisk videre til slutdato. Når du vælger slutdato, lukker vi automatisk.")
                    ) {
                        Button(role: .destructive) {
                            planStore.clear()
                        } label: {
                            Label("Ryd plan", systemImage: "trash")
                        }
                        .accessibilityHint("Fjerner alle valgte kampe fra planen")
                    }

                    ForEach(days, id: \.self) { day in
                        Section(header: Text(dayTitle(day))) {
                            ForEach(grouped[day] ?? []) { f in
                                Button {
                                    planStore.toggle(f.id)
                                } label: {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text("\(clubName(f.homeTeamId)) – \(clubName(f.awayTeamId))")
                                                    .font(.headline)
                                                Spacer()
                                                Text(timeString(f.kickoff))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Text(stadiumLine(for: f))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: planStore.contains(f.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(planStore.contains(f.id) ? .green : .secondary)
                                            .font(.title3)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("weekend-fixture-\(f.id)")
                                .accessibilityLabel("\(clubName(f.homeTeamId)) mod \(clubName(f.awayTeamId)), \(timeString(f.kickoff))")
                                .accessibilityValue(planStore.contains(f.id) ? "valgt" : "ikke valgt")
                                .accessibilityHint(planStore.contains(f.id) ? "Fjern kampen fra planen" : "Tilføj kampen til planen")
                            }
                        }
                    }
                }

                Section(header: Text("Min tur"), footer: footerView) {
                    if selectedFixtures.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Du har ikke valgt nogen kampe endnu.")
                                .font(.subheadline.weight(.semibold))
                            Text("Brug anbefalingen ovenfor eller tryk på en kamp i listen for at bygge din tur.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(selectedFixtures) { f in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(clubName(f.homeTeamId)) – \(clubName(f.awayTeamId))")
                                        .font(.headline)
                                    Text("\(dayTitle(f.kickoff)) • \(timeString(f.kickoff))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(stadiumLine(for: f))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    planStore.remove(f.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("weekend-remove-\(f.id)")
                                .accessibilityLabel("Fjern kamp fra plan")
                                .accessibilityHint("Fjerner den valgte kamp")
                            }
                            .padding(.vertical, 4)
                        }

                        Button {
                            copyPlanText()
                        } label: {
                            Label("Kopiér plan", systemImage: "doc.on.doc")
                        }
                        .accessibilityHint("Kopierer planen til udklipsholderen")
                    }
                }
            }
            .accessibilityIdentifier("weekend-planner-root")
            .navigationTitle("Plan")
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text(pickerMode == .start ? "Vælg startdato" : "Vælg slutdato")
                        .font(.headline)
                        .padding(.horizontal)

                    if pickerMode == .start {
                        DatePicker(
                            "Start",
                            selection: Binding(
                                get: { startDate },
                                set: { newValue in
                                    let d = matchCalendar.startOfDay(for: newValue)
                                    startDate = d
                                    if endDate < d { endDate = d }

                                    // Auto-hop til slutdato uden “Færdig”
                                    DispatchQueue.main.async {
                                        pickerMode = .end
                                    }
                                }
                            ),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal)
                    } else {
                        DatePicker(
                            "Slut",
                            selection: Binding(
                                get: { endDate },
                                set: { newValue in
                                    let d = matchCalendar.startOfDay(for: newValue)
                                    endDate = max(d, startDate)

                                    // Auto-luk når slutdato vælges
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        showPicker = false
                                    }
                                }
                            ),
                            in: startDate...,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal)
                    }

                    Text("Valgt: \(intervalText())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Spacer()
                }
                .navigationTitle("Interval")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if pickerMode == .end {
                            Button("Tilbage") { pickerMode = .start }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Luk") { showPicker = false }
                    }
                }
            }
        }
        .onAppear {
            let availableCountryCodes = Set(clubs.map(\.countryCode))
            if !availableCountryCodes.contains(countryFilterRawValue) {
                countryFilterRawValue = LeaguePresentation.resolvedHomeCountryCode(availableCountryCodes: availableCountryCodes)
            }
            if isUITestingWeekendDefault {
                setWeekendFrom(Date())
            }
        }
    }

    private var footerView: some View {
        Group {
            if !selectedFixtures.isEmpty {
                Text("Tip: Kopiér planen og del den i en chat med din makker.")
            }
        }
    }
}

private struct MatchRecommendationCard: View {
    let fixture: Fixture
    let title: String
    let subtitle: String
    let detail: String
    let reasons: [String]
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .font(.title3)
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !reasons.isEmpty {
                HStack(spacing: 6) {
                    ForEach(reasons, id: \.self) { reason in
                        Text(reason)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PlanActionButtonLabel: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.green.opacity(0.22) : Color.green.opacity(0.14)
        }
        return colorScheme == .dark ? Color.white : Color.black
    }

    private var foregroundColor: Color {
        if isSelected {
            return .green
        }
        return colorScheme == .dark ? .black : .white
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
