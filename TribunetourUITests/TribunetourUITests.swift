import XCTest

final class TribunetourUITests: XCTestCase {
    private func elementStringValue(_ element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty {
            return value
        }
        return element.label
    }

    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchArguments.append(contentsOf: extraArguments)
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
            let refreshedValue = elementStringValue(element)
            if refreshedValue != initialValue {
                return refreshedValue
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTFail("Expected switch value to change from \(initialValue)")
        return initialValue
    }

    private func clearTrailingText(_ text: String, in element: XCUIElement) {
        guard !text.isEmpty else { return }
        element.tap()
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
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

    private func openStadiumDetail(for clubId: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)["stadium-row-\(clubId)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["Stadion"].waitForExistence(timeout: 10))
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

        let initialValue = elementStringValue(visitedToggle)
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

        let initialSelectionValue = elementStringValue(fixtureButton)
        fixtureButton.tap()
        let selectedValue = waitForElementValueChange(for: fixtureButton, from: initialSelectionValue)
        XCTAssertEqual(selectedValue, "valgt")

        fixtureButton.tap()
        let restoredValue = waitForElementValueChange(for: fixtureButton, from: selectedValue)
        XCTAssertEqual(restoredValue, initialSelectionValue)
    }

    @MainActor
    func testCanEditNoteAndRestoreOriginalValue() throws {
        let app = launchApp()
        openStadiumDetail(for: "agf", in: app)

        let noteField = app.textFields["stadium-note-field"]
        revealElement(noteField, in: app)
        XCTAssertTrue(noteField.waitForExistence(timeout: 10))

        let marker = " UITESTNOTE"
        noteField.tap()
        noteField.typeText(marker)
        let updatedValue = elementStringValue(noteField)
        XCTAssertTrue(updatedValue.contains("UITESTNOTE"))

        clearTrailingText(marker, in: noteField)
        let restoredValue = elementStringValue(noteField)
        XCTAssertFalse(restoredValue.contains("UITESTNOTE"))
    }

    @MainActor
    func testCanEditReviewAndRestoreOriginalValue() throws {
        let app = launchApp(extraArguments: ["--uitesting-reset-review-agf"])
        openStadiumDetail(for: "agf", in: app)

        let matchField = app.textFields["review-match-field"]
        revealElement(matchField, in: app)
        XCTAssertTrue(matchField.waitForExistence(timeout: 10))
        matchField.tap()
        matchField.typeText("UITEST MATCH")

        let summaryField = app.textFields["review-summary-field"]
        revealElement(summaryField, in: app)
        XCTAssertTrue(summaryField.waitForExistence(timeout: 10))

        let marker = "UITESTSUMMARY"
        summaryField.tap()
        summaryField.typeText(marker)
        let updatedSummary = elementStringValue(summaryField)
        XCTAssertTrue(updatedSummary.contains("UITESTSUMMARY"))

        let tagsField = app.textFields["review-tags-field"]
        revealElement(tagsField, in: app)
        XCTAssertTrue(tagsField.waitForExistence(timeout: 10))
        tagsField.tap()
        tagsField.typeText("tag1,tag2")

        let clearButton = app.buttons["review-clear-button"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 10))
        XCTAssertTrue(clearButton.isEnabled)
        clearButton.tap()

        XCTAssertFalse(clearButton.isEnabled)
    }

    @MainActor
    func testCanEditPhotoCaptionAndDeleteSeededPhoto() throws {
        let app = launchApp(extraArguments: ["--uitesting-seed-photo-agf"])
        openStadiumDetail(for: "agf", in: app)

        let photoThumb = app.buttons["photo-thumb-uitest_agf_photo.jpg"]
        revealElement(photoThumb, in: app)
        XCTAssertTrue(photoThumb.waitForExistence(timeout: 10))
        photoThumb.tap()

        let captionField = app.textFields["photo-caption-field"]
        XCTAssertTrue(captionField.waitForExistence(timeout: 10))
        captionField.tap()
        let caption = "UITEST CAPTION"
        captionField.typeText(caption)

        let saveButton = app.buttons["photo-caption-save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10))
        saveButton.tap()

        let closeButton = app.buttons["photo-fullscreen-close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 10))
        closeButton.tap()

        let captionPreview = app.staticTexts[caption]
        revealElement(captionPreview, in: app)
        XCTAssertTrue(captionPreview.waitForExistence(timeout: 10))

        let deleteButton = app.buttons["photo-delete-uitest_agf_photo.jpg"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        deleteButton.tap()

        let destructiveDelete = app.buttons["Slet billede"]
        XCTAssertTrue(destructiveDelete.waitForExistence(timeout: 10))
        destructiveDelete.tap()

        XCTAssertFalse(photoThumb.waitForExistence(timeout: 5))
    }
}
