import Foundation
import Testing
@testable import VinylSetBuilderCore

// SEG-07. Every string below is a real read, measured off the owner's records by the OCR
// spike and quoted verbatim from `.local/ocr/ocr2_out.json`:
//   "The Message -" / "Brown" / "Dom &" / "Roland" / "0-44904"   IMG_0498
//   "A: High Down" / "Cause 4 Concern" / "Strange"               IMG_0503
//   "Da Lick"                                                    IMG_0508 (read four times)
// Nothing here is invented. The over-split shapes are what D-03-4's Act I segmenter emits.

private func makeDraft(_ texts: [String], vinyl: UUID = UUID()) -> SegmentationDraft {
    let tracks = texts.enumerated().map {
        Track(vinylID: vinyl, position: $0.offset, rawOCRText: $0.element)
    }
    return SegmentationDraft(vinylID: vinyl, tracks: tracks)
}

// MARK: - Construction

@Test("SEG-07: a draft is one line per track, in position order, straight from the raw read")
func test_givenTracksOutOfOrder_whenDrafted_thenLinesFollowPositionAndCarryRawText() {
    let vinyl = UUID()
    let tracks = [
        Track(vinylID: vinyl, position: 2, rawOCRText: "Roland"),
        Track(vinylID: vinyl, position: 0, rawOCRText: "The Message -"),
        Track(vinylID: vinyl, position: 1, rawOCRText: "Dom &"),
    ]
    let draft = SegmentationDraft(vinylID: vinyl, tracks: tracks)

    #expect(draft.lines.map(\.text) == ["The Message -", "Dom &", "Roland"])
    #expect(draft.lines.allSatisfy { $0.isHandEdited == false })
    #expect(draft.vinylID == vinyl)
}

@Test("SEG-07: an empty track list drafts empty and converts back empty, not into a trap")
func test_givenNoTracks_whenDrafted_thenLinesAndTracksAreBothEmpty() {
    let draft = makeDraft([])
    #expect(draft.lines.isEmpty)
    #expect(draft.tracks().isEmpty)
}

// MARK: - mergeUp — the operation the over-split Act I draft needs first (D-03-4)

@Test("SEG-07: merging line 2 into line 1 joins the texts with one space and drops the SECOND line")
func test_givenTwoLines_whenSecondMergedUp_thenOneLineRemainsAndItIsTheFirst() {
    var draft = makeDraft(["Da Lick", "Da Lick"])
    let firstID = draft.lines[0].id
    let secondID = draft.lines[1].id

    draft.mergeUp(secondID)

    #expect(draft.lines.count == 1)
    #expect(draft.lines[0].text == "Da Lick Da Lick")
    #expect(draft.lines[0].id == firstID)                    // the survivor is the line ABOVE
    #expect(!draft.lines.contains { $0.id == secondID })     // and the second is gone
}

@Test("SEG-07: mergeUp on the FIRST line is a no-op — there is nothing above it")
func test_givenTheFirstLine_whenMergedUp_thenTheDraftIsUnchangedIncludingIDs() {
    var draft = makeDraft(["The Message -", "Brown"])
    let before = draft

    draft.mergeUp(draft.lines[0].id)

    #expect(draft.lines.count == 2)
    #expect(draft.lines.map(\.text) == ["The Message -", "Brown"])
    #expect(draft.lines.map(\.id) == before.lines.map(\.id))
    #expect(draft == before)
}

@Test("SEG-07: mergeUp on an id the draft does not hold is a no-op, not a trap")
func test_givenAnUnknownID_whenMergedUp_thenTheDraftIsUnchanged() {
    var draft = makeDraft(["The Message -", "Brown"])
    let before = draft

    draft.mergeUp(UUID())

    #expect(draft == before)
}

