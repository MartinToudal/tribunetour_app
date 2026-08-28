import Testing
import Foundation
@testable import Tribunetour

struct LeaguePackAccessTests {
    @Test func startupScopeLoadsOnlyDenmark() throws {
        let clubs = try CSVClubImporter.loadEnabledClubsFromBundle(
            csvFileName: "stadiums",
            enabledLeaguePacks: [AppLeaguePackId.coreDenmark.rawValue]
        )

        #expect(clubs.contains(where: { $0.id == "dk-viborg-ff" }))
        #expect(!clubs.contains(where: { $0.id == "de-hamburger-sv" }))
    }

    @Test func selectedCountryScopeLoadsDenmarkAndGermany() throws {
        let clubs = try CSVClubImporter.loadEnabledClubsFromBundle(
            csvFileName: "stadiums",
            enabledLeaguePacks: [AppLeaguePackId.coreDenmark.rawValue, AppLeaguePackId.germanyTop3.rawValue]
        )

        #expect(clubs.contains(where: { $0.id == "dk-viborg-ff" }))
        #expect(clubs.contains(where: { $0.id == "de-hamburger-sv" }))
        #expect(clubs.contains(where: { $0.id == "de-heidenheim" }))
    }

    @Test func selectedCountryScopeLoadsDenmarkAndItaly() throws {
        let clubs = try CSVClubImporter.loadEnabledClubsFromBundle(
            csvFileName: "stadiums",
            enabledLeaguePacks: [AppLeaguePackId.coreDenmark.rawValue, AppLeaguePackId.italyTop3.rawValue]
        )

        #expect(clubs.contains(where: { $0.id == "dk-viborg-ff" }))
        #expect(clubs.contains(where: { $0.id == "it-ssc-napoli" }))
        #expect(clubs.contains(where: { $0.id == "it-palermo" }))
        #expect(clubs.contains(where: { $0.id == "it-triestina" }))
    }

    @Test func countryCatalogIsAvailableWithoutAuthentication() {
        let guestPacks = AppLeaguePackSettings.effectiveEnabledLeaguePacks(isAuthenticated: false)
        let authenticatedPacks = AppLeaguePackSettings.effectiveEnabledLeaguePacks(isAuthenticated: true)

        #expect(guestPacks == authenticatedPacks)
        #expect(guestPacks == AppLeaguePackCatalog.allCountryPackIds)
        #expect(AppLeaguePackCatalog.availableCountryCodes.first == "dk")
        #expect(AppLeaguePackCatalog.availableCountryCodes.contains("de"))
        #expect(Set(AppLeaguePackCatalog.availableCountryCodes).count == AppLeaguePackCatalog.availableCountryCodes.count)
    }

    @MainActor
    @Test func remoteFixturesProviderMergesFallbackWithoutDuplicateIds() async throws {
        let provider = RemoteFixturesProvider(
            remoteURL: URL(string: "https://example.com/fixtures.json"),
            fetchData: { _ in
                Data(
                    """
                    {
                      "fixtures": [
                        {
                          "id": "sl-r26-sif-ob",
                          "kickoff": "2026-04-12T14:00:00+02:00",
                          "round": "Superliga - Spillerunde 26",
                          "homeTeamId": "sif",
                          "awayTeamId": "ob",
                          "venueClubId": "sif",
                          "status": "scheduled"
                        }
                      ]
                    }
                    """.utf8
                )
            },
            localFallback: {
                [
                    Fixture(
                        id: "bl-r29-vfb-hsv",
                        kickoff: ISO8601DateFormatter().date(from: "2026-04-12T15:30:00+02:00")!,
                        round: "Bundesliga - Runde 29",
                        homeTeamId: "de-vfb-stuttgart",
                        awayTeamId: "de-hamburger-sv",
                        venueClubId: "de-vfb-stuttgart",
                        status: .scheduled,
                        homeScore: nil,
                        awayScore: nil
                    )
                ]
            }
        )

        let result = try await provider.loadFixtures()
        #expect(result.fixtures.count == 2)
        #expect(result.fixtures.contains(where: { $0.id == "sl-r26-sif-ob" }))
        #expect(result.fixtures.contains(where: { $0.id == "bl-r29-vfb-hsv" }))
    }
}
