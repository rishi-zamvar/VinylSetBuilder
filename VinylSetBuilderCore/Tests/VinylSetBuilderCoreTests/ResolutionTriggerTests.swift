import Foundation
import Testing
@testable import VinylSetBuilderCore

/// Phase 8, swap 3. Which records the app spends a network request on, and what a record that
/// could not be given a tempo says for itself on screen.

private func track(_ position: Int, artist: String? = nil, title: String? = nil,
                   failure: String? = nil, bpm: Double? = nil) -> Track {
    Track(vinylID: UUID(), position: position, rawOCRText: "LINE \(position)",
          artist: artist, title: title, bpm: bpm, failureReason: failure)
}

@Test("RES-02: a record whose lines carry no identity is the one the resolver is spent on")
func test_givenUnidentifiedCandidates_whenAsked_thenTheRecordNeedsResolution() {
    let unidentified = VinylEntry(candidates: [track(0), track(1)])
    #expect(unidentified.needsResolution)
}

@Test("RES-06: a record that already has an artist and a title is never re-resolved")
func test_givenIdentifiedCandidates_whenAsked_thenTheRecordIsLeftAlone() {
    // This is the guard that stops a hand-typed correction being overwritten by a later
    // automatic pass, and it is the reason the fixture crates cost zero requests.
    let identified = VinylEntry(candidates: [track(0, artist: "Photek", title: "Ni Ten Ichi Ryu")])
    #expect(!identified.needsResolution)

    // Half an identity is not an identity: a title with no artist is not resolvable by
    // artist+title and is still the resolver's job.
    #expect(VinylEntry(candidates: [track(0, title: "Untitled")]).needsResolution)
    #expect(VinylEntry(candidates: [track(0, artist: "Unknown Artist")]).needsResolution)
}

@Test("RES-01: a record with no candidate lines has nothing to look up")
func test_givenNoCandidates_whenAsked_thenThereIsNothingToResolve() {
    #expect(!VinylEntry(candidates: []).needsResolution)
}

@Test("BPM-07: the bucket row prints the ladder's own reason, not the sequencer's summary")
func test_givenATrackTheLadderCouldNotAnswer_whenTheRowIsBuilt_thenItSaysWhy() throws {
    let ladderSaid = "not in the bundled corpus, and no audio route configured"
    let vinyl = VinylEntry(candidates: [track(0, artist: "Abstract", title: "The Message",
                                              failure: ladderSaid)])
    let crate = Crate(name: "One", vinyls: [vinyl])
    let result = SequenceResult(sequence: [],
                                notIncluded: [NotIncluded(vinylID: vinyl.id, reason: "no BPM")],
                                totalCamelotDistance: 0)

    let row = try #require(CrateRows.make(result: result, crate: crate).notIncluded.first)
    #expect(row.reason == ladderSaid)
    // The identity survives — BPM-07's "surfaced for manual entry rather than silently dropped"
    // is worth nothing if the record loses its name on the way to the bucket.
    #expect(vinyl.orderedCandidates.first?.artist == "Abstract")
}

@Test("D7: with no ladder reason the sequencer's own words still stand, verbatim")
func test_givenNoLadderReason_whenTheRowIsBuilt_thenTheSequencerSpeaks() throws {
    let vinyl = VinylEntry(candidates: [track(0, artist: "A", title: "B", bpm: 178)])
    let crate = Crate(name: "One", vinyls: [vinyl])
    let result = SequenceResult(sequence: [],
                                notIncluded: [NotIncluded(vinylID: vinyl.id,
                                                          reason: "178 BPM is outside the window")],
                                totalCamelotDistance: 0)
    let row = try #require(CrateRows.make(result: result, crate: crate).notIncluded.first)
    #expect(row.reason == "178 BPM is outside the window")
}
