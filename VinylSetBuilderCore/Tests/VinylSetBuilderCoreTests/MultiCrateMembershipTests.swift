import Foundation
import Testing
@testable import VinylSetBuilderCore

// CRATE-07: one vinyl, several crates, independent selections. This file exists because a
// "selection lives on the vinyl" implementation silently fails every test here.

@Test("Selecting differently in two crates keeps each crate's own selection")
func test_givenOneVinylAddedToTwoCrates_whenSelectionsAreSetDifferently_thenEachCrateKeepsItsOwn() {
    let vinylID = UUID()
    let trackA = Track(id: UUID(), vinylID: vinylID, position: 0, title: "A")
    let trackB = Track(id: UUID(), vinylID: vinylID, position: 1, title: "B")
    let vinyl = VinylEntry(id: vinylID, candidates: [trackA, trackB], position: 0)

    var store = CrateStore(crates: [Crate(name: "Crate 1"), Crate(name: "Crate 2")])
    let crate1 = store.crates[0].id
    let crate2 = store.crates[1].id

    store.addVinyl(vinyl, to: crate1)
    store.addVinyl(vinyl, to: crate2)

    store.selectTrack(trackA.id, forVinyl: vinylID, in: crate1)
    store.selectTrack(trackB.id, forVinyl: vinylID, in: crate2)

    // Both directions, so a last-write-wins bug cannot hide behind assertion order.
    #expect(store.selectedTrack(forVinyl: vinylID, in: crate1) == trackA.id)
    #expect(store.selectedTrack(forVinyl: vinylID, in: crate2) == trackB.id)
    #expect(store.selectedTrack(forVinyl: vinylID, in: crate2) == trackB.id)
    #expect(store.selectedTrack(forVinyl: vinylID, in: crate1) == trackA.id)
}

@Test("Re-selecting in one crate leaves the other crate's whole value unchanged")
func test_givenOneVinylInTwoCrates_whenOneSelectionChanges_thenTheOtherIsUntouched() {
    let vinylID = UUID()
    let trackA = Track(id: UUID(), vinylID: vinylID, position: 0, title: "A")
    let trackB = Track(id: UUID(), vinylID: vinylID, position: 1, title: "B")
    let vinyl = VinylEntry(id: vinylID, candidates: [trackA, trackB], position: 0)

    var store = CrateStore(crates: [Crate(name: "Crate 1"), Crate(name: "Crate 2")])
    let crate1 = store.crates[0].id
    let crate2 = store.crates[1].id
    store.addVinyl(vinyl, to: crate1)
    store.addVinyl(vinyl, to: crate2)
    store.selectTrack(trackA.id, forVinyl: vinylID, in: crate1)
    store.selectTrack(trackA.id, forVinyl: vinylID, in: crate2)

    let crate2Before = store.crate(crate2)
    store.selectTrack(trackB.id, forVinyl: vinylID, in: crate1)

    #expect(store.crate(crate2) == crate2Before)
}

@Test("Removing a vinyl from one crate leaves it, with its selection, in the other")
func test_givenOneVinylInTwoCrates_whenRemovedFromOne_thenItRemainsInTheOther() {
    let vinylID = UUID()
    let track = Track(id: UUID(), vinylID: vinylID, position: 0, title: "A")
    let vinyl = VinylEntry(id: vinylID, candidates: [track], position: 0)

    var store = CrateStore(crates: [Crate(name: "Crate 1"), Crate(name: "Crate 2")])
    let crate1 = store.crates[0].id
    let crate2 = store.crates[1].id
    store.addVinyl(vinyl, to: crate1)
    store.addVinyl(vinyl, to: crate2)
    store.selectTrack(track.id, forVinyl: vinylID, in: crate2)

    store.removeVinyl(vinylID, from: crate1)

    #expect(store.crate(crate1)?.vinyls.isEmpty == true)
    #expect(store.crate(crate2)?.vinyls.map(\.id) == [vinylID])
    #expect(store.selectedTrack(forVinyl: vinylID, in: crate2) == track.id)
}

