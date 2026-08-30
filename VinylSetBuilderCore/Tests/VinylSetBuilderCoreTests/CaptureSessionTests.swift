import CoreGraphics
import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - helpers

private func observation(_ text: String, _ confidence: Float) -> TextObservation {
    TextObservation(text: text,
                    boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.1),
                    confidence: confidence,
                    baselineAngle: 0)
}

private func item(index: Int = 1,
                  photoRef: String = "IMG_0000.HEIC",
                  observations: [TextObservation] = [observation("HIGHER", 1.0)],
                  sideMarkers: [String] = [],
                  status: CaptureItemStatus = .read) -> CaptureItem {
    CaptureItem(index: index, photoRef: photoRef, observations: observations,
                sideMarkers: sideMarkers, status: status)
}

/// The Task-2 stand-in for `FixtureLineSegmenter`: one track per observation, nothing clever.
/// Deliberately not the real one — `vinylEntry(for:segmenter:)` is being tested here, not
/// segmentation, and a local stub keeps the two failures distinguishable.
private struct CountingSegmenter: LabelSegmenting {
    func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> LabelSegmentation {
        LabelSegmentation(tracks: observations.enumerated().map {
            Track(vinylID: vinylID, side: side, position: $0.offset, rawOCRText: $0.element.text)
        })
    }
}

// MARK: - CAP-03: the status a thumbnail shows

@Test("CAP-03/CAP-01: read status has four cases and every one of them says something")
func test_givenCaptureItemStatus_whenEnumerated_thenFourCasesAllCarryDistinctLabels() {
    #expect(CaptureItemStatus.allCases.count == 4)
    #expect(Set(CaptureItemStatus.allCases) == [.reading, .read, .partial, .unread])

    // Iterated, not named four times: a fifth case added later cannot slip through unlabelled.
    for status in CaptureItemStatus.allCases {
        #expect(!status.label.isEmpty, "\(status) has no label")
    }
    #expect(Set(CaptureItemStatus.allCases.map(\.label)).count == 4,
            "two statuses render the same label — the strip could not tell them apart")
    // Exactly one of the four is not a verdict, and it is the one CAP-01 added.
    #expect(CaptureItemStatus.allCases.filter { !$0.isVerdict } == [.reading])
}

// MARK: - CAP-03 / D-03-6: an item names itself from its own text

@Test("D-03-6: an item names itself from its first trusted observation, trimmed")
func test_givenAnItemWithTrustedText_whenNamed_thenItUsesThatTextTrimmed() {
    let subject = item(observations: [observation("  Cause 4 Concern  ", 1.0),
                                      observation("Hide Down", 1.0)])
    #expect(subject.displayLabel == "Cause 4 Concern")
}

@Test("D-03-6: an item with nothing trusted falls back to its photo reference")
func test_givenAnItemWithNoTrustedText_whenNamed_thenItFallsBackToThePhotoRef() {
    let subject = item(photoRef: "IMG_0507.HEIC",
                       observations: [observation("cemenic", 0.5), observation("DrumBass", 0.3)])
    #expect(subject.displayLabel == "IMG_0507.HEIC")
}

@Test("V12: a price-sticker fragment does not title a record")
func test_givenAFixtureWhoseFirstTrustedReadIsASticker_whenNamed_thenItSkipsIt() throws {
    // IMG_0503's FIRST trusted observation is "Zzz." — a two-syllable shard of a shop price
    // sticker — and for the whole of Act I it was this record's name on the thumbnail strip,
    // the flip prompt and the inspect sheet. The photograph also reads "Cause 4 Concern-" at
    // 1.00, four observations later in spatial reading order.
    let fixture = try #require(FixtureObservations.all.first { $0.file == "IMG_0503.HEIC" })
    #expect(fixture.observations.first?.text == "Zzz.", "the defect's own precondition moved")

    let subject = item(photoRef: fixture.file, observations: fixture.observations)
    #expect(subject.displayLabel != "Zzz.")
    #expect(subject.displayLabel == "Cause 4 Concern-")
}

