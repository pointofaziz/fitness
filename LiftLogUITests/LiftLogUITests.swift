import XCTest

final class LiftLogUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + (reset ? ["--reset-test-store"] : [])
        app.launch(); return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    func testFirstWorkoutCompletedSetSurvivesRelaunch() {
        let app = launch()
        XCTAssertTrue(app.buttons["startWorkout"].waitForExistence(timeout: 10))
        reveal(app.buttons["startWorkout"], in: app); app.buttons["startWorkout"].tap()
        reveal(app.buttons["set-0"], in: app); app.buttons["set-0"].tap()
        XCTAssertTrue(app.textFields["repsInput"].waitForExistence(timeout: 5))
        app.textFields["repsInput"].tap(); app.textFields["repsInput"].typeText("8")
        app.textFields["rirInput"].tap(); app.textFields["rirInput"].typeText("3")
        XCTAssertTrue(app.buttons["saveSet"].isHittable, "Primary save must be reachable above the keyboard")
        app.buttons["saveSet"].tap()
        app.terminate()
        let reopened = launch(reset: false)
        XCTAssertTrue(reopened.buttons["resumeWorkout"].waitForExistence(timeout: 10))
        reopened.buttons["resumeWorkout"].tap()
        XCTAssertTrue(reopened.staticTexts["30 kg × 8 · RIR 3"].waitForExistence(timeout: 5))
    }
    func testUnconfirmedRepsCannotCompleteAndUndoWorks() {
        let app = launch(); reveal(app.buttons["startWorkout"], in: app); app.buttons["startWorkout"].tap(); reveal(app.buttons["set-0"], in: app); app.buttons["set-0"].tap()
        app.buttons["saveSet"].tap()
        XCTAssertTrue(app.staticTexts["validationMessage"].exists)
        app.textFields["repsInput"].tap(); app.textFields["repsInput"].typeText("8")
        app.textFields["rirInput"].tap(); app.textFields["rirInput"].typeText("3")
        app.buttons["saveSet"].tap(); reveal(app.buttons["set-0"], in: app); app.buttons["set-0"].tap()
        app.buttons["Undo completion"].tap()
        XCTAssertTrue(app.staticTexts["Not completed · tap to record"].firstMatch.exists)
    }

    func testCompleteIntroUpperSession() {
        let app = launch()
        reveal(app.buttons["startWorkout"], in: app); app.buttons["startWorkout"].tap()
        for _ in 0..<8 {
            for set in 0..<2 {
                let button = app.buttons["set-\(set)"]
                reveal(button, in: app); button.tap()
                let weight = app.textFields["weightInput"]
                if (weight.value as? String)?.isEmpty != false || (weight.value as? String) == "Weight (kg)" {
                    weight.tap(); weight.typeText("10")
                }
                app.textFields["repsInput"].tap(); app.textFields["repsInput"].typeText("12")
                app.textFields["rirInput"].tap(); app.textFields["rirInput"].typeText("3")
                XCTAssertTrue(app.buttons["saveSet"].isHittable)
                app.buttons["saveSet"].tap()
            }
            reveal(app.buttons["Clean form"], in: app); app.buttons["Clean form"].tap()
            reveal(app.buttons["Next exercise"], in: app); app.buttons["Next exercise"].tap()
            // The next exercise can be above the retained scroll offset.
            for _ in 0..<5 { app.swipeDown() }
        }
        for _ in 0..<4 {
            let hold = app.buttons["Save hold"].firstMatch
            reveal(hold, in: app); hold.tap()
        }
        reveal(app.buttons["finishWorkout"], in: app); app.buttons["finishWorkout"].tap()
        app.buttons["Complete workout"].tap()
        XCTAssertTrue(app.staticTexts["16 working sets actually recorded"].waitForExistence(timeout: 5))
    }
    func testNavigationAndLargeTextSmoke() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for tab in ["Programme", "Progress", "Settings", "Train"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[tab].exists)
        }
        reveal(app.buttons["startWorkout"], in: app); app.buttons["startWorkout"].tap()
        XCTAssertTrue(app.buttons["set-0"].waitForExistence(timeout: 5))
    }
}
