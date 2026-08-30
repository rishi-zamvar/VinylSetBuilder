import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - Fixture

/// One vinyl, one candidate, one known BPM and key — so a test can talk about "the third row"
/// without depending on which candidate the sequencer happened to pick.
private func ladderVinyl(bpm: Double, camelot: String, position: Int, title: String) -> VinylEntry {
    let vinyl = UUID()
    let track = Track(id: UUID(), vinylID: vinyl, position: 0,
                      artist: "Ladder", title: title, bpm: bpm, camelot: camelot)
    return VinylEntry(id: vinyl, candidates: [track], position: position)
}

/// Three vinyls two BPM apart, so every one of them makes the running order under the default
/// tolerance. Deliberately not a `FixtureCrates` crate: these tests are about ORDER, and they
/// must stay readable when Phase 9 changes how membership is decided (D2-5).
private func ladderCrate() -> Crate {
    Crate(name: "Ladder", vinyls: [
        ladderVinyl(bpm: 170, camelot: "5A", position: 0, title: "One"),
        ladderVinyl(bpm: 172, camelot: "6A", position: 1, title: "Two"),
        ladderVinyl(bpm: 174, camelot: "7A", position: 2, title: "Three"),
    ])
}

/// A model whose three rows are sequenced and then dragged into the order 3, 1, 2.
private func draggedLadder() throws -> (model: CrateDetailModel, sequencedIDs: [UUID]) {
    var model = CrateDetailModel(crate: ladderCrate())
    model.resequence(using: BeamSearchSequencer())
    let sequenced = model.rows.sequenced.map(\.id)
    try #require(sequenced.count == 3, "the ladder crate must sequence all three vinyls")
    model.moveRows(fromOffsets: IndexSet(integer: 2), toOffset: 0)
    return (model, sequenced)
}

// MARK: - CRATE-04: the manual override

@Test("CRATE-04: moving a row changes the displayed order immediately")
func test_givenASequencedOrder_whenRowsAreMoved_thenTheDisplayedOrderFollowsTheDrag() throws {
    let (model, sequenced) = try draggedLadder()

    #expect(model.rows.sequenced.map(\.id) == [sequenced[2], sequenced[0], sequenced[1]])
}

@Test("CRATE-04: the position column renumbers one-based in the NEW order, not the old one")
func test_givenAMove_whenIndexLabelsAreRead_thenTheyRenumberOneBasedInTheNewOrder() throws {
    let (model, sequenced) = try draggedLadder()

    #expect(model.rows.sequenced.map(\.indexLabel) == ["1", "2", "3"])
    #expect(model.rows.sequenced.first?.id == sequenced[2])
    #expect(model.rows.sequenced.first?.indexLabel == "1")
}

@Test("CRATE-04: the ordering mode is readable, so a screen can say which mode it is in")
func test_givenAMove_whenOrderingModeIsRead_thenItIsManual() throws {
    var model = CrateDetailModel(crate: ladderCrate())
    model.resequence(using: BeamSearchSequencer())
    #expect(model.orderingMode == .sequenced)

    model.moveRows(fromOffsets: IndexSet(integer: 2), toOffset: 0)
    #expect(model.orderingMode == .manual)
}

@Test("CRATE-04/D9: the override persists as a scalar Crate.manualOrder, never by reordering vinyls")
func test_givenAMove_whenStored_thenItPersistsAsCrateManualOrder() throws {
    let original = ladderCrate()
    var model = CrateDetailModel(crate: original)
    model.resequence(using: BeamSearchSequencer())
    let sequenced = model.rows.sequenced.map(\.id)
    try #require(sequenced.count == 3)
    model.moveRows(fromOffsets: IndexSet(integer: 2), toOffset: 0)

    #expect(model.crate.manualOrder == [sequenced[2], sequenced[0], sequenced[1]])
    #expect(model.crate.manualOrder == model.rows.sequenced.map(\.id))
    #expect(model.crate.vinyls == original.vinyls)   // D9: vinyls are NOT reordered in place
}

@Test("CRATE-04: a re-sequence over the same candidates does not undo the user's drag")
func test_givenAManualOrder_whenResequencedWithTheSameCandidates_thenTheUsersOrderSurvives() throws {
    var (model, sequenced) = try draggedLadder()

    model.resequence(using: BeamSearchSequencer())

    #expect(model.rows.sequenced.map(\.id) == [sequenced[2], sequenced[0], sequenced[1]])
    #expect(model.orderingMode == .manual)
    #expect(model.result.sequence.map(\.id) == sequenced)   // the sequencer's own answer is intact
}

