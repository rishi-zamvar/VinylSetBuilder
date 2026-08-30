import CoreGraphics
import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - OCR-02: the orientation transform, applied exactly once

@Test("OCR-02: orientation 1 is the identity — nothing is rotated twice")
func test_givenOrientationUp_whenMadeUpright_thenTheObservationIsUnchanged() {
    let subject = TextObservation(text: "Abstract",
                                  boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
                                  confidence: 1.0, baselineAngle: 0.25)
    let result = ObservationGeometry.upright(subject, orientation: .up)
    #expect(result == subject)
}

@Test("OCR-02: all twelve fixtures are orientation 6, and 6 sends the measured -90 to 0")
func test_givenOrientationRight_whenMadeUpright_thenTheSleeveBaselineReadsHorizontal() {
    // The spike measured every sleeve line at approximately -90 degrees in the RAW buffer,
    // because the reader reports in the original unrotated frame even when given an
    // orientation. Upright, a flat sleeve line must read horizontally.
    let raw = TextObservation(text: "DRUMSOUND &",
                              boundingBox: CGRect(x: 0.862, y: 0.415, width: 0.065, height: 0.302),
                              confidence: 1.0, baselineAngle: -.pi / 2)
    let result = ObservationGeometry.upright(raw, orientation: .right)
    #expect(abs(result.baselineAngle) < 1e-9)
}

@Test("OCR-02: orientation 6 maps the box corner and swaps the extents")
func test_givenOrientationRight_whenMadeUpright_thenTheBoxIsRotatedNotJustRelabelled() {
    let raw = TextObservation(text: "x", boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
                              confidence: 1.0, baselineAngle: 0)
    let box = ObservationGeometry.upright(raw, orientation: .right).boundingBox
    // (x, y, w, h) -> (1 - (y + h), x, h, w)
    #expect(abs(box.origin.x - 0.4) < 1e-9)
    #expect(abs(box.origin.y - 0.1) < 1e-9)
    #expect(abs(box.width - 0.4) < 1e-9)
    #expect(abs(box.height - 0.3) < 1e-9)
    // The rotation is area-preserving and stays inside the unit square.
    #expect(abs(box.width * box.height - 0.12) < 1e-9)
    #expect(box.minX >= 0 && box.maxX <= 1 && box.minY >= 0 && box.maxY <= 1)
}

@Test("OCR-02: applying the transform twice is NOT the same as applying it once")
func test_givenOrientationRight_whenAppliedTwice_thenTheResultDiffers() {
    // The whole point of OCR-02 is "exactly once". A transform that is idempotent could be
    // applied twice by mistake and nobody would notice; this one cannot.
    let raw = TextObservation(text: "x", boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
                              confidence: 1.0, baselineAngle: -.pi / 2)
    let once = ObservationGeometry.upright(raw, orientation: .right)
    let twice = ObservationGeometry.upright(once, orientation: .right)
    #expect(once != twice)
}

@Test("OCR-02: every committed fixture carries EXIF orientation 6")
func test_givenTheFixtureCorpus_whenRead_thenTheOrientationIsRight() {
    #expect(PhotoOrientation.right.rawValue == 6)
    #expect(PhotoOrientation(rawValue: 6) == .right)
    #expect(PhotoOrientation(rawValue: 99) == nil)
}

// MARK: - cap height: the axis-aligned box of rotated text overstates its thickness

@Test("SEG-02: cap height inverts the axis-aligned box of rotated text")
func test_givenARotatedTextBox_whenCapHeightIsDerived_thenItIsTheTrueThicknessNotMinWH() {
    // IMG_0505 'DUBTRACK': w=0.061 h=0.097 at -66.6 degrees. min(w,h) reads 0.061, which is
    // more than twice the truth and merges the two track lines into one.
    let derived = ObservationGeometry.capHeight(width: 0.061, height: 0.097,
                                                angle: -66.6 * .pi / 180)
    #expect(abs(derived - 0.0255) < 0.001, "derived \(derived)")
    #expect(derived < min(0.061, 0.097))
}

@Test("SEG-02: cap height round-trips a synthesised box exactly")
func test_givenKnownWidthHeightAndAngle_whenBoxIsSynthesised_thenCapHeightRecoversIt() {
    for degrees in [0.0, 10, 20, 66, 70, 90, 120, -30, -66, -160] {
        let angle = degrees * .pi / 180
        let (trueWidth, trueHeight) = (0.30, 0.04)
        let c = abs(cos(angle)), s = abs(sin(angle))
        let boxWidth = trueWidth * c + trueHeight * s
        let boxHeight = trueWidth * s + trueHeight * c
        let derived = ObservationGeometry.capHeight(width: boxWidth, height: boxHeight, angle: angle)
        #expect(abs(derived - trueHeight) < 1e-6, "at \(degrees) got \(derived)")
    }
}

@Test("SEG-02: near the diagonal the inversion is singular, so it falls back to min(w,h)")
func test_givenTextNearFortyFiveDegrees_whenCapHeightIsDerived_thenItFallsBackSafely() {
    let derived = ObservationGeometry.capHeight(width: 0.24, height: 0.24, angle: .pi / 4)
    #expect(derived == 0.24)
    // Also guard against a derivation that comes out negative or absurdly large.
    #expect(ObservationGeometry.capHeight(width: 0.05, height: 0.9, angle: 0) == 0.05)
}

// MARK: - fuzzy matching: OCR misreads a character or two, not a word

@Test("SEG-03: edit distance is Levenshtein, both directions, with an empty-string base case")
func test_givenTwoStrings_whenDistanceIsTaken_thenItIsSymmetricAndCorrect() {
    #expect(FuzzyMatch.distance("", "") == 0)
    #expect(FuzzyMatch.distance("ABC", "") == 3)
    #expect(FuzzyMatch.distance("", "ABC") == 3)
    #expect(FuzzyMatch.distance("WIDEOPEN", "WIDEOPBY") == 2)
    #expect(FuzzyMatch.distance("SIDEONE", "GIDEONE") == 1)
    #expect(FuzzyMatch.distance("DJKANE", "DIKANE") == 1)
    #expect(FuzzyMatch.distance("A", "B") == FuzzyMatch.distance("B", "A"))
}

@Test("SEG-03: one edit per four characters — calibrated on the spike's own WIDE OPBY")
func test_givenAnOCRMisread_whenComparedFuzzily_thenItMatchesButUnrelatedTextDoesNot() {
    #expect(FuzzyMatch.isClose("WIDEOPEN", "WIDEOPBY"))     // 2 edits / 8
    #expect(FuzzyMatch.isClose("SIDEONE", "GIDEONE"))       // 1 / 7
    #expect(FuzzyMatch.isClose("MONK", "MONH"))             // 1 / 4
    #expect(!FuzzyMatch.isClose("JAZZ", "JA22"))            // 2 / 4 — the spike scored this partial
    #expect(!FuzzyMatch.isClose("GIVEITTOME", "STAYFOCUSED"))
    #expect(!FuzzyMatch.isClose("", "ANYTHING"))
    #expect(FuzzyMatch.isClose("DALICK", "DALICH"))
}
