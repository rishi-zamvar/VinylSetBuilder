import Foundation
import Testing
@testable import VinylSetBuilderCore

/// SEQ-03 as the owner revised it on 2026-08-30: `|bpm[i+1] − bpm[i]| ≤ tolerance`, in EITHER
/// direction, between CONSECUTIVE tracks. See `.planning/SEQUENCER-SPEC.md`.
///
/// Every fixture here is hand-built except the two sweeps, which use the seeded crate fixture.

// MARK: - Helpers

/// The gate, re-derived from raw BPMs rather than asked of `BPMRules` — a test that calls the
/// same function the implementation calls proves only that the function agrees with itself.
private func adjacentDeltas(_ result: SequenceResult) -> [Double] {
    zip(result.sequence, result.sequence.dropFirst()).map { $1.bpm! - $0.bpm! }
}

private let sweptTolerances: [Double] = [3, 4, 5, 6]

// MARK: - Gate 1: adjacency holds in BOTH directions

@Test("Every adjacent pair is within tolerance, swept over four tolerances and five seeds")
func test_givenAnyCrate_whenSequenced_thenEveryAdjacentPairIsWithinToleranceEitherWay() {
    for seed in [UInt64(7), 42, 1234, 99, 2026] {
        let candidates = makeCrateFixture(vinylCount: 40, seed: seed)
        for tolerance in sweptTolerances {
            let result = BeamSearchSequencer().sequence(candidates: candidates,
                                                        bpmTolerance: tolerance)
            for delta in adjacentDeltas(result) {
                #expect(abs(delta) <= tolerance + 1e-9,
                        "seed \(seed) tolerance \(tolerance): adjacent delta \(delta)")
            }
        }
    }
}

@Test("Exactly 4.0 apart is admitted going UP, through the sequencer")
func test_givenExactlyToleranceApartUpward_whenSequenced_thenBothIncluded() {
    let candidates = makeVinyl(1, bpms: [170]) + makeVinyl(2, bpms: [174])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.count == 2)
}

@Test("4.01 apart excludes the second vinyl going UP, through the sequencer")
func test_givenJustOverToleranceUpward_whenSequenced_thenSecondIsExcluded() {
    let candidates = makeVinyl(1, bpms: [170]) + makeVinyl(2, bpms: [174.01])
    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(result.sequence.count == 1)
    #expect(result.notIncluded.count == 1)
}

/// A two-vinyl fixture cannot express a DOWNWARD boundary — the winner between two records is
/// always rendered lowest-first by the tiebreak, so the step is never negative. Four vinyls
/// with a forced out-and-back shape are the smallest thing that can carry the claim.
///
/// Legal edges at tolerance 4: 170–172, 170–174, 172–174, 172–176, 174–176. NOT 170–176.
/// Keys 170=8A, 174=8A, 176=8A, 172=9A make `170 → 174 → 176 → 172` cost 1, uniquely cheapest
/// after the tiebreak — and its final hop `176 → 172` is a step of exactly −4.0.
@Test("A step of exactly −4.0 is admitted going DOWN, through the sequencer")
func test_givenExactlyToleranceApartDownward_whenSequenced_thenTheDownwardStepIsAdmitted() {
    let candidates = makeVinyl(1, bpms: [170], camelots: ["8A"])
        + makeVinyl(2, bpms: [172], camelots: ["9A"])
        + makeVinyl(3, bpms: [174], camelots: ["8A"])
        + makeVinyl(4, bpms: [176], camelots: ["8A"])

    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)

    #expect(result.sequence.count == 4)
    #expect(result.sequence.map(\.bpm) == [170, 174, 176, 172])
    #expect(adjacentDeltas(result).contains(-4.0))  // the 176 -> 172 hop
    #expect(result.totalCamelotDistance == 1)
}

@Test("At 4.01 that same downward pair is never adjacent — the boundary is symmetric")
func test_givenJustOverToleranceDownward_whenSequenced_thenThatPairIsNeverAdjacent() {
    // 171.99 instead of 172: 176 − 171.99 = 4.01, so the −4 hop above becomes illegal.
    let candidates = makeVinyl(1, bpms: [170], camelots: ["8A"])
        + makeVinyl(2, bpms: [171.99], camelots: ["9A"])
        + makeVinyl(3, bpms: [174], camelots: ["8A"])
        + makeVinyl(4, bpms: [176], camelots: ["8A"])

    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)

    let bpms = result.sequence.map { $0.bpm! }
    for (a, b) in zip(bpms, bpms.dropFirst()) {
        #expect(abs(a - b) <= 4 + 1e-9)
        #expect(Set([a, b]) != Set([176.0, 171.99]), "the 4.01 pair went adjacent anyway")
    }
}

// MARK: - Gate 2: a BACKWARD step is produced when the keys make it the better path