@Test("CRATE-04/D2-1: after an add, survivors keep their manual places and the newcomer appends")
func test_givenAManualOrder_whenAVinylIsAddedAndResequenced_thenSurvivorsKeepTheirPlacesAndTheNewcomerAppends() throws {
    let (dragged, sequenced) = try draggedLadder()

    let newcomer = ladderVinyl(bpm: 176, camelot: "8A", position: 3, title: "Four")
    let newcomerTrackID = try #require(newcomer.candidates.first?.id)
    var crate = dragged.crate                       // carries the manual order (D9)
    crate.vinyls.append(newcomer)

    var model = CrateDetailModel(crate: crate)
    model.resequence(using: BeamSearchSequencer())

    let displayed = model.rows.sequenced.map(\.id)
    #expect(displayed.count == 4)
    #expect(Array(displayed.prefix(3)) == [sequenced[2], sequenced[0], sequenced[1]])
    #expect(displayed.last == newcomerTrackID)
    #expect(model.crate.manualOrder == displayed)
}

@Test("CRATE-04: a track that leaves the set leaves the manual order too — no dangling ID")
func test_givenAManualOrder_whenATrackLeavesTheSet_thenItLeavesTheManualOrderWithNoDanglingID() throws {
    let (dragged, sequenced) = try draggedLadder()

    // Drop the vinyl whose track sits second in the sequencer's own order.
    let departingTrackID = sequenced[1]
    var crate = dragged.crate
    let departingVinylID = try #require(crate.vinyls.first {
        $0.candidates.contains { $0.id == departingTrackID }
    }?.id)
    crate.vinyls.removeAll { $0.id == departingVinylID }

    var model = CrateDetailModel(crate: crate)
    model.resequence(using: BeamSearchSequencer())

    #expect(!model.rows.sequenced.map(\.id).contains(departingTrackID))
    #expect(model.crate.manualOrder?.contains(departingTrackID) == false)
    #expect(model.rows.sequenced.map(\.id) == [sequenced[2], sequenced[0]])
    #expect(model.rows.sequenced.map(\.indexLabel) == ["1", "2"])
}

@Test("CRATE-04: when every track leaves the set the override collapses rather than lingering empty")
func test_givenAManualOrder_whenEveryTrackLeavesTheSet_thenTheOverrideCollapsesToSequenced() throws {
    let (dragged, _) = try draggedLadder()
    var crate = dragged.crate
    crate.vinyls = []

    var model = CrateDetailModel(crate: crate)
    model.resequence(using: BeamSearchSequencer())

    #expect(model.rows == CrateRows.empty)
    #expect(model.crate.manualOrder == nil)
    #expect(model.orderingMode == .sequenced)
}

@Test("CRATE-04: one call restores the sequencer's own order exactly")
func test_givenAManualOrder_whenCleared_thenTheSequencersOrderReturnsExactly() throws {
    var (model, sequenced) = try draggedLadder()

    model.clearManualOrder()

    #expect(model.crate.manualOrder == nil)
    #expect(model.orderingMode == .sequenced)
    #expect(model.rows.sequenced.map(\.id) == model.result.sequence.map(\.id))
    #expect(model.rows.sequenced.map(\.id) == sequenced)
    #expect(model.rows.sequenced.map(\.indexLabel) == ["1", "2", "3"])
}

@Test("CRATE-04: re-sequencing without a drag never invents an override")
func test_givenNoManualOrder_whenResequenced_thenNoOverrideIsCreated() {
    var model = CrateDetailModel(crate: ladderCrate())
    model.resequence(using: BeamSearchSequencer())
    model.resequence(using: BeamSearchSequencer())

    #expect(model.crate.manualOrder == nil)
    #expect(model.orderingMode == .sequenced)
}