@Test("V12: no fixture is named by anything the SEG-03 noise filter rejects")
func test_givenTheTwelveFixtures_whenNamed_thenNoNameIsFilteredNoise() {
    for (offset, fixture) in FixtureObservations.all.enumerated() {
        let name = item(index: offset + 1, photoRef: fixture.file,
                        observations: fixture.observations).displayLabel
        // The photo reference is the documented fallback and is not a reading at all.
        guard name != fixture.file else { continue }
        #expect(!TrackTextFilter.isNoise(name), "\(fixture.file) is named \(name)")
    }
}

@Test("D-03-6: no fixture ever renders as \"Vinyl N\" — V3 is kept out of the capture screens")
func test_givenTheTwelveFixtures_whenNamed_thenNoneRendersAsVinylN() throws {
    let vinylN = try Regex(#"^Vinyl \d+$"#)
    for (offset, fixture) in FixtureObservations.all.enumerated() {
        let subject = item(index: offset + 1, photoRef: fixture.file,
                           observations: fixture.observations)
        #expect(subject.displayLabel.firstMatch(of: vinylN) == nil,
                "\(fixture.file) rendered as \(subject.displayLabel)")
        #expect(!subject.displayLabel.isEmpty)
    }
    // Negative control: the regex does match the string V3 actually produces, so the loop
    // above is testing something rather than a pattern that never matches anything.
    #expect("Vinyl 2".firstMatch(of: vinylN) != nil)
}

// MARK: - CAP-05: the flip rule

@Test("CAP-05: the flip prompt is exactly \"fewer than two sides were read\"")
func test_givenSideMarkerCounts_whenAskedAboutAFlip_thenOnlyTwoOrMoreSuppressesThePrompt() {
    #expect(item(sideMarkers: []).shouldPromptForFlip)
    #expect(item(sideMarkers: ["A"]).shouldPromptForFlip)
    #expect(!item(sideMarkers: ["A", "AA"]).shouldPromptForFlip)
    #expect(!item(sideMarkers: ["COLD", "STEEL", "BONUS"]).shouldPromptForFlip)
}

// MARK: - CAP-03 / CAP-05: the session

@Test("CAP-03: a fresh session holds nothing and asks nothing")
func test_givenANewSession_whenInspected_thenItHasNoItemsAndNoPendingPrompt() {
    let session = CaptureSession(crateID: UUID())
    #expect(session.items.isEmpty)
    #expect(session.pendingFlipPrompt == nil)
    #expect(session.statusTally.isEmpty)
}

@Test("CAP-05: appending raises the prompt for a one-sided item and not for a two-sided one")
func test_givenASession_whenItemsAreAppended_thenOnlyTheOneSidedItemRaisesThePrompt() {
    var session = CaptureSession(crateID: UUID())

    let oneSided = item(index: 1, sideMarkers: ["A"])
    session.append(oneSided)
    #expect(session.pendingFlipPrompt == oneSided.id)

    // The other half in the same test: a count-only assertion would pass on always-prompt.
    session.dismissFlipPrompt()
    let twoSided = item(index: 2, sideMarkers: ["A", "AA"])
    session.append(twoSided)
    #expect(session.pendingFlipPrompt == nil)
}

@Test("CAP-05: dismissing clears the prompt, and dismissing nothing is not a trap")
func test_givenAPendingPrompt_whenDismissed_thenItClearsAndASecondDismissIsANoOp() {
    var session = CaptureSession(crateID: UUID())
    session.append(item(sideMarkers: []))
    #expect(session.pendingFlipPrompt != nil)

    session.dismissFlipPrompt()
    #expect(session.pendingFlipPrompt == nil)

    let before = session
    session.dismissFlipPrompt()
    #expect(session == before, "a second dismiss changed the session")
}

@Test("CAP-03: the strip keeps insertion order and each item's index is its 1-based position")
func test_givenSeveralAppends_whenTheStripIsRead_thenOrderAndIndicesAreContiguousFromOne() {
    var session = CaptureSession(crateID: UUID())
    for n in 1...5 {
        session.append(item(index: n, photoRef: "IMG_\(n).HEIC"))
    }
    #expect(session.items.map(\.photoRef)
            == ["IMG_1.HEIC", "IMG_2.HEIC", "IMG_3.HEIC", "IMG_4.HEIC", "IMG_5.HEIC"])
    #expect(session.items.map(\.index) == Array(1...5))
}

