import CoreGraphics
import XCTest

/// **Phase 3's ship criterion, executable.** The roadmap's sentence, verbatim: *all 12 fixture
/// photographs load through the stubbed capture screen in one simulated session; the flip prompt
/// fires on exactly the fixtures that lack a second side marker and on no others; every screen
/// and sheet state is screenshotted after a settle delay.*
///
/// Two tests, because the criterion has two independent halves and one long test that fails at
/// shot nineteen tells you nothing about shots one to twelve:
///
/// 1. **The twelve-fixture session** — the named flip set, the status tally, and the five states
///    a person actually looks at along the way.
/// 2. **The twenty-one-item strip** — CAP-03's "scrolls past 20 items without layout breaking",
///    which is a *layout* claim and needs a measurement a count cannot give.
///
/// **Every number here is `CONTEXT.md` §3's, and it is asserted as a named set, never as a
/// count.** Nine wrong indices pass `count == 9`; `[1, 3, 4, 5, 7, 8, 10, 11, 12]` does not.
/// The suppressed set `[2, 6, 9]` is asserted *separately* so a walk that recorded nothing at
/// all reddens here instead of passing vacuously on an empty `fired` array.
///
/// Second-observation discipline: 03-01's Core unit tests assert both the flip set and the 6/5/1
/// tally against `FixturePhotoSource` directly. This file asserts the same two facts against
/// real prompts and real tile labels in a real session. Two independent observations, by
/// construction rather than by re-running the same check twice.
///
/// Every query is typed (`app.buttons[…]`, `app.staticTexts[…]`, `app.otherElements[…]`,
/// `app.scrollViews[…]`): SwiftUI publishes some controls as two elements and a bare
/// `descendants(matching: .any)[id]` throws on them.
final class CaptureWalkUITests: XCTestCase {

    private var app: XCUIApplication!

    /// `CONTEXT.md` §3, transcribed once. `[2, 6, 9]` are IMG_0499, IMG_0503 and IMG_0506 — the
    /// three photographs that already read two distinct side markers, so CAP-05 has nothing to
    /// ask about. The prompt fires on the other nine.
    private static let expectedFired = [1, 3, 4, 5, 7, 8, 10, 11, 12]
    private static let expectedSuppressed = [2, 6, 9]

    /// The spike's own 6 clean / 5 partial / 1 fail, keyed on `CaptureItemStatus.label`.
    private static let expectedTally = ["Read": 6, "Partial": 5, "Unread": 1]

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: 1 — the twelve, in one session

