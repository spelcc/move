import XCTest

@MainActor
final class MoveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "cc.spel.move")
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testApplicationLaunches() {
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10) || app.state == .runningForeground)
    }

    func testKeyboardShortcutDoesNotCrashApplication() {
        app.typeKey("m", modifierFlags: [.command, .option])
        XCTAssertTrue(app.state == .runningBackground || app.state == .runningForeground)
    }
}