@Test("CAP-03: the status tally accounts for every item in the session, and only those")
func test_givenAMixedSession_whenTallied_thenTheCountsSumToTheItemCount() {
    var session = CaptureSession(crateID: UUID())
    for (n, status) in [CaptureItemStatus.read, .read, .partial, .unread].enumerated() {
        session.append(item(index: n + 1, status: status))
    }
    #expect(session.statusTally == [.read: 2, .partial: 1, .unread: 1])
    #expect(session.statusTally.values.reduce(0, +) == session.items.count)
}

@Test("CAP-03: an item becomes a vinyl entry carrying its own photo and its own lines")
func test_givenAnItemInASession_whenTurnedIntoAVinylEntry_thenItKeepsItsIdentityAndOrder() throws {
    var session = CaptureSession(crateID: UUID())
    let subject = item(photoRef: "IMG_0503.HEIC",
                       observations: [observation("SIDE A", 1.0),
                                      observation("TYME 012", 1.0),
                                      observation("Strange", 1.0)])
    session.append(subject)

    let entry = try #require(session.vinylEntry(for: subject.id, segmenter: CountingSegmenter()))
    #expect(entry.id == subject.id)
    #expect(entry.photoRefs == ["IMG_0503.HEIC"])
    #expect(entry.candidates.map(\.rawOCRText) == ["SIDE A", "TYME 012", "Strange"])
    #expect(entry.candidates.map(\.position) == [0, 1, 2])
    #expect(entry.candidates.allSatisfy { $0.vinylID == subject.id })

    // Two-sided: an id the session does not hold yields nothing, so the lookup is a real lookup.
    #expect(session.vinylEntry(for: UUID(), segmenter: CountingSegmenter()) == nil)
}

// MARK: - D-03-3 / CAP-03 / CAP-05: the twelve-fixture source
//
// This is the phase's ground truth, hand-scored in CONTEXT.md §3 from the owner's own OCR run.
// Every number below is a NAMED SET or a NAMED STRING, never a bare count: a table that
// suppressed the flip prompt on the wrong three records would still produce a count of three.

private func captureAll(_ n: Int, from source: FixturePhotoSource) async -> [CaptureItem] {
    var captured: [CaptureItem] = []
    for _ in 0..<n {
        if let item = await source.capture() { captured.append(item) }
    }
    return captured
}

@Test("CAP-03: the source deals the twelve real photographs in order, once each")
func test_givenTheFixtureSource_whenShotTwelveTimes_thenItYieldsTheTwelveRecordsInOrder() async {
    let items = await captureAll(12, from: FixturePhotoSource(crateID: UUID()))

    #expect(items.count == 12)
    #expect(items.map(\.photoRef) == FixtureObservations.all.map(\.file))
    #expect(items.map(\.index) == Array(1...12))
    #expect(Set(items.map(\.id)).count == 12, "two captures shared an id")
}

@Test("CAP-03: the twelve read 6 clean / 5 partial / 1 unread, exactly as the spike measured")
func test_givenTheTwelveFixtures_whenTallied_thenSixReadFivePartialOneUnread() async {
    var session = CaptureSession(crateID: UUID())
    for item in await captureAll(12, from: FixturePhotoSource(crateID: UUID())) {
        session.append(item)
    }

    #expect(session.statusTally == [.read: 6, .partial: 5, .unread: 1])
    #expect(session.statusTally.values.reduce(0, +) == 12)
}

@Test("CAP-05: the flip prompt fires on nine named fixtures and is suppressed on {2, 6, 9}")
func test_givenTheTwelveFixtures_whenAskedAboutFlips_thenExactlyTwoSixAndNineAreSuppressed() async {
    let items = await captureAll(12, from: FixturePhotoSource(crateID: UUID()))

    let prompting = Set(items.filter(\.shouldPromptForFlip).map(\.index))
    let suppressed = Set(items.filter { !$0.shouldPromptForFlip }.map(\.index))

    // Both sets, not both counts. A count-only assertion passes on the wrong nine.
    #expect(prompting == [1, 3, 4, 5, 7, 8, 10, 11, 12])
    #expect(suppressed == [2, 6, 9])
    #expect(prompting.isDisjoint(with: suppressed))
}

