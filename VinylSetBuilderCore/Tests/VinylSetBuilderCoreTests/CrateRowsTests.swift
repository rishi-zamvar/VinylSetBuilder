import Foundation
import Testing
@testable import VinylSetBuilderCore

// Note: 01-04 (the real sequencer) had not landed a SUMMARY at the time this plan ran.
// These tests build `SequenceResult`/`NotIncluded` fixtures directly — CrateRows only
// asserts that whatever reason string arrives is passed through unchanged, which is
// testable without knowing 01-04's exact wording. Re-run the verbatim-wording cross-check
// against 01-04-SUMMARY.md once it lands.

private func makeCrate(vinyls: [VinylEntry]) -> Crate {
    Crate(name: "Test Crate", vinyls: vinyls)
}

private func makeVinylEntry(_ n: Int, candidates: [Track]) -> VinylEntry {
    VinylEntry(id: vinylID(n), candidates: candidates, position: n - 1)
}

// MARK: - SEQ-11 at list level

@Test("Every sequenced row has both badges, never the BPM placeholder")
func test_givenASequencedResult_whenRowsBuilt_thenEveryRowHasBothBadges() {
    let sequence = [
        makeTrack(vinyl: 1, bpm: 170, camelot: "8A"),
        makeTrack(vinyl: 2, bpm: 174, camelot: "9A"),
    ]
    let crate = makeCrate(vinyls: [makeVinylEntry(1, candidates: sequence), makeVinylEntry(2, candidates: [sequence[1]])])
    let result = SequenceResult(sequence: sequence, notIncluded: [], totalCamelotDistance: 1)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(!rows.sequenced.isEmpty)
    for row in rows.sequenced {
        #expect(!row.badges.bpm.isEmpty)
        #expect(!row.badges.key.isEmpty)
        #expect(row.badges.bpm != TrackBadges.placeholder)
    }
}

@Test("Position labels are one-based")
func test_givenASequencedResult_whenRowsBuilt_thenPositionLabelsAreOneBased() {
    let sequence = [
        makeTrack(vinyl: 1, bpm: 170, camelot: "8A"),
        makeTrack(vinyl: 2, bpm: 174, camelot: "9A"),
        makeTrack(vinyl: 3, bpm: 178, camelot: "10A"),
    ]
    let crate = makeCrate(vinyls: sequence.enumerated().map { i, t in makeVinylEntry(i + 1, candidates: [t]) })
    let result = SequenceResult(sequence: sequence, notIncluded: [], totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.sequenced.map(\.indexLabel) == ["1", "2", "3"])
}

@Test("Row order matches the sequence exactly — a projection, not a re-sort")
func test_givenASequencedResult_whenRowsBuilt_thenRowOrderMatchesTheSequenceExactly() {
    let sequence = [
        makeTrack(vinyl: 3, bpm: 178, camelot: "10A"),
        makeTrack(vinyl: 1, bpm: 170, camelot: "8A"),
        makeTrack(vinyl: 2, bpm: 174, camelot: "9A"),
    ]
    let crate = makeCrate(vinyls: [
        makeVinylEntry(3, candidates: [sequence[0]]),
        makeVinylEntry(1, candidates: [sequence[1]]),
        makeVinylEntry(2, candidates: [sequence[2]]),
    ])
    let result = SequenceResult(sequence: sequence, notIncluded: [], totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.sequenced.map(\.id) == sequence.map(\.id))
}

// MARK: - SEQ-07: one bucket

@Test("Excluded and unresolved vinyls share one collection")
func test_givenBothExcludedAndUnresolvedVinyls_whenRowsBuilt_thenTheyShareOneCollection() {
    let excludedTrack = makeTrack(vinyl: 1, bpm: 220, camelot: "8A")
    let unresolvedTrack = makeTrack(vinyl: 2, bpm: nil, camelot: nil)
    let crate = makeCrate(vinyls: [
        makeVinylEntry(1, candidates: [excludedTrack]),
        makeVinylEntry(2, candidates: [unresolvedTrack]),
    ])
    let notIncluded = [
        NotIncluded(vinylID: vinylID(1), reason: "No track within 4 BPM of the set"),
        NotIncluded(vinylID: vinylID(2), reason: "No BPM found"),
    ]
    let result = SequenceResult(sequence: [], notIncluded: notIncluded, totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.notIncluded.count == 2)
    let reasons = Set(rows.notIncluded.map(\.reason))
    #expect(reasons.count == 2)
}

@Test("Each not-included row carries the sequencer's reason verbatim")
func test_givenNotIncludedRows_whenRead_thenEachCarriesTheSequencersReasonVerbatim() {
    let track = makeTrack(vinyl: 1, bpm: 220, camelot: "8A")
    let crate = makeCrate(vinyls: [makeVinylEntry(1, candidates: [track])])
    let notIncluded = [NotIncluded(vinylID: vinylID(1), reason: "No track within 4 BPM of the set")]
    let result = SequenceResult(sequence: [], notIncluded: notIncluded, totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.notIncluded[0].reason == result.notIncluded[0].reason)
}

