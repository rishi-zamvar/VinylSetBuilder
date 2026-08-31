import CoreGraphics
import XCTest

/// Plan 03-04's evidence: OCR-04 (the raw recognised text, **including the reads the pipeline
/// threw away**) and SEG-07 (split, merge-up and hand-type, each in one tap) driven through the
/// real sheet against the owner's real OCR output.
///
/// **Why this is its own file rather than five more states bolted onto the walk.** The walk is
/// Phase 2's fifteen-state ship criterion and 03-05 owns extending it; reaching fixture 6 from
/// inside it would mean six shutter presses in the middle of a test whose shape other plans
/// assert on. `CaptureScreenUITests` set the precedent — a short, self-contained test that
/// enters through CRATE-05's Add More.
///
/// **Two fixtures, and the split is deliberate.**
///
/// - **Fixture 6, `IMG_0503`** — the richest real read in the set (16 observations: `SIDE A`,
///   `A: High Down`, `AAA: Strange Nat ure`, `TYME 012`, a `$9.73 [Import]` price sticker). Every
///   correction state is photographed here so no frame is a two-line stub.
/// - **Fixture 1, `IMG_0498`** — 11 observations of which **9 are trusted**: `зali/ti| Fuck W` at
///   0.30 and `Remi:600` at 0.30 are dropped by the segmenter and appear nowhere else in the app.
///   That is the whole of OCR-04, and it is **not demonstrable on fixture 6**, whose 16
///   observations are all 1.00 — measured, not assumed (see the plan's SUMMARY). So the
///   raw-text frame is taken here, where the picture actually shows what its caption claims.
///
/// Every query is typed (`app.buttons[…]`, `app.staticTexts[…]`, `app.textFields[…]`,
/// `app.otherElements[…]`): SwiftUI publishes some controls as two elements and a bare
/// `descendants(matching: .any)[id]` throws on them.
final class InspectSheetUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    func test_givenSixCapturedSleeves_whenTheInspectSheetIsDriven_thenRawTextIsReadableAndEveryCorrectionIsOneTap() {
        app = XCUIApplication()
        app.launchFresh()

        openCaptureScreen()
        shoot(times: 6)

