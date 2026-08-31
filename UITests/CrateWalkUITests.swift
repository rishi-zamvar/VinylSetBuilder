import CoreGraphics
import XCTest

/// **Phase 2's ship criterion, executable.** One linear XCUITest that walks the entire crate
/// flow against stubbed fixture data and photographs every state it passes through: list →
/// create → name → capture → detail → reorder → restore → Add More → remove vinyl → second
/// crate → delete crate → empty.
///
/// Two rules govern every assertion below, and both were paid for.
///
/// 1. **Assert on identifiers, never on display strings a later phase might reword.** Defect V1
///    changed "1 records" into "1 record" *while plan 02-02 was running*; that plan's test
///    survived only because it matched on fixture crate names. The one place a string is
///    unavoidable — `ordering-mode-label`, whose *value* is the thing under test — is handled by
///    capturing the label before the drag and asserting it *changed*, rather than hardcoding
///    "Custom order".
/// 2. **A test that passes must be provably able to fail.** Plan 02-02 nearly shipped a broad
///    `NSPredicate` matcher that went green while matching nothing. So the negative controls in
///    steps 1, 5 and 13 are deliberate: a query family that resolves a nonsense identifier, or a
///    set-membership check that is true of everything, is caught here rather than believed.
///
/// The identifier contract is 02-03's, measured against the live accessibility tree, not guessed:
/// rows are `staticTexts`, the two lists are `collectionViews`, and `new-crate-button`,
/// `back-to-crates-button` and `add-more-button` each publish TWO elements — so every query is
/// typed (`app.buttons[…]`) and a bare `descendants(matching: .any)[id]` would throw.
///
/// State resets on every launch (`AppModel` loads `FixtureCrates.demoStore` fresh; persistence is
/// Phase 13), so the walk may delete every crate at the end without poisoning the next run.
final class CrateWalkUITests: XCTestCase {

    private var app: XCUIApplication!

    /// The `edit-button` label with the list NOT in edit mode, read once rather than assumed to
    /// be "Edit" — so edit state is tracked without hardcoding either of its two captions.
    private var editLabelWhenInactive = ""

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: The walk