/// The canonical proof that the rule changed. Three vinyls, all pairwise within 4, so every
/// permutation is BPM-legal and the key objective alone decides.
///
///   v1 170 8A   v2 172 2A   v3 174 9A
///   d(8A,2A) = 6   d(8A,9A) = 1   d(9A,2A) = 5
///
/// Ascending `170 → 172 → 174` costs 6 + 5 = **11** — and it is the only order the retired
/// single forward pass could ever have returned. `170 → 174 → 172` costs 1 + 5 = **6** and
/// steps backward on its final hop. Cost 6 is the assertion that the search now reaches it.
@Test("A backward step is produced when it yields the better key path")
func test_givenKeysThatFavourABackwardStep_whenSequenced_thenABackwardStepIsProduced() {
    let candidates = makeVinyl(1, bpms: [170], camelots: ["8A"])
        + makeVinyl(2, bpms: [172], camelots: ["2A"])
        + makeVinyl(3, bpms: [174], camelots: ["9A"])

    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)

    #expect(result.sequence.count == 3)
    #expect(result.totalCamelotDistance == 6)        // the ascending order costs 11
    #expect(result.sequence.map(\.bpm) == [170, 174, 172])
    #expect(result.sequence.map(\.vinylID) == [vinylID(1), vinylID(3), vinylID(2)])
    #expect(adjacentDeltas(result).contains { $0 < 0 }, "no backward step in the winner")
}

/// The owner's literal example, `170 → 178 → 174`, is ARITHMETICALLY UNREACHABLE under the
/// confirmed consecutive reading: |178 − 170| = 8, which exceeds tolerance at every point of
/// the user-tunable range 3…6. It is legal only under the two-apart reading, which
/// `SEQUENCER-SPEC.md` explicitly kills. This test pins both halves of that finding so it
/// cannot quietly come back.
@Test("The owner's literal 170 → 178 → 174 is unreachable at every tolerance in range")
func test_givenTheOwnersLiteralExample_whenSequenced_thenItIsUnreachableAndTheBridgeOrderWins() {
    for tolerance in sweptTolerances {
        #expect(BPMRules.canFollow(170, 178, tolerance: tolerance) == false)
        #expect(BPMRules.canFollow(178, 170, tolerance: tolerance) == false)
    }

    let candidates = makeVinyl(1, bpms: [170], camelots: ["8A"])
        + makeVinyl(2, bpms: [178], camelots: ["9A"])
        + makeVinyl(3, bpms: [174], camelots: ["8B"])

    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)

    #expect(result.sequence.map(\.bpm) == [170, 174, 178])
    #expect(result.sequence.map(\.bpm) != [170, 178, 174])
}

// MARK: - Gate 3: the theorem's invariant

/// Proved in `05-PLAN.md`: a set admits a legal sequence **iff** its ascending-BPM ordering has
/// every consecutive gap within tolerance. So re-sorting any winning sequence by BPM must
/// itself be legal. If this ever fails, the search returned an infeasible set — which no
/// adjacency assertion on the produced order alone would catch.
@Test("Re-sorting the winning sequence by BPM is itself legal — the feasibility invariant")
func test_givenAnyWinningSequence_whenResortedByBPM_thenItIsStillLegal() {
    for seed in [UInt64(7), 42, 1234, 99, 2026] {
        let candidates = makeCrateFixture(vinylCount: 40, seed: seed)
        for tolerance in sweptTolerances {
            let result = BeamSearchSequencer().sequence(candidates: candidates,
                                                        bpmTolerance: tolerance)
            let ascending = result.sequence.map { $0.bpm! }.sorted()
            for (a, b) in zip(ascending, ascending.dropFirst()) {
                #expect(b - a <= tolerance + 1e-9,
                        "seed \(seed) tolerance \(tolerance): infeasible set, gap \(b - a)")
            }
        }
    }
}

// MARK: - Gate 3b: one track per vinyl, under the wider search

@Test("Two candidates of the same vinyl, both ideal for the same slot, still yield one")
func test_givenTwoIdenticallyIdealCandidatesOfOneVinyl_whenSequenced_thenOnlyOneIsUsed() {
    // Both of vinyl 2's candidates sit inside the window AND carry the perfect key, so a
    // search that forgot the vinyl constraint would happily take both.
    let candidates = makeVinyl(1, bpms: [170], camelots: ["8A"])
        + makeVinyl(2, bpms: [172, 173], camelots: ["8A", "8A"])
        + makeVinyl(3, bpms: [174], camelots: ["8A"])

    let result = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)

    let ids = result.sequence.map(\.vinylID)
    #expect(ids.count == 3)
    #expect(Set(ids).count == 3)
    #expect(ids.filter { $0 == vinylID(2) }.count == 1)
}

@Test("Vinyl IDs stay unique across the swept fixture, under the bidirectional search")
func test_givenSweptFixtures_whenSequenced_thenVinylIDsAreAlwaysUnique() {
    for seed in [UInt64(7), 42, 1234, 99, 2026] {
        let candidates = makeCrateFixture(vinylCount: 40, seed: seed)
        for tolerance in sweptTolerances {
            let ids = BeamSearchSequencer()
                .sequence(candidates: candidates, bpmTolerance: tolerance)
                .sequence.map(\.vinylID)
            #expect(Set(ids).count == ids.count, "seed \(seed) tolerance \(tolerance)")
        }
    }
}
