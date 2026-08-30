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

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func assertHorizontallyContained(
        _ element: XCUIElement,
        in window: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), file: file, line: line)

        let elementFrame = element.frame
        let windowFrame = window.frame
        XCTAssertGreaterThan(elementFrame.width, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(elementFrame.minX, windowFrame.minX - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(elementFrame.maxX, windowFrame.maxX + 1, file: file, line: line)
    }

    @MainActor
    func testStadiumOverviewFitsPortraitWidth() throws {
        let app = launchApp(extraArguments: ["--uitesting-country-dk"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        assertHorizontallyContained(element("stadium-scope-summary", in: app), in: window)
        let countrySelector = app.buttons["country-selector"]
        assertHorizontallyContained(countrySelector, in: window)
        assertHorizontallyContained(app.buttons["stadium-fullscreen-map"], in: window)
        assertHorizontallyContained(element("stadium-map-preview", in: app), in: window)
    }

    @MainActor
    func testGermanyCanBeLoadedWithoutAuthentication() throws {
        let app = launchApp(extraArguments: ["--uitesting-country-dk"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let countrySelector = app.buttons["country-selector"]
        XCTAssertTrue(countrySelector.waitForExistence(timeout: 10))

        countrySelector.tap()

        let germany = app.buttons["country-option-de"]
        XCTAssertTrue(germany.waitForExistence(timeout: 10))
        germany.tap()

        let loadedGermany = NSPredicate(
            format: "value MATCHES %@",
            "Tyskland, [1-9][0-9]* stadions"
        )
        expectation(for: loadedGermany, evaluatedWith: countrySelector)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(app.staticTexts["Anmod om adgang"].exists)
    }

    @MainActor
    func testMatchesAreExplicitlyScopedToDenmark() throws {
        let app = launchApp(extraArguments: ["--uitesting-country-de"])

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["Kampe"].tap()

        let countryScope = element("matches-country-scope", in: app)
        XCTAssertTrue(countryScope.waitForExistence(timeout: 10))
        XCTAssertEqual(countryScope.label, "Danmark")

        app.buttons["Åbn filtre"].tap()
        XCTAssertTrue(app.navigationBars["Filtre"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Alle aktive lande"].exists)
        XCTAssertFalse(app.staticTexts["Land"].exists)
    }
}