        inspectFixtureOne()
        inspectFixtureSix()
    }

    // MARK: Getting onto the capture screen with six real sleeves in the strip

    private func openCaptureScreen() {
        XCTAssertTrue(app.buttons["crate-row-Sunday Chill"].waitForExistence(timeout: 20),
                      "the crate list never appeared")
        app.buttons["crate-row-Sunday Chill"].tap()
        XCTAssertTrue(app.buttons["add-more-button"].waitForExistence(timeout: 10),
                      "the crate detail screen never appeared")
        app.buttons["add-more-button"].tap()
        XCTAssertTrue(app.staticTexts["capture-crate-name"].waitForExistence(timeout: 10),
                      "Add More did not reach the capture screen")
    }

    /// `SleevePhotoSource` walks the twelve in filename order, so N presses puts fixtures 1…N in
    /// the strip. The flip prompt fires on some of them and never blocks the shutter (proved in
    /// `CaptureScreenUITests`), so nothing is dismissed here.
    ///
    /// Each shot is waited out to its verdict: the shutter returns before Vision has read
    /// anything (CAP-01), so a sheet opened on a `Reading` tile would show an empty draft.
    private func shoot(times: Int) {
        for n in 1...times {
            app.buttons["capture-shutter-button"].tap()
            XCTAssertTrue(app.buttons["capture-thumb-\(n)"].waitForExistence(timeout: 10),
                          "CAP-03: shutter press \(n) put nothing in the strip")
            let status = app.staticTexts["capture-thumb-status-\(n)"]
            let deadline = Date().addingTimeInterval(90)
            while Date() < deadline, status.label.isEmpty || status.label == "Reading" {
                Thread.sleep(forTimeInterval: 0.25)
            }
            XCTAssertNotEqual(status.label, "Reading", "CAP-01: shot \(n) never finished reading")
        }
        XCTAssertFalse(app.buttons["capture-thumb-\(times + 1)"].exists,
                       "CAP-03: \(times) shutter presses produced a \(times + 1)th thumbnail")
    }

    // MARK: OCR-04 — the untrusted reads are on screen, on the fixture that has some

    private func inspectFixtureOne() {
        tapThumb(1)
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForExistence(timeout: 10),
                      "tapping a thumbnail did not present the inspect sheet")
        XCTAssertTrue(app.staticTexts["inspect-title"].exists, "the sheet carries no title")

        // Two-sided, so a family that resolved everything would redden here rather than pass.
        // **Phase 8, swap 1.** This was 9 — one draft line per trusted observation, the stub's
        // rule. `AngleClusterSegmenter` returns the record's two actual track lines. Measured,
        // not guessed: `Abstract` and `The Message - Brown Gtauno Originat Mix!`, with
        // `0-44904` lifted out as the catalogue number.
        let lines = lineCount()
        XCTAssertEqual(lines, 2,
                       "IMG_0498 segments to 2 track lines; the draft opened with \(lines) lines")
        XCTAssertTrue(app.otherElements["inspect-line-\(lines)"].exists)
        XCTAssertFalse(app.otherElements["inspect-line-\(lines + 1)"].exists,
                       "the inspect-line family is not contiguous — line \(lines + 1) resolved")

        // The section is collapsed until asked for: reference material, not the task.
        XCTAssertFalse(app.staticTexts["inspect-raw-obs-1"].exists,
                       "OCR-04: the raw text is expanded before anyone asked for it")
        app.buttons["inspect-raw-text-section"].tap()
        XCTAssertTrue(app.staticTexts["inspect-raw-obs-1"].waitForExistence(timeout: 5),
                      "OCR-04: expanding the raw-text section showed nothing")

        // **Recorded, not pinned.** The macOS spike recorded 11 observations for IMG_0498; live
        // Vision on iOS does not return the same number for every sleeve (IMG_0505 gives 13 here
        // against 12 there). OCR-04's claim is the inequality below, and that is what is asserted.
        let raw = rawRowCount()
        print("OCR04 IMG_0498: \(raw) raw observations against \(lines) draft lines")
        XCTAssertTrue(app.staticTexts["inspect-raw-obs-\(raw)"].exists)
        XCTAssertFalse(app.staticTexts["inspect-raw-obs-\(raw + 1)"].exists,
                       "the inspect-raw-obs family is not contiguous — row \(raw + 1) resolved")

        // The requirement itself, as an inequality rather than a hardcoded pair, so a fixture
        // change cannot quietly make this vacuous.
        XCTAssertGreaterThan(raw, lines,
                             "OCR-04: the raw list (\(raw)) is not keeping the observations the segmenter dropped (\(lines) lines)")

        // …and the dropped rows are the LOW-confidence ones, asserted in both directions so a
        // list that silently hid them, or one that showed nothing but them, both redden. By
        // EXISTENCE rather than by row index: the row a given reading lands on is a property of
        // the reader's output order, which is not stable across OS versions, but "this sheet
        // shows readings the segmenter would not trust, alongside ones it would" is the
        // requirement and does not move.
        var confidences: [String] = []
        for n in 1...raw { confidences.append(app.staticTexts["inspect-raw-obs-\(n)"].label) }
        print("OCR04 IMG_0498 rows = \(confidences)")
        // Untrusted means "not 1.00" — that is the whole of `TrackTextFilter.isTrusted`. The
        // live reader returns 0.50 where the macOS spike returned 0.30 on the same photograph,
        // so the number itself is an OS detail and the tier is the requirement.
        XCTAssertTrue(confidences.contains { !$0.contains("1.00") },
                      "OCR-04: no untrusted reading is on screen, so the raw list is showing only what survived")
        XCTAssertTrue(confidences.contains { $0.contains("1.00") },
                      "OCR-04: no trusted reading is on screen either — the raw list is not showing the reader's output")

        assertNegativeControls()
        capture("03-04-sheet-raw-text")

        app.buttons["inspect-close-button"].tap()
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForNonExistence(timeout: 5),
                      "Close did not dismiss the sheet")
    }

    // MARK: SEG-07 — split, merge and hand-type, each one tap, on the richest real read

    private func inspectFixtureSix() {
        tapThumb(6)
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForExistence(timeout: 10),
                      "the sheet did not present for fixture 6")

        // **Phase 8, swap 1.** This was 16 — IMG_0503's sixteen trusted readings, one line each.
        // The record has two tracks: `A: HIGH DOWN` and `AAA: STRANGE NAT URE`.
        let opened = lineCount()
        XCTAssertEqual(opened, 2,
                       "IMG_0503 segments to 2 track lines; the draft opened with \(opened) lines")
        XCTAssertTrue(app.otherElements["inspect-line-\(opened)"].exists)
        XCTAssertFalse(app.otherElements["inspect-line-\(opened + 1)"].exists,
                       "the draft opened with a non-contiguous line family")
        // The affordance matches the behaviour: merging the first line is a no-op in Core.
        XCTAssertFalse(app.buttons["inspect-merge-up-1"].isEnabled,
                       "SEG-07: merge-up is live on the first row, where it does nothing")
        XCTAssertTrue(app.buttons["inspect-merge-up-2"].isEnabled,
                      "SEG-07: merge-up is disabled on the second row, where it works")
        assertNegativeControls()
        capture("03-04-sheet-lines")

        // ------------------------------------------------------------------ merge, one tap
        app.buttons["inspect-merge-up-2"].tap()
        let merged = lineCount()
        XCTAssertEqual(merged, opened - 1,
                       "SEG-07: one merge-up took \(opened) lines to \(merged)")
        XCTAssertTrue(app.otherElements["inspect-line-\(merged)"].exists)
        XCTAssertFalse(app.otherElements["inspect-line-\(merged + 1)"].exists,
                       "SEG-07: merge-up left a line behind past the end of the list")
        capture("03-04-sheet-after-merge")

        // ------------------------------------------------------------------ split, one tap
        app.buttons["inspect-split-1"].tap()
        let split = lineCount()
        XCTAssertEqual(split, opened,
                       "SEG-07: split did not put the line back — \(merged) -> \(split), expected \(opened)")
        XCTAssertFalse(app.otherElements["inspect-line-\(split + 1)"].exists,
                       "SEG-07: split added more than one line")
        capture("03-04-sheet-after-split")

        // -------------------------------------------------------------- hand entry, one tap
        // The path for IMG_0507, which the OCR failed outright: three junk reads and nothing
        // usable, so that record is only enterable by hand.
        let addLine = app.buttons["inspect-add-line-button"]
        scrollIntoView(addLine, name: "inspect-add-line-button") { app.swipeUp(velocity: .slow) }
        addLine.tap()
        let added = lineCount()
        XCTAssertEqual(added, split + 1, "SEG-07: Add a line did not append a line")

        let field = app.textFields["inspect-line-field-\(added)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5),
                      "SEG-07: the appended line has no editable field")
        scrollIntoView(field, name: "inspect-line-field-\(added)") { app.swipeUp(velocity: .slow) }
        field.tap()
        // **Wait for the keyboard before counting anything.** Measured: reading the line count
        // in the frame immediately after the tap sees 16 of 17 rows, because the tree is being
        // rebuilt around the appearing keyboard — an assertion placed there fails on a
        // transient, not on a defect. Once the keyboard is up the tree is settled.
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10),
                      "SEG-07: the keyboard never appeared for the hand-typed line")
        // Turns a stray tap into a sentence instead of a baffling "no matching snapshot" three
        // lines later: if the touch landed on a neighbouring split or merge-up control, the line
        // family renumbers and every identifier after it means something different.
        XCTAssertEqual(lineCount(), added,
                       "the tap on inspect-line-field-\(added) landed on something else — the line count moved")
        let typed = "DUBPLATE WHITE LABEL"
        field.typeText(typed)
        XCTAssertEqual(field.value as? String, typed,
                       "SEG-07: the hand-typed line reads back as '\(String(describing: field.value))'")
        XCTAssertFalse((field.value as? String ?? "").isEmpty,
                       "SEG-07: the hand-typed line came back empty")
        // Not Return: V15 made the field `axis: .vertical`, so Return inserts a newline instead
        // of resigning. Tapping the sheet's own title dismisses the keyboard and touches nothing.
        app.staticTexts["inspect-title"].tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 5)
        capture("03-04-sheet-hand-typed")

        // ------------------------------------------------- Apply writes back, Close does not
        app.buttons["inspect-apply-button"].tap()
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForNonExistence(timeout: 5),
                      "Apply did not dismiss the sheet")

        tapThumb(6)
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForExistence(timeout: 10),
                      "the sheet did not re-present after Apply")
        let persisted = lineCount()
        XCTAssertEqual(persisted, added,
                       "SEG-07: Apply did not write \(added) corrected lines back to the crate — reopened with \(persisted)")
        XCTAssertFalse(app.otherElements["inspect-line-\(persisted + 1)"].exists,
                       "SEG-07: the write-back left a line past the end of the list")

        // An edit that is then CLOSED must change nothing. Without the merge first, this would
        // pass on a sheet that never wrote anything at all.
        app.buttons["inspect-merge-up-2"].tap()
        XCTAssertEqual(lineCount(), persisted - 1, "the discarded edit did not take effect in the sheet")
        app.buttons["inspect-close-button"].tap()
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForNonExistence(timeout: 5),
                      "Close did not dismiss the sheet")

        tapThumb(6)
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForExistence(timeout: 10),
                      "the sheet did not re-present after Close")
        XCTAssertEqual(lineCount(), persisted,
                       "SEG-07: closing the sheet wrote the discarded merge back to the crate anyway")
        app.buttons["inspect-close-button"].tap()
    }

    // MARK: Helpers

    /// Both `{n}` families are 1-based and contiguous by construction, so the count is however
    /// far you can walk. The cap stops a runaway if that ever stops being true.
    private func lineCount() -> Int {
        var n = 0
        while n < 60, app.otherElements["inspect-line-\(n + 1)"].exists { n += 1 }
        return n
    }

    private func rawRowCount() -> Int {
        var n = 0
        while n < 60, app.staticTexts["inspect-raw-obs-\(n + 1)"].exists { n += 1 }
        return n
    }

    /// Without these, a broad matcher resolving everything would make every count above
    /// meaningless. Asserted on both families, in both sheets.
    private func assertNegativeControls() {
        XCTAssertFalse(app.staticTexts["inspect-raw-obs-999"].exists,
                       "a nonsense inspect-raw-obs identifier resolved — the raw-text queries are not discriminating")
        XCTAssertFalse(app.otherElements["inspect-line-99"].exists,
                       "a nonsense inspect-line identifier resolved — the line queries are not discriminating")
    }

    /// CAP-03's strip scrolls horizontally so twenty-one records do not shrink to twenty-one
    /// slivers — which means the sixth tile sits off the right edge. Measured, not guessed: the
    /// first run failed here with `capture-thumb-6` at x=586 on a 393pt-wide screen.
    private func tapThumb(_ n: Int) {
        let thumb = app.buttons["capture-thumb-\(n)"]
        XCTAssertTrue(thumb.exists, "capture-thumb-\(n) is not in the strip")
        scrollIntoView(thumb, name: "capture-thumb-\(n)") {
            app.scrollViews["capture-thumbnail-strip"].swipeLeft(velocity: .slow)
        }
        thumb.tap()
    }

    /// **Not `isHittable`.** An element whose frame lies wholly outside the window has no
    /// activation point, and `isHittable` does not return false for it — it *throws*
    /// ("Failed to determine hittability"), aborting the test rather than driving the loop.
    /// Measured on this suite's second run. The element's own frame is readable in that state,
    /// so containment is the check that works.
    ///
    /// **Slow swipes, and a settle after each one.** A fast swipe keeps scrolling under
    /// momentum after the gesture ends, so `tap()` can resolve an element's frame and then
    /// synthesise the touch a few points later — landing on the neighbouring control. Measured:
    /// one run tapped a row's merge-up button instead of the field beneath it, which removed a
    /// line and renumbered the family, and the test then failed on a missing
    /// `inspect-line-field-17` rather than on anything it was testing.
    private func scrollIntoView(_ element: XCUIElement,
                                name: String,
                                maxSwipes: Int = 8,
                                _ scroll: () -> Void) {
        var swipes = 0
        while !isOnScreen(element), swipes < maxSwipes {
            scroll()
            Thread.sleep(forTimeInterval: 0.5)   // let the momentum die before the next frame read
            swipes += 1
        }
        XCTAssertTrue(isOnScreen(element),
                      "\(name) never scrolled into view after \(swipes) swipes (frame \(element.frame))")
    }

    private func isOnScreen(_ element: XCUIElement) -> Bool {
        let frame = element.frame
        guard frame.width > 0, frame.height > 0 else { return false }
        return app.windows.firstMatch.frame
            .contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    private func capture(_ name: String, settle: TimeInterval = ScreenshotRecorder.defaultSettle) {
        XCTAssertEqual(app.state, .runningForeground,
                       "refusing to photograph '\(name)': the app is not in the foreground")
        ScreenshotRecorder.capture(name, settle: settle, in: self)
    }
}