@Test("Each not-included row carries its vinyl label")
func test_givenNotIncludedRows_whenRead_thenEachCarriesItsVinylLabel() {
    let track = makeTrack(vinyl: 1, bpm: 220, camelot: "8A", title: "Some Track")
    let entry = VinylEntry(id: vinylID(1), candidates: [
        Track(id: track.id, vinylID: track.vinylID, position: 0, artist: "Someone",
              title: "Some Track", bpm: 220, camelot: "8A", resolutionState: .resolved),
    ], position: 0)
    let crate = makeCrate(vinyls: [entry])
    let notIncluded = [NotIncluded(vinylID: vinylID(1), reason: "No track within 4 BPM of the set")]
    let result = SequenceResult(sequence: [], notIncluded: notIncluded, totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.notIncluded[0].label == entry.label)
    #expect(rows.notIncluded[0].label != "")
}

@Test("Section is hidden when nothing was left out")
func test_givenNothingWasLeftOut_whenRowsBuilt_thenTheSectionIsHidden() {
    let result = SequenceResult(sequence: [], notIncluded: [], totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: makeCrate(vinyls: []))
    #expect(rows.notIncluded.isEmpty)
    #expect(rows.showsNotIncludedSection == false)
}

@Test("Header states the count when something was left out")
func test_givenSomethingWasLeftOut_whenRowsBuilt_thenTheHeaderStatesTheCount() {
    let crate = makeCrate(vinyls: [
        makeVinylEntry(1, candidates: [makeTrack(vinyl: 1, bpm: 220)]),
        makeVinylEntry(2, candidates: [makeTrack(vinyl: 2, bpm: nil)]),
    ])
    let notIncluded = [
        NotIncluded(vinylID: vinylID(1), reason: "No track within 4 BPM of the set"),
        NotIncluded(vinylID: vinylID(2), reason: "No BPM found"),
    ]
    let result = SequenceResult(sequence: [], notIncluded: notIncluded, totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.notIncludedHeader.contains("2"))
}

@Test("A not-included vinyl with candidates shows its best-known badges")
func test_givenANotIncludedVinylWithCandidates_whenRowsBuilt_thenItsBestKnownBadgesAreShown() {
    let entry = VinylEntry(id: vinylID(1), candidates: [
        makeTrack(vinyl: 1, bpm: 178, camelot: "9A", position: 0),
        makeTrack(vinyl: 1, bpm: nil, camelot: nil, position: 1),
    ], position: 0)
    let crate = makeCrate(vinyls: [entry])
    let notIncluded = [NotIncluded(vinylID: vinylID(1), reason: "No track within 4 BPM of the set")]
    let result = SequenceResult(sequence: [], notIncluded: notIncluded, totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.notIncluded[0].badges.bpm == "178")
}

@Test("A not-included vinyl with no BPM at all shows placeholders")
func test_givenANotIncludedVinylWithNoBPMAtAll_whenRowsBuilt_thenBadgesArePlaceholders() {
    let entry = VinylEntry(id: vinylID(1), candidates: [makeTrack(vinyl: 1, bpm: nil, camelot: nil)], position: 0)
    let crate = makeCrate(vinyls: [entry])
    let notIncluded = [NotIncluded(vinylID: vinylID(1), reason: "No BPM found")]
    let result = SequenceResult(sequence: [], notIncluded: notIncluded, totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.notIncluded[0].badges.bpm == TrackBadges.placeholder)
    #expect(rows.notIncluded[0].badges.key == TrackBadges.placeholder)
}

@Test("A stale vinylID in notIncluded is skipped, not crashed")
func test_givenAVinylIDInNotIncludedThatIsNotInTheCrate_whenRowsBuilt_thenItIsSkippedNotCrashed() {
    let crate = makeCrate(vinyls: [])
    let notIncluded = [NotIncluded(vinylID: vinylID(99), reason: "No BPM found")]
    let result = SequenceResult(sequence: [], notIncluded: notIncluded, totalCamelotDistance: 0)
    let rows = CrateRows.make(result: result, crate: crate)
    #expect(rows.notIncluded.isEmpty)
}

@Test("An empty result yields both empty collections and nothing crashes")
func test_givenAnEmptyResult_whenRowsBuilt_thenBothCollectionsAreEmptyAndNothingCrashes() {
    let rows = CrateRows.make(result: .empty, crate: makeCrate(vinyls: []))
    #expect(rows.sequenced.isEmpty)
    #expect(rows.notIncluded.isEmpty)
    #expect(rows == CrateRows.empty)
}
