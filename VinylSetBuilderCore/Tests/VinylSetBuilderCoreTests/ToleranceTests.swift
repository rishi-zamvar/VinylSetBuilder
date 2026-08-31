import Foundation
import Testing
@testable import VinylSetBuilderCore

/// **SEQ-05** — "adjust BPM_TOLERANCE on a slider from 3 to 6, defaulting to 4.0, and the
/// sequence re-optimises".
///
/// Three separate claims, and they are tested separately because two of them were already
/// true before this file existed and only the third is new:
///
///   1. the range and the clamp (`BPMRules`, Phase 5)
///   2. the default (`CrateStore.createCrate`, Phase 2)
///   3. **that moving it actually changes the set** — which nothing had ever asserted, and
///      which is the only part of SEQ-05 a person would notice
///
/// Claim 3 is deliberately made on the SHIPPING sequencer over a fixture whose answer is
/// hand-derivable, not on a random crate: "the set changed" is only evidence if you can say
/// what it changed to.

// MARK: - 1. The range and the clamp

@Test("The tolerance range is exactly 3 to 6")
func test_givenTheToleranceRange_whenRead_thenItIsThreeToSix() {
    #expect(BPMRules.toleranceRange.lowerBound == 3.0)
    #expect(BPMRules.toleranceRange.upperBound == 6.0)
    #expect(BPMRules.defaultTolerance == 4.0)
    #expect(BPMRules.toleranceRange.contains(BPMRules.defaultTolerance))
}

@Test("A tolerance below, above and inside the range clamps to the range")
func test_givenAToleranceOutsideTheRange_whenStored_thenItIsClamped() {
    var store = CrateStore(crates: [Crate(id: vinylID(1), name: "C")])

    store.setBPMTolerance(2.0, in: vinylID(1))
    #expect(store.crate(vinylID(1))?.bpmTolerance == 3.0)

    store.setBPMTolerance(9.0, in: vinylID(1))
    #expect(store.crate(vinylID(1))?.bpmTolerance == 6.0)

    store.setBPMTolerance(4.5, in: vinylID(1))
    #expect(store.crate(vinylID(1))?.bpmTolerance == 4.5)
}

@Test("Setting the tolerance on an unknown crate is a no-op, not a trap")
func test_givenAnUnknownCrateID_whenToleranceIsSet_thenNothingChanges() {
    let before = CrateStore(crates: [Crate(id: vinylID(1), name: "C")])
    var after = before
    after.setBPMTolerance(6.0, in: vinylID(99))
    #expect(after == before)
}

// MARK: - 2. The default

@Test("A crate created through the store starts at 4.0, the slider's default")
func test_givenANewCrate_whenCreated_thenItsToleranceIsTheSliderDefault() {
    var store = CrateStore()
    let id = store.createCrate(named: "Friday")
    #expect(store.crate(id)?.bpmTolerance == 4.0)
}

// MARK: - 3. Moving it re-optimises — the claim nothing had ever made

/// Five vinyls at 170, 174, 178, 182, 186 — each exactly 4 apart, so at the DEFAULT tolerance
/// every neighbour is reachable and all five sequence. Drop to 3 and every edge is 4 > 3, so
/// the chain shatters into single records and the set collapses to one.
///
/// The fixture is chosen so both answers are derivable by hand: at 4 the set is 5, at 3 it is 1.
private let ladder: [Track] = (0..<5).flatMap { i in
    makeVinyl(i + 1, bpms: [170 + Double(i) * 4], camelots: ["8A"])
}

@Test("Tightening the tolerance from 4 to 3 shortens the set")
func test_givenAFourApartLadder_whenToleranceTightensToThree_thenTheSetShortens() {
    let atFour = BeamSearchSequencer().sequence(candidates: ladder, bpmTolerance: 4)
    let atThree = BeamSearchSequencer().sequence(candidates: ladder, bpmTolerance: 3)

    #expect(atFour.sequence.count == 5)
    #expect(atThree.sequence.count == 1)
    #expect(atThree.notIncluded.count == 4)
}

/// The other direction, and the one that matters more: widening admits a record that was out.
/// 170 and 175 are 5 apart — excluded at 4, admitted at 5 and at 6.
@Test("Widening the tolerance to 5 admits a record that 4 excluded")
func test_givenAFiveApartPair_whenToleranceWidens_thenTheExcludedRecordRejoins() {
    let pair = makeVinyl(1, bpms: [170], camelots: ["8A"]) + makeVinyl(2, bpms: [175], camelots: ["8A"])

    let atFour = BeamSearchSequencer().sequence(candidates: pair, bpmTolerance: 4)
    #expect(atFour.sequence.count == 1)
    #expect(atFour.notIncluded.count == 1)

    for wider in [5.0, 6.0] {
        let result = BeamSearchSequencer().sequence(candidates: pair, bpmTolerance: wider)
        #expect(result.sequence.count == 2, "at tolerance \(wider) the pair should sequence")
        #expect(result.notIncluded.isEmpty)
    }
}

