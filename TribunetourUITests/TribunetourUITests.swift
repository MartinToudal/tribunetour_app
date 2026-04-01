import XCTest

final class TribunetourUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
        return app
    }

    private func waitForElementValueChange(
        for element: XCUIElement,
        from initialValue: String,
        timeout: TimeInterval = 10
    ) -> String {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let refreshedValue = (element.value as? String) ?? ""
            if refreshedValue != initialValue {
                return refreshedValue
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTFail("Expected switch value to change from \(initialValue)")
        return initialValue
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSmokeTabsAndPrimaryScreens() throws {
        let app = launchApp()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        let stadiumsTab = tabBar.buttons["Stadions"]
        let matchesTab = tabBar.buttons["Kampe"]
        let planTab = tabBar.buttons["Plan"]
        let myTripTab = tabBar.buttons["Min tur"]

        XCTAssertTrue(stadiumsTab.exists)
        XCTAssertTrue(matchesTab.exists)
        XCTAssertTrue(planTab.exists)
        XCTAssertTrue(myTripTab.exists)

        XCTAssertTrue(app.navigationBars["Stadions"].waitForExistence(timeout: 10))

        matchesTab.tap()
        XCTAssertTrue(app.navigationBars["Kampe"].waitForExistence(timeout: 10))

        planTab.tap()
        XCTAssertTrue(app.navigationBars["Plan"].waitForExistence(timeout: 10))

        myTripTab.tap()
        XCTAssertTrue(app.navigationBars["Min tur"].waitForExistence(timeout: 10))

        stadiumsTab.tap()
        XCTAssertTrue(app.navigationBars["Stadions"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testCanToggleVisitedAndRestoreOriginalValue() throws {
        let app = launchApp()

        let visitedToggle = app.switches.matching(identifier: "stadium-toggle-agf").element(boundBy: 1)
        XCTAssertTrue(visitedToggle.waitForExistence(timeout: 10))

        let initialValue = (visitedToggle.value as? String) ?? ""
        visitedToggle.tap()
        let toggledValue = waitForElementValueChange(for: visitedToggle, from: initialValue)

        app.switches.matching(identifier: "stadium-toggle-agf").element(boundBy: 1).tap()
        let restoredValue = waitForElementValueChange(for: visitedToggle, from: toggledValue)

        XCTAssertEqual(restoredValue, initialValue)
    }

    @MainActor
    func testCanAddAndRemoveFixtureFromWeekendPlan() throws {
        let app = launchApp()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        tabBar.buttons["Plan"].tap()

        let weekendButton = app.descendants(matching: .any)["weekend-set-range"]
        XCTAssertTrue(weekendButton.waitForExistence(timeout: 10))
        weekendButton.tap()

        let fixtureButton = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "weekend-fixture-"))
            .firstMatch
        XCTAssertTrue(fixtureButton.waitForExistence(timeout: 10))

        let initialSelectionValue = (fixtureButton.value as? String) ?? ""
        fixtureButton.tap()
        let selectedValue = waitForElementValueChange(for: fixtureButton, from: initialSelectionValue)
        XCTAssertEqual(selectedValue, "valgt")

        fixtureButton.tap()
        let restoredValue = waitForElementValueChange(for: fixtureButton, from: selectedValue)
        XCTAssertEqual(restoredValue, initialSelectionValue)
    }
}
