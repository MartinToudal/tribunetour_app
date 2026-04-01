//
//  TribunetourTests.swift
//  TribunetourTests
//
//  Created by Martin Toudal on 02/03/2026.
//

import Testing
import Foundation
@testable import Tribunetour

struct TribunetourTests {
    @MainActor
    @Test func stadiumReviewRoundTripEncoding() throws {
        let review = VisitedStore.StadiumReview(
            matchLabel: "FCK - Brøndby",
            scores: [
                .atmosphereSound: 9,
                .facilities: 6
            ],
            categoryNotes: [
                .atmosphereSound: "Fed stemning hele kampen"
            ],
            summary: "God totaloplevelse",
            tags: "derby,fyldt stadion"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(review)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitedStore.StadiumReview.self, from: data)

        #expect(decoded.matchLabel == review.matchLabel)
        #expect(decoded.scores[.atmosphereSound] == 9)
        #expect(decoded.scores[.facilities] == 6)
        #expect(decoded.note(for: .atmosphereSound) == "Fed stemning hele kampen")
        #expect(decoded.summary == "God totaloplevelse")
        #expect(decoded.tags == "derby,fyldt stadion")
    }

    @Test func remoteFixtureDTOMapsToFixture() throws {
        let dto = RemoteFixtureDTO(
            id: "f_1",
            kickoff: "2026-04-20T19:00:00+02:00",
            round: "27. SPILLERUNDE",
            homeTeamId: "fcm",
            awayTeamId: "agf",
            venueClubId: "fcm",
            status: "scheduled",
            homeScore: nil,
            awayScore: nil
        )

        let fixture = try dto.toFixture()
        #expect(fixture.id == "f_1")
        #expect(fixture.round == "27. SPILLERUNDE")
        #expect(fixture.homeTeamId == "fcm")
        #expect(fixture.awayTeamId == "agf")
        #expect(fixture.venueClubId == "fcm")
        #expect(fixture.status == .scheduled)
    }

    @MainActor
    @Test func remoteProviderFallsBackToLocalWhenPayloadIsInvalid() async throws {
        let provider = RemoteFixturesProvider(
            remoteURL: URL(string: "https://example.com/fixtures.json"),
            fetchData: { _ in
                Data("not-json".utf8)
            },
            localFallback: {
                [
                    Fixture(
                        id: "local_1",
                        kickoff: Date(timeIntervalSince1970: 1000),
                        round: "fallback",
                        homeTeamId: "a",
                        awayTeamId: "b",
                        venueClubId: "a",
                        status: .scheduled,
                        homeScore: nil,
                        awayScore: nil
                    )
                ]
            }
        )

        let result = try await provider.loadFixtures()
        #expect(result.source == .localFallback)
        #expect(result.fixtures.count == 1)
        let firstFixtureId = result.fixtures.first?.id
        #expect(firstFixtureId == "local_1")
    }

    @MainActor
    @Test func mergeRecordVisitedUsesOrRule() {
        let local = VisitedStore.Record(visited: false, updatedAt: Date(timeIntervalSince1970: 10))
        let remote = VisitedStore.Record(visited: true, updatedAt: Date(timeIntervalSince1970: 20))
        let merged = AppVisitedMergePolicy.appPrimaryDuringMigration.merge(local: local, remote: remote)
        #expect(merged.visited == true)
    }

    @MainActor
    @Test func mergeRecordVisitedDateUsesEarliestDate() {
        let localDate = Date(timeIntervalSince1970: 200)
        let remoteDate = Date(timeIntervalSince1970: 100)
        let local = VisitedStore.Record(visited: true, visitedDate: localDate, updatedAt: Date(timeIntervalSince1970: 10))
        let remote = VisitedStore.Record(visited: true, visitedDate: remoteDate, updatedAt: Date(timeIntervalSince1970: 20))
        let merged = AppVisitedMergePolicy.appPrimaryDuringMigration.merge(local: local, remote: remote)
        #expect(merged.visitedDate == remoteDate)
    }

    @MainActor
    @Test func mergeRecordNotesUsesNewestRecordTimestamp() {
        let local = VisitedStore.Record(visited: true, notes: "local note", updatedAt: Date(timeIntervalSince1970: 10))
        let remote = VisitedStore.Record(visited: true, notes: "remote note", updatedAt: Date(timeIntervalSince1970: 20))
        let merged = AppVisitedMergePolicy.appPrimaryDuringMigration.merge(local: local, remote: remote)
        #expect(merged.notes == "remote note")
    }

    @MainActor
    @Test func mergeRecordReviewUsesNewestReviewTimestamp() {
        let oldReview = VisitedStore.StadiumReview(summary: "old", updatedAt: Date(timeIntervalSince1970: 50))
        let newReview = VisitedStore.StadiumReview(summary: "new", updatedAt: Date(timeIntervalSince1970: 100))
        let local = VisitedStore.Record(visited: true, review: oldReview, updatedAt: Date(timeIntervalSince1970: 10))
        let remote = VisitedStore.Record(visited: true, review: newReview, updatedAt: Date(timeIntervalSince1970: 20))
        let merged = AppVisitedMergePolicy.appPrimaryDuringMigration.merge(local: local, remote: remote)
        #expect(merged.review?.summary == "new")
    }

