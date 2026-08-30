import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - SEQ-02: one track per vinyl

@Test("Two candidates from the same vinyl both inside the BPM window still yield only one")
func test_givenTwoCandidatesFromSameVinylBothInBPMWindow_whenSequenced_thenOnlyOneAppears() {
    var candidates = makeVinyl(1, bpms: [172, 173])
    candidates += makeVinyl(2, bpms: [174])
    candidates += makeVinyl(3, bpms: [177])

    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)

    let ids = result.sequence.map(\.vinylID)
    #expect(Set(ids).count == ids.count)
    #expect(result.sequence.count == 3)
}

@Test("Vinyl IDs in the winning sequence are always unique, on a large random fixture")
func test_givenAnyFixture_whenSequenced_thenVinylIDsAreUnique() {
    let candidates = makeCrateFixture(vinylCount: 40, seed: 7)
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    let ids = result.sequence.map(\.vinylID)
    #expect(Set(ids).count == ids.count)
}

// MARK: - SEQ-03: BPM gate, bidirectional since 2026-08-30
//
// The three assertions that used to live here defended the RETIRED non-decreasing rule — a
// raw "next BPM is at least the previous BPM" comparison — and were green while doing it.
// They are gone. Adjacency, both boundary directions and the backward step now live in
// SequencerAdjacencyTests.swift, which asserts the window rather than the direction.

@Test("Every adjacent pair of the winning sequence is within tolerance, either direction")
func test_givenSequence_whenInspected_thenEveryAdjacentPairIsWithinTolerance() {
    let candidates = makeCrateFixture(vinylCount: 40, seed: 7)
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.count > 1, "a one-track sequence would make this vacuous")
    for (a, b) in zip(result.sequence, result.sequence.dropFirst()) {
        #expect(abs(b.bpm! - a.bpm!) <= 4 + 1e-9)
    }
}

@Test("A half-time BPM is folded before the gate runs, not after")
func test_givenHalfTimeBPM_whenSequenced_thenFoldedBeforeGating() {
    let candidates = makeVinyl(1, bpms: [174]) + makeVinyl(2, bpms: [87])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.count == 2)
    let folded = result.sequence.first { $0.vinylID == vinylID(2) }
    #expect(folded?.bpm == 174)
}

// MARK: - SEQ-04: objective (count first, then distance)

@Test("A longer, less harmonic path beats a shorter, smoother one")
func test_givenLongerPathAndSmootherPath_whenSequenced_thenVinylCountWinsOverKey() {
    // Full 4-vinyl chain: v1(8A)-v2(8A)-v3(2A)-v4(8A), distances 0 + 6 + 6 = 12.
    // A smoother 3-vinyl subset exists (v1-v2-v4, all 8A, distance 0) but is shorter.
    let candidates = [
        makeTrack(vinyl: 1, bpm: 172, camelot: "8A"),
        makeTrack(vinyl: 2, bpm: 174, camelot: "8A"),
        makeTrack(vinyl: 3, bpm: 176, camelot: "2A"),
        makeTrack(vinyl: 4, bpm: 178, camelot: "8A"),
    ]
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.count == 4)
}

@Test("Equal vinyl count ties break on lowest total Camelot distance")
func test_givenTwoPathsOfEqualLength_whenSequenced_thenLowestCamelotDistanceWins() {
    // Chain A: 3 vinyls, total distance 2. Chain B: 3 vinyls, total distance 8.
    // Far apart in BPM so the two chains can never link into one longer path.
    let chainA = [
        makeTrack(vinyl: 1, bpm: 100, camelot: "8A"),
        makeTrack(vinyl: 2, bpm: 102, camelot: "9A"),
        makeTrack(vinyl: 3, bpm: 104, camelot: "10A"),
    ]
    let chainB = [
        makeTrack(vinyl: 4, bpm: 200, camelot: "8A"),
        makeTrack(vinyl: 5, bpm: 202, camelot: "2A"),
        makeTrack(vinyl: 6, bpm: 204, camelot: "3B"),
    ]
    let result = BeamSearchSequencer().sequence(candidates: chainA + chainB, bpmTolerance: 4)
    #expect(result.sequence.count == 3)
    #expect(result.totalCamelotDistance == 2)
    #expect(Set(result.sequence.map(\.vinylID)) == Set([vinylID(1), vinylID(2), vinylID(3)]))
}

