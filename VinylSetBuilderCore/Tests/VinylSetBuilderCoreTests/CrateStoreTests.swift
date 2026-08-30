import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - CRATE-01: listing

@Test("Each saved crate summarises with its name and record count")
func test_givenSavedCrates_whenSummarised_thenEachCarriesItsNameAndRecordCount() {
    let empty = Crate(name: "Empty", vinyls: [])
    let one = Crate(name: "One", vinyls: [VinylEntry(position: 0)])
    let four = Crate(name: "Four", vinyls: (0..<4).map { VinylEntry(position: $0) })
    let store = CrateStore(crates: [empty, one, four])

    let summaries = Dictionary(uniqueKeysWithValues: store.summaries.map { ($0.name, $0.recordCount) })
    #expect(summaries["Empty"] == 0)
    #expect(summaries["One"] == 1)
    #expect(summaries["Four"] == 4)
}

@Test("An empty store summarises to an empty list, not nil")
func test_givenNoCrates_whenSummarised_thenTheListIsEmptyNotNil() {
    let store = CrateStore()
    #expect(store.summaries.isEmpty)
}

@Test("Crates created in sequence summarise newest first")
func test_givenCratesCreatedInSequence_whenSummarised_thenNewestIsFirst() {
    var store = CrateStore()
    let base = Date(timeIntervalSince1970: 0)
    store.createCrate(named: "First", now: base)
    store.createCrate(named: "Second", now: base.addingTimeInterval(60))
    store.createCrate(named: "Third", now: base.addingTimeInterval(120))

    #expect(store.summaries.map(\.name) == ["Third", "Second", "First"])
}

@Test("Removing a vinyl drops the derived record count, not a stored one")
func test_givenAVinylIsRemoved_whenSummarised_thenTheRecordCountDrops() {
    let crateID = UUID()
    let vinyl = VinylEntry(id: UUID(), position: 0)
    var store = CrateStore(crates: [Crate(id: crateID, name: "Crate", vinyls: [vinyl])])

    #expect(store.summaries.first?.recordCount == 1)
    store.removeVinyl(vinyl.id, from: crateID)
    #expect(store.summaries.first?.recordCount == 0)
}

// MARK: - CRATE-02: creation

@Test("Creating a crate names it, lists it, and routes to capture in one call")
func test_givenAName_whenCrateCreated_thenItAppearsInTheListAndTheRouteIsCapture() {
    var store = CrateStore()
    let newID = store.createCrate(named: "Friday")

    #expect(store.crates.contains { $0.id == newID })
    #expect(store.summaries.contains { $0.id == newID && $0.name == "Friday" })
    #expect(store.route == .capture(crateID: newID))
}

@Test("A blank name falls back to Untitled Crate")
func test_givenABlankName_whenCrateCreated_thenItGetsAFallbackName() {
    var store = CrateStore()
    let id1 = store.createCrate(named: "")
    let id2 = store.createCrate(named: "   ")

    #expect(store.crate(id1)?.name == "Untitled Crate")
    #expect(store.crate(id2)?.name == "Untitled Crate")
}

@Test("A whitespace-padded name is trimmed")
func test_givenAWhitespacePaddedName_whenCrateCreated_thenItIsTrimmed() {
    var store = CrateStore()
    let id = store.createCrate(named: "  Friday  ")
    #expect(store.crate(id)?.name == "Friday")
}

@Test("A newly created crate has the default BPM tolerance")
func test_givenANewCrate_whenCreated_thenItHasTheDefaultBPMTolerance() {
    var store = CrateStore()
    let id = store.createCrate(named: "Crate")
    #expect(store.crate(id)?.bpmTolerance == BPMRules.defaultTolerance)
}

// MARK: - CRATE-06: deletion

