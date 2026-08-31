import Foundation
import Testing
@testable import VinylSetBuilderCore

/// PERS-01's instrument, checked before it is trusted. A dump that is not deterministic would
/// report differences that are not differences, and the whole "diff == 0" gate would be noise.

/// Fixed ids and a fixed date: two calls must produce the SAME crate, or every test below is
/// comparing two different records and proving nothing about the dump.
private func sampleCrate() -> Crate {
    let vinylA = vinylID(801), vinylB = vinylID(802)
    let when = Date(timeIntervalSince1970: 1_750_000_000)
    let one = Track(id: vinylID(811), vinylID: vinylA, position: 0, rawOCRText: "A: HIGH\nDOWN",
                    artist: "Cause 4 Concern", title: "High Down", bpm: 174, camelot: "8A",
                    matchConfidence: 0.91, resolutionState: .resolved)
    let two = Track(id: vinylID(812), vinylID: vinylA, side: .b, position: 1,
                    rawOCRText: "AA: STRANGE NATURE")
    let three = Track(id: vinylID(813), vinylID: vinylB, position: 0, rawOCRText: "SCRIBBLE",
                      resolutionState: .manual)
    return Crate(id: vinylID(800), name: "Friday", createdAt: when, vinyls: [
        VinylEntry(id: vinylA, capturedAt: when, photoRefs: ["p1", "p2"], sidesScanned: [.a, .b],
                   candidates: [one, two], position: 0, catalogueNumber: "TYME012"),
        VinylEntry(id: vinylB, capturedAt: when, candidates: [three], position: 1),
    ], manualOrder: [one.id, three.id], selectedTrackByVinyl: [vinylA: one.id, vinylB: three.id])
}

@Test("PERS-01: the dump is byte-identical for the same value, twice")
func test_givenTheSameCrates_whenDumpedTwice_thenTheTextIsIdentical() {
    let crate = sampleCrate()
    #expect(CrateDump.text([crate]) == CrateDump.text([crate]))
}

@Test("PERS-01: the dump does not depend on dictionary or set iteration order")
func test_givenReconstructedDictionaries_whenDumped_thenTheTextIsUnchanged() {
    // Rebuilding a dictionary and a set from their contents gives a value that compares equal
    // but iterates in a different order. That difference must not reach the file, or the diff
    // gate reports a change on every launch and means nothing.
    var scrambled = sampleCrate()
    scrambled.selectedTrackByVinyl = Dictionary(
        uniqueKeysWithValues: scrambled.selectedTrackByVinyl.map { ($0.key, $0.value) }.reversed())
    scrambled.vinyls[0].sidesScanned = Set(scrambled.vinyls[0].sidesScanned.reversed())
    #expect(CrateDump.text([scrambled]) == CrateDump.text([sampleCrate()]))
}

@Test("PERS-01: the diff unit is one FIELD — changing one value changes exactly one line")
func test_givenOneChangedField_whenDumped_thenExactlyOneLineDiffers() {
    let before = CrateDump.lines([sampleCrate()])
    var after = sampleCrate()
    after.vinyls[0].candidates[0].bpm = 175
    let changed = zip(before, CrateDump.lines([after])).filter { $0 != $1 }.count
    #expect(changed == 1, "a one-field change moved \(changed) lines — the diff unit is not a field")
}

@Test("PERS-01: losing the stored ORDER is a different diff from losing the position field")
func test_givenReorderedArrays_whenDumped_thenTheDiffIsVisible() {
    // The gotcha this whole design exists for: a to-many relationship is backed by a set and
    // does not preserve order. If the dump printed vinyls sorted by position it would be BLIND
    // to that exact failure, so it prints them in stored order AND prints the position.
    let before = CrateDump.text([sampleCrate()])
    var swapped = sampleCrate()
    swapped.vinyls.reverse()
    #expect(CrateDump.text([swapped]) != before)
}

@Test("PERS-03: every candidate appears, selected or not")
func test_givenAnUnselectedCandidate_whenDumped_thenItIsStillThere() {
    let crate = sampleCrate()
    let unselected = crate.vinyls[0].candidates[1]
    #expect(crate.selectedTrackByVinyl[crate.vinyls[0].id] != unselected.id)
    #expect(CrateDump.text([crate]).contains(unselected.id.uuidString))
    #expect(CrateDump.text([crate]).contains("candidateCount=2"))
}

@Test("PERS-01: a newline inside OCR text does not split a field across two lines")
func test_givenMultilineOCRText_whenDumped_thenEveryLineIsOneField() {
    let lines = CrateDump.lines([sampleCrate()])
    #expect(lines.allSatisfy { !$0.isEmpty })
    #expect(lines.contains { $0.hasSuffix("raw=A: HIGH\\nDOWN") })
    #expect(lines.count == CrateDump.text([sampleCrate()])
        .split(separator: "\n", omittingEmptySubsequences: false).count - 1)
}

@Test("PERS-01: crate order is part of the dump, so a reordered list diffs")
func test_givenTwoCratesInEitherOrder_whenDumped_thenTheTextDiffers() {
    let a = sampleCrate()
    let b = Crate(id: vinylID(900), name: "Sunday",
                  createdAt: Date(timeIntervalSince1970: 1_750_000_000))
    #expect(CrateDump.text([a, b]) != CrateDump.text([b, a]))
}
