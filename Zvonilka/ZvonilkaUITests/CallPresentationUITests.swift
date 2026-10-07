import XCTest

final class CallPresentationUITests: XCTestCase {
    @MainActor
    func testRepeatedCancellationKeepsGridAvailableWithoutCover() {
        let app = launch()
        let contact = app.cells["contact-sasha"]
        for _ in 0..<2 {
            XCTAssertTrue(contact.waitForExistence(timeout: 5))
            contact.tap()
            let alert = app.alerts["Подтверждение вызова"]
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["return-to-contacts"].exists)
            alert.buttons["Отмена"].tap()

            XCTAssertFalse(app.buttons["return-to-contacts"].exists)
            XCTAssertTrue(contact.isHittable)
            XCTAssertTrue(contact.label.contains("звонков: 0"))
        }
    }

    @MainActor
    func testCancellationReactivationKeepsGridAvailableWithoutCover() {
        let app = launch(arguments: ["--cancel-reactivates"])
        let contact = app.cells["contact-sasha"]
        XCTAssertTrue(contact.waitForExistence(timeout: 5))
        contact.tap()
        let alert = app.alerts["Подтверждение вызова"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Отмена"].tap()
        XCTAssertFalse(app.buttons["return-to-contacts"].exists)
        XCTAssertTrue(contact.isHittable)
        XCTAssertTrue(contact.label.contains("звонков: 0"))
    }

    @MainActor
    func testGridRemainsAvailableWhenCallEventHasNotArrived() {
        let app = launch(arguments: ["--no-observed-call"])
        let contact = app.cells["contact-sasha"]
        XCTAssertTrue(contact.waitForExistence(timeout: 5))
        contact.tap()
        let alert = app.alerts["Подтверждение вызова"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Позвонить"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 2))
        XCTAssertFalse(app.buttons["return-to-contacts"].exists)
        XCTAssertTrue(contact.isHittable)
        XCTAssertTrue(contact.label.contains("звонков: 0"))
    }

    @MainActor
    func testConfirmedCallUpdatesCountAndOrderBeforeSlowReload() {
        assertConfirmedCall()
    }

    @MainActor
    func testDelayedConfirmationAfterReturnUpdatesCountAndOrder() {
        assertConfirmedCall(arguments: ["--confirm-on-return"])
    }

    @MainActor
    func testConfirmationBeforeBackgroundStillCountsOnlyOnce() {
        assertConfirmedCall(arguments: ["--confirm-before-background"])
    }

    @MainActor
    func testTransientActivationBeforeBackgroundPreservesCallAttempt() {
        assertConfirmedCall(arguments: ["--transient-active"])
    }

    @MainActor
    func testEndedUnansweredCallStillCountsOnce() {
        assertConfirmedCall(arguments: ["--ended-without-connection"])
    }

    @MainActor
    func testCancellationThenConfirmedCallCountsOnlyOnce() {
        let app = launch(arguments: ["--cancel-reactivates", "--confirm-on-return"])
        let contact = app.cells["contact-sasha"]
        XCTAssertTrue(contact.waitForExistence(timeout: 5))
        contact.tap()
        let alert = app.alerts["Подтверждение вызова"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Отмена"].tap()
        XCTAssertFalse(app.buttons["return-to-contacts"].exists)
        XCTAssertTrue(contact.isHittable)
        XCTAssertTrue(contact.label.contains("звонков: 0"))
        confirmCallAndAssertGrid(app)
    }

    @MainActor
    private func assertConfirmedCall(arguments: [String] = []) {
        let app = launch(arguments: arguments)
        XCTAssertTrue(app.cells["contact-anna"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.cells.element(boundBy: 0).identifier, "contact-anna")
        confirmCallAndAssertGrid(app)
    }

    @MainActor
    private func confirmCallAndAssertGrid(_ app: XCUIApplication) {
        let contact = app.cells["contact-sasha"]
        contact.tap()
        let alert = app.alerts["Подтверждение вызова"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["return-to-contacts"].exists)
        alert.buttons["Позвонить"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 2))
        XCTAssertFalse(app.buttons["return-to-contacts"].exists)
        XCTAssertTrue(contact.isHittable)
        let updatedCount = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "звонков: 1"), object: contact)
        XCTAssertEqual(XCTWaiter.wait(for: [updatedCount], timeout: 2), .completed)
        XCTAssertTrue(contact.label.contains("звонков: 1"), contact.label)
        XCTAssertEqual(app.cells.element(boundBy: 0).identifier, "contact-sasha")
        // Медленная загрузка адресной книги не должна откатить новый счётчик.
        let revertsToOldData = NSPredicate { _, _ in
            !contact.label.contains("звонков: 1") || app.cells.element(boundBy: 0).identifier != "contact-sasha"
        }
        let stableGrid = XCTNSPredicateExpectation(predicate: revertsToOldData, object: nil)
        stableGrid.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [stableGrid], timeout: 3), .completed)
    }

    @MainActor
    private func launch(arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-call-flow"] + arguments
        app.launch()
        return app
    }
}
