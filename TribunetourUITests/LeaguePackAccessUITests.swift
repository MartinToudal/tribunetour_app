import XCTest

final class LeaguePackAccessUITests: XCTestCase {
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()
        return app
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGermanyCanBeLoadedWithoutAuthentication() throws {
        let app = launchApp(extraArguments: ["--uitesting-country-dk"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let countrySelector = app.buttons["country-selector"]
        XCTAssertTrue(countrySelector.waitForExistence(timeout: 10))
        countrySelector.tap()

        let germany = app.buttons["country-option-de"]
        XCTAssertTrue(germany.waitForExistence(timeout: 5))
        germany.tap()

        let loadedGermany = NSPredicate(
            format: "value MATCHES %@",
            "Tyskland, [1-9][0-9]* stadions"
        )
        expectation(for: loadedGermany, evaluatedWith: countrySelector)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(app.staticTexts["Anmod om adgang"].exists)
    }
}