@Test("Deleting one crate leaves the other untouched")
func test_givenTwoCrates_whenOneIsDeleted_thenOnlyThatOneDisappears() {
    let survivor = Crate(name: "Survivor", vinyls: [VinylEntry(position: 0)],
                          selectedTrackByVinyl: [UUID(): UUID()])
    let doomed = Crate(name: "Doomed", vinyls: [VinylEntry(position: 0)])
    var store = CrateStore(crates: [survivor, doomed])

    store.deleteCrate(doomed.id)

    #expect(store.crates.count == 1)
    #expect(store.crate(survivor.id) == survivor)
}

@Test("Removing a vinyl removes only that vinyl")
func test_givenACrateWithVinyls_whenAVinylIsRemoved_thenOnlyThatVinylGoes() {
    let track = Track(vinylID: UUID(), position: 0, artist: "A", title: "T")
    let keep = VinylEntry(id: UUID(), candidates: [track], position: 0)
    let gone = VinylEntry(id: UUID(), position: 1)
    let crateID = UUID()
    var store = CrateStore(crates: [Crate(id: crateID, name: "Crate", vinyls: [keep, gone])])

    store.removeVinyl(gone.id, from: crateID)

    let remaining = store.crate(crateID)?.vinyls ?? []
    #expect(remaining.map(\.id) == [keep.id])
    #expect(remaining.first?.candidates == [track])
}

@Test("Removing the middle vinyl renumbers survivors contiguously")
func test_givenAVinylIsRemoved_whenPositionsAreRead_thenSurvivorsAreRenumberedContiguously() {
    let v0 = VinylEntry(id: UUID(), position: 0)
    let v1 = VinylEntry(id: UUID(), position: 1)
    let v2 = VinylEntry(id: UUID(), position: 2)
    let crateID = UUID()
    var store = CrateStore(crates: [Crate(id: crateID, name: "Crate", vinyls: [v0, v1, v2])])

    store.removeVinyl(v1.id, from: crateID)

    let positions = store.crate(crateID)?.vinyls.map(\.position).sorted() ?? []
    #expect(positions == [0, 1])
}

@Test("Removing a vinyl also removes its selection")
func test_givenAVinylIsRemoved_whenSelectionsAreRead_thenItsSelectionIsAlsoGone() {
    let vinyl = VinylEntry(id: UUID(), position: 0)
    let crateID = UUID()
    var store = CrateStore(crates: [Crate(id: crateID, name: "Crate", vinyls: [vinyl],
                                           selectedTrackByVinyl: [vinyl.id: UUID()])])

    store.removeVinyl(vinyl.id, from: crateID)

    #expect(store.crate(crateID)?.selectedTrackByVinyl[vinyl.id] == nil)
}

@Test("Deleting the currently open crate falls the route back to the list")
func test_givenTheCurrentlyOpenCrate_whenDeleted_thenTheRouteFallsBackToTheList() {
    let crate = Crate(name: "Crate", vinyls: [])
    var store = CrateStore(crates: [crate])
    store.open(crate.id)
    #expect(store.route == .crateDetail(crateID: crate.id))

    store.deleteCrate(crate.id)

    #expect(store.route == .crateList)
}

@Test("Deleting an unknown crate ID changes nothing and does not crash")
func test_givenAnUnknownCrateID_whenDeleted_thenNothingChangesAndNothingCrashes() {
    let crate = Crate(name: "Crate", vinyls: [])
    var store = CrateStore(crates: [crate])

    store.deleteCrate(UUID())

    #expect(store.crates == [crate])
}

// MARK: - Route

@Test("A fresh store's route is the crate list")
func test_givenAFreshStore_whenRouteIsRead_thenItIsTheCrateList() {
    let store = CrateStore()
    #expect(store.route == .crateList)
}

@Test("Opening a crate routes to that crate's detail")
func test_givenACrateIsOpened_whenRouteIsRead_thenItIsThatCrateDetail() {
    let crate = Crate(name: "Crate", vinyls: [])
    var store = CrateStore(crates: [crate])

    store.open(crate.id)

    #expect(store.route == .crateDetail(crateID: crate.id))
}
