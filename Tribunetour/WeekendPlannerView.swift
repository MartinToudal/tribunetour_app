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
            .sorted { $0.kickoff < $1.kickoff }
    }

    private var selectedFixtures: [Fixture] {
        let ids = planStore.selectedFixtureIds
        return fixtures
            .filter { ids.contains($0.id) }
            .sorted { $0.kickoff < $1.kickoff }
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
                Section(
                    header: Text("Vælg interval"),
                    footer: Text("Vælg startdato – så hopper vi automatisk videre til slutdato. Når du vælger slutdato, lukker vi automatisk.")
                ) {
                    Button {
                        pickerMode = .start
                        showPicker = true
                    } label: {
                        HStack {
                            Label("Interval", systemImage: "calendar")
                            Spacer()
                            Text(intervalText())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        setWeekendFrom(startDate)
                    } label: {
                        Label("Sæt til weekend (fre–søn)", systemImage: "calendar.badge.clock")
                    }
                    .accessibilityIdentifier("weekend-set-range")
                    .accessibilityHint("Sætter intervallet til fredag til søndag")

                    Button(role: .destructive) {
                        planStore.clear()
                    } label: {
                        Label("Ryd plan", systemImage: "trash")
                    }
                    .accessibilityHint("Fjerner alle valgte kampe fra planen")
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
                        Text("Tilføj kampe ved at trykke på dem ovenfor.")
                            .foregroundStyle(.secondary)
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
    }

    private var footerView: some View {
        Group {
            if !selectedFixtures.isEmpty {
                Text("Tip: Kopiér planen og del den i en chat med din makker.")
            }
        }
    }
}