@Test("SEG-07: four over-split IMG_0498 lines merge bottom-up into one track")
func test_givenFourOverSplitLines_whenMergedThreeTimes_thenOneLineAndOneTrackRemain() {
    var draft = makeDraft(["The Message -", "Brown", "Dom &", "Roland"])
    #expect(draft.tracks().count == 4)          // the state the merge has to fix

    for _ in 0..<3 {
        draft.mergeUp(draft.lines[draft.lines.count - 1].id)
    }

    #expect(draft.lines.count == 1)
    #expect(draft.lines[0].text == "The Message - Brown Dom & Roland")
    #expect(draft.tracks().count == 1)
    #expect(draft.tracks()[0].rawOCRText == "The Message - Brown Dom & Roland")
}

// MARK: - splitLine

@Test("SEG-07: a multi-word line splits at the word midpoint, in place")
func test_givenAMultiWordLine_whenSplit_thenTwoLinesAndTheNewOneSitsImmediatelyAfter() {
    var draft = makeDraft(["A: High Down Strange Nature", "0-44904"])
    let target = draft.lines[0].id

    draft.splitLine(target)

    #expect(draft.lines.count == 3)
    #expect(draft.lines.map(\.text) == ["A: High Down", "Strange Nature", "0-44904"])
    #expect(draft.lines[0].id == target)                 // the original line keeps its id
    #expect(draft.lines[1].id != target)                 // the new half is a new line
}

@Test("SEG-07: an odd word count favours the first line — three words split 2/1")
func test_givenAThreeWordLine_whenSplit_thenTheFirstLineTakesTwoWords() {
    var draft = makeDraft(["Cause 4 Concern"])

    draft.splitLine(draft.lines[0].id)

    #expect(draft.lines.map(\.text) == ["Cause 4", "Concern"])
}

@Test("SEG-07: splitting a SINGLE-WORD line is a no-op — the boundary the rule most easily gets wrong")
func test_givenASingleWordLine_whenSplit_thenNothingChangesIncludingTheID() {
    var draft = makeDraft(["Roland"])
    let before = draft

    draft.splitLine(draft.lines[0].id)

    #expect(draft.lines.count == 1)
    #expect(draft.lines[0].text == "Roland")
    #expect(draft.lines[0].id == before.lines[0].id)
    #expect(draft == before)
}

@Test("SEG-07: splitLine on an unknown id is a no-op")
func test_givenAnUnknownID_whenSplit_thenTheDraftIsUnchanged() {
    var draft = makeDraft(["A: High Down Strange Nature"])
    let before = draft

    draft.splitLine(UUID())

    #expect(draft == before)
}

@Test("SEG-07: split then mergeUp restores the original text EXACTLY — the round trip both ways")
func test_givenASplitLine_whenMergedBackUp_thenTheOriginalTextIsRestoredVerbatim() {
    let original = "A: High Down Strange Nature"
    var draft = makeDraft([original])

    draft.splitLine(draft.lines[0].id)
    #expect(draft.lines.count == 2)                       // negative control: the split DID happen
    #expect(draft.lines[0].text != original)              // and it really changed the text

    draft.mergeUp(draft.lines[1].id)

    #expect(draft.lines.count == 1)
    #expect(draft.lines[0].text == original)
}

// MARK: - setText / addLine (hand entry)

@Test("SEG-07: setText replaces the text, flags the line hand-edited, and leaves the others alone")
func test_givenALine_whenTextSet_thenOnlyThatLineChangesAndIsFlagged() {
    var draft = makeDraft(["Da Lich", "Da Lick"])

    draft.setText(draft.lines[0].id, to: "Da Lick")

    #expect(draft.lines[0].text == "Da Lick")
    #expect(draft.lines[0].isHandEdited == true)
    #expect(draft.lines[1].text == "Da Lick")
    #expect(draft.lines[1].isHandEdited == false)
}

