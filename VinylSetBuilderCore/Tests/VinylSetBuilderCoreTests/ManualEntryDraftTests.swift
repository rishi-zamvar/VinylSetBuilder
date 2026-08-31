import Foundation
import Testing
@testable import VinylSetBuilderCore

/// MAN-01, MAN-02 and MAN-03 as a value, so the sheet that renders them holds no rules.
///
/// The reason this is load-bearing rather than a fallback: Phase 7 measured the bundled tier-0
/// corpus at **0 of 35** against this collection, and the last end-to-end run put **8 of 12**
/// records outside the set. Hand entry is the path half a jungle crate takes, so it is designed
/// for the twelfth use of the evening, not the first.

private func track(bpm: Double? = nil, camelot: String? = nil,
                   artist: String? = nil, title: String? = nil,
                   raw: String = "A: SCRIBBLE") -> Track {
    Track(vinylID: UUID(), rawOCRText: raw, artist: artist, title: title,
          bpm: bpm, camelot: camelot)
}

// MARK: - MAN-03: the field is never empty

@Test("MAN-03: the track's own tempo wins the prefill")
func test_givenATrackThatAlreadyHasATempo_whenTheDraftOpens_thenItsOwnValueIsOffered() {
    let draft = ManualEntryDraft(track: track(bpm: 172.5), neighbours: [track(bpm: 100)])
    #expect(draft.bpmText == "172.5")
}

@Test("MAN-03: with no tempo of its own the crate's MEDIAN neighbour is offered")
func test_givenNoTempoOfItsOwn_whenTheDraftOpens_thenTheMedianNeighbourIsOffered() {
    // Median, not mean, and this fixture is why: one out-of-genre read at the bottom drags a
    // mean somewhere the crate never goes. Mean here is 165.75 — a tempo no record in this
    // collection has. Sorted the four are [141, 172, 174, 176]; the lower of the two middles
    // is 172, which is a tempo the crate actually contains.
    let neighbours = [track(bpm: 172), track(bpm: 174), track(bpm: 176), track(bpm: 141)]
    let draft = ManualEntryDraft(track: track(), neighbours: neighbours)
    #expect(draft.bpmText == "172")
    #expect(draft.bpmText != "165.75", "the prefill is a mean, and a mean is not in the crate")
}

@Test("MAN-03: an even number of neighbours takes the lower of the two middles, deterministically")
func test_givenAnEvenNumberOfNeighbours_whenTheDraftOpens_thenThePrefillIsDeterministic() {
    let neighbours = [track(bpm: 170), track(bpm: 176)]
    let a = ManualEntryDraft(track: track(), neighbours: neighbours).bpmText
    let b = ManualEntryDraft(track: track(), neighbours: neighbours.reversed()).bpmText
    #expect(a == b, "the prefill depends on the order the neighbours arrive in")
    #expect(a == "170")
}

@Test("MAN-03: neighbours are folded before the median is taken")
func test_givenAHalfTimeNeighbour_whenTheDraftOpens_thenItIsFoldedFirst() {
    // An 87 BPM read IS a 174 BPM record (D6). Taking the median of raw reads would offer 87,
    // which is a number this collection never contains.
    let draft = ManualEntryDraft(track: track(), neighbours: [track(bpm: 87), track(bpm: 174),
                                                              track(bpm: 88)])
    #expect(draft.bpmText == "174")
}

@Test("MAN-03: with nothing to go on the field still is not empty")
func test_givenNoNeighboursAtAll_whenTheDraftOpens_thenTheGenreCentreIsOffered() {
    let draft = ManualEntryDraft(track: track(), neighbours: [])
    #expect(draft.bpmText == "174")
    #expect(!draft.bpmText.isEmpty, "MAN-03 forbids an empty tempo field")
}

@Test("MAN-03: a neighbour with no tempo contributes nothing rather than a zero")
func test_givenNeighboursWithoutTempos_whenTheDraftOpens_thenTheyAreIgnored() {
    let draft = ManualEntryDraft(track: track(), neighbours: [track(), track(bpm: 168), track()])
    #expect(draft.bpmText == "168")
}

