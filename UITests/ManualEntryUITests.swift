import XCTest

/// **MAN-01, MAN-02, MAN-03, MAN-04 and MAN-05 driven through the real UI.**
///
/// MAN-01's "under 15 seconds" is measured here as an **interaction count**, not with a
/// stopwatch, because a stopwatch on a simulator measures the simulator. The count is what the
/// design controls; the per-interaction cost is stated so the 15-second claim is arithmetic
/// anyone can redo. The wall clock is printed as well, but as a sanity check on the count, not
/// as the claim.
///
/// **The cost model, stated once and used for every number this file prints:**
///
/// | Interaction | Cost | Where the figure comes from |
/// | --- | --- | --- |
/// | one tap on a control already on screen | **1.0 s** | conservative: measured phone-UI tap-to-target times sit at 0.6–1.0 s; the top of that band is used |
/// | one keystroke on the software keyboard | **0.3 s** | conservative against typical thumb-typing rates of 25–40 wpm |
/// | one sheet presentation | **0.5 s** | the animation, which the typist waits through once |
///
/// Nothing here is a stopwatch reading dressed up as a design property. If the count changes,
/// the claim changes with it.
final class ManualEntryUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Everything the count is made of, tallied as the walk goes so the printed total cannot
    /// drift from what the test actually did.
    private var taps = 0
    private var keystrokes = 0
    private var sheets = 0

    private func tap(_ element: XCUIElement, _ what: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(what) never appeared")
        element.tap()
        taps += 1
    }

    private func type(_ element: XCUIElement, _ text: String) {
        element.typeText(text)
        keystrokes += text.count
    }

    /// One tap, not one keystroke per character. Counted as a tap, because that is what it is.
    private func clear(_ identifier: String) {
        tap(app.buttons["\(identifier)-clear"], "\(identifier)-clear")
    }

    private var costedSeconds: Double {
        Double(taps) * 1.0 + Double(keystrokes) * 0.3 + Double(sheets) * 0.5
    }

    override func setUp() {
        continueAfterFailure = false
        taps = 0
        keystrokes = 0
        sheets = 0
    }

    // MARK: - MAN-05 half one: from the sequenced list

    func test_givenASequencedRow_whenTappedAndAllFourFieldsEdited_thenTheRowChangesInsideTheBudget() {
        app = XCUIApplication()
        app.launchFresh()
        openFridayWarehouse()

        let before = app.staticTexts["sequenced-row-1"].label
        XCTAssertFalse(before.isEmpty, "sequenced-row-1 rendered nothing to compare against")

        let started = Date()

        // MAN-05: the row IS the affordance. One tap, no mode, no menu, no long press.
        tap(app.staticTexts["sequenced-row-1"], "sequenced-row-1")
        XCTAssertTrue(app.otherElements["manual-entry-sheet"].waitForExistence(timeout: 10),
                      "MAN-05: tapping a sequenced row did not open the hand-entry sheet")
        sheets += 1

        // MAN-03, asserted rather than assumed: the tempo field is NOT empty on arrival.
        let bpmField = app.textFields["manual-bpm-field"]
        XCTAssertTrue(bpmField.waitForExistence(timeout: 5), "the BPM field is missing")
        let prefilled = (bpmField.value as? String) ?? ""
        XCTAssertFalse(prefilled.isEmpty, "MAN-03: the tempo field arrived empty")
        XCTAssertNotNil(Double(prefilled), "MAN-03: the prefill '\(prefilled)' is not a number")
        print("MAN-03 prefill = '\(prefilled)'")

        editAllFourFields(artist: "Hand Typed", title: "By Ear")

        tap(app.buttons["manual-save-button"], "manual-save-button")

        let elapsed = Date().timeIntervalSince(started)

        // The row must actually change. Comparing against the captured `before` rather than a
        // hardcoded string, for the same reason the crate walk does: this test refuses to own
        // the product's wording.
        let row = app.staticTexts["sequenced-row-1"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the sequenced list did not come back")
        let after = firstRowLabelContaining("Hand Typed")
        XCTAssertNotNil(after, "MAN-01: nothing in the running order carries the typed artist")
        XCTAssertNotEqual(after, before, "the row did not change")
        print("MAN-01 sequenced-list edit: taps=\(taps) keystrokes=\(keystrokes) sheets=\(sheets) "
              + "costed=\(String(format: "%.1f", costedSeconds))s wallclock=\(String(format: "%.1f", elapsed))s")
        XCTAssertLessThan(costedSeconds, 15.0,
                          "MAN-01: \(taps) taps + \(keystrokes) keystrokes costs "
                          + "\(String(format: "%.1f", costedSeconds))s, over the 15 s budget")

        capture("09-manual-01-after-sequenced-edit")

        // MAN-04 on screen, and PERS-01's first observation in one step: leave the crate, come
        // back, and the typed value is still there — through a full re-sequence AND through the
        // automatic resolution pass that `.task` fires on arrival.
        tap(app.buttons["back-to-crates-button"], "back-to-crates-button")
        tap(app.buttons["crate-row-Friday Warehouse"], "crate-row-Friday Warehouse")
        XCTAssertNotNil(firstRowLabelContaining("Hand Typed"),
                        "MAN-04: the typed artist did not survive a re-sequence and a resolution pass")

        // PERS-01, observation one: kill the process and relaunch WITHOUT the reset token.
        app.terminate()
        app.launchArguments = []
        app.launch()
        openFridayWarehouse()
        XCTAssertNotNil(firstRowLabelContaining("Hand Typed"),
                        "PERS-01: the hand-typed track did not survive terminate and relaunch")
        capture("09-manual-02-after-relaunch")
    }

    // MARK: - MAN-05 half two: from the not-included bucket

    func test_givenANotIncludedRow_whenTappedAndGivenATempo_thenItIsEditableAndCanRejoin() {
        app = XCUIApplication()
        app.launchFresh()
        openFridayWarehouse()

        let sequencedBefore = countIn(app.staticTexts["ordering-mode-label"].label)
        XCTAssertNotNil(sequencedBefore, "could not read a count out of ordering-mode-label")

        tap(app.buttons["not-included-section"], "not-included-section")
        let bucketRow = app.staticTexts["not-included-reason-1"]
        XCTAssertTrue(bucketRow.waitForExistence(timeout: 10),
                      "SEQ-07: the bucket expanded but carries no reason line")
        // V19 on screen: whatever this row says, it is one of the four terminal causes and not
        // a rung's note. Asserted as "it names a cause the four-string table contains".
        let reason = bucketRow.label
        print("V19 bucket reason on screen = '\(reason)'")
        XCTAssertTrue(["No BPM yet", "No track within", "No identity to look up",
                       "No SoundCloud upload matched"].contains { reason.hasPrefix($0) },
                      "V19: '\(reason)' is not one of the four terminal causes")
        capture("09-manual-03-bucket-expanded")

        // MAN-05: the bucket row is an affordance too. This is the half that matters — after the
        // last live run 9 of 12 records were in here and none of them was correctable.
        // The row publishes as an accessibility CONTAINER (`.contain`, so the badge pair keeps
        // its own element and stays screenshot-able), which means it is not a `staticText`.
        // Tapping its reason line lands inside the container and fires the row's own gesture —
        // and `not-included-reason-1` is an identifier the crate walk already proves resolves.
        tap(app.staticTexts["not-included-reason-1"], "not-included-row-1 (via its reason line)")
        XCTAssertTrue(app.otherElements["manual-entry-sheet"].waitForExistence(timeout: 10),
                      "MAN-05: tapping a not-included row did not open the hand-entry sheet")
        sheets += 1
        capture("09-manual-04-sheet-from-bucket")

        // Give it a tempo the set can actually reach. The fixture crate runs 170–174 at the
        // default 4.0 tolerance, so 172 is inside the window from either end.
        // The tempo field has no clear button — it is never empty by design (MAN-03) and a
        // cleared tempo field is not a state this sheet wants to offer. Three deletes.
        let bpmField = app.textFields["manual-bpm-field"]
        tap(bpmField, "manual-bpm-field")
        let existing = ((bpmField.value as? String) ?? "").count
        bpmField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing))
        keystrokes += existing
        type(bpmField, "172")

        // MAN-02: ONE tap for a key, out of 24. Not two, and certainly not three keystrokes.
        tap(app.buttons["manual-key-8A"], "manual-key-8A")
        tap(app.buttons["manual-save-button"], "manual-save-button")

        XCTAssertTrue(app.staticTexts["ordering-mode-label"].waitForExistence(timeout: 10),
                      "the crate screen did not come back after saving")
        // SEQ-08's rejoin, driven from the hand-entry path: a record given a tempo by hand is a
        // record the sequencer may now be able to place, and membership is re-derived in full.
        let sequencedAfter = countIn(app.staticTexts["ordering-mode-label"].label)
        print("MAN-05 bucket edit: running order \(sequencedBefore ?? -1) -> \(sequencedAfter ?? -1), "
              + "taps=\(taps) keystrokes=\(keystrokes) costed=\(String(format: "%.1f", costedSeconds))s")
        XCTAssertEqual(sequencedAfter, (sequencedBefore ?? 0) + 1,
                       "a record given a tempo by hand did not rejoin the running order")
        capture("09-manual-05-rejoined")
    }

    // MARK: - Helpers

    private func openFridayWarehouse() {
        XCTAssertTrue(app.navigationBars["Crates"].waitForExistence(timeout: 30),
                      "the crate list never appeared")
        let row = app.buttons["crate-row-Friday Warehouse"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the fixture crate is missing")
        row.tap()
        XCTAssertTrue(app.collectionViews["crate-detail-list"].waitForExistence(timeout: 10),
                      "the crate detail list never appeared")
    }

    /// The full four-field correction MAN-01 is measured on.
    private func editAllFourFields(artist: String, title: String) {
        // Tempo and key FIRST, because that is the order the sheet lays them out and the order
        // a DJ supplies them in — and because doing them before the keyboard comes up keeps the
        // 24-code grid on screen. One tap, from a prefill that is already a neighbour's tempo
        // (MAN-03): the realistic correction, and the reason the steppers exist.
        tap(app.buttons["manual-bpm-plus"], "manual-bpm-plus")
        // MAN-02: one tap out of the 24-code grid.
        tap(app.buttons["manual-key-9B"], "manual-key-9B")

        clear("manual-artist-field")
        let artistField = app.textFields["manual-artist-field"]
        tap(artistField, "manual-artist-field")
        type(artistField, artist)

        clear("manual-title-field")
        let titleField = app.textFields["manual-title-field"]
        tap(titleField, "manual-title-field")
        type(titleField, title)

    }

    private func firstRowLabelContaining(_ needle: String) -> String? {
        for index in 1...12 {
            let row = app.staticTexts["sequenced-row-\(index)"]
            guard row.exists else { continue }
            if row.label.contains(needle) { return row.label }
        }
        return nil
    }

    /// Pulls the parenthesised count out of "Running order (3)" without owning the caption.
    private func countIn(_ label: String) -> Int? {
        guard let open = label.lastIndex(of: "("), let close = label.lastIndex(of: ")"),
              open < close else { return nil }
        return Int(label[label.index(after: open)..<close])
    }

    @discardableResult
    private func capture(_ name: String) -> URL? {
        ScreenshotRecorder.capture(name, in: self)
    }
}
