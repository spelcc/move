import XCTest

final class MoveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "cc.spel.move")
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testApplicationLaunches() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testKeyboardShortcutDoesNotCrashApplication() {
        app.typeKey("m", modifierFlags: [.command, .option])
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