// MARK: - MAN-02: a tap grid, never a keyboard

@Test("MAN-02: the grid is the whole wheel — 24 codes, all distinct, all parseable")
func test_givenTheCamelotGrid_whenRead_thenItIsTheWholeWheelExactlyOnce() {
    let grid = ManualEntryDraft.camelotGrid
    #expect(grid.count == 24)
    #expect(Set(grid).count == 24)
    #expect(grid.allSatisfy { Camelot.parse($0) != nil })
    // Every hour appears once as minor and once as major — a grid missing 11B is a grid that
    // cannot express a third of this collection.
    for hour in 1...12 {
        #expect(grid.contains("\(hour)A"))
        #expect(grid.contains("\(hour)B"))
    }
}

@Test("MAN-02: the grid reads as two blocks of twelve, minor then major")
func test_givenTheCamelotGrid_whenRead_thenItIsOrderedForTheEye() {
    #expect(ManualEntryDraft.camelotGrid.first == "1A")
    #expect(ManualEntryDraft.camelotGrid[11] == "12A")
    #expect(ManualEntryDraft.camelotGrid[12] == "1B")
    #expect(ManualEntryDraft.camelotGrid.last == "12B")
}

@Test("MAN-02: a key already on the track opens selected, so confirming it costs no taps")
func test_givenATrackWithAKey_whenTheDraftOpens_thenThatKeyIsAlreadySelected() {
    #expect(ManualEntryDraft(track: track(camelot: "6A"), neighbours: []).camelot == "6A")
    // A musical key that came off a database rather than the wheel is normalised on the way in,
    // so the grid can show it as selected at all.
    #expect(ManualEntryDraft(track: track(camelot: "Am"), neighbours: []).camelot == "8A")
    #expect(ManualEntryDraft(track: track(camelot: "utter nonsense"), neighbours: []).camelot == nil)
}

// MARK: - MAN-01: applying the edit

@Test("MAN-01: all four fields land on the track, and it is marked manual")
func test_givenAnEditedDraft_whenApplied_thenAllFourFieldsLandAndTheTrackIsMarked() {
    let original = track(raw: "A: HDDN AGNDA")
    var draft = ManualEntryDraft(track: original, neighbours: [])
    draft.artist = "Hidden Agenda"
    draft.title = "Is It Love"
    draft.bpmText = "172"
    draft.camelot = "6A"

    let edited = draft.applied(to: original)
    #expect(edited.artist == "Hidden Agenda")
    #expect(edited.title == "Is It Love")
    #expect(edited.bpm == 172)
    #expect(edited.camelot == "6A")
    #expect(edited.resolutionState == .manual)   // MAN-04's mark, set here and only here
    #expect(edited.id == original.id)
    #expect(edited.vinylID == original.vinylID)
    #expect(edited.position == original.position)
    // The raw read is evidence of what the camera saw and is never edited away.
    #expect(edited.rawOCRText == "A: HDDN AGNDA")
}

@Test("MAN-01: a hand-typed tempo folds exactly like every other tempo in the app")
func test_givenAHalfTimeTypedTempo_whenApplied_thenItFoldsLikeTheBadgeDoes() {
    // The badge renders the FOLDED value and the sequencer gates on it. If hand entry did not
    // fold, a typed 87 would show as 174 on the badge and be gated at 87 — the screen would
    // contradict the ordering, which is exactly the class of bug D6 exists to prevent.
    var draft = ManualEntryDraft(track: track(), neighbours: [])
    draft.bpmText = "87"
    #expect(draft.applied(to: track()).bpm == 174)
}