    func test_givenTheStubbedApp_whenTheWholeCrateFlowIsWalked_thenEveryStateRendersAndIsPhotographed() {
        app = XCUIApplication()
        app.launchFresh()

        // ---------------------------------------------------------------- 1. the crate list
        XCTAssertTrue(app.navigationBars["Crates"].waitForExistence(timeout: 20),
                      "the crate list's navigation bar never appeared")
        XCTAssertTrue(app.buttons["crate-row-Sunday Chill"].waitForExistence(timeout: 10),
                      "the Sunday Chill fixture crate row is missing")
        XCTAssertTrue(app.buttons["crate-row-Friday Warehouse"].exists,
                      "the Friday Warehouse fixture crate row is missing")

        // V1, closed by measurement. BOTH halves are required: `contains("1 record")` alone is
        // also true of the broken string "1 records", which is exactly how V1 survived once.
        let sundayCount = app.staticTexts["record-count-Sunday Chill"]
        XCTAssertTrue(sundayCount.waitForExistence(timeout: 10),
                      "record-count-Sunday Chill did not resolve as a staticText")
        XCTAssertTrue(sundayCount.label.contains("1 record"),
                      "V1: expected an inflected '1 record', got '\(sundayCount.label)'")
        XCTAssertFalse(sundayCount.label.contains("1 records"),
                       "V1 REGRESSED: '\(sundayCount.label)' is the un-inflected plural")

        // Negative control for the whole `record-count-*` query family. If this resolved, every
        // count assertion in this test would be matching something other than what it names.
        XCTAssertFalse(app.staticTexts["record-count-Wednesday Nonexistent"].exists,
                       "a nonsense record-count identifier resolved — the count queries are not discriminating")

        let fridayCountAtStart = recordCount(for: "Friday Warehouse")
        XCTAssertNotNil(fridayCountAtStart, "could not read a number out of record-count-Friday Warehouse")
        print("WALK record-count-Friday Warehouse at launch = \(app.staticTexts["record-count-Friday Warehouse"].label)")

        capture("02-walk-01-crate-list", settle: ScreenshotRecorder.launchSettle)

        // ------------------------------------------------------------- 2. the new-crate sheet
        app.buttons["new-crate-button"].tap()
        let nameField = app.textFields["new-crate-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "the new-crate sheet never appeared")
        nameField.tap()
        _ = app.keyboards.element.waitForExistence(timeout: 5)   // best effort; typing is asserted below
        nameField.typeText("Test Crate")
        XCTAssertEqual(nameField.value as? String, "Test Crate",
                       "the crate name field did not take the typed value")
        capture("02-walk-02-new-crate-sheet")

        // ------------------------------------------- 3. CRATE-02: create lands you in capture
        app.buttons["new-crate-create-button"].tap()
        let captureName = app.staticTexts["capture-crate-name"]
        XCTAssertTrue(captureName.waitForExistence(timeout: 10),
                      "CRATE-02: creating a crate did not route to the capture screen")
        XCTAssertEqual(captureName.label, "Test Crate",
                       "CRATE-02: capture opened on '\(captureName.label)', not the crate just created")
        capture("02-walk-03-capture-empty")

        // ------------------------------------------------------ 4. a real capture goes in
        // CHANGED BY PLAN 03-03, and deliberately stronger than what it replaces.
        // Phase 2 tapped the placeholder screen's Add-Fixture button, which died with that
        // screen; `capture-shutter-button` replaces it. The extra two assertions close
        // deferred item D-02-04-1: walk states 3 and 4 were byte-identical (md5 `6a903ce3`,
        // measured twice) because the old screen rendered NOTHING that reflected the crate's
        // contents. The thumbnail strip does, so the two states now differ by construction —
        // and the pair below is two-sided, where Phase 2 asserted nothing here at all.
        app.buttons["capture-shutter-button"].tap()
        XCTAssertTrue(app.buttons["capture-thumb-1"].waitForExistence(timeout: 10),
                      "CAP-03: the shutter put nothing in the thumbnail strip")
        XCTAssertFalse(app.buttons["capture-thumb-2"].exists,
                       "CAP-03: one shutter press produced more than one thumbnail")
        XCTAssertTrue(app.staticTexts["capture-crate-name"].exists,
                      "the shutter navigated away from capture")
        capture("02-walk-04-capture-with-vinyl")

        // ------------------------------- 5. CRATE-03: the new crate, and its order is EMPTY
        // CHANGED BY PLAN 03-03, and this one is also a strengthening. Nothing resolves in
        // Act I (D-03-5), so the vinyl the shutter just added carries real OCR text and no
        // BPM — the sequencer cannot schedule it, and it goes to the not-included bucket with
        // "No BPM yet". `sequenced-row-1` therefore CANNOT appear, and `empty-running-order`
        // must. Phase 2 could never reach that branch because its placeholder button added a
        // fully resolved fixture vinyl, which is exactly coverage gap V7. This assertion, and
        // the screenshot below it, close V7.
        app.buttons["capture-done-button"].tap()
        XCTAssertTrue(app.staticTexts["empty-running-order"].waitForExistence(timeout: 10),
                      "V7: the new crate shows neither a running order nor the empty-order placeholder")
        XCTAssertFalse(app.staticTexts["sequenced-row-1"].exists,
                       "CRATE-03: a vinyl with no BPM was sequenced anyway")
        XCTAssertTrue(app.buttons["not-included-section"].exists,
                      "SEQ-07: the un-sequenceable capture is missing from the not-included bucket")
        // Negative control for the `sequenced-row-*` family: rows are numbered one-based and
        // contiguous, so `sequencedRowLabels()` below relies on row 99 NOT existing. If a broad
        // matcher were resolving everything, this would resolve too.
        XCTAssertFalse(app.staticTexts["sequenced-row-99"].exists,
                       "a nonsense sequenced-row identifier resolved — row queries are not discriminating")
        capture("02-walk-05-new-crate-detail")

        // ------------------------------- 6. the fixture crate: sequenced order + SEQ-07 bucket
        app.buttons["back-to-crates-button"].tap()
        XCTAssertTrue(app.buttons["crate-row-Friday Warehouse"].waitForExistence(timeout: 10),
                      "back did not return to the crate list")
        app.buttons["crate-row-Friday Warehouse"].tap()

        let detailList = app.collectionViews["crate-detail-list"]
        XCTAssertTrue(detailList.waitForExistence(timeout: 10), "the crate detail list never appeared")
        XCTAssertTrue(app.staticTexts["sequenced-row-1"].waitForExistence(timeout: 10),
                      "CRATE-03: Friday Warehouse has no sequenced row 1")
        XCTAssertTrue(app.buttons["not-included-section"].exists,
                      "SEQ-07: the not-included bucket is missing from a crate that has excluded vinyls")

        // Captured, never hardcoded — the caption is the product's wording and this test refuses
        // to own it. Every later comparison is against THIS value.
        let runningOrderLabel = app.staticTexts["ordering-mode-label"].label
        XCTAssertFalse(runningOrderLabel.isEmpty, "ordering-mode-label rendered nothing")
        print("WALK ordering-mode-label (sequenced) = '\(runningOrderLabel)'")

        // For CRATE-07 at step 13. Recorded here, out of edit mode, because edit mode prefixes
        // every row label with "Remove, ".
        let fridayTitles = sequencedRowLabels()
        XCTAssertGreaterThanOrEqual(fridayTitles.count, 2,
                                    "the walk needs at least two sequenced rows to reorder; got \(fridayTitles.count)")
        print("WALK fridayTitles = \(fridayTitles)")
        capture("02-walk-06-crate-detail-sequenced")

        // ------------------------------------------------- 7. SEQ-07: the bucket, expanded
        let cellsCollapsed = detailList.cells.count
        let textsCollapsed = detailList.staticTexts.count
        app.buttons["not-included-section"].tap()
        XCTAssertTrue(detailList.cells.count > cellsCollapsed || detailList.staticTexts.count > textsCollapsed,
                      "SEQ-07: expanding the bucket revealed nothing")
        let cellsExpanded = detailList.cells.count
        let textsExpanded = detailList.staticTexts.count
        XCTAssertGreaterThan(cellsExpanded, cellsCollapsed,
                             "SEQ-07: the expanded bucket shows no more cells than the collapsed one")
        // A not-included row renders a label, two badges AND its reason line, so each revealed
        // cell must contribute more than one static text. One-text-per-cell would mean the rows
        // appeared without their reasons — which is the half of SEQ-07 that actually matters.
        XCTAssertGreaterThan(textsExpanded, textsCollapsed + (cellsExpanded - cellsCollapsed),
                             "SEQ-07: rows appeared but carry no reason line")
        print("WALK not-included collapsed cells=\(cellsCollapsed) texts=\(textsCollapsed) -> expanded cells=\(cellsExpanded) texts=\(textsExpanded)")
        capture("02-walk-07-not-included-expanded")

        // --------------------------------------------------------------- 8. edit mode is real
        editLabelWhenInactive = app.buttons["edit-button"].label
        let listButtonsBeforeEdit = detailList.buttons.count
        app.buttons["edit-button"].tap()
        XCTAssertNotEqual(app.buttons["edit-button"].label, editLabelWhenInactive,
                          "the edit control did not change state when tapped")
        // The caption flipping is not proof — 02-03 measured EditButton() flipping its own label
        // while the List stayed inactive. The affordances appearing is the proof.
        XCTAssertGreaterThan(detailList.buttons.count, listButtonsBeforeEdit,
                             "edit mode rendered no reorder/remove affordances — the List is not actually editing")
        print("WALK detail list buttons \(listButtonsBeforeEdit) -> \(detailList.buttons.count) on entering edit mode")
        capture("02-walk-08-detail-edit-mode")

        // ------------------------------------------------- 9/10. CRATE-04: override, then restore
        let drag = performReorderDrag()
        let recipe = drag.recipe
        // The recipes run in different edit modes and the first one to fire wins, so without
        // this the state photographed as 9 and 10 depends on WHICH recipe fired. Measured:
        // when recipe 2 (edit mode OFF) won, `02-walk-10-detail-restored` came back
        // byte-identical — 0 differing pixels — to `02-walk-07-not-included-expanded`, and the
        // audit's near-duplicate gate reddened on a pair that is only a duplicate by accident
        // of gesture routing. Edit mode ON is the state frame 8 established and the state the
        // committed 9/10 pair was photographed in.
        setEditMode(true)
        print("WALK DRAG RECIPE FIRED: \(recipe)")
        print("WALK row order BEFORE drag = \(drag.before)")
        print("WALK row order AFTER  drag = \(drag.after)")
        var stateCount = 15

        // Controls on the comparator every assertion below now rests on — V18 got through
        // because nobody asked whether the success signal could ever be false.
        // Negative: a list is not a permutation of itself.
        XCTAssertFalse(isReorder(from: drag.before, to: drag.before),
                       "the reorder comparator calls a list a permutation of ITSELF — it cannot fail")
        // Positive: it can still see a real one, so the negative above is not passing vacuously.
        XCTAssertTrue(isReorder(from: drag.before, to: Array(drag.before.reversed())),
                      "the reorder comparator cannot see a reversal — it cannot succeed either")
        // And the strip that makes those two controls meaningful actually fires. If a label
        // carried no position, `rowIdentities` would be the identity function and the check
        // above would be comparing POSITIONS rather than rows — which is the whole defect.
        XCTAssertNotEqual(rowIdentities(drag.before), drag.before,
                          "no position was stripped from \(drag.before) — the permutation check is comparing positions, not rows")

        if recipe == "none" {
            // Documented fallback. The gesture is not faked, the assertion is not deleted, and no
            // test-only hook is added to the shipping app: state 9 is dropped, the manifest is
            // recorded as fourteen states, and U8 goes into .planning/UAT-PENDING.md.
            stateCount = 14
            XCTAssertFalse(app.buttons["restore-sequenced-order-button"].exists,
                           "no drag recipe fired, yet a manual order exists — the walk lost track of state")
            XCTAssertEqual(drag.after, drag.before,
                           "no drag recipe fired, yet the row order moved — the walk lost track of state")
        } else {
            // V18. The ROW ORDER is the assertion; the button and the header are corroboration.
            // All three are kept, and this one is first, because it is the one that failed.
            XCTAssertTrue(isReorder(from: drag.before, to: drag.after),
                          "CRATE-04: recipe '\(recipe)' reported success but \(drag.after) is not a permutation of \(drag.before)")
            // Re-measured at the moment of photography, not only at the moment of the drag: the
            // frame is the artefact, so the frame's own state is what has to be asserted.
            XCTAssertTrue(isReorder(from: drag.before, to: sequencedRowLabels()),
                          "CRATE-04: the rows are back in the sequencer's order at the instant this frame is photographed")
            XCTAssertTrue(app.buttons["restore-sequenced-order-button"].exists,
                          "CRATE-04: the drag reordered nothing")
            XCTAssertNotEqual(app.staticTexts["ordering-mode-label"].label, runningOrderLabel,
                              "CRATE-04: the header still reads '\(runningOrderLabel)' after a manual reorder")
            print("WALK ordering-mode-label (manual) = '\(app.staticTexts["ordering-mode-label"].label)'")
            capture("02-walk-09-detail-manual-order")

            app.buttons["restore-sequenced-order-button"].tap()
            XCTAssertTrue(app.buttons["restore-sequenced-order-button"].waitForNonExistence(timeout: 5),
                          "CRATE-04: Restore did not clear the manual order")
            XCTAssertEqual(app.staticTexts["ordering-mode-label"].label, runningOrderLabel,
                           "CRATE-04: Restore did not put the header back to the sequencer's order")
            // And the rows, not only the header — the same omission, on the other side of the
            // round trip. Polled, because the button vanishing and the list settling back are
            // not the same frame.
            var restored = rowIdentities(sequencedRowLabels())
            let want = rowIdentities(drag.before)
            let restoreDeadline = Date().addingTimeInterval(3)
            while restored != want && Date() < restoreDeadline {
                Thread.sleep(forTimeInterval: 0.25)
                restored = rowIdentities(sequencedRowLabels())
            }
            XCTAssertEqual(restored, want,
                           "CRATE-04: Restore put the header back but left the rows at \(restored)")
        }
        capture("02-walk-10-detail-restored")

        // ------------------------------------------- 11. CRATE-05: Add More, on the SAME crate
        setEditMode(false)
        app.buttons["add-more-button"].tap()
        let addMoreName = app.staticTexts["capture-crate-name"]
        XCTAssertTrue(addMoreName.waitForExistence(timeout: 10),
                      "CRATE-05: Add More did not reach the capture screen")
        XCTAssertEqual(addMoreName.label, "Friday Warehouse",
                       "CRATE-05: Add More opened '\(addMoreName.label)' — a different crate, or a new one")
        capture("02-walk-11-add-more-capture")

        // ------------------------------------------------------- 12. CRATE-06: remove a vinyl
        app.buttons["capture-done-button"].tap()
        XCTAssertTrue(detailList.waitForExistence(timeout: 10), "Done did not return to the crate detail")
        let rowsBeforeRemoval = sequencedRowLabels().count
        XCTAssertGreaterThan(rowsBeforeRemoval, 0, "nothing to remove — the running order is empty")
        swipeDelete(app.staticTexts["sequenced-row-1"])
        let rowsAfterRemoval = sequencedRowLabels().count
        XCTAssertEqual(rowsAfterRemoval, rowsBeforeRemoval - 1,
                       "CRATE-06: the running order went from \(rowsBeforeRemoval) to \(rowsAfterRemoval) rows")
        capture("02-walk-12-detail-after-remove-vinyl")

        // ----------------------------------- 13. CRATE-07 + SEQ-11: the same vinyl, elsewhere
        app.buttons["back-to-crates-button"].tap()
        XCTAssertTrue(app.buttons["crate-row-Sunday Chill"].waitForExistence(timeout: 10),
                      "back did not return to the crate list")

        // The list's count followed the removal. Compared against what was read at step 1, never
        // against a hardcoded 4 and 3 — the fixture is allowed to grow.
        let fridayCountAfter = recordCount(for: "Friday Warehouse")
        XCTAssertEqual(fridayCountAfter, fridayCountAtStart.map { $0 - 1 },
                       "CRATE-06: the crate list count went \(String(describing: fridayCountAtStart)) -> \(String(describing: fridayCountAfter))")

        app.buttons["crate-row-Sunday Chill"].tap()
        XCTAssertTrue(app.staticTexts["sequenced-row-1"].waitForExistence(timeout: 10),
                      "Sunday Chill has no running order")
        let sundayRows = sequencedRowLabels()
        XCTAssertEqual(sundayRows.count, 1, "Sunday Chill should hold exactly the one shared vinyl")
        let sundayRow = sundayRows[0]
        print("WALK sundayRow = '\(sundayRow)'")

        // CRATE-07. Both crates hold the SAME physical vinyl; only the per-crate pin differs. If
        // the pin were ignored, this row would render identically to Friday's Photek row and the
        // membership check below would find it.
        XCTAssertFalse(fridayTitles.contains(sundayRow),
                       "CRATE-07: '\(sundayRow)' also appears in Friday Warehouse — the per-crate selection is not being honoured")
        // Positive control for that very check: the same containment test, applied to something
        // that IS in the set, must succeed. Without this, an always-false `contains` would pass.
        XCTAssertTrue(fridayTitles.contains(fridayTitles[0]),
                      "the fridayTitles membership check is vacuous — it fails even on its own members")

        // SEQ-11. `.accessibilityElement(children: .combine)` joins the row's four Texts with
        // ", ", so the last two components are the BPM and Camelot badges. Neither may be the
        // em-dash placeholder on a fully resolved track.
        let parts = sundayRow.components(separatedBy: ", ")
        XCTAssertGreaterThanOrEqual(parts.count, 3, "SEQ-11: '\(sundayRow)' carries no badge pair")
        let badges = parts.suffix(2)
        for badge in badges {
            XCTAssertFalse(badge.isEmpty, "SEQ-11: a badge rendered as an empty string")
            XCTAssertNotEqual(badge, "\u{2014}",
                              "SEQ-11: '\(sundayRow)' shows the placeholder for a resolved track")
        }
        print("WALK sunday badges = \(Array(badges))")
        capture("02-walk-13-second-crate-different-selection")

        // ----------------------------------------------------- 14. CRATE-06: delete one crate
        app.buttons["back-to-crates-button"].tap()
        XCTAssertTrue(app.buttons["crate-row-Test Crate"].waitForExistence(timeout: 10),
                      "the crate created in step 2 is missing from the list")
        swipeDelete(app.buttons["crate-row-Test Crate"])
        XCTAssertTrue(app.buttons["crate-row-Test Crate"].waitForNonExistence(timeout: 5),
                      "CRATE-06: the deleted crate is still on the list")
        XCTAssertTrue(app.buttons["crate-row-Sunday Chill"].exists,
                      "CRATE-06: deleting one crate removed Sunday Chill too")
        XCTAssertTrue(app.buttons["crate-row-Friday Warehouse"].exists,
                      "CRATE-06: deleting one crate removed Friday Warehouse too")
        capture("02-walk-14-crate-list-after-delete")

        // ------------------------------------------------------------------ 15. the empty state
        for name in ["Sunday Chill", "Friday Warehouse"] {
            swipeDelete(app.buttons["crate-row-\(name)"])
            XCTAssertTrue(app.buttons["crate-row-\(name)"].waitForNonExistence(timeout: 5),
                          "CRATE-06: \(name) survived its delete")
        }
        // Identifier-based and primary: no crate row of any fixture name remains.
        for name in ["Sunday Chill", "Friday Warehouse", "Test Crate"] {
            XCTAssertFalse(app.buttons["crate-row-\(name)"].exists, "\(name) is still on an emptied list")
        }
        XCTAssertTrue(app.staticTexts["No Crates Yet"].waitForExistence(timeout: 10),
                      "the empty state did not appear once every crate was deleted")
        capture("02-walk-15-crate-list-empty")

        print("WALK COMPLETE — recorded state count = \(stateCount)")
    }

    // MARK: Queries

    /// One-based and contiguous by construction (`CrateRows.make` numbers them by `enumerated()`),
    /// so walking upward until a row is absent counts the running order exactly — and it counts
    /// it through the frozen identifiers rather than through cell geometry, which edit mode
    /// changes and a later phase may restyle.
    private func sequencedRowLabels() -> [String] {
        var labels: [String] = []
        var index = 1
        while app.staticTexts["sequenced-row-\(index)"].exists {
            labels.append(app.staticTexts["sequenced-row-\(index)"].label)
            index += 1
        }
        return labels
    }

    /// The leading integer of e.g. "4 records". Only the number is read — the noun is the
    /// product's wording, and V1 already proved it changes underneath a test that reads it.
    private func recordCount(for crateName: String) -> Int? {
        let element = app.staticTexts["record-count-\(crateName)"]
        guard element.waitForExistence(timeout: 10) else { return nil }
        return Int(element.label.prefix { $0.isNumber })
    }

    // MARK: Gestures

    /// A swipe-to-delete that tolerates SwiftUI's full-swipe shortcut: a long synthesised swipe
    /// sometimes commits the destructive action outright and never renders a button to tap.
    /// Both outcomes are the same delete, so the button tap is conditional and the CALLER
    /// asserts the row is gone.
    private func swipeDelete(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "nothing to swipe-delete")
        element.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        if delete.waitForExistence(timeout: 3) { delete.tap() }
    }

