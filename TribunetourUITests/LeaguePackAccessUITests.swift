import XCTest

final class LeaguePackAccessUITests: XCTestCase {
    private let germanyMatchRowId = "match-row-b2-r29-scp-fcm"
    private let matchesSearchPlaceholder = "Søg klub, stadion, by, runde…"

    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func revealElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 8
    ) {
        for _ in 0..<maxSwipes where !(element.exists && element.isHittable) {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGermanyPackEnabledShowsGermanContentAcrossTabs() throws {
        let app = launchApp(extraArguments: ["--uitesting-enable-germany", "--uitesting-country-de", "--uitesting-plan-weekend"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        tabBar.buttons["Kampe"].tap()
        XCTAssertTrue(app.searchFields[matchesSearchPlaceholder].waitForExistence(timeout: 10))
        XCTAssertTrue(element(germanyMatchRowId, in: app).waitForExistence(timeout: 10))

        app.tabBars.firstMatch.buttons["Plan"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(element("weekend-planner-root", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(element("weekend-set-range", in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testGermanyPackDisabledHidesGermanContentAcrossTabs() throws {
        let app = launchApp(extraArguments: ["--uitesting-disable-germany", "--uitesting-country-de", "--uitesting-plan-weekend"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        let tabBar = app.tabBars.firstMatch

        tabBar.buttons["Kampe"].tap()
        XCTAssertTrue(app.searchFields[matchesSearchPlaceholder].waitForExistence(timeout: 10))
        XCTAssertFalse(element(germanyMatchRowId, in: app).waitForExistence(timeout: 2))

        app.tabBars.firstMatch.buttons["Plan"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(element("weekend-planner-root", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(element("weekend-set-range", in: app).waitForExistence(timeout: 10))
    }
}
