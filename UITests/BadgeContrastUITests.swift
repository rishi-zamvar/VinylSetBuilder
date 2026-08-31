import UIKit
import XCTest

/// **Defect V4, measured on real pixels rather than judged by eye.**
///
/// SEQ-11's rule is that a missing value is *dimmed, never hidden*. That is two claims pulling
/// in opposite directions, and satisfying either one alone is not closing the defect:
///
/// 1. the placeholder badge must be legible — `contrast >= CONTRAST_MIN`
/// 2. it must still read as quieter than a complete one — `contrast(complete) > contrast(placeholder)`
///
/// Both are asserted below on element screenshots, so the crop IS the badge pair and no
/// coordinate arithmetic enters the measurement. The same PNGs are written out to the runner's
/// Documents directory, carried onto the host by `Scripts/collect-screenshots.sh`, and are
/// independently re-measurable with
/// `python3 Scripts/probe-frames.py --ink 128 Artifacts/screenshots/04-badge-*.png` — two
/// independent measurement paths over one set of pixels, which is what the two-observation rule
/// in `.planning/VISUAL-DEFECTS.md` asks for.
///
/// The luminance convention is deliberately `PIL.Image.convert("L")`'s — ITU-R 601-2, rounded —
/// so a number printed here and a number printed by `probe-frames.py` mean the same thing.
final class BadgeContrastUITests: XCTestCase {

    /// **Fixed in advance, before a single badge was measured, and never re-fitted.**
    /// If a fix lands at 58, the fix is wrong, not the threshold. Moving a bar to make a frame
    /// pass is the rule defect V2 left behind, and it applies to this file's own bar.
    private static let contrastMin = 60

    /// Pixels strictly darker than this count as ink. Same value `probe-frames.py --ink 128` is
    /// invoked with everywhere in this repo's history.
    private static let inkThreshold = 128

    /// **WCAG 2.2 §1.4.3 (Contrast, Minimum), AA, text below 18 pt.** The badge font is
    /// `.caption`, which is 12 pt, so this is the applicable row of the standard.
    ///
    /// WHY THERE ARE TWO GATES, AND WHY THIS ONE WAS ADDED SECOND — say it plainly, because
    /// adding a metric after seeing another one pass is exactly the move `.planning/VISUAL-DEFECTS.md`
    /// forbids when it is done to change a verdict, and the reader is owed the ability to judge:
    ///
    /// `contrastMin = 60` was fixed by `04-03-PLAN.md` before anything was measured, and it has
    /// NOT been moved. It was then measured on the pre-fix badge and came back **125** — the
    /// defective badge cleared the floor by a factor of two. So that gate is kept, and it is
    /// reported for what it is: a floor the defect never touched, and therefore a gate that
    /// could not have caught V4.
    ///
    /// This second gate is not a re-fitted version of the first. Its number is not chosen from
    /// this repo's data at all — 4.5:1 is the published AA threshold, and it would read the same
    /// if no badge had ever been measured. It IS provably able to fail: the pre-fix placeholder
    /// measures 4.03:1, which is below it, and the negative control in `04-03-SUMMARY.md`
    /// reddens exactly this line.
    private static let wcagAAMin = 4.5

    private var app: XCUIApplication!

    override func setUp() { continueAfterFailure = false }