@Test("SEG-07: clearing a field REMOVES the line — that is how a person deletes a junk read")
func test_givenAJunkLine_whenClearedToEmptyOrWhitespace_thenTheLineIsRemoved() {
    var draft = makeDraft(["Remi:600", "Da Lick"])
    draft.setText(draft.lines[0].id, to: "")
    #expect(draft.lines.map(\.text) == ["Da Lick"])

    var whitespace = makeDraft(["Remi:600", "Da Lick"])
    whitespace.setText(whitespace.lines[0].id, to: "   ")
    #expect(whitespace.lines.map(\.text) == ["Da Lick"])
}

@Test("SEG-07: setText on an unknown id is a no-op")
func test_givenAnUnknownID_whenTextSet_thenTheDraftIsUnchanged() {
    var draft = makeDraft(["Da Lick"])
    let before = draft

    draft.setText(UUID(), to: "Something Else")

    #expect(draft == before)
}

@Test("SEG-07: addLine appends one empty hand-typed line, and twice gives two distinct ids")
func test_givenADraft_whenLinesAdded_thenEachIsEmptyHandEditedAndUniquelyIdentified() {
    var draft = makeDraft(["Da Lick"])

    draft.addLine()
    #expect(draft.lines.count == 2)
    #expect(draft.lines[1].text.isEmpty)
    #expect(draft.lines[1].isHandEdited == true)

    let firstAdded = draft.lines[1].id
    draft.addLine()
    #expect(draft.lines.count == 3)
    #expect(draft.lines[2].id != firstAdded)
}

// MARK: - tracks()

@Test("SEG-07: positions are contiguous 0..<n after ANY sequence of edits")
func test_givenManyEdits_whenConvertedBack_thenPositionsAreContiguousFromZero() {
    var draft = makeDraft(["The Message -", "Brown", "Dom &", "Roland"])
    draft.mergeUp(draft.lines[1].id)                       // 4 -> 3
    draft.splitLine(draft.lines[0].id)                     // 3 -> 4
    draft.addLine()                                        // 4 lines + 1 blank
    draft.setText(draft.lines[4].id, to: "0-44904")        // the blank becomes a real line

    let tracks = draft.tracks()
    #expect(tracks.count == 5)
    #expect(tracks.map(\.position) == Array(0..<5))
}

@Test("SEG-07: every produced track carries the draft's vinyl, its line's text, and no metadata yet")
func test_givenADraft_whenConvertedBack_thenTracksArePendingAndUnresolved() {
    let vinyl = UUID()
    let draft = makeDraft(["A: High Down", "AAA: Strange Nat ure"], vinyl: vinyl)

    let tracks = draft.tracks()

    #expect(tracks.map(\.rawOCRText) == ["A: High Down", "AAA: Strange Nat ure"])
    #expect(tracks.allSatisfy { $0.vinylID == vinyl })
    #expect(tracks.allSatisfy { $0.resolutionState == .pending })
    #expect(tracks.allSatisfy { $0.bpm == nil })
    #expect(tracks.allSatisfy { $0.camelot == nil })
}

@Test("SEG-07: empty and whitespace-only lines never become tracks")
func test_givenBlankLines_whenConvertedBack_thenTheyAreDroppedAndTheRestRenumber() {
    var draft = makeDraft(["Da Lick"])
    draft.addLine()                                        // an untouched blank line
    #expect(draft.lines.count == 2)                        // it IS in the draft...

    let tracks = draft.tracks()
    #expect(tracks.count == 1)                             // ...and is NOT in the tracks
    #expect(tracks.map(\.position) == [0])
}

@Test("SEG-07: line ids are stable across tracks(), so a re-render cannot lose the selection")
func test_givenADraft_whenConvertedTwice_thenTheTrackIDsAreIdentical() {
    var draft = makeDraft(["The Message -", "Brown"])
    draft.mergeUp(draft.lines[1].id)

    let first = draft.tracks().map(\.id)
    let second = draft.tracks().map(\.id)

    #expect(first == second)
    #expect(first == draft.lines.map(\.id))
}