@Test("MAN-01: whitespace and empty fields clear rather than storing blanks")
func test_givenBlankFields_whenApplied_thenTheyClearRatherThanStoringEmptyStrings() {
    var draft = ManualEntryDraft(track: track(artist: "Wrong", title: "Wrong"), neighbours: [])
    draft.artist = "   "
    draft.title = ""
    draft.bpmText = ""
    draft.camelot = nil
    let edited = draft.applied(to: track(artist: "Wrong", title: "Wrong"))
    #expect(edited.artist == nil)
    #expect(edited.title == nil)
    #expect(edited.bpm == nil)
    #expect(edited.camelot == nil)
    // An empty string would render as a blank row rather than falling back to the raw read,
    // which is why `displayName` must still find something to say.
    #expect(edited.displayName == "A: SCRIBBLE")
}

@Test("MAN-01: an unparseable tempo is refused rather than stored as garbage")
func test_givenAnUnparseableTempo_whenApplied_thenNoTempoIsStored() {
    var draft = ManualEntryDraft(track: track(), neighbours: [])
    draft.bpmText = "one seventy four"
    #expect(draft.applied(to: track()).bpm == nil)
}

@Test("MAN-01: a stale failure note is cleared — a person has now answered the question")
func test_givenATrackCarryingAFailureNote_whenAppliedByHand_thenTheNoteIsCleared() {
    var original = track()
    original.failureReason = ExclusionReason.noSoundCloudMatch
    var draft = ManualEntryDraft(track: original, neighbours: [])
    draft.bpmText = "174"
    #expect(draft.applied(to: original).failureReason == nil)
}

@Test("MAN-01: the steppers move the tempo by exactly one, from whatever is in the field")
func test_givenTheStepper_whenNudged_thenTheTempoMovesByOneAndStaysReadable() {
    var draft = ManualEntryDraft(track: track(bpm: 174), neighbours: [])
    draft.nudgeBPM(by: 1)
    #expect(draft.bpmText == "175")
    draft.nudgeBPM(by: -1)
    draft.nudgeBPM(by: -1)
    #expect(draft.bpmText == "173")
    // A stepper on an unreadable field falls back to the prefill rather than doing nothing —
    // a dead control is worse than a surprising one.
    draft.bpmText = "banana"
    draft.nudgeBPM(by: 1)
    #expect(Double(draft.bpmText) != nil)
}

// MARK: - The one write path

@Test("MAN-01: an edited candidate is written back through exactly one store mutator")
func test_givenAnEditedTrack_whenWrittenBack_thenTheCrateCarriesItAndNothingElseMoves() {
    let vinylA = UUID(), vinylB = UUID()
    let target = Track(id: UUID(), vinylID: vinylA, position: 1, rawOCRText: "TWO")
    let sibling = Track(id: UUID(), vinylID: vinylA, position: 0, rawOCRText: "ONE")
    let other = Track(id: UUID(), vinylID: vinylB, position: 0, rawOCRText: "ELSEWHERE")
    let crate = Crate(name: "C", vinyls: [
        VinylEntry(id: vinylA, candidates: [sibling, target], position: 0),
        VinylEntry(id: vinylB, candidates: [other], position: 1),
    ])
    var store = CrateStore(crates: [crate])

    var edited = target
    edited.artist = "Hidden Agenda"
    edited.resolutionState = .manual
    store.updateTrack(edited, in: crate.id)

    let after = store.crate(crate.id)!
    #expect(after.vinyls[0].orderedCandidates[1].artist == "Hidden Agenda")
    #expect(after.vinyls[0].orderedCandidates[1].position == 1, "PERS-02: the position field is untouched")
    #expect(after.vinyls[0].orderedCandidates[0] == sibling, "a sibling candidate was disturbed")
    #expect(after.vinyls[1].orderedCandidates[0] == other, "another vinyl was disturbed")
}

@Test("MAN-01: writing back a track no crate holds is a no-op, not a trap")
func test_givenAnUnknownTrackOrCrate_whenWrittenBack_thenNothingHappens() {
    let crate = Crate(name: "C", vinyls: [VinylEntry(candidates: [])])
    var store = CrateStore(crates: [crate])
    store.updateTrack(Track(vinylID: UUID()), in: crate.id)
    store.updateTrack(Track(vinylID: UUID()), in: UUID())
    #expect(store.crate(crate.id) == crate)
}