/// The set is not merely a different length — it is a different SET. Swept across the whole
/// slider so no single tolerance carries the claim on its own.
@Test("The four slider stops produce four different set sizes on the ladder fixture")
func test_givenTheFourSliderStops_whenSequenced_thenTheSetSizeIsMonotonicInTolerance() {
    let sizes = [3.0, 4.0, 5.0, 6.0].map {
        BeamSearchSequencer().sequence(candidates: ladder, bpmTolerance: $0).sequence.count
    }
    #expect(sizes == [1, 5, 5, 5])
    // A wider window can never admit fewer records than a narrower one.
    #expect(sizes == sizes.sorted())
}

/// **The end-to-end claim, through the store the app mutates and the rows the app renders.**
/// Not through the sequencer directly: SEQ-05 is a property of the screen, and the screen goes
/// store -> crate.bpmTolerance -> sequencer -> CrateRows. A mutator that clamped correctly but
/// was not threaded through would still pass every test above.
@Test("Moving the tolerance through the store changes the rendered rows and their reason")
func test_givenACrate_whenToleranceIsChangedInTheStore_thenTheRenderedRowsChange() {
    let vinyls = (0..<5).map { i in
        VinylEntry(id: vinylID(i + 1), candidates: makeVinyl(i + 1, bpms: [170 + Double(i) * 4],
                                                             camelots: ["8A"]),
                   position: i)
    }
    var store = CrateStore(crates: [Crate(id: vinylID(100), name: "Ladder", vinyls: vinyls)])

    func rows(_ id: UUID) -> CrateRows {
        let crate = store.crate(id)!
        return CrateRows.make(
            result: BeamSearchSequencer().sequence(candidates: crate.allCandidates,
                                                   bpmTolerance: crate.bpmTolerance),
            crate: crate)
    }

    let atDefault = rows(vinylID(100))
    #expect(atDefault.sequenced.count == 5)
    #expect(atDefault.notIncluded.isEmpty)

    store.setBPMTolerance(3.0, in: vinylID(100))
    let atThree = rows(vinylID(100))
    #expect(atThree.sequenced.count == 1)
    #expect(atThree.notIncluded.count == 4)
    // V19: the reason quotes the tolerance the crate now carries, not the one it used to.
    #expect(atThree.notIncluded.allSatisfy { $0.reason == "No track within 3 BPM of the set" })
}

// MARK: - 4. The expectations the UI walk asserts, derived here rather than guessed there

/// **`SEQ05ToleranceUITests` drags the real slider on `Friday Warehouse` and asserts against
/// these numbers. They are computed HERE, on the shipping sequencer through the SAME model the
/// screen uses, so the walk checks a derived answer and not a hopeful one.**
///
/// **`CrateDetailModel.sequencerInput`, not `crate.allCandidates`, and that distinction cost a
/// red walk.** CRATE-07 pins one candidate per vinyl where the crate has a selection, so the
/// crate offers the sequencer five tracks and the SCREEN offers it four. Sequencing the raw
/// candidate list gives a different, and wrong, expectation — three records at the default
/// instead of two. A test that measures a path the app does not take is worse than no test.
///
/// The crate's *pinned* tempos are 170 (Source Direct), 172 (Photek), 178 (Dillinja) and one
/// record with no tempo at all:
///
/// | tolerance | set | bucket | why |
/// | --- | --- | --- | --- |
/// | 3, 4, 5 | 2 | 2 | 170 → 172; Dillinja at 178 is 6 from the nearest, so it stays out |
/// | 6 | 3 | 1 | 172 → 178 is exactly 6, and Dillinja **rejoins** |
///
/// Worth stating rather than hiding: on this crate *tightening* below the default changes
/// nothing, because 170 → 172 is 2 apart and survives every stop on the slider. The direction
/// that moves is widening, and it moves by admitting a record — which is the more valuable half
/// of SEQ-05 anyway, and the same shape as SEQ-08's rejoin.
@Test("The fixture crate's set at 3, 4 and 6 is the answer the UI walk asserts")
func test_givenTheFixtureCrate_whenToleranceSwept_thenTheExcludedRecordRejoinsAtSix() {
    func screen(at tolerance: Double) -> CrateRows {
        var swept = FixtureCrates.mixedResultsCrate
        swept.bpmTolerance = tolerance
        var model = CrateDetailModel(crate: swept)
        model.resequence(using: BeamSearchSequencer())
        return model.rows
    }

    for tolerance in [3.0, 4.0, 5.0] {
        let rows = screen(at: tolerance)
        #expect(rows.sequenced.count == 2, "at tolerance \(tolerance) the set should hold two records")
        #expect(rows.notIncluded.count == 2)
        #expect(!rows.sequenced.contains { $0.title.contains("Angels Fell") })
        // V19: the sentence quotes the tolerance the crate now carries, not a frozen 4.
        #expect(rows.notIncluded.contains { $0.reason == ExclusionReason.outsideWindow(tolerance: tolerance) })
    }

    let atSix = screen(at: 6.0)
    #expect(atSix.sequenced.count == 3, "at tolerance 6 the excluded record should rejoin the set")
    #expect(atSix.notIncluded.count == 1)
    #expect(atSix.sequenced.contains { $0.title.contains("Angels Fell") })
    // The one record left out at 6 is left out for a reason the slider cannot fix.
    #expect(atSix.notIncluded.allSatisfy { $0.reason == ExclusionReason.noBPM })
}