    func test_givenTheNotIncludedBucket_whenBothBadgePairsAreMeasured_thenThePlaceholderIsLegibleAndStillQuieter() {
        app = XCUIApplication()
        app.launchFresh()

        XCTAssertTrue(app.buttons["crate-row-Friday Warehouse"].waitForExistence(timeout: 20),
                      "the Friday Warehouse fixture crate row never appeared")
        app.buttons["crate-row-Friday Warehouse"].tap()

        let bucket = app.buttons["not-included-section"]
        XCTAssertTrue(bucket.waitForExistence(timeout: 10),
                      "SEQ-07: Friday Warehouse rendered no not-included bucket to expand")
        bucket.tap()

        // The per-row identifiers this plan added. Before them SEQ-07's rows were unqueryable
        // and V4 could only ever be argued from a photograph.
        XCTAssertTrue(app.otherElements["not-included-row-1"].waitForExistence(timeout: 10),
                      "not-included-row-1 did not resolve — the bucket did not expand, or the "
                      + "row identifier is not reaching the accessibility tree")
        XCTAssertTrue(app.otherElements["not-included-row-2"].exists,
                      "not-included-row-2 is missing — the bucket should hold TWO rows "
                      + "(the excluded vinyl and the unresolved one)")

        // Negative control for the whole query family. If a nonsense identifier resolved, every
        // measurement below would be measuring something other than what it names.
        XCTAssertFalse(app.otherElements["not-included-row-99"].exists,
                       "a nonsense not-included-row identifier resolved — the queries are not discriminating")
        XCTAssertFalse(badgePair(99).exists,
                       "a nonsense badge-pair identifier resolved — the queries are not discriminating")

        let first = badgePair(1)
        let second = badgePair(2)
        XCTAssertTrue(first.waitForExistence(timeout: 10), "badge-pair-notincluded-1 did not resolve")
        XCTAssertTrue(second.exists, "badge-pair-notincluded-2 did not resolve")

        // Which row carries the placeholders is decided by READING the badges, not by trusting
        // the bucket's order: the fixture's positions are the subject of defect V5 in this very
        // plan, and a measurement that assumed an order would move when V5's fix landed.
        // A complete pair carries a BPM, so it contains a decimal digit; `TrackBadges.placeholder`
        // (U+2014) does not.
        let firstHasDigits = first.label.contains(where: \.isNumber)
        let secondHasDigits = second.label.contains(where: \.isNumber)
        print("BADGE labels: pair1='\(first.label)' pair2='\(second.label)'")
        XCTAssertNotEqual(firstHasDigits, secondHasDigits,
                          "the bucket must hold exactly one COMPLETE and one PLACEHOLDER pair; "
                          + "got '\(first.label)' and '\(second.label)'. Measuring two badges of "
                          + "the same kind would make the 'dimmed, never hidden' half vacuous.")

        let complete = firstHasDigits ? first : second
        let placeholder = firstHasDigits ? second : first

        let completeStats = measure(complete, writingTo: "04-badge-complete")
        let placeholderStats = measure(placeholder, writingTo: "04-badge-placeholder")

        print("BADGE complete    \(completeStats)")
        print("BADGE placeholder \(placeholderStats)")

        // Half one of SEQ-11: legible. The threshold is Self.contrastMin and it does not move.
        XCTAssertGreaterThanOrEqual(
            placeholderStats.contrast, Self.contrastMin,
            "V4: the placeholder badge pair's contrast is \(placeholderStats.contrast) "
            + "(mode \(placeholderStats.mode) - min \(placeholderStats.min)), below the "
            + "\(Self.contrastMin)-unit legibility floor. SEQ-11 says a missing value is dimmed, "
            + "never hidden.")

        // Half two of SEQ-11: still quieter. Strictly — equal contrast means the dimming is gone.
        XCTAssertGreaterThan(
            completeStats.contrast, placeholderStats.contrast,
            "SEQ-11: the complete badge pair's contrast (\(completeStats.contrast)) is not "
            + "strictly greater than the placeholder's (\(placeholderStats.contrast)) — the "
            + "placeholder has stopped reading as dimmed.")

        // A badge pair with no ink at all is 'hidden', whatever its contrast arithmetic says.
        XCTAssertGreaterThan(placeholderStats.ink, 0,
                             "the placeholder badge pair contains no pixel darker than "
                             + "\(Self.inkThreshold) — it is not dimmed, it is invisible")

        // Reading a single darkest pixel as "the ink" only means something on a grey-on-grey
        // badge. Asserted rather than assumed, so a future coloured badge breaks this loudly
        // instead of being silently mis-measured.
        for (what, stats) in [("placeholder", placeholderStats), ("complete", completeStats)] {
            XCTAssertLessThan(stats.chroma, 24,
                              "the \(what) badge pair is not grey on grey (chroma \(stats.chroma)) "
                              + "— the darkest-pixel-as-ink model no longer applies to it")
        }

        // V4's real gate. See `wcagAAMin` for why this one exists and why it was added second.
        XCTAssertGreaterThanOrEqual(
            placeholderStats.ratio, Self.wcagAAMin,
            "V4: the placeholder badge pair reads at "
            + "\(String(format: "%.2f", placeholderStats.ratio)):1 "
            + "(ink \(placeholderStats.darkestRGB) on ground \(placeholderStats.modeRGB)), below "
            + "WCAG 2.2 AA's \(Self.wcagAAMin):1 for 12 pt text. SEQ-11 says a missing value is "
            + "dimmed, never hidden.")

        // And the complete badge must be at least as legible as the placeholder, on this metric
        // too — otherwise 'quieter' has been achieved by making the wrong one harder to read.
        XCTAssertGreaterThan(
            completeStats.ratio, placeholderStats.ratio,
            "SEQ-11: the complete pair reads at "
            + "\(String(format: "%.2f", completeStats.ratio)):1, not above the placeholder's "
            + "\(String(format: "%.2f", placeholderStats.ratio)):1")
    }

    // MARK: Measurement

    private struct Stats: CustomStringConvertible {
        let w: Int, h: Int, min: Int, max: Int, mode: Int, ink: Int, area: Int
        /// The plan's metric, unchanged: modal background luminance minus darkest ink.
        var contrast: Int { mode - min }
        /// The real RGB of the darkest pixel and of one pixel at the modal luminance, so the
        /// WCAG ratio below is computed from actual colour and not from a greyscale guess.
        let darkestRGB: (Int, Int, Int)
        let modeRGB: (Int, Int, Int)
        /// Largest max-channel-minus-min-channel spread anywhere in the crop. Near zero means
        /// the badge really is grey on grey, which is the only condition under which reading a
        /// single "darkest pixel" as the ink colour is meaningful.
        let chroma: Int

