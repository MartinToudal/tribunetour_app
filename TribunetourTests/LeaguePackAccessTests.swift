import Testing
import Foundation
@testable import Tribunetour

struct LeaguePackAccessTests {
    @Test func loadEnabledClubsExcludesGermanyWhenPackIsDisabled() throws {
        let clubs = try CSVClubImporter.loadEnabledClubsFromBundle(
            csvFileName: "stadiums",
            enabledLeaguePacks: [AppLeaguePackId.coreDenmark.rawValue]
        )

        #expect(clubs.contains(where: { $0.id == "dk-viborg-ff" }))
        #expect(!clubs.contains(where: { $0.id == "de-hamburger-sv" }))
    }

    @Test func loadEnabledClubsIncludesGermanyWhenPackIsEnabled() throws {
        let clubs = try CSVClubImporter.loadEnabledClubsFromBundle(
            csvFileName: "stadiums",
            enabledLeaguePacks: [AppLeaguePackId.coreDenmark.rawValue, AppLeaguePackId.germanyTop3.rawValue]
        )

        #expect(clubs.contains(where: { $0.id == "dk-viborg-ff" }))
        #expect(clubs.contains(where: { $0.id == "de-hamburger-sv" }))
        #expect(clubs.contains(where: { $0.id == "de-heidenheim" }))
    }

    @MainActor
    @Test func remoteFixturesProviderDoesNotMergeLocalGermanyFixturesWhenPackIsDisabled() async throws {
        AppLeaguePackSettings.clearRemoteEnabledLeaguePacks()
        UserDefaults.standard.set(false, forKey: AppLeaguePackSettings.germanyTop3EnabledKey)

        defer {
            AppLeaguePackSettings.clearRemoteEnabledLeaguePacks()
            UserDefaults.standard.removeObject(forKey: AppLeaguePackSettings.germanyTop3EnabledKey)
        }

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
        #expect(result.fixtures.count == 1)
        #expect(result.fixtures.contains(where: { $0.id == "sl-r26-sif-ob" }))
        #expect(!result.fixtures.contains(where: { $0.id == "bl-r29-vfb-hsv" }))
    }

    @MainActor
    @Test func remoteFixturesProviderMergesLocalGermanyFixturesWhenPackIsEnabled() async throws {
        AppLeaguePackSettings.setRemoteEnabledLeaguePacks([AppLeaguePackId.germanyTop3.rawValue])
        UserDefaults.standard.set(false, forKey: AppLeaguePackSettings.germanyTop3EnabledKey)

        defer {
            AppLeaguePackSettings.clearRemoteEnabledLeaguePacks()
            UserDefaults.standard.removeObject(forKey: AppLeaguePackSettings.germanyTop3EnabledKey)
        }

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
