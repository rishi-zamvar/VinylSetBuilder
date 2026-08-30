import Foundation
import Testing
@testable import VinylSetBuilderCore

@Test("VinylEntry.orderedCandidates sorts by position, not array order")
func test_givenVinylEntry_whenCandidatesReadInOrder_thenPositionIsTheSourceOfTruth() {
    let vinylID = UUID()
    let t0 = Track(vinylID: vinylID, position: 0, rawOCRText: "first")
    let t1 = Track(vinylID: vinylID, position: 1, rawOCRText: "second")
    let t2 = Track(vinylID: vinylID, position: 2, rawOCRText: "third")
    // Shuffled relative to position.
    let entry = VinylEntry(id: vinylID, capturedAt: .now, photoRefs: [], sidesScanned: [.a],
                            candidates: [t2, t0, t1], position: 0)
    #expect(entry.orderedCandidates.map(\.rawOCRText) == ["first", "second", "third"])
}

@Test("Same VinylEntry across two crates gets independent selections (CRATE-07)")
func test_givenCrate_whenSameVinylAppearsInTwoCrates_thenSelectionIsPerCrate() {
    let vinylID = UUID()
    let trackA = UUID()
    let trackB = UUID()
    let entry = VinylEntry(id: vinylID, capturedAt: .now, photoRefs: [], sidesScanned: [.a],
                            candidates: [], position: 0)

    var crate1 = Crate(id: UUID(), name: "Crate 1", createdAt: .now, vinyls: [entry],
                        bpmTolerance: 4.0, manualOrder: nil, selectedTrackByVinyl: [:])
    var crate2 = Crate(id: UUID(), name: "Crate 2", createdAt: .now, vinyls: [entry],
                        bpmTolerance: 4.0, manualOrder: nil, selectedTrackByVinyl: [:])

    crate1.selectedTrackByVinyl[vinylID] = trackA
    crate2.selectedTrackByVinyl[vinylID] = trackB

    #expect(crate1.selectedTrackByVinyl[vinylID] == trackA)
    #expect(crate2.selectedTrackByVinyl[vinylID] == trackB)
    #expect(crate1.selectedTrackByVinyl[vinylID] != crate2.selectedTrackByVinyl[vinylID])
}

@Test("Track Codable round-trip preserves every field")
func test_givenTrack_whenEncodedAndDecoded_thenRoundTripsIdentically() throws {
    let track = Track(vinylID: UUID(), side: .b, position: 3, rawOCRText: "raw text",
                       artist: "Photek", title: "Ni Ten Ichi Ryu", bpm: 172.5, camelot: "8A",
                       matchConfidence: 0.91, resolutionState: .resolved, failureReason: nil)
    let data = try JSONEncoder().encode(track)
    let decoded = try JSONDecoder().decode(Track.self, from: data)
    #expect(decoded == track)
}

@Test("SequenceResult with no tracks included puts everything in one notIncluded bucket")
func test_givenSequenceResult_whenNoTracksIncluded_thenNotIncludedIsOneBucket() {
    let vinyl1 = UUID()
    let vinyl2 = UUID()
    let result = SequenceResult(
        sequence: [],
        notIncluded: [
            NotIncluded(vinylID: vinyl1, reason: "No resolved tracks on this vinyl"),
            NotIncluded(vinylID: vinyl2, reason: "BPM outside tolerance of every other track"),
        ],
        totalCamelotDistance: 0
    )
    #expect(result.sequence.isEmpty)
    #expect(result.notIncluded.count == 2)
    for item in result.notIncluded {
        #expect(!item.reason.isEmpty)
    }
}