@Test("Deleting one crate leaves the other holding the shared vinyl and its selection")
func test_givenOneVinylInTwoCrates_whenOneCrateIsDeleted_thenTheOtherKeepsTheVinylAndItsSelection() {
    let vinylID = UUID()
    let track = Track(id: UUID(), vinylID: vinylID, position: 0, title: "A")
    let vinyl = VinylEntry(id: vinylID, candidates: [track], position: 0)

    var store = CrateStore(crates: [Crate(name: "Crate 1"), Crate(name: "Crate 2")])
    let crate1 = store.crates[0].id
    let crate2 = store.crates[1].id
    store.addVinyl(vinyl, to: crate1)
    store.addVinyl(vinyl, to: crate2)
    store.selectTrack(track.id, forVinyl: vinylID, in: crate2)

    store.deleteCrate(crate1)

    #expect(store.crate(crate1) == nil)
    #expect(store.crate(crate2)?.vinyls.map(\.id) == [vinylID])
    #expect(store.selectedTrack(forVinyl: vinylID, in: crate2) == track.id)
}

@Test("Adding the same vinyl twice to one crate is idempotent")
func test_givenAVinylAddedTwiceToTheSameCrate_whenRead_thenItAppearsOnce() {
    let vinylID = UUID()
    let vinyl = VinylEntry(id: vinylID, position: 0)
    var store = CrateStore(crates: [Crate(name: "Crate")])
    let crateID = store.crates[0].id

    store.addVinyl(vinyl, to: crateID)
    store.addVinyl(vinyl, to: crateID)

    #expect(store.crate(crateID)?.vinyls.count == 1)
}

@Test("Selecting a track for a vinyl not in the crate is ignored")
func test_givenASelectionForAVinylNotInTheCrate_whenSet_thenItIsIgnored() {
    var store = CrateStore(crates: [Crate(name: "Crate")])
    let crateID = store.crates[0].id
    let strayVinylID = UUID()
    let strayTrackID = UUID()

    store.selectTrack(strayTrackID, forVinyl: strayVinylID, in: crateID)

    #expect(store.selectedTrack(forVinyl: strayVinylID, in: crateID) == nil)
    #expect(store.crate(crateID)?.selectedTrackByVinyl.isEmpty == true)
}

// MARK: - Fixture library

@Test("The fixture library exercises the hard cases by construction")
func test_givenTheFixtureLibrary_whenInspected_thenItExercisesTheHardCases() {
    let mixed = FixtureCrates.mixedResultsCrate
    let second = FixtureCrates.secondCrate

    // (a) at least one vinyl with two candidate tracks in the BPM window (SEQ-02).
    #expect(mixed.vinyls.contains { $0.candidates.count >= 2 })

    // (b) at least one vinyl with bpm == nil — the unresolved bucket.
    let allTracks = mixed.vinyls.flatMap(\.candidates)
    #expect(allTracks.contains { $0.bpm == nil })

    // (c) at least one vinyl outside the default 4.0 window.
    let resolvedBPMs = allTracks.compactMap(\.bpm).sorted()
    let spansMoreThanTolerance = (resolvedBPMs.last ?? 0) - (resolvedBPMs.first ?? 0) > BPMRules.defaultTolerance
    #expect(spansMoreThanTolerance)

    // (d) one vinyl present in two different crates with different selections — CRATE-07.
    let sharedVinylID = Set(mixed.vinyls.map(\.id)).intersection(second.vinyls.map(\.id)).first
    #expect(sharedVinylID != nil)
    if let sharedVinylID {
        let selectionInMixed = mixed.selectedTrackByVinyl[sharedVinylID]
        let selectionInSecond = second.selectedTrackByVinyl[sharedVinylID]
        #expect(selectionInMixed != nil)
        #expect(selectionInSecond != nil)
        #expect(selectionInMixed != selectionInSecond)
    }

    // demoStore wires both crates in and is deterministic across runs.
    let demo1 = FixtureCrates.demoStore
    let demo2 = FixtureCrates.demoStore
    #expect(demo1 == demo2)
    #expect(demo1.crates.count >= 2)
}
