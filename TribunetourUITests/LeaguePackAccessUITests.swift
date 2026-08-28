import XCTest

final class LeaguePackAccessUITests: XCTestCase {
    private let hamburgerSVRowId = "stadium-row-de-hamburger-sv"

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
    func testGermanyCanBeLoadedWithoutAuthentication() throws {
        let app = launchApp(extraArguments: ["--uitesting-country-de"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("Hamburger")
        XCTAssertTrue(element(hamburgerSVRowId, in: app).waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Anmod om adgang"].exists)
    }
}
