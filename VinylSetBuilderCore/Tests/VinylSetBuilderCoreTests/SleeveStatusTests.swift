import CoreGraphics
import Foundation
import Testing
@testable import VinylSetBuilderCore

/// Phase 8, swap 2. The read status stops being a hand-scored table and becomes a rule.
///
/// `FixturePhotoSource` carried CONTEXT.md §3's verdicts as literals, which was honest while
/// nothing actually read a photograph. Now something does, so the status has to be DERIVED from
/// what the reader and the segmenter produced — including on a record the owner has never
/// photographed, which is every record after the twelve.
///
/// The rule is deliberately not tuned. A sleeve read WELL when it yielded something to resolve
/// *with* — a catalogue number or a stated side — as well as something to resolve. It read
/// PARTIALLY when it yielded only lines. It did not read at all when it yielded no line.
private func observation(_ text: String, _ confidence: Float = 1.0) -> TextObservation {
    TextObservation(text: text,
                    boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.1),
                    confidence: confidence,
                    baselineAngle: 0)
}

private func segmentation(lines: Int, catalogue: String? = nil, sides: [String] = []) -> LabelSegmentation {
    let vinylID = UUID()
    return LabelSegmentation(tracks: (0..<lines).map {
        Track(vinylID: vinylID, position: $0, rawOCRText: "line \($0)")
    }, catalogueNumber: catalogue, sides: sides)
}

@Test("CAP-03: a sleeve that gave lines AND a catalogue number reads as Read")
func test_givenLinesAndACatalogueNumber_whenScored_thenTheSleeveReads() {
    #expect(SleeveStatus.status(for: segmentation(lines: 3, catalogue: "TYME012")) == .read)
}

@Test("CAP-03: a sleeve that gave lines AND a stated side reads as Read")
func test_givenLinesAndAStatedSide_whenScored_thenTheSleeveReads() {
    #expect(SleeveStatus.status(for: segmentation(lines: 2, sides: ["A", "AA"])) == .read)
}

@Test("CAP-03: lines with no catalogue number and no stated side are a Partial read")
func test_givenLinesAlone_whenScored_thenTheSleeveIsPartial() {
    #expect(SleeveStatus.status(for: segmentation(lines: 5)) == .partial)
}

@Test("CAP-03: no track line at all is Unread, whatever else was on the sleeve")
func test_givenNoLines_whenScored_thenTheSleeveIsUnread() {
    #expect(SleeveStatus.status(for: segmentation(lines: 0)) == .unread)
    // Two-sided: a catalogue number is not a track, so it cannot promote an empty read.
    #expect(SleeveStatus.status(for: segmentation(lines: 0, catalogue: "TECH008")) == .unread)
    #expect(SleeveStatus.status(for: segmentation(lines: 0, sides: ["A"])) == .unread)
}

@Test("CAP-01: a status that means 'the reader has not answered yet' exists and is distinct")
func test_givenTheReadingStatus_whenLabelled_thenItIsItsOwnCaseWithItsOwnLabel() {
    #expect(CaptureItemStatus.allCases.contains(.reading))
    #expect(Set(CaptureItemStatus.allCases.map(\.label)).count == CaptureItemStatus.allCases.count,
            "two statuses render the same label — the strip could not tell them apart")
    #expect(!CaptureItemStatus.reading.label.isEmpty)
    // The whole point of the case: it is not a verdict, so it must not be mistaken for one.
    #expect(CaptureItemStatus.reading != .unread)
}

// MARK: - CAP-01: the two-phase item

@Test("CAP-01: an item can be captured before it has been read, and replaced once it has")
func test_givenAReadingItem_whenReplacedWithItsRead_thenTheSessionShowsTheRead() {
    var session = CaptureSession(crateID: UUID())
    let pending = CaptureItem(index: 1, photoRef: "shot.heic", observations: [],
                              sideMarkers: [], status: .reading)
    session.append(pending)
    #expect(session.items.map(\.status) == [.reading])

    let read = CaptureItem(id: pending.id, index: 1, photoRef: "shot.heic",
                           observations: [observation("HIGHER")],
                           sideMarkers: ["A", "AA"], status: .read)
    session.replace(read)

    #expect(session.items.count == 1, "replace appended instead of replacing")
    #expect(session.items[0].status == .read)
    #expect(session.items[0].observations.map(\.text) == ["HIGHER"])
    // The identity survives the replacement, or the inspect sheet loses its way back.
    #expect(session.items[0].id == pending.id)
}

@Test("CAP-05: the flip prompt is decided when the READ lands, not when the shutter fires")
func test_givenAReadingItem_whenItsReadYieldsTwoSides_thenTheFlipPromptIsWithdrawn() {
    var session = CaptureSession(crateID: UUID())
    let pending = CaptureItem(index: 1, photoRef: "shot.heic", observations: [],
                              sideMarkers: [], status: .reading)
    session.append(pending)
    // A not-yet-read item has read no markers, so a prompt raised at append time would ask
    // about every single photograph — including the ones that turn out to state both sides.
    session.replace(CaptureItem(id: pending.id, index: 1, photoRef: "shot.heic",
                                observations: [observation("A:")],
                                sideMarkers: ["A", "AA"], status: .read))
    #expect(session.pendingFlipPrompt == nil)

    // …and the other direction, in the same test, so a `pendingFlipPrompt` that was simply
    // always nil could not pass.
    var second = CaptureSession(crateID: UUID())
    let other = CaptureItem(index: 1, photoRef: "b.heic", observations: [],
                            sideMarkers: [], status: .reading)
    second.append(other)
    second.replace(CaptureItem(id: other.id, index: 1, photoRef: "b.heic",
                               observations: [observation("HIGHER")],
                               sideMarkers: ["A"], status: .partial))
    #expect(second.pendingFlipPrompt == other.id)
}

@Test("CAP-05: a replaced item that is no longer the latest does not raise a prompt")
func test_givenTwoShots_whenTheFirstReadLandsLast_thenItDoesNotRaiseAPromptOverTheSecond() {
    var session = CaptureSession(crateID: UUID())
    let first = CaptureItem(index: 1, photoRef: "a.heic", observations: [], sideMarkers: [], status: .reading)
    let second = CaptureItem(index: 2, photoRef: "b.heic", observations: [], sideMarkers: [], status: .reading)
    session.append(first)
    session.append(second)

    // Recognition is concurrent, so the first shot's read can land after the second shot.
    session.replace(CaptureItem(id: first.id, index: 1, photoRef: "a.heic",
                                observations: [observation("HIGHER")],
                                sideMarkers: [], status: .partial))
    #expect(session.pendingFlipPrompt == nil,
            "a stale read raised the flip prompt about a record two shutter presses ago")
}

@Test("OCR-02: an item carries the orientation its observations were read at")
func test_givenAnItemReadAtAnOrientation_whenSegmented_thenTheOrientationTravelsWithIt() {
    let subject = CaptureItem(index: 1, photoRef: "a.heic", observations: [observation("HIGHER")],
                              sideMarkers: [], status: .read, orientation: .left)
    #expect(subject.orientation == .left)
    // The corpus's own orientation is the default, so nothing that does not know has to guess.
    #expect(CaptureItem(index: 1, photoRef: "a.heic", observations: [], sideMarkers: [],
                        status: .reading).orientation == .right)
}