@Test("An unparseable or missing key never excludes a BPM-legal track")
func test_givenTrackWithUnparseableKey_whenSequenced_thenStillEligible() {
    let candidates = [
        makeTrack(vinyl: 1, bpm: 150, camelot: nil),
        makeTrack(vinyl: 2, bpm: 152, camelot: "banana"),
    ]
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.count == 2)
}

// MARK: - SEQ-06: exclusion reasons

@Test("A vinyl outside the BPM window is excluded with a reason naming the tolerance")
func test_givenVinylOutsideBPMWindow_whenSequenced_thenExcludedWithTempoReason() {
    let candidates = makeVinyl(1, bpms: [150]) + makeVinyl(2, bpms: [200])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    let reason = result.notIncluded.first { $0.vinylID == vinylID(2) }?.reason
    #expect(reason == "No track within 4 BPM of the set")
}

@Test("A vinyl with no BPM at all is excluded with the unresolved reason")
func test_givenVinylWithNoBPMAtAll_whenSequenced_thenExcludedWithUnresolvedReason() {
    let candidates = makeVinyl(1, bpms: [150]) + makeVinyl(2, bpms: [nil])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    let reason = result.notIncluded.first { $0.vinylID == vinylID(2) }?.reason
    #expect(reason == "No BPM yet — resolve it or enter it by hand")
}

@Test("A vinyl with several rejected candidates still appears exactly once")
func test_givenExcludedVinyls_whenSequenced_thenEachAppearsExactlyOnceInNotIncluded() {
    let candidates = makeVinyl(1, bpms: [150]) + makeVinyl(2, bpms: [200, 201, 202, 203])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.notIncluded.filter { $0.vinylID == vinylID(2) }.count == 1)
}

@Test("Sequence and notIncluded exactly partition every vinyl in the crate")
func test_givenIncludedVinyl_whenSequenced_thenItIsAbsentFromNotIncluded() {
    let candidates = makeVinyl(1, bpms: [150]) + makeVinyl(2, bpms: [152]) + makeVinyl(3, bpms: [200])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    let allVinyls = Set(candidates.map(\.vinylID))
    let included = Set(result.sequence.map(\.vinylID))
    let excluded = Set(result.notIncluded.map(\.vinylID))
    #expect(included.union(excluded) == allVinyls)
    #expect(included.intersection(excluded).isEmpty)
}

// MARK: - Degenerate inputs

@Test("Empty candidates return the empty result, no crash")
func test_givenEmptyCandidates_whenSequenced_thenEmptyResult() {
    let result = BeamSearchSequencer().sequence(candidates: [], bpmTolerance: 4)
    #expect(result == .empty)
}

@Test("A single vinyl with a single track sequences to a run of one")
func test_givenSingleVinylSingleTrack_whenSequenced_thenSequenceOfOne() {
    let candidates = makeVinyl(1, bpms: [150])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.count == 1)
    #expect(result.notIncluded.isEmpty)
    #expect(result.totalCamelotDistance == 0)
}

@Test("All-nil BPM crate returns every vinyl unresolved with an empty sequence")
func test_givenAllNilBPM_whenSequenced_thenAllUnresolvedAndSequenceEmpty() {
    let candidates = makeVinyl(1, bpms: [nil]) + makeVinyl(2, bpms: [nil, nil])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.isEmpty)
    #expect(result.notIncluded.count == 2)
    #expect(result.notIncluded.allSatisfy { $0.reason == "No BPM yet — resolve it or enter it by hand" })
}

@Test("A single vinyl with many candidates still yields exactly one track")
func test_givenSingleVinylManyCandidates_whenSequenced_thenExactlyOneChosen() {
    let candidates = makeVinyl(1, bpms: [150, 151, 152, 153])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.count == 1)
}