    /// CRATE-04's gesture, which is the flakiest thing in this walk. Recipes are tried in
    /// order and stopped at the FIRST one that takes effect — two successful drags on a
    /// two-row list return it to where it started, and the assertion then fails for the
    /// opposite reason. Returns the recipe that fired, for the record.
    /// Returns the recipe that fired, and the row order either side of it, for the record AND
    /// for the caller's assertions. The pre-drag order is re-read immediately before EVERY
    /// attempt rather than once at the top: edit mode prefixes every row label with "Remove, ",
    /// and recipe 2 toggles it, so one `before` captured in the wrong mode would make every
    /// comparison below a comparison of two different label formats.
    private func performReorderDrag() -> (recipe: String, before: [String], after: [String]) {
        let first = app.staticTexts["sequenced-row-1"]
        let second = app.staticTexts["sequenced-row-2"]

        // 1. The exact gesture 02-03 measured working, with the List in edit mode.
        var before = sequencedRowLabels()
        first.press(forDuration: 1.0, thenDragTo: second)
        if reorderTookEffect(from: before) {
            return ("1: press-and-drag on the row, edit mode ON", before, sequencedRowLabels())
        }

        // 2. 02-03's measured configuration exactly: the same gesture with edit mode OFF, where
        //    a long press on the row body is itself the drag handle.
        setEditMode(false)
        before = sequencedRowLabels()
        first.press(forDuration: 1.0, thenDragTo: second)
        if reorderTookEffect(from: before) {
            return ("2: press-and-drag on the row, edit mode OFF", before, sequencedRowLabels())
        }

        // 3. Aim at the reorder handle on the trailing edge rather than the row's middle.
        setEditMode(true)
        before = sequencedRowLabels()
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
            .press(forDuration: 1.2,
                   thenDragTo: second.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.2)))
        if reorderTookEffect(from: before) {
            return ("3: coordinate drag onto the trailing-edge handle", before, sequencedRowLabels())
        }

        // 4. Drag PAST the target instead of onto it — SwiftUI reorders on crossing the
        //    midpoint, and landing exactly on the boundary is a coin flip.
        before = sequencedRowLabels()
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
            .press(forDuration: 1.2,
                   thenDragTo: second.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 1.6)))
        if reorderTookEffect(from: before) {
            return ("4: coordinate drag past the target", before, sequencedRowLabels())
        }

        return ("none", before, sequencedRowLabels())
    }

    /// A row's accessibility label leads with its POSITION — `"Remove, 1, Source Direct —
    /// Snake Style, 170, 5A"` — because `sequenced-row-N` is numbered by `indexLabel`, and
    /// `indexLabel` renumbers 1…N in the new order after every move. So a genuine swap changes
    /// the *text of every label*, not just their order, and a multiset comparison of raw labels
    /// sees two disjoint sets and reports no permutation. Measured, not reasoned about: with
    /// the raw labels this walk fired all four drag recipes on a two-row list, swapped it four
    /// times, and reported `recipe: none` over a committed manual order.
    ///
    /// Stripping the first all-digit component leaves what actually identifies the row. The BPM
    /// badge is also all digits, so `firstIndex` matters — the position comes first.
    ///
    /// A leading "Remove" goes too: that is edit mode's delete affordance joining the combined
    /// label, not part of the row. Without it, an order read in edit mode could never be
    /// compared with one read out of it — and the drag recipes run in both.
    ///
    /// Order is preserved, so equality of two identity arrays means the same rows in the same
    /// order, and this is a safe comparator for the restore round-trip as well as the drag.
    private func rowIdentities(_ labels: [String]) -> [String] {
        labels.map { label in
            var parts = label.components(separatedBy: ", ")
            if parts.first == "Remove" { parts.removeFirst() }
            if let i = parts.firstIndex(where: { !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
                parts.remove(at: i)
            }
            return parts.joined(separator: ", ")
        }
    }

    /// A genuine reorder and nothing else: the **same rows, in a different order**.
    ///
    /// Deliberately not a bare `after != before`. A drag that deleted a row satisfies that, and
    /// so does a tree read mid-animation with a row briefly missing — neither is a reorder, and
    /// treating them as one would put the wrong frame in `Artifacts/screenshots/` again. Pure,
    /// and separate from the query, so the walk can run a control on the comparator itself.
    private func isReorder(from before: [String], to after: [String]) -> Bool {
        let b = rowIdentities(before), a = rowIdentities(after)
        return !b.isEmpty && a != b && a.sorted() == b.sorted()
    }

    /// **V18.** This used to ask whether `restore-sequenced-order-button` EXISTS. That button
    /// appears whenever a manual order is committed — which, before the `moveRows` identity
    /// guard, happened on a drag that reordered nothing. So the walk photographed the SEQUENCED
    /// order under a "Custom order" header and still reported 7 passed / 0 failed, on 2 of 3
    /// clean runs, and `screenshots.sh` exited 1 both times. A presence assertion was standing
    /// where a measurement belongs.
    ///
    /// It now measures the row order, and the poll still doubles as the settle the reorder
    /// animation needs — the timeout is unchanged at 3s.
    private func reorderTookEffect(from before: [String]) -> Bool {
        let deadline = Date().addingTimeInterval(3)
        repeat {
            if isReorder(from: before, to: sequencedRowLabels()) { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return isReorder(from: before, to: sequencedRowLabels())
    }

    /// Edit state is read off the caption *relative to* the one recorded when the list was known
    /// inactive, so neither "Edit" nor "Done" is hardcoded here.
    private func setEditMode(_ wanted: Bool) {
        let button = app.buttons["edit-button"]
        guard button.exists, !editLabelWhenInactive.isEmpty else { return }
        if (button.label != editLabelWhenInactive) != wanted { button.tap() }
    }

    // MARK: Capture

    /// Every state goes through `ScreenshotRecorder`, never `XCUIScreen.main.screenshot()`
    /// directly — the mandatory >=3s settle from `.planning/VISUAL-DEFECTS.md` lives in exactly
    /// one place so it cannot be forgotten on one state out of fifteen.
    private func capture(_ name: String, settle: TimeInterval = ScreenshotRecorder.defaultSettle) {
        XCTAssertEqual(app.state, .runningForeground,
                       "refusing to photograph '\(name)': the app is not in the foreground")
        ScreenshotRecorder.capture(name, settle: settle, in: self)
    }
}

private extension XCUIElement {
    /// `waitForExistence`'s missing opposite: an absence assertion that gives the UI time to
    /// animate the element away, instead of reading `.exists` the instant after a tap.
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !exists { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return !exists
    }
}
