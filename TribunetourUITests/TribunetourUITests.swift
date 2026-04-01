import XCTest

final class TribunetourUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSmokeTabsAndPrimaryScreens() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()

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
}
