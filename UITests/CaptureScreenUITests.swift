import XCTest

/// Plan 03-03's own evidence: the four capture-screen states, photographed, plus the
/// assertions that make each photograph mean something.
///
/// The last two states are **one claim asserted both ways in a single run**. Fixture 1
/// (`IMG_0498`) read no side markers, so CAP-05's prompt fires on it; fixture 2 (`IMG_0499`)
/// read `A` and `AA` off one photograph of a flat sleeve, so the prompt is suppressed. A
/// screenshot of a prompt appearing proves nothing on its own — a prompt that appears
/// unconditionally would produce exactly the same picture.
///
/// Every identifier here comes from the frozen contract in the phase's CONTEXT.md §5, and every
/// query is typed (`app.buttons[…]`, `app.staticTexts[…]`, `app.otherElements[…]`,
/// `app.scrollViews[…]`) because SwiftUI publishes some controls as two elements and a bare
/// `descendants(matching: .any)[id]` throws on them.
final class CaptureScreenUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    func test_givenTheCaptureScreen_whenTwoSleevesAreShot_thenTheStripFillsAndTheFlipPromptFiresOnlyWhereOneSideWasRead() {
        app = XCUIApplication()
        app.launch()

        // CRATE-05's Add More is the shortest way onto the capture screen, and it reuses a
        // fixture crate rather than typing a new name — fewer moving parts than the walk needs.
        XCTAssertTrue(app.buttons["crate-row-Sunday Chill"].waitForExistence(timeout: 20),
                      "the crate list never appeared")
        app.buttons["crate-row-Sunday Chill"].tap()
        XCTAssertTrue(app.buttons["add-more-button"].waitForExistence(timeout: 10),
                      "the crate detail screen never appeared")
        app.buttons["add-more-button"].tap()
        XCTAssertTrue(app.staticTexts["capture-crate-name"].waitForExistence(timeout: 10),
                      "Add More did not reach the capture screen")

        // ------------------------------------------------------- 1. the guide, strip empty
        let guide = app.otherElements["capture-framing-guide"]
        XCTAssertTrue(guide.waitForExistence(timeout: 10),
                      "CAP-02: no framing guide on the capture screen")
        // CAP-02's aspectRatio is 1.0 — a 12" sleeve is square — and this reads it back off the
        // rendered accessibility frame rather than off the constant that drew it.
        let guideFrame = guide.frame
        print("CAPTURE framing-guide frame = \(guideFrame)")
        XCTAssertEqual(guideFrame.width, guideFrame.height, accuracy: 2.0,
                       "CAP-02: the framing guide rendered \(guideFrame.width)x\(guideFrame.height) — not square")

        XCTAssertTrue(app.scrollViews["capture-thumbnail-strip"].exists,
                      "CAP-03: the thumbnail strip is missing before anything is shot")
        XCTAssertFalse(app.buttons["capture-thumb-1"].exists,
                       "CAP-03: a thumbnail exists before the shutter was ever pressed")
        XCTAssertFalse(app.otherElements["capture-flip-prompt"].exists,
                       "CAP-05: the flip prompt is showing before anything was captured")
        capture("03-03-capture-empty", settle: ScreenshotRecorder.launchSettle)

        // -------------------------------------------- 2. fixture 1 — the prompt DOES fire
        app.buttons["capture-shutter-button"].tap()
        XCTAssertTrue(app.buttons["capture-thumb-1"].waitForExistence(timeout: 10),
                      "CAP-03: the shutter put nothing in the strip")
        // Negative control for the whole `capture-thumb-{n}` family. The family is 1-based and
        // contiguous by construction, so if 99 resolves, every count in this phase is matching
        // something other than what it names.
        XCTAssertFalse(app.buttons["capture-thumb-99"].exists,
                       "a nonsense capture-thumb identifier resolved — the strip queries are not discriminating")