@Test("CAP-05: the three suppressed records are suppressed for the markers they actually read")
func test_givenTheSuppressedFixtures_whenInspected_thenTheyCarryTheirRealSideMarkers() async throws {
    let items = await captureAll(12, from: FixturePhotoSource(crateID: UUID()))

    func markers(_ index: Int) throws -> [String] {
        try #require(items.first { $0.index == index }).sideMarkers
    }

    #expect(try items.first { $0.index == 6 }?.photoRef == "IMG_0503.HEIC")
    #expect(try markers(6) == ["A", "AA"])
    #expect(try items.first { $0.index == 9 }?.photoRef == "IMG_0506.HEIC")
    #expect(try markers(9) == ["COLD", "STEEL"])
    // One-sided reading is not the same as no reading: fixture 3 read "Side One" and only that.
    #expect(try markers(3) == ["ONE"])
    #expect(try markers(1).isEmpty)
}

@Test("CAP-03: the source wraps, so a session longer than twelve shots is reachable")
func test_givenTwelveShotsTaken_whenTheThirteenthIsShot_thenTheSourceWrapsAndKeepsCounting() async throws {
    let source = FixturePhotoSource(crateID: UUID())
    let items = await captureAll(13, from: source)

    let thirteenth = try #require(items.last)
    #expect(thirteenth.photoRef == "IMG_0498.HEIC")
    #expect(thirteenth.index == 13)
    #expect(thirteenth.id != items[0].id, "the wrapped shot reused the first item's identity")
}

@Test("D-03-1: every dealt item carries the real observations, unmodified")
func test_givenTheFixtureSource_whenItemsAreDealt_thenTheirTextIsTheGeneratedTable() async {
    let items = await captureAll(12, from: FixturePhotoSource(crateID: UUID()))

    for (item, fixture) in zip(items, FixtureObservations.all) {
        #expect(!item.observations.isEmpty)
        #expect(item.observations == fixture.observations, "\(fixture.file) drifted from the table")
    }
}

// MARK: - D-03-4: the Act I segmenter

@Test("D-03-4: the Act I segmenter emits one line per trusted observation, in reading order")
func test_givenObservations_whenSegmented_thenOneTrackPerTrustedObservationInOrder() {
    let vinylID = UUID()
    let tracks = FixtureLineSegmenter().segment(
        [observation("SIDE A", 1.0), observation("noise", 0.3),
         observation("TYME 012", 1.0), observation("blur", 0.5)],
        vinylID: vinylID, side: .a).tracks

    #expect(tracks.map(\.rawOCRText) == ["SIDE A", "TYME 012"])
    #expect(tracks.map(\.position) == [0, 1])
    #expect(tracks.allSatisfy { $0.vinylID == vinylID })
    #expect(tracks.allSatisfy { $0.side == .a })
    #expect(tracks.allSatisfy { $0.resolutionState == .pending })
    #expect(tracks.allSatisfy { $0.bpm == nil && $0.camelot == nil })
}

@Test("D-03-4: untrusted observations produce no lines at all")
func test_givenOnlyUntrustedObservations_whenSegmented_thenNothingIsEmitted() {
    // Negative control: a segmenter that ignored confidence would emit three here and the
    // trusted-count assertions elsewhere would still pass on the fixtures that read cleanly.
    let tracks = FixtureLineSegmenter().segment(
        [observation("a", 0.5), observation("b", 0.5), observation("c", 0.5)],
        vinylID: UUID(), side: .b).tracks
    #expect(tracks.isEmpty)
    #expect(FixtureLineSegmenter().segment([], vinylID: UUID(), side: .a).tracks.isEmpty)
}

@Test("D-03-4: on the real fixtures the segmenter emits the trusted counts, large and small")
func test_givenTwoRealFixtures_whenSegmented_thenSixteenLinesAndThreeLines() throws {
    func lineCount(_ file: String) throws -> Int {
        let fixture = try #require(FixtureObservations.all.first { $0.file == file })
        return FixtureLineSegmenter().segment(fixture.observations,
                                              vinylID: UUID(), side: .a).tracks.count
    }
    #expect(try lineCount("IMG_0503.HEIC") == 16)   // the one that read everything
    #expect(try lineCount("IMG_0507.HEIC") == 3)    // the dubplate that read almost nothing
}
