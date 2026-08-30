import CoreGraphics
import Foundation
import Testing
@testable import VinylSetBuilderCore

// OCR-04. Text and confidence pairs are real, quoted from `.local/ocr/ocr2_out.json`:
//   1.00 "A: High Down" / "AAA: Strange Nat ure"   IMG_0503
//   1.00 "·009"                                    IMG_0499
//   0.50 "Skynet 6.00g"                            IMG_0500
//   0.30 "Remi:600"                                IMG_0498
// The spike measured confidence to be exactly 1.00 / 0.50 / 0.30 and nothing else (finding 4).

private func makeRawObservation(_ text: String, _ confidence: Float) -> TextObservation {
    TextObservation(text: text,
                    boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
                    confidence: confidence,
                    baselineAngle: -1.639)
}

// MARK: - The point of OCR-04: the dropped reads are the evidence

@Test("OCR-04: every observation becomes a row — INCLUDING the ones the trusted tier throws away")
func test_givenTrustedAndUntrustedReads_whenProjected_thenTheUntrustedOnesAreStillThere() {
    let rows = RawObservationRows.make([
        makeRawObservation("A: High Down", 1.0),
        makeRawObservation("Skynet 6.00g", 0.5),
        makeRawObservation("Remi:600", 0.3),
    ])

    #expect(rows.count == 3)
    #expect(rows.map(\.text) == ["A: High Down", "Skynet 6.00g", "Remi:600"])
    #expect(rows.contains { $0.text == "Skynet 6.00g" })   // 0.50 — a bad read is what you inspect
    #expect(rows.contains { $0.text == "Remi:600" })       // 0.30 — so is this one
    #expect(rows.filter { !$0.isTrusted }.count == 2)
}

@Test("OCR-04: ids are 1-based and contiguous in reading order — asserted as a set, not a count")
func test_givenNObservations_whenProjected_thenTheIDsAreExactlyOneThroughN() {
    let texts = ["Da Lick", "Da Lich", "Da Lick", "MADE IN", "ENGLAND"]
    let rows = RawObservationRows.make(texts.map { makeRawObservation($0, 1.0) })

    #expect(Set(rows.map(\.id)) == Set(1...5))
    #expect(rows.map(\.id) == [1, 2, 3, 4, 5])
    #expect(rows.map(\.text) == texts)          // input order, no sort and no dedupe
}

// MARK: - Confidence, formatted exactly once

@Test("OCR-04: confidence is preformatted to two places under en_US_POSIX")
func test_givenTheThreeMeasuredConfidences_whenProjected_thenEachFormatsToTwoPlaces() {
    let rows = RawObservationRows.make([
        makeRawObservation("A: High Down", 1.0),
        makeRawObservation("Skynet 6.00g", 0.5),
        makeRawObservation("Remi:600", 0.3),
    ])

    #expect(rows.map(\.confidence) == ["1.00", "0.50", "0.30"])
}

@Test("OCR-04: trusted is a TIER — true at 1.0, false at BOTH 0.5 and 0.3 (spike finding 4)")
func test_givenBothUntrustedValues_whenProjected_thenNeitherIsTrustedAndOnePointZeroIs() {
    let rows = RawObservationRows.make([
        makeRawObservation("A: High Down", 1.0),
        makeRawObservation("Skynet 6.00g", 0.5),
        makeRawObservation("Remi:600", 0.3),
    ])

    #expect(rows[0].isTrusted == true)
    #expect(rows[1].isTrusted == false)      // a >= 0.4 threshold would pass without this line
    #expect(rows[2].isTrusted == false)      // a >= 0.6 threshold would pass without this one
}

@Test("OCR-04: 0.999 is NOT trusted — the tier is >= 1.0, and > 0.9 would pass everything else")
func test_givenAlmostOne_whenProjected_thenItIsUntrustedWhileExactlyOneIsTrusted() {
    let rows = RawObservationRows.make([
        makeRawObservation("A: High Down", 0.999),
        makeRawObservation("A: High Down", 1.0),
    ])

    #expect(rows[0].isTrusted == false)
    #expect(rows[1].isTrusted == true)
}

// MARK: - The raw read is the evidence, so nothing touches it

@Test("OCR-04: text passes through verbatim, inner spacing and all")
func test_givenAGarbledRead_whenProjected_thenTheTextIsUnchanged() {
    let rows = RawObservationRows.make([
        makeRawObservation("AAA: Strange Nat ure", 1.0),
        makeRawObservation("·009", 1.0),
    ])

    #expect(rows[0].text == "AAA: Strange Nat ure")     // the broken word is the diagnosis
    #expect(rows[1].text == "·009")
}

@Test("OCR-04: nothing is trimmed — a padded read keeps its padding")
func test_givenLeadingAndTrailingWhitespace_whenProjected_thenItSurvives() {
    // A real read with padding deliberately added: the probe that catches a `.trimming…` call,
    // which no genuine fixture string could catch on its own.
    let padded = "  Da Lick  "
    let rows = RawObservationRows.make([makeRawObservation(padded, 1.0)])

    #expect(rows[0].text == padded)
    #expect(rows[0].text.count == padded.count)
}

@Test("OCR-04: no observations yields no rows")
func test_givenNoObservations_whenProjected_thenTheRowListIsEmpty() {
    #expect(RawObservationRows.make([]).isEmpty)
}