        let status1 = app.staticTexts["capture-thumb-status-1"]
        XCTAssertTrue(status1.exists, "CAP-03: the first tile carries no status indicator")
        // CAP-01: the tile arrives before the read does, so the verdict is waited for.
        waitForRead(1)
        XCTAssertEqual(status1.label, "Read",
                       "CAP-03: fixture 1 (IMG_0498) scored .read in the spike; the tile says '\(status1.label)'")

        // V1's inflection, two-sided — `contains("1 record")` alone is also true of "1 records".
        let count = app.staticTexts["capture-session-count"]
        XCTAssertTrue(count.exists, "CAP-03: the session count is missing")
        XCTAssertTrue(count.label.contains("1 record"),
                      "expected an inflected '1 record', got '\(count.label)'")
        XCTAssertFalse(count.label.contains("1 records"),
                       "the session count is not inflecting: '\(count.label)'")

        XCTAssertTrue(app.otherElements["capture-flip-prompt"].waitForExistence(timeout: 10),
                      "CAP-05: no flip prompt after fixture 1, which read no side markers at all")
        XCTAssertTrue(app.buttons["capture-flip-scan-button"].exists, "CAP-05: no Scan button")
        XCTAssertTrue(app.buttons["capture-flip-skip-button"].exists, "CAP-05: no Skip button")
        // CAP-05's "without leaving the camera": the crate name and the shutter are still on
        // screen behind the prompt, so it is a banner and not a sheet, an alert or a push.
        XCTAssertTrue(app.staticTexts["capture-crate-name"].exists,
                      "CAP-05: the flip prompt left the capture screen")
        XCTAssertTrue(app.buttons["capture-shutter-button"].isHittable,
                      "CAP-05: the flip prompt is blocking the shutter")
        capture("03-03-capture-flip-prompt")

        // ------------------------------------------ 3. Skip clears it, the record remains
        app.buttons["capture-flip-skip-button"].tap()
        XCTAssertTrue(app.otherElements["capture-flip-prompt"].waitForNonExistence(timeout: 5),
                      "CAP-05: Skip did not dismiss the flip prompt")
        XCTAssertTrue(app.buttons["capture-thumb-1"].exists,
                      "CAP-05: Skip removed the record it was asking about")
        capture("03-03-capture-one-item")

        // ------------------------------------- 4. fixture 2 — the prompt is SUPPRESSED
        // IMG_0499 read `A` and `AA` off one photograph, so both sides are already in hand.
        app.buttons["capture-shutter-button"].tap()
        XCTAssertTrue(app.buttons["capture-thumb-2"].waitForExistence(timeout: 10),
                      "CAP-03: the second shutter press put nothing in the strip")
        waitForRead(2)
        XCTAssertEqual(app.staticTexts["capture-thumb-status-2"].label, "Read",
                       "CAP-03: fixture 2 (IMG_0499) scored .read in the spike")
        XCTAssertFalse(app.buttons["capture-thumb-3"].exists,
                       "CAP-03: two shutter presses produced a third thumbnail")
        XCTAssertTrue(app.otherElements["capture-flip-prompt"].waitForNonExistence(timeout: 5),
                      "CAP-05: the prompt fired on a photograph that already read TWO sides")
        capture("03-03-capture-flip-suppressed")
    }

    /// A tile carries `Reading` until Vision answers; the element exists throughout, so it is
    /// the LABEL that has to be polled rather than the existence.
    @discardableResult
    private func waitForRead(_ index: Int, timeout: TimeInterval = 90) -> String {
        let status = app.staticTexts["capture-thumb-status-\(index)"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let label = status.label
            if !label.isEmpty, label != "Reading" { return label }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return status.label
    }

    /// The same guard the walk uses: every state goes through `ScreenshotRecorder`, never
    /// `XCUIScreen.main.screenshot()` directly, so the mandatory >=3s settle cannot be skipped.
    private func capture(_ name: String, settle: TimeInterval = ScreenshotRecorder.defaultSettle) {
        XCTAssertEqual(app.state, .runningForeground,
                       "refusing to photograph '\(name)': the app is not in the foreground")
        ScreenshotRecorder.capture(name, settle: settle, in: self)
    }
}