    @MainActor
    @Test func mergeRecordPhotosUseUnionAndNewestMetadata() {
        let localMeta = VisitedStore.Record.PhotoMeta(caption: "old caption", createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 10))
        let remoteMeta = VisitedStore.Record.PhotoMeta(caption: "new caption", createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 20))

        let local = VisitedStore.Record(
            visited: true,
            photoFileNames: ["a.jpg"],
            photoMetadata: ["a.jpg": localMeta],
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let remote = VisitedStore.Record(
            visited: true,
            photoFileNames: ["a.jpg", "b.jpg"],
            photoMetadata: ["a.jpg": remoteMeta, "b.jpg": VisitedStore.Record.PhotoMeta(caption: "b", createdAt: Date(timeIntervalSince1970: 2), updatedAt: Date(timeIntervalSince1970: 30))],
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let merged = AppVisitedMergePolicy.appPrimaryDuringMigration.merge(local: local, remote: remote)
        #expect(Set(merged.photoFileNames) == Set(["a.jpg", "b.jpg"]))
        #expect(merged.photoMetadata["a.jpg"]?.caption == "new caption")
        #expect(merged.photoMetadata["b.jpg"] != nil)
    }

    @Test func weekendWindowStartsFridayAndEndsMondayInCopenhagen() throws {
        let tz = try #require(TimeZone(identifier: "Europe/Copenhagen"))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let monday = try #require(formatter.date(from: "2026-03-23T10:00:00+01:00"))
        let window = try #require(WeekendOpportunityNotifier.upcomingWeekendWindow(from: monday, timeZone: tz))

        let calendar = WeekendOpportunityNotifier.calendar(for: tz)
        let startComponents = calendar.dateComponents([.weekday, .hour, .minute], from: window.start)
        let endComponents = calendar.dateComponents([.weekday, .hour, .minute], from: window.end)
        #expect(startComponents.weekday == 6) // fredag
        #expect(startComponents.hour == 0)
        #expect(startComponents.minute == 0)
        #expect(endComponents.weekday == 2) // mandag
        #expect(endComponents.hour == 0)
        #expect(endComponents.minute == 0)
    }

    @Test func midweekWindowStartsTuesdayAndEndsFridayInCopenhagen() throws {
        let tz = try #require(TimeZone(identifier: "Europe/Copenhagen"))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let monday = try #require(formatter.date(from: "2026-03-23T10:00:00+01:00"))
        let window = try #require(WeekendOpportunityNotifier.upcomingMidweekWindow(from: monday, timeZone: tz))

        let calendar = WeekendOpportunityNotifier.calendar(for: tz)
        let startComponents = calendar.dateComponents([.weekday, .hour, .minute], from: window.start)
        let endComponents = calendar.dateComponents([.weekday, .hour, .minute], from: window.end)
        #expect(startComponents.weekday == 3) // tirsdag
        #expect(startComponents.hour == 0)
        #expect(startComponents.minute == 0)
        #expect(endComponents.weekday == 6) // fredag
        #expect(endComponents.hour == 0)
        #expect(endComponents.minute == 0)
    }

    @Test func countUnvisitedVenuesCountsUniqueScheduledInWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plusOneHour = now.addingTimeInterval(3600)
        let plusTwoHours = now.addingTimeInterval(7200)
        let plusThreeHours = now.addingTimeInterval(10_800)
        let tomorrow = now.addingTimeInterval(24 * 3600)

        let fixtures = [
            Fixture(id: "a", kickoff: plusOneHour, round: nil, homeTeamId: "h1", awayTeamId: "a1", venueClubId: "fcm", status: .scheduled, homeScore: nil, awayScore: nil),
            Fixture(id: "b", kickoff: plusTwoHours, round: nil, homeTeamId: "h2", awayTeamId: "a2", venueClubId: "fcm", status: .scheduled, homeScore: nil, awayScore: nil),
            Fixture(id: "c", kickoff: plusThreeHours, round: nil, homeTeamId: "h3", awayTeamId: "a3", venueClubId: "agf", status: .cancelled, homeScore: nil, awayScore: nil),
            Fixture(id: "d", kickoff: tomorrow, round: nil, homeTeamId: "h4", awayTeamId: "a4", venueClubId: "ob", status: .scheduled, homeScore: nil, awayScore: nil)
        ]

        let count = WeekendOpportunityNotifier.countUnvisitedVenues(
            fixtures: fixtures,
            visitedVenueClubIds: ["ob"],
            start: now,
            end: now.addingTimeInterval(12 * 3600)
        )
        #expect(count == 1) // kun "fcm" tælles (unik + scheduled + i vinduet + ikke besøgt)
    }
}