    func test_givenTwelveFixturePhotographs_whenShotInOneSession_thenTheFlipPromptFiresOnExactlyNine() {
        app = XCUIApplication()
        app.launch()

        // CRATE-02 routes straight from Create into capture, which is the entry a person
        // actually uses to start a crate — Add More is the other entry and test 2 takes it.
        XCTAssertTrue(app.buttons["new-crate-button"].waitForExistence(timeout: 20),
                      "the crate list never appeared")
        app.buttons["new-crate-button"].tap()
        let nameField = app.textFields["new-crate-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "the new-crate sheet never appeared")
        nameField.tap()
        _ = app.keyboards.element.waitForExistence(timeout: 5)
        nameField.typeText("Twelve Fixtures")
        app.buttons["new-crate-create-button"].tap()

        XCTAssertTrue(app.staticTexts["capture-crate-name"].waitForExistence(timeout: 10),
                      "CRATE-02: creating a crate did not route to the capture screen")

        // ------------------------------------------------- state 1: the guide, strip empty
        let guide = app.otherElements["capture-framing-guide"]
        XCTAssertTrue(guide.waitForExistence(timeout: 10), "CAP-02: no framing guide")
        XCTAssertTrue(app.scrollViews["capture-thumbnail-strip"].exists,
                      "CAP-03: the strip is missing before anything is shot")
        XCTAssertFalse(app.buttons["capture-thumb-1"].exists,
                       "CAP-03: a thumbnail exists before the shutter was ever pressed")
        XCTAssertFalse(app.otherElements["capture-flip-prompt"].exists,
                       "CAP-05: the flip prompt is showing before anything was captured")
        print("WALK12 framing-guide frame (empty strip) = \(guide.frame)")
        capture("03-walk-01-capture-guide", settle: ScreenshotRecorder.launchSettle)

        // ------------------------------------------------------------- the twelve shutters
        var fired: [Int] = []
        var suppressed: [Int] = []
        var tally: [String: Int] = [:]

        for i in 1...12 {
            app.buttons["capture-shutter-button"].tap()

            let thumb = app.buttons["capture-thumb-\(i)"]
            XCTAssertTrue(thumb.waitForExistence(timeout: 15),
                          "CAP-03: shutter press \(i) put nothing in the strip")
            // Two-sided. A one-sided existence check passes on a strip that added two tiles.
            XCTAssertFalse(app.buttons["capture-thumb-\(i + 1)"].exists,
                           "CAP-03: shutter press \(i) produced a tile \(i + 1)")

            // D-03-6 / defect V3, asserted rather than hoped for: the strip names a record from
            // its own OCR text and never through `VinylEntry.label`, which would call every one
            // of these "Vinyl N". The grep gate in the plan's audit is the other half of this.
            let tileName = thumb.label
            XCTAssertNil(tileName.range(of: "^Vinyl [0-9]+$", options: .regularExpression),
                         "D-03-6: tile \(i) is named '\(tileName)' — VinylEntry.label leaked into the strip")

            // The prompt is set in the same mutation that appends the item, so it is on screen
            // by the time the tile is. The wait is for render lag, not for a race.
            let prompt = app.otherElements["capture-flip-prompt"]
            if prompt.waitForExistence(timeout: 3) {
                fired.append(i)
                print("WALK12 fixture \(i) PROMPT '\(prompt.label)'")
                if i == 1 { capture("03-walk-02-flip-prompt-fires") }
                // Skip, not Scan: Scan fires a thirteenth shutter and the session stops being
                // twelve photographs.
                app.buttons["capture-flip-skip-button"].tap()
                XCTAssertTrue(prompt.waitForNonExistence(timeout: 5),
                              "CAP-05: Skip did not dismiss the prompt on fixture \(i)")
                XCTAssertTrue(thumb.exists,
                              "CAP-05: Skip removed the record it was asking about (fixture \(i))")
            } else {
                suppressed.append(i)
                print("WALK12 fixture \(i) SUPPRESSED")
                if i == 2 { capture("03-walk-03-flip-suppressed") }
            }

            let status = app.staticTexts["capture-thumb-status-\(i)"]
            XCTAssertTrue(status.exists, "CAP-03: tile \(i) carries no status indicator")
            let statusLabel = status.label
            XCTAssertFalse(statusLabel.isEmpty, "CAP-03: tile \(i)'s status rendered blank")
            tally[statusLabel, default: 0] += 1
            print("WALK12 fixture \(i) tile='\(tileName)' status='\(statusLabel)'")

            if i == 1 {
                // V1's inflection, two-sided, on the strip's own counter — `contains("1 record")`
                // alone is also true of the broken "1 records".
                let one = app.staticTexts["capture-session-count"].label
                XCTAssertTrue(one.contains("1 record"), "expected an inflected '1 record', got '\(one)'")
                XCTAssertFalse(one.contains("1 records"), "the session count is not inflecting: '\(one)'")
            }
        }

        // ------------------------------------------------------------------ the two numbers
        // Ascending-order array equality, which is set equality plus ordering — strictly
        // stronger than the named-set check the plan requires, and it can still only pass on
        // exactly [1, 3, 4, 5, 7, 8, 10, 11, 12].
        XCTAssertEqual(fired, Self.expectedFired,
                       "CAP-05: the flip prompt fired on \(fired), not on \(Self.expectedFired)")
        // Asserted separately and in its own direction: a walk that recorded nothing at all
        // would pass a `fired` assertion vacuously if the two were folded into one check.
        XCTAssertEqual(suppressed, Self.expectedSuppressed,
                       "CAP-05: suppressed on \(suppressed), not on exactly [2, 6, 9]")
        XCTAssertEqual(fired.count + suppressed.count, 12,
                       "the walk recorded \(fired.count + suppressed.count) verdicts across twelve shutter presses")

        // The whole dictionary, not the three counts one at a time: a status the strip rendered
        // blank shows up here as a missing key rather than being silently skipped.
        XCTAssertEqual(tally, Self.expectedTally,
                       "CAP-03: the strip's status tally is \(tally), not 6 Read / 5 Partial / 1 Unread")

        // Ship criterion 1: all twelve loaded, and only twelve.
        XCTAssertTrue(app.buttons["capture-thumb-12"].exists, "the twelfth fixture is not in the strip")
        XCTAssertFalse(app.buttons["capture-thumb-13"].exists, "a thirteenth tile appeared in a twelve-shot session")

        let sessionCount = app.staticTexts["capture-session-count"].label
        XCTAssertTrue(sessionCount.contains("12"), "the session count reads '\(sessionCount)', not 12")
        XCTAssertTrue(sessionCount.contains("12 records"), "the session count is not inflecting the plural: '\(sessionCount)'")
        XCTAssertFalse(sessionCount.contains("1 records"), "the session count reads the un-inflected '1 records': '\(sessionCount)'")

        // ---------------------------------------------------------------- negative controls
        XCTAssertFalse(app.buttons["capture-thumb-99"].exists,
                       "a nonsense capture-thumb identifier resolved — every count above is matching something other than what it names")
        XCTAssertFalse(app.staticTexts["capture-thumb-status-99"].exists,
                       "a nonsense capture-thumb-status identifier resolved — the tally is not discriminating")
        // …and a positive control on the same query family, so an always-false matcher cannot
        // pass the two above by matching nothing at all.
        XCTAssertTrue(app.buttons["capture-thumb-1"].exists,
                      "the capture-thumb family resolves nothing at all — the negative controls above are vacuous")

        capture("03-walk-04-strip-twelve")

        // ------------------------------- states 5 and 6: the sheet, on the two fixtures that
        // actually answer defect V13 (see the plan's SUMMARY for why these two and not one)
        inspectLongestLineWraps()
        inspectLongestRawRead()

        // ------------------------------------------------------- state 7: CAP-06, and V3 again
        doneAndOpenTheBucket()
    }

    // MARK: 2 — CAP-03's "past twenty items without layout breaking"

    func test_givenTwentyOneScans_whenTheStripIsScrolled_thenTheLastTileIsReachable() {
        app = XCUIApplication()
        app.launch()

        // CRATE-05's Add More: a second, shorter route onto the same screen, and it needs no
        // keyboard.
        XCTAssertTrue(app.buttons["crate-row-Sunday Chill"].waitForExistence(timeout: 20),
                      "the crate list never appeared")
        app.buttons["crate-row-Sunday Chill"].tap()
        XCTAssertTrue(app.buttons["add-more-button"].waitForExistence(timeout: 10),
                      "the crate detail screen never appeared")
        app.buttons["add-more-button"].tap()
        XCTAssertTrue(app.staticTexts["capture-crate-name"].waitForExistence(timeout: 10),
                      "Add More did not reach the capture screen")

        // Measured with no prompt on screen, at both ends, so the two widths are read under the
        // same layout conditions. (The prompt shrinks the *preview* — defect V10 — never a tile.)
        shootOnce(1)
        dismissAnyFlipPrompt()
        let widthAtOne = app.buttons["capture-thumb-1"].frame.width
        XCTAssertGreaterThan(widthAtOne, 0, "tile 1 has no width at one item")

        // `FixturePhotoSource` wraps past the twelfth, so shots 13…21 are fixtures 1…9 again
        // with fresh, still-ascending indices. No screenshot per tap: twenty-one settles at
        // three seconds each is a minute of dead time for frames nobody will look at.
        for i in 2...21 {
            shootOnce(i)
            dismissAnyFlipPrompt()
        }

        XCTAssertTrue(app.buttons["capture-thumb-21"].exists, "CAP-03: the twenty-first tile is missing")
        XCTAssertFalse(app.buttons["capture-thumb-22"].exists, "CAP-03: a twenty-second tile appeared after 21 presses")
        XCTAssertFalse(app.buttons["capture-thumb-99"].exists,
                       "a nonsense capture-thumb identifier resolved — the two assertions above are not discriminating")

        // **The actual layout failure mode.** An `HStack` that shrinks to fit twenty-one tiles
        // renders twenty-one slivers and still passes every existence and count assertion above.
        // Only the width can see it.
        let widthAtTwentyOne = app.buttons["capture-thumb-1"].frame.width
        print("STRIP21 tile 1 width: \(widthAtOne) at 1 item -> \(widthAtTwentyOne) at 21")
        XCTAssertEqual(widthAtOne, widthAtTwentyOne, accuracy: 1.0,
                       "CAP-03: the tiles compressed from \(widthAtOne)pt to \(widthAtTwentyOne)pt — the strip is shrinking, not scrolling")

        capture("03-walk-08-strip-twentyone")

        // Existence is not reachability: a tile can be in the accessibility tree and permanently
        // off the right-hand edge of a strip that does not scroll.
        let last = app.buttons["capture-thumb-21"]
        print("STRIP21 tile 21 frame before scrolling = \(last.frame), window = \(windowFrame)")
        let swipes = scrollStripUntilReachable(last, limit: 30)
        XCTAssertTrue(isReachable(last),
                      "CAP-03: tile 21 never came on screen after \(swipes) drag steps — the strip does not scroll to its end")
        // Now that the activation point is known valid, the real hittability question is safe
        // to ask, and it is the one CAP-03 is actually about.
        XCTAssertTrue(last.isHittable,
                      "CAP-03: tile 21 is on screen but not hittable — something is covering the end of the strip")
        print("STRIP21 tile 21 hittable after \(swipes) drag step(s), frame = \(last.frame)")

        capture("03-walk-09-strip-scrolled-to-end")
    }

    // MARK: The two sheet states

    /// **State 5 — defect V15, closed by measurement rather than by assertion.**
    ///
    /// V15: the correction field truncated the corpus's longest read at about 22 characters in
    /// a 237.3pt single-line `TextField`. Swap 1 made that WORSE and not better — the premise
    /// for handing V15 to Phase 6 was that SEG-03's filter would shorten the long lines, and
    /// the opposite happened: `AngleClusterSegmenter` JOINS a cluster's readings into one track
    /// line, so the longest draft line in the corpus went from 44 characters to 57 (IMG_0500,
    /// fixture 3). The fix is `axis: .vertical` on the field.
    ///
    /// Measured with a control in the same run, because "it is tall" means nothing on its own:
    /// fixture 5's single 29-character line is the one-line control and fixture 3's 57-character
    /// line has to be visibly taller than it.
    private func inspectLongestLineWraps() {
        openThumb(5)
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForExistence(timeout: 10),
                      "tapping tile 5 did not present the inspect sheet")
        XCTAssertEqual(lineCount(), 1, "IMG_0502 segments to one track line")
        let control = app.textFields["inspect-line-field-1"]
        let controlValue = (control.value as? String) ?? ""
        let controlHeight = control.frame.height
        print("WALK12 V15 control: \(controlValue.count) chars, field \(control.frame.width)x\(controlHeight)pt, '\(controlValue)'")
        XCTAssertEqual(controlValue.count, 29,
                       "the one-line control is \(controlValue.count) characters ('\(controlValue)'), not 29")
        closeSheet()

        openThumb(3)
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForExistence(timeout: 10),
                      "tapping tile 3 did not present the inspect sheet")
        let lines = lineCount()
        XCTAssertEqual(lines, 1, "IMG_0500 segments to one track line; the draft opened with \(lines)")
        XCTAssertFalse(app.otherElements["inspect-line-\(lines + 1)"].exists,
                       "the inspect-line family is not contiguous — line \(lines + 1) resolved")
        XCTAssertFalse(app.otherElements["inspect-line-99"].exists,
                       "a nonsense inspect-line identifier resolved — the line count is not discriminating")

