import XCTest

/// The proof that the XCUITest harness itself works, run against a screen that already
/// exists and already renders. Plan 02-04 writes the full fifteen-state walk on top of this;
/// if this test is red, that walk cannot be trusted to be reporting on the product.
///
/// Asserts only on crate *names*, which come from `FixtureCrates` and are stable. It
/// deliberately does not assert on the record-count strings: 02-03 rewords "1 records" into
/// "1 record" (defect V1), and a harness that breaks when the product is corrected is a
/// harness that will be ignored.
///
/// The accessibility tree of this screen was dumped on 2026-08-30 and recorded in
/// 02-02-SUMMARY.md. It confirms SwiftUI publishes both the merged row label
/// ("Friday Warehouse, 4 records") and each child `StaticText` separately, so an exact-label
/// `staticTexts` query resolves — no substring matching is needed here.
final class SmokeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_givenTheApp_whenLaunched_thenTheCrateListRendersTheFixtureCrates() {
        let app = XCUIApplication()
        app.launchFresh()

        // 20s, not 5s: the first install-and-launch on a cold simulator is slow, and a tight
        // timeout produces a flake that reads exactly like a product bug.
        XCTAssertTrue(app.navigationBars["Crates"].waitForExistence(timeout: 20),
                      "the crate list's navigation bar never appeared")

        ScreenshotRecorder.capture("02-smoke-crate-list",
                                   settle: ScreenshotRecorder.launchSettle,
                                   in: self)

        XCTAssertTrue(app.staticTexts["Friday Warehouse"].waitForExistence(timeout: 10),
                      "the Friday Warehouse fixture crate is not on screen")
        XCTAssertTrue(app.staticTexts["Sunday Chill"].exists,
                      "the Sunday Chill fixture crate is not on screen")
    }
}
