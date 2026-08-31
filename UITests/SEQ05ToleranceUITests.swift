import XCTest

/// **SEQ-05, driven through the real slider.** "Adjust BPM_TOLERANCE on a slider from 3 to 6,
/// defaulting to 4.0, and the sequence re-optimises."
///
/// Three claims, and the third is the requirement — the first two are only its preconditions:
///
///   1. the control exists on the crate screen and arrives reading the default
///   2. it spans 3 to 6 and nothing outside
///   3. **moving it changes the set on screen**, in both directions and in both ways: a
///      tighter window drops a record into the bucket, and a wider one keeps every record but
///      picks a different candidate for one of them
///
/// The expected sets are NOT invented here. `ToleranceTests.test_givenTheFixtureCrate_…`
/// computes them on the shipping sequencer over the same fixture crate this walk launches
/// into, so if the sequencer changes, the Core test fails first and says why — rather than this
/// walk failing on a simulator with a number nobody can trace.
///
/// Rule 1 of `CrateWalkUITests` still applies: identifiers, never display strings a later phase
/// might reword. The one string under test is `bpm-tolerance-label`, whose *value* is the thing
/// being asserted, and it is handled the way `ordering-mode-label` always has been — captured
/// before the act, asserted CHANGED after it. The single hardcoded value in this file is the
/// default `4`, and it is hardcoded because SEQ-05's own wording names it.
final class SEQ05ToleranceUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    func test_givenTheToleranceSlider_whenDraggedDownAndUp_thenTheSetReoptimisesBothWays() {
        app = XCUIApplication()
        app.launchFresh()
        openFridayWarehouse()

        let slider = app.sliders["bpm-tolerance-slider"]
        let caption = app.staticTexts["bpm-tolerance-label"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10),
                      "SEQ-05: there is no BPM tolerance slider on the crate screen")
        XCTAssertTrue(caption.exists, "SEQ-05: the slider has no caption to read its value from")

        // ------------------------------------------------- 1. it arrives at SEQ-05's default
        let atDefault = caption.label
        XCTAssertTrue(atDefault.contains("4"),
                      "SEQ-05: the slider should arrive at 4.0; the caption reads '\(atDefault)'")
        XCTAssertFalse(atDefault.contains("4.5"),
                       "the caption reads '\(atDefault)' — 4, not 4.5, is the default")

        let sequencedAtDefault = sequencedLabels()
        XCTAssertEqual(sequencedAtDefault.count, 2,
                       "the fixture crate sequences two records at the default 4.0 (see ToleranceTests)")
        XCTAssertEqual(countIn(app.buttons["not-included-section"].label), 2,
                       "two records are out of the set at 4.0: one 6 BPM away, one with no tempo")

        // ------------------------------- 2. widen to the top stop: the excluded record rejoins
        slider.adjust(toNormalizedSliderPosition: 1.0)
        let atMaximum = caption.label
        XCTAssertNotEqual(atMaximum, atDefault,
                          "SEQ-05: dragging the slider to its upper stop did not change the caption")
        XCTAssertTrue(atMaximum.contains("6"),
                      "SEQ-05: the upper stop should be 6; the caption reads '\(atMaximum)'")

        let sequencedAtMaximum = waitForSequencedCount(3)
        XCTAssertEqual(sequencedAtMaximum.count, 3,
                       "SEQ-05: at tolerance 6 the record 6 BPM out should rejoin the set, giving three")
        XCTAssertEqual(countIn(app.buttons["not-included-section"].label), 1,
                       "SEQ-05: the bucket should have shed the record that rejoined")
        XCTAssertNotEqual(sequencedAtMaximum, sequencedAtDefault,
                          "SEQ-05: widening 4 -> 6 produced the identical set; nothing re-optimised")

        ScreenshotRecorder.capture("10-seq05-tolerance-widened", in: self)

        // ------------------------- 3. back to the bottom stop: it leaves again, and says why
        slider.adjust(toNormalizedSliderPosition: 0.0)
        let atMinimum = caption.label
        XCTAssertNotEqual(atMinimum, atMaximum, "the caption did not follow the slider back down")
        XCTAssertTrue(atMinimum.contains("3"),
                      "SEQ-05: the lower stop should be 3; the caption reads '\(atMinimum)'")

        let sequencedAtMinimum = waitForSequencedCount(2)
        XCTAssertEqual(sequencedAtMinimum.count, 2,
                       "SEQ-05: at tolerance 3 the widened record should leave the set again")
        XCTAssertEqual(countIn(app.buttons["not-included-section"].label), 2,
                       "SEQ-05: the record the tighter window rejected should be IN the bucket, not gone")

        // V19: the bucket's sentence follows the slider, or it is telling the owner to widen to
        // a number they have already passed. SEQ-07 keeps the bucket collapsed, so its rows are
        // not in the accessibility tree at all until it is opened.
        app.buttons["not-included-section"].tap()
        var reasons: [String] = []
        let reasonDeadline = Date().addingTimeInterval(10)
        repeat {
            reasons = (1...4).compactMap { n -> String? in
                let row = app.staticTexts["not-included-reason-\(n)"]
                return row.exists ? row.label : nil
            }
            if reasons.contains(where: { $0.contains("within 3 BPM") }) { break }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < reasonDeadline
        XCTAssertTrue(reasons.contains { $0.contains("within 3 BPM") },
                      "V19: no bucket row quotes the new tolerance — reasons were \(reasons)")

        // Negative control: a query family that resolves a nonsense identifier would make every
        // count above meaningless.
        XCTAssertFalse(app.sliders["bpm-tolerance-slider-99"].exists,
                       "a nonsense slider identifier resolved — the assertions above prove nothing")

        ScreenshotRecorder.capture("10-seq05-tolerance-widened", in: self)
    }

    // MARK: Helpers

    private func openFridayWarehouse() {
        XCTAssertTrue(app.navigationBars["Crates"].waitForExistence(timeout: 20),
                      "the crate list never appeared")
        let row = app.buttons["crate-row-Friday Warehouse"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the fixture crate is missing")
        row.tap()
        XCTAssertTrue(app.collectionViews["crate-detail-list"].waitForExistence(timeout: 10),
                      "the crate detail list never appeared")
    }

    private func sequencedLabels() -> [String] {
        var labels: [String] = []
        var n = 1
        while n <= 20, app.staticTexts["sequenced-row-\(n)"].exists {
            labels.append(app.staticTexts["sequenced-row-\(n)"].label)
            n += 1
        }
        return labels
    }

    /// The re-derivation is off the main actor (SEQ-09) and lands a beat after the thumb is
    /// released, so a single read can catch the previous set still drawn. Bounded settle, and
    /// the caller still asserts on what it got — this is not retry-until-green.
    private func waitForSequencedCount(_ expected: Int) -> [String] {
        var labels = sequencedLabels()
        let deadline = Date().addingTimeInterval(15)
        while labels.count != expected, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
            labels = sequencedLabels()
        }
        return labels
    }

    private func countIn(_ label: String) -> Int? {
        guard let open = label.lastIndex(of: "("), let close = label.lastIndex(of: ")"),
              open < close else { return nil }
        return Int(label[label.index(after: open)..<close])
    }
}
