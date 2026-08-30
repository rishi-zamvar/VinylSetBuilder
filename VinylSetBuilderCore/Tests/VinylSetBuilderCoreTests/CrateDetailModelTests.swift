import Foundation
import Testing
@testable import VinylSetBuilderCore

/// The vinyl that `FixtureCrates` deliberately puts in BOTH crates. Derived by intersection
/// rather than hardcoded, so CRATE-07's claim is tested against the fixture's actual shape.
private func sharedFixtureVinylID() throws -> UUID {
    let mixed = Set(FixtureCrates.mixedResultsCrate.vinyls.map(\.id))
    let second = Set(FixtureCrates.secondCrate.vinyls.map(\.id))
    return try #require(mixed.intersection(second).first,
                        "the two fixture crates no longer share a vinyl — CRATE-07 is untestable")
}

// MARK: - CRATE-03: the running order

@Test("CRATE-03: a sequenced crate's rows are exactly the sequencer's running order")
func test_givenACrate_whenSequenced_thenTheRunningOrderIsTheSequencersOutput() {
    var model = CrateDetailModel(crate: FixtureCrates.mixedResultsCrate)
    model.resequence(using: BeamSearchSequencer())

    #expect(!model.result.sequence.isEmpty)
    #expect(model.rows.sequenced.map(\.id) == model.result.sequence.map(\.id))
    #expect(model.rows.sequenced.map(\.indexLabel)
            == (1...model.result.sequence.count).map(String.init))
}

@Test("CRATE-03/SEQ-07: the one bucket carries both the unresolved and the excluded vinyl, and says why in different words")
func test_givenACrateWithAnExcludedAndAnUnresolvedVinyl_whenSequenced_thenTheBucketCarriesBoth() {
    var model = CrateDetailModel(crate: FixtureCrates.mixedResultsCrate)
    model.resequence(using: BeamSearchSequencer())

    #expect(model.rows.showsNotIncludedSection)
    #expect(model.rows.notIncluded.count >= 2)
    #expect(model.rows.notIncluded.allSatisfy { !$0.reason.isEmpty })

    // Distinct reasons: "no BPM at all" and "no BPM close enough" must not read identically,
    // or the bucket teaches the user nothing about what to do next.
    let reasons = model.rows.notIncluded.map(\.reason)
    #expect(Set(reasons).count == reasons.count)
}

@Test("CRATE-03: an empty crate sequences to an empty order without trapping")
func test_givenAnEmptyCrate_whenSequenced_thenTheOrderIsEmptyAndNothingTraps() {
    var model = CrateDetailModel(crate: Crate(name: "Empty"))
    model.resequence(using: BeamSearchSequencer())

    #expect(model.rows == CrateRows.empty)
    #expect(!model.rows.showsNotIncludedSection)
    #expect(model.result == SequenceResult.empty)
}

@Test("CRATE-03: sequencing the same crate twice yields identical rows")
func test_givenTheSameCrate_whenSequencedTwice_thenTheRowsAreIdentical() {
    var first = CrateDetailModel(crate: FixtureCrates.mixedResultsCrate)
    first.resequence(using: BeamSearchSequencer())
    var second = CrateDetailModel(crate: FixtureCrates.mixedResultsCrate)
    second.resequence(using: BeamSearchSequencer())

    #expect(first.rows == second.rows)
}

@Test("CRATE-03: a freshly built model is empty rather than stale — init does no work")
func test_givenACrate_whenNeverSequenced_thenTheModelIsEmptyRatherThanStale() {
    let model = CrateDetailModel(crate: FixtureCrates.mixedResultsCrate)

    #expect(model.result == SequenceResult.empty)
    #expect(model.rows == CrateRows.empty)
    #expect(model.crateName == "Friday Warehouse")
    #expect(model.recordCount == FixtureCrates.mixedResultsCrate.vinyls.count)
    #expect(model.crateID == FixtureCrates.mixedResultsCrate.id)
}

// MARK: - CRATE-07: the per-crate pin (D2-2)

@Test("CRATE-07: a pinned vinyl offers the sequencer only the pinned candidate")
func test_givenAVinylWithAPinnedTrack_whenSequencerInputIsBuilt_thenOnlyThePinnedCandidateIsOffered() throws {
    let crate = FixtureCrates.mixedResultsCrate
    let sharedID = try sharedFixtureVinylID()
    let pinned = try #require(crate.selectedTrackByVinyl[sharedID])
    let vinyl = try #require(crate.vinyls.first { $0.id == sharedID })
    try #require(vinyl.candidates.count > 1, "the shared vinyl must carry more than one candidate")

    let model = CrateDetailModel(crate: crate)
    let offered = model.sequencerInput.filter { $0.vinylID == sharedID }

    #expect(offered.map(\.id) == [pinned])
}

@Test("CRATE-07: an unpinned vinyl still offers the sequencer every candidate")
func test_givenAVinylWithNoPin_whenSequencerInputIsBuilt_thenAllItsCandidatesAreOffered() throws {
    var crate = FixtureCrates.mixedResultsCrate
    let sharedID = try sharedFixtureVinylID()
    crate.selectedTrackByVinyl.removeValue(forKey: sharedID)
    let vinyl = try #require(crate.vinyls.first { $0.id == sharedID })

    let model = CrateDetailModel(crate: crate)
    let offered = model.sequencerInput.filter { $0.vinylID == sharedID }

    #expect(offered.map(\.id) == vinyl.orderedCandidates.map(\.id))
}

@Test("CRATE-07: a pin naming a track the vinyl does not carry is ignored, not trusted")
func test_givenAPinNamingATrackThatIsNotACandidate_whenSequencerInputIsBuilt_thenThePinIsIgnored() throws {
    var crate = FixtureCrates.mixedResultsCrate
    let sharedID = try sharedFixtureVinylID()
    crate.selectedTrackByVinyl[sharedID] = UUID()   // stale selection
    let vinyl = try #require(crate.vinyls.first { $0.id == sharedID })

    let model = CrateDetailModel(crate: crate)
    let offered = model.sequencerInput.filter { $0.vinylID == sharedID }

    // A stale pin must never silently erase a vinyl from the set.
    #expect(offered.map(\.id) == vinyl.orderedCandidates.map(\.id))
}

@Test("CRATE-07: the same vinyl in two crates with different pins yields different tracks on screen")
func test_givenTheSameVinylInTwoCratesWithDifferentPins_whenBothAreSequenced_thenTheRunningOrdersShowDifferentTracks() throws {
    let sharedID = try sharedFixtureVinylID()

    var friday = CrateDetailModel(crate: FixtureCrates.mixedResultsCrate)
    friday.resequence(using: BeamSearchSequencer())
    var sunday = CrateDetailModel(crate: FixtureCrates.secondCrate)
    sunday.resequence(using: BeamSearchSequencer())

    let fridayRow = try #require(friday.rows.sequenced.first { $0.vinylID == sharedID },
                                 "the shared vinyl did not make Friday Warehouse's running order")
    let sundayRow = try #require(sunday.rows.sequenced.first { $0.vinylID == sharedID },
                                 "the shared vinyl did not make Sunday Chill's running order")

    #expect(fridayRow.id != sundayRow.id)
    #expect(fridayRow.title != sundayRow.title)
}