        /// WCAG 2.2 §1.4.3 contrast ratio, (L1 + 0.05) / (L2 + 0.05) on relative luminance.
        var ratio: Double {
            let a = Self.relativeLuminance(modeRGB), b = Self.relativeLuminance(darkestRGB)
            return (Swift.max(a, b) + 0.05) / (Swift.min(a, b) + 0.05)
        }

        private static func relativeLuminance(_ rgb: (Int, Int, Int)) -> Double {
            func linear(_ v: Int) -> Double {
                let c = Double(v) / 255.0
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
        }

        var description: String {
            "\(w)x\(h) px  min=\(min) max=\(max) mode=\(mode) contrast=\(contrast) "
            + "ratio=\(String(format: "%.2f", ratio)):1 "
            + "darkestRGB=\(darkestRGB) modeRGB=\(modeRGB) chroma=\(chroma) "
            + "ink=\(ink)/\(area) (\(String(format: "%.4f", Double(ink) / Double(area))))"
        }
    }

    /// Measured on the live accessibility tree 2026-08-30, not guessed: a `.combine`d pair
    /// surfaces as a **staticText**, while a `.contain` row surfaces as an **otherElement**.
    /// An untyped `descendants(matching: .any)` would match both and throw on ambiguity.
    private func badgePair(_ n: Int) -> XCUIElement {
        app.staticTexts["badge-pair-notincluded-\(n)"]
    }

    /// Element screenshot -> PNG on disk (host evidence) -> luminance stats (the assertion).
    ///
    /// If `XCUIElement.screenshot()` ever returns a zero-size image for a combined element, this
    /// fails LOUDLY rather than falling back silently. `04-03-PLAN.md` names the fallback —
    /// crop the row's frame out of the full-screen shot with `probe-frames.py --region` — and it
    /// is a different measurement method, so switching to it without saying so would break the
    /// comparability of every number recorded here.
    private func measure(_ element: XCUIElement, writingTo name: String) -> Stats {
        let png = element.screenshot().pngRepresentation
        let url = ScreenshotRecorder.outputDirectory.appendingPathComponent("\(name).png")
        do { try png.write(to: url) } catch { XCTFail("could not write \(name).png: \(error)") }

        guard let image = UIImage(data: png), let cg = image.cgImage,
              cg.width > 0, cg.height > 0 else {
            XCTFail("\(name): the element screenshot decoded to nothing — see 04-03-PLAN.md's "
                    + "documented --region fallback; do NOT switch method silently")
            return Stats(w: 0, h: 0, min: 0, max: 0, mode: 0, ink: 0, area: 0,
                         darkestRGB: (0, 0, 0), modeRGB: (0, 0, 0), chroma: 0)
        }

        let w = cg.width, h = cg.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        var histogram = [Int](repeating: 0, count: 256)
        bytes.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                XCTFail("\(name): could not build an RGB bitmap context")
                return
            }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        var luminance = [Int](repeating: 0, count: w * h)
        var chroma = 0
        for p in 0..<(w * h) {
            let i = p * 4
            let r = Int(bytes[i]), g = Int(bytes[i + 1]), b = Int(bytes[i + 2])
            // ITU-R 601-2, rounded — PIL's convert("L"), so the numbers this test prints and
            // the numbers `Scripts/probe-frames.py --ink` prints are the same numbers.
            let l = Swift.min(255, Swift.max(0, Int((0.299 * Double(r) + 0.587 * Double(g)
                                                     + 0.114 * Double(b)).rounded())))
            luminance[p] = l
            histogram[l] += 1
            chroma = Swift.max(chroma, Swift.max(r, Swift.max(g, b)) - Swift.min(r, Swift.min(g, b)))
        }

        let lo = histogram.firstIndex(where: { $0 > 0 }) ?? 0
        let hi = histogram.lastIndex(where: { $0 > 0 }) ?? 0
        // MODE and not mean: a badge is mostly background, so the modal luminance IS the ground
        // the ink sits on. A mean would drag toward the ink and make a badge look better
        // contrasted the more characters it carried.
        let mode = histogram.indices.max(by: { histogram[$0] < histogram[$1] }) ?? 0
        let ink = histogram[0..<Self.inkThreshold].reduce(0, +)

        func rgb(atLuminance target: Int) -> (Int, Int, Int) {
            guard let p = luminance.firstIndex(of: target) else { return (0, 0, 0) }
            return (Int(bytes[p * 4]), Int(bytes[p * 4 + 1]), Int(bytes[p * 4 + 2]))
        }
        return Stats(w: w, h: h, min: lo, max: hi, mode: mode, ink: ink, area: w * h,
                     darkestRGB: rgb(atLuminance: lo), modeRGB: rgb(atLuminance: mode),
                     chroma: chroma)
    }
}