        let longest = app.textFields["inspect-line-field-1"]
        let value = (longest.value as? String) ?? ""
        print("WALK12 V15 longest: \(value.count) chars, field \(longest.frame.width)x\(longest.frame.height)pt, '\(value)'")
        // The value is intact — that was never in doubt, V15 was always about legibility.
        XCTAssertEqual(value.count, 57,
                       "expected the corpus's longest draft line at 57 characters; the field holds \(value.count) ('\(value)')")
        // …and it is now DRAWN, not cut off. A single-line field would render both at the same
        // height, which is exactly what V15 was.
        // At least one whole rendered line taller than the control. Measured: a line is 22pt,
        // the 29-character control wraps to two (44pt) and the 57-character line to three
        // (66pt). `* 1.5` was tried first and is EXACTLY the 2:3 ratio, so it failed on a
        // floating-point ulp — 66.00000000000003 against 66.00000000000004 — while measuring
        // the right thing. A whole-line margin says what is meant and has slack.
        XCTAssertGreaterThan(longest.frame.height, controlHeight + 10,
                             "V15: the 57-character line renders at \(longest.frame.height)pt against the 29-character control's \(controlHeight)pt — it is still being truncated")

        capture("03-walk-05-inspect-sheet")
        closeSheet()
    }

    /// **State 6 — fixture 8 (`IMG_0505`), whose raw list is the only place in the app the
    /// 106-character read exists.** OCR-04 is about the observations the segmenter threw away,
    /// and this is the largest one in the corpus by a factor of four.
    private func inspectLongestRawRead() {
        openThumb(8)
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForExistence(timeout: 10),
                      "tapping tile 8 did not present the inspect sheet")

        // **Phase 8, swap 1.** This was 11 — one line per trusted observation. IMG_0505 has two
        // tracks, `DUBTRACK` and `SUPERSONIC`, and `TECH008` came out as the catalogue number.
        let lines = lineCount()
        XCTAssertEqual(lines, 2, "IMG_0505 segments to 2 track lines; the draft opened with \(lines) lines")

        // **Defect V16, closed here.** The over-split draft carried the SAME string twice when
        // the OCR read it off two surfaces of one sleeve — IMG_0505 listed `SIMON BASSLINE
        // SMITH` on lines 2 and 5, and a person correcting the sheet could not tell the two
        // apart. `AngleClusterSegmenter` removes cross-cluster repeats and collapses near
        // duplicates inside a cluster, so this is now an ASSERTION and not a print.
        var lineTexts: [String] = []
        for n in 1...lines {
            lineTexts.append((app.textFields["inspect-line-field-\(n)"].value as? String) ?? "")
        }
        let duplicates = Dictionary(grouping: lineTexts, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        print("WALK12 V13 IMG_0505 lines = \(lineTexts)")
        print("WALK12 V16 IMG_0505 duplicate line texts = \(duplicates)")
        XCTAssertTrue(duplicates.isEmpty,
                      "V16: the draft still carries identical lines: \(duplicates)")

        XCTAssertFalse(app.staticTexts["inspect-raw-obs-1"].exists,
                       "OCR-04: the raw text is expanded before anyone asked for it")
        app.buttons["inspect-raw-text-section"].tap()
        XCTAssertTrue(app.staticTexts["inspect-raw-obs-1"].waitForExistence(timeout: 5),
                      "OCR-04: expanding the raw-text section showed nothing")

        let raw = rawRowCount()
        XCTAssertEqual(raw, 12, "IMG_0505 produced 12 observations; the sheet lists \(raw)")
        XCTAssertGreaterThan(raw, lines,
                             "OCR-04: the raw list (\(raw)) is not keeping the observation the segmenter dropped (\(lines) lines)")
        XCTAssertFalse(app.staticTexts["inspect-raw-obs-999"].exists,
                       "a nonsense inspect-raw-obs identifier resolved — the raw count is not discriminating")

        // Row 3 is the 106-character read, at 0.30. Both halves asserted: it is present, and it
        // is present *as untrusted*, so a list that silently promoted it would redden too.
        let row3 = app.staticTexts["inspect-raw-obs-3"].label
        print("WALK12 V13 raw row 3: \(row3.count) chars, '\(row3)'")
        XCTAssertTrue(row3.contains("0.30"), "OCR-04: observation 3 came back at 0.30; the sheet says '\(row3)'")
        XCTAssertGreaterThan(row3.count, 100,
                             "V13: expected the 106-character read on row 3; got \(row3.count) characters")

        // **V13, the half a photograph cannot answer.** Row 3 sits at the bottom edge of the
        // frame, so whether the 106-character read WRAPS onto further lines or is cut off is not
        // visible in the picture. Height answers it: a wrapped row is several times taller than
        // a one-line row, and rows 1 and 2 are the one-line control.
        for n in 1...3 {
            print("WALK12 V13 raw row \(n) height = \(app.staticTexts["inspect-raw-obs-\(n)"].frame.height)pt")
        }
        let oneLine = app.staticTexts["inspect-raw-obs-1"].frame.height
        let longRow = app.staticTexts["inspect-raw-obs-3"].frame.height
        XCTAssertGreaterThan(longRow, oneLine * 1.5,
                             "V13: the 106-character read renders at \(longRow)pt against a one-line row's \(oneLine)pt — it is being cut off, not wrapped")

        capture("03-walk-06-inspect-raw-text")
        closeSheet()
    }

    // MARK: CAP-06, and defect V3's second sighting

    /// Done leaves the capture loop and lands on the crate. Nothing resolves in Act I, so twelve
    /// records with OCR text and no BPM cannot be sequenced: the running order is genuinely
    /// empty and all twelve sit in the not-included bucket.
    ///
    /// **The bucket is expanded here on purpose.** It is collapsed by default, which is why plan
    /// 03-03 could not obtain V3's second sighting and correctly declined to claim it. One tap
    /// puts the row labels in the frame. **Nothing asserts that the rows read "Vinyl N"** — the
    /// photograph is the evidence, and an assertion on a defect is a landmine for whichever plan
    /// fixes it. The labels are printed instead.
    private func doneAndOpenTheBucket() {
        app.buttons["capture-done-button"].tap()

        XCTAssertTrue(app.staticTexts["empty-running-order"].waitForExistence(timeout: 15),
                      "CAP-06/V7: the crate shows neither a running order nor the empty-order placeholder")
        XCTAssertFalse(app.staticTexts["capture-crate-name"].exists,
                       "CAP-06: Done did not leave the capture loop")
        XCTAssertFalse(app.staticTexts["sequenced-row-1"].exists,
                       "twelve records with no BPM were sequenced anyway")
        XCTAssertFalse(app.staticTexts["sequenced-row-99"].exists,
                       "a nonsense sequenced-row identifier resolved — the assertion above is not discriminating")

        let detailList = app.collectionViews["crate-detail-list"]
        XCTAssertTrue(detailList.waitForExistence(timeout: 10), "the crate detail list never appeared")
        XCTAssertTrue(app.buttons["not-included-section"].exists,
                      "SEQ-07: twelve un-sequenceable captures are missing from the not-included bucket")

        let textsCollapsed = detailList.staticTexts.count
        app.buttons["not-included-section"].tap()
        // The disclosure animates, so the count is polled rather than read once.
        var textsExpanded = detailList.staticTexts.count
        for _ in 0..<10 where textsExpanded <= textsCollapsed {
            Thread.sleep(forTimeInterval: 0.5)
            textsExpanded = detailList.staticTexts.count
        }
        XCTAssertGreaterThan(textsExpanded, textsCollapsed,
                             "SEQ-07: the expanded bucket shows no more text than the collapsed one")

        let labels = detailList.staticTexts.allElementsBoundByIndex.map { $0.label }
        let vinylN = labels.filter { $0.range(of: "^Vinyl [0-9]+$", options: .regularExpression) != nil }
        print("WALK12 not-included: \(textsCollapsed) -> \(textsExpanded) texts; V3-shaped labels = \(vinylN)")

        capture("03-walk-07-done-sequenced")
    }

    // MARK: Helpers

    private func shootOnce(_ index: Int) {
        app.buttons["capture-shutter-button"].tap()
        XCTAssertTrue(app.buttons["capture-thumb-\(index)"].waitForExistence(timeout: 15),
                      "CAP-03: shutter press \(index) put nothing in the strip")
    }

    private func dismissAnyFlipPrompt() {
        let prompt = app.otherElements["capture-flip-prompt"]
        guard prompt.waitForExistence(timeout: 1) else { return }
        app.buttons["capture-flip-skip-button"].tap()
        _ = prompt.waitForNonExistence(timeout: 5)
    }

    /// Tiles past the third are off the right-hand edge of a 393pt screen, so reaching one is a
    /// scroll and not a tap. Bounded, and it asserts it got there rather than tapping blind.
    private func openThumb(_ index: Int) {
        let thumb = app.buttons["capture-thumb-\(index)"]
        XCTAssertTrue(thumb.exists, "tile \(index) is not in the strip")
        let swipes = scrollStripUntilReachable(thumb, limit: 30)
        XCTAssertTrue(isReachable(thumb),
                      "tile \(index) never became reachable after \(swipes) drag steps — frame \(thumb.frame) against window \(windowFrame)")
        thumb.tap()
    }

    /// **`isHittable` cannot be used as the loop condition, and that is a measured fact rather
    /// than a preference.** Asked of a tile scrolled off the right-hand edge, it does not return
    /// `false` — it raises *"Activation point invalid and no suggested hit points based on
    /// element frame"* and fails the test outright. Observed on `capture-thumb-5` and
    /// `capture-thumb-21` on this file's first run.
    ///
    /// So reachability is asked of the geometry first: a tap lands on the element's **centre**,
    /// so a tile whose centre is inside the window has a valid activation point by definition.
    /// `isHittable` is then safe to assert, and test 2 does assert it.
    private var windowFrame: CGRect { app.windows.firstMatch.frame }

    private func isReachable(_ element: XCUIElement) -> Bool {
        let f = element.frame
        guard f.width > 1, f.height > 1 else { return false }
        return windowFrame.insetBy(dx: 4, dy: 4).contains(CGPoint(x: f.midX, y: f.midY))
    }

    /// **Not `swipeLeft()`, and that is also measured.** A swipe releases with momentum, so a
    /// tile in the *middle* of a twelve-item strip is routinely carried straight past: on this
    /// file's first full-suite run, fifteen consecutive `swipeLeft(velocity: .slow)` calls drove
    /// `capture-thumb-5` from off the right-hand edge to `x = -516`, off the left one, because a
    /// one-directional loop cannot come back.
    ///
    /// This drags a bounded step and **holds at the end**, which kills the inertial scroll, and
    /// it chooses its direction from where the tile actually is on each pass. It therefore
    /// converges instead of running away, and it works for a tile in the middle as well as for
    /// the last one.
    @discardableResult
    private func scrollStripUntilReachable(_ element: XCUIElement, limit: Int) -> Int {
        let strip = app.scrollViews["capture-thumbnail-strip"]
        var steps = 0
        while !isReachable(element) && steps < limit {
            let frame = element.frame
            guard frame.width > 1 else { break }
            // Capped so the drag's end point stays inside the window; signed so a tile to the
            // left is fetched back rather than pushed further away.
            let wanted = frame.midX - windowFrame.midX
            let step = max(-170, min(170, wanted))
            let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = start.withOffset(CGVector(dx: -step, dy: 0))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            steps += 1
        }
        return steps
    }

    private func closeSheet() {
        app.buttons["inspect-close-button"].tap()
        XCTAssertTrue(app.otherElements["inspect-sheet"].waitForNonExistence(timeout: 10),
                      "Close did not dismiss the inspect sheet")
    }

    /// The `{n}` families are 1-based and contiguous by construction, so walking upward until
    /// one is absent is a count — and `…-99` not resolving is what makes that safe.
    private func lineCount() -> Int {
        var n = 0
        while app.otherElements["inspect-line-\(n + 1)"].exists { n += 1 }
        return n
    }

    private func rawRowCount() -> Int {
        var n = 0
        while app.staticTexts["inspect-raw-obs-\(n + 1)"].exists { n += 1 }
        return n
    }

    /// Every state goes through `ScreenshotRecorder.capture`, never `XCUIScreen.main.screenshot()`
    /// directly, so the mandatory >=3s settle cannot be skipped on one frame out of nine.
    private func capture(_ name: String, settle: TimeInterval = ScreenshotRecorder.defaultSettle) {
        XCTAssertEqual(app.state, .runningForeground,
                       "refusing to photograph '\(name)': the app is not in the foreground")
        ScreenshotRecorder.capture(name, settle: settle, in: self)
    }
}
