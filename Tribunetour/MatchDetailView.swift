import SwiftUI
import MapKit
import CoreLocation

struct MatchDetailView: View {
    let fixture: Fixture
    let clubById: [String: Club]
    let fixtures: [Fixture]
    @ObservedObject var visitedStore: VisitedStore
    @ObservedObject var notesStore: AppNotesStore

    init(
        fixture: Fixture,
        clubById: [String: Club],
        visitedStore: VisitedStore,
        notesStore: AppNotesStore,
        fixtures: [Fixture] = []
    ) {
        self.fixture = fixture
        self.clubById = clubById
        self.visitedStore = visitedStore
        self.notesStore = notesStore
        self.fixtures = fixtures
    }
    private let matchTimeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current

    private var homeClub: Club? { clubById[fixture.homeTeamId] }
    private var awayClub: Club? { clubById[fixture.awayTeamId] }
    private var venueClub: Club? { clubById[fixture.venueClubId] }
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
        List {
            Section {
                VStack(spacing: 8) {
                    Text(homeClub?.name ?? fixture.homeTeamId)
                        .font(.title2)
                        .bold()

                    Text("mod")
                        .foregroundStyle(.secondary)

                    Text(awayClub?.name ?? fixture.awayTeamId)
                        .font(.title2)
                        .bold()
                }
                .accessibilityElement(children: .combine)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section {
                LabeledContent("Dato") { Text(kickoffDateText) }
                LabeledContent("Tid") { Text(kickoffTimeText) }

                if let round = fixture.round, !round.isEmpty {
                    LabeledContent("Række / runde") { Text(round) }
                }
            }

            if let venueClub {
                Section("Stadion") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(venueClub.stadium.name)
                            .font(.headline)

                        Text(venueClub.stadium.city)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    // ✅ Hurtig handling: markér besøgt direkte her
                    Toggle("Markér som besøgt", isOn: Binding(
                        get: { visitedStore.isVisited(venueClub.id) },
                        set: { visitedStore.setVisited(venueClub.id, $0) }
                    ))
                    .accessibilityHint("Skifter besøgt-status for stadionet")

                    NavigationLink {
                        StadiumDetailView(
                            club: venueClub,
                            visitedStore: visitedStore,
                            notesStore: notesStore,
                            clubById: clubById,
                            fixtures: fixtures
                        )
                    } label: {
                        Label("Åbn stadion-detaljer", systemImage: "info.circle")
                    }
                    .accessibilityHint("Vis flere oplysninger om stadionet")

                    Button {
                        openInMaps(club: venueClub)
                    } label: {
                        Label("Åbn i Apple Maps", systemImage: "map")
                    }
                    .accessibilityHint("Åbner rutevejledning til stadionet")
                }
            } else {
                Section("Stadion") {
                    Text("Ukendt stadion/hold-id: \(fixture.venueClubId)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Kamp")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openInMaps(club: Club) {
        let location = CLLocation(
            latitude: club.stadium.latitude,
            longitude: club.stadium.longitude
        )

        let item = MKMapItem(location: location, address: nil)
        item.name = "\(club.stadium.name) – \(club.name)"
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