@Test("CRATE-04: an out-of-range or no-op move does nothing and does not trap")
func test_givenAnOutOfRangeMove_whenApplied_thenNothingTraps() throws {
    // No rows at all — the model was never sequenced.
    var empty = CrateDetailModel(crate: Crate(name: "Empty"))
    empty.moveRows(fromOffsets: IndexSet(integer: 0), toOffset: 0)
    #expect(empty.rows == CrateRows.empty)
    #expect(empty.crate.manualOrder == nil)

    // A single row moved onto itself.
    var single = CrateDetailModel(crate: Crate(name: "One", vinyls: [
        ladderVinyl(bpm: 170, camelot: "5A", position: 0, title: "Only"),
    ]))
    single.resequence(using: BeamSearchSequencer())
    let onlyID = try #require(single.rows.sequenced.first?.id)
    single.moveRows(fromOffsets: IndexSet(integer: 0), toOffset: 0)
    #expect(single.rows.sequenced.map(\.id) == [onlyID])
    // V18. The displayed order alone is not the whole claim: a move that changed NOTHING must
    // not commit an override either, or the screen offers a Restore with nothing to restore.
    #expect(single.crate.manualOrder == nil)
    #expect(single.orderingMode == .sequenced)

    // An index past the end of the list.
    var ladder = CrateDetailModel(crate: ladderCrate())
    ladder.resequence(using: BeamSearchSequencer())
    let before = ladder.rows.sequenced.map(\.id)
    ladder.moveRows(fromOffsets: IndexSet(integer: 9), toOffset: 0)
    ladder.moveRows(fromOffsets: IndexSet(integer: 0), toOffset: 99)
    #expect(ladder.rows.sequenced.map(\.id) == before)
    #expect(ladder.crate.manualOrder == nil)

    // A row moved to its own index changes nothing about the displayed order.
    ladder.moveRows(fromOffsets: IndexSet(integer: 1), toOffset: 1)
    #expect(ladder.rows.sequenced.map(\.id) == before)
    // V18, and the assertion this case omitted while its out-of-range sibling twelve lines
    // above made it. An identity drag is a no-op: it may not put the crate into .manual.
    #expect(ladder.crate.manualOrder == nil)
    #expect(ladder.orderingMode == .sequenced)
}

/// V18, the OTHER direction. The guard that stops an identity drag committing an override must
/// not become a guard that CLEARS one: on a list the user has already arranged by hand, a drag
/// that lands where it started has to leave that arrangement exactly as it is. Without this
/// test, "clear manualOrder on a no-op move" would pass the case above and silently throw the
/// user's ordering away on a mistimed touch.
@Test("CRATE-04: an identity drag on an ALREADY-MANUAL list preserves the order it already has")
func test_givenAManualOrder_whenARowIsMovedOntoItsOwnIndex_thenTheExistingOrderIsPreserved() throws {
    var (model, _) = try draggedLadder()
    let manualBefore = try #require(model.crate.manualOrder, "the dragged ladder must be manual")
    let displayedBefore = model.rows.sequenced.map(\.id)

    model.moveRows(fromOffsets: IndexSet(integer: 1), toOffset: 1)

    #expect(model.crate.manualOrder == manualBefore)
    #expect(model.orderingMode == .manual)
    #expect(model.rows.sequenced.map(\.id) == displayedBefore)
}

// MARK: - CRATE-05: Add More

@Test("CRATE-05: Add More routes to capture for the SAME crate, not a new one")
func test_givenAnOpenCrate_whenAddMoreIsInvoked_thenTheRouteIsCaptureForTheSameCrate() throws {
    var store = FixtureCrates.demoStore
    let crateID = try #require(store.crates.first?.id)
    store.open(crateID)

    store.addMore(to: crateID)

    #expect(store.route == .capture(crateID: crateID))
    #expect(store.crates.count == FixtureCrates.demoStore.crates.count)
}

@Test("CRATE-05: Add More is navigation and nothing else — the crate value is untouched")
func test_givenAddMore_whenInvoked_thenTheCrateValueIsByteForByteUnchanged() throws {
    var store = FixtureCrates.demoStore
    let crateID = try #require(store.crates.first?.id)
    let before = try #require(store.crate(crateID))

    store.addMore(to: crateID)

    #expect(store.crate(crateID) == before)
    #expect(store.crates == FixtureCrates.demoStore.crates)
}

@Test("CRATE-05: Add More on an unknown crate navigates nowhere")
func test_givenAddMoreOnAnUnknownCrateID_whenInvoked_thenTheRouteIsUnchanged() {
    var store = FixtureCrates.demoStore
    store.closeToList()

    store.addMore(to: UUID())

    #expect(store.route == .crateList)
}

// MARK: - CrateStore.update — the commit path the detail screen needs

@Test("An edited crate is written back in place, so the newest-first list order is undisturbed")
func test_givenAnEditedCrate_whenUpdated_thenTheStoreHoldsTheNewValueInTheSamePosition() throws {
    var store = FixtureCrates.demoStore
    let originalOrder = store.crates.map(\.id)
    var edited = try #require(store.crates.last)
    edited.manualOrder = [UUID()]

    store.update(edited)

    #expect(store.crates.map(\.id) == originalOrder)
    #expect(store.crate(edited.id)?.manualOrder == edited.manualOrder)
}

@Test("Updating a crate the store does not hold inserts nothing")
func test_givenAnUnknownCrate_whenUpdated_thenTheStoreIsUnchanged() {
    var store = FixtureCrates.demoStore
    let before = store.crates

    store.update(Crate(name: "Never added"))

    #expect(store.crates == before)
}
