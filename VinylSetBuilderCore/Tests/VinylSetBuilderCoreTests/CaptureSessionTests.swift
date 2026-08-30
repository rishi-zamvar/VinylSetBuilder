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

// MARK: - CAP-05 / SEG-04: the flip set, derived rather than transcribed
//
// `FixturePhotoSource` is DELETED. It dealt out a hand-written table of readings with a
// hand-scored verdict and a hand-normalised side marker per record; the app now photographs,
// reads and segments for real, so these assertions run the SHIPPING segmenter over the twelve
// recorded reads and check the answers it arrives at on its own.
//
// Every number is a NAMED SET or a NAMED STRING, never a bare count: a rule that suppressed the
// flip prompt on the wrong three records would still produce a count of three.

private func derivedSides(_ file: String) throws -> [String] {
    let fixture = try #require(FixtureObservations.all.first { $0.file == file })
    return AngleClusterSegmenter().segment(fixture.observations, vinylID: UUID(), side: .a).sides
}

@Test("CAP-05: the flip prompt is suppressed on exactly the three sleeves that state two sides")
func test_givenTheTwelveFixtures_whenSidesAreDerived_thenExactlyThreeStateBothSides() throws {
    var suppressed: [String] = []
    var prompting: [String] = []
    for fixture in FixtureObservations.all {
        let sides = try derivedSides(fixture.file)
        if sides.count < 2 { prompting.append(fixture.file) } else { suppressed.append(fixture.file) }
    }

    // Both sets, not both counts, and both directions — a rule that never suppressed anything
    // would pass a `prompting` assertion vacuously if the two were folded into one check.
    #expect(suppressed == ["IMG_0499.HEIC", "IMG_0503.HEIC", "IMG_0506.HEIC"])
    #expect(prompting == ["IMG_0498.HEIC", "IMG_0500.HEIC", "IMG_0501.HEIC", "IMG_0502.HEIC",
                          "IMG_0504.HEIC", "IMG_0505.HEIC", "IMG_0507.HEIC", "IMG_0508.HEIC",
                          "IMG_0509.HEIC"])
    #expect(suppressed.count + prompting.count == 12)
}

@Test("SEG-04: the derived side markers are the ones actually printed on those sleeves")
func test_givenTheSuppressedFixtures_whenSidesAreDerived_thenTheyAreTheMarkersOnTheSleeve() throws {
    #expect(try derivedSides("IMG_0503.HEIC") == ["A", "AAA"])
    #expect(try derivedSides("IMG_0506.HEIC") == ["COLD", "STEEL"])
    // One-sided reading is not the same as no reading: IMG_0500 states one side and only one.
    #expect(try derivedSides("IMG_0500.HEIC") == ["ONE"])
    #expect(try derivedSides("IMG_0498.HEIC").isEmpty)
}

// MARK: - Phase 8, swap 1: the real segmenter is what the capture screen now uses
//
// The Act I `FixtureLineSegmenter` (one line per trusted observation) is DELETED. These are the
// same two fixtures the old tests used, re-measured against `AngleClusterSegmenter` — the
// numbers moved a long way, which is the point of the swap.

@Test("swap 1: the real segmenter collapses the over-split draft to the record's actual tracks")
func test_givenTwoRealFixtures_whenSegmentedForReal_thenTheDraftIsTheTrackListNotTheReadings() throws {
    func segmentation(_ file: String) throws -> LabelSegmentation {
        let fixture = try #require(FixtureObservations.all.first { $0.file == file })
        return AngleClusterSegmenter().segment(fixture.observations, vinylID: UUID(), side: .a)
    }

    // IMG_0503 read SIXTEEN trusted observations off one sleeve. The stub made sixteen draft
    // lines of them. The record has two tracks, and they are named.
    let rich = try segmentation("IMG_0503.HEIC")
    #expect(rich.tracks.map(\.rawOCRText) == ["A: HIGH DOWN", "AAA: STRANGE NAT URE"])
    #expect(rich.catalogueNumber == "TYME012")

    // IMG_0507 is the dubplate that reads nothing usable. The stub emitted three junk lines;
    // the real segmenter emits none and the record goes to hand entry, which is honest.
    #expect(try segmentation("IMG_0507.HEIC").tracks.isEmpty)
}

@Test("V16: the real segmenter leaves no two identical lines in a draft, on any fixture")
func test_givenEveryFixture_whenSegmented_thenNoDraftCarriesADuplicateLine() {
    for fixture in FixtureObservations.all {
        let lines = AngleClusterSegmenter()
            .segment(fixture.observations, vinylID: UUID(), side: .a)
            .tracks.map(\.rawOCRText)
        #expect(Set(lines).count == lines.count,
                Comment(rawValue: "\(fixture.file) drafted a duplicate line: \(lines)"))
    }
}

@Test("CAP-03: the derived read status reproduces the owner's own hand score on all twelve")
func test_givenTheTwelveFixtures_whenStatusIsDerived_thenItIsSixReadFivePartialOneUnread() {
    var tally: [CaptureItemStatus: Int] = [:]
    for fixture in FixtureObservations.all {
        let segmentation = AngleClusterSegmenter().segment(fixture.observations,
                                                           vinylID: UUID(), side: .a)
        tally[SleeveStatus.status(for: segmentation), default: 0] += 1
    }
    // CONTEXT.md §3's hand-scored 6/5/1, reproduced by a rule that never saw it. That agreement
    // is the evidence the rule is not arbitrary — it was not fitted to this tally, and the one
    // record it calls unread is the same dubplate the owner called unread.
    #expect(tally == [.read: 6, .partial: 5, .unread: 1])
}
