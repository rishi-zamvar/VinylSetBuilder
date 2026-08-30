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
    func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> [Track] {
        observations.enumerated().map {
            Track(vinylID: vinylID, side: side, position: $0.offset, rawOCRText: $0.element.text)
        }
    }
}

// MARK: - CAP-03: the status a thumbnail shows

@Test("CAP-03/D-03-5: read status has exactly three cases and every one of them says something")
func test_givenCaptureItemStatus_whenEnumerated_thenThreeCasesAllCarryDistinctLabels() {
    #expect(CaptureItemStatus.allCases.count == 3)
    #expect(Set(CaptureItemStatus.allCases) == [.read, .partial, .unread])

    // Iterated, not named three times: a fourth case added later cannot slip through unlabelled.
    for status in CaptureItemStatus.allCases {
        #expect(!status.label.isEmpty, "\(status) has no label")
    }
    #expect(Set(CaptureItemStatus.allCases.map(\.label)).count == 3,
            "two statuses render the same label — the strip could not tell them apart")
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
