import Foundation
import Testing
@testable import VinylSetBuilderCore

/// **Q1** — `.planning/open-questions/Q1-sequencer-determinism.md`. Is the sequencer
/// order-dependent? The whole product re-runs it on every add, so an order-dependent sequencer
/// would produce different sets from the same records.
///
/// The answer has to be a measurement over **vinyl IDs**, not over `Track` structs and not over
/// `SequenceResult` as a whole — see `test_…_thenOnlyTheNotIncludedORDERMoves` below, which is
/// the part the original half-written test got wrong.

private func shuffles(_ candidates: [Track], count: Int) -> [[Track]] {
    (1...count).map { s in
        var rng = SeededRandom(seed: UInt64(s) &* 2_654_435_761)
        return candidates.shuffled(using: &rng)
    }
}

// MARK: - The headline: 10 seeded shuffles, vinyl ID order identical

@Test("Q1: ten seeded shuffles of the candidate array give one identical vinyl order")
func test_givenTenSeededShuffles_whenSequenced_thenTheVinylOrderIsIdentical() {
    for seed in [UInt64(7), 42, 1234, 99, 2026] {
        let candidates = makeCrateFixture(vinylCount: 40, seed: seed)
        for tolerance in [3.0, 4.0, 5.0, 6.0] {
            let expected = BeamSearchSequencer()
                .sequence(candidates: candidates, bpmTolerance: tolerance)
                .sequence.map(\.vinylID)
            #expect(expected.count > 1, "seed \(seed) tol \(tolerance): vacuous")

            var degenerate = 0
            for shuffled in shuffles(candidates, count: 10) {
                // A shuffle that did not shuffle would let this test pass by doing nothing.
                if shuffled.map(\.id) == candidates.map(\.id) { degenerate += 1 }

                let actual = BeamSearchSequencer()
                    .sequence(candidates: shuffled, bpmTolerance: tolerance)
                    .sequence.map(\.vinylID)
                #expect(actual == expected, "seed \(seed) tol \(tolerance): order moved")
            }
            #expect(degenerate == 0, "seed \(seed): a shuffle left the array untouched")
        }
    }
}

@Test("Q1: the same holds on a dense 100-vinyl / 400-candidate crate")
func test_givenADenseCrate_whenShuffledTenWays_thenTheVinylOrderIsIdentical() {
    let candidates = makeDenseCrateFixture(vinylCount: 100, candidatesPerVinyl: 4, seed: 2026)
    let expected = BeamSearchSequencer()
        .sequence(candidates: candidates, bpmTolerance: 4)
        .sequence.map(\.vinylID)
    #expect(expected.count == 100)

    for shuffled in shuffles(candidates, count: 10) {
        let actual = BeamSearchSequencer()
            .sequence(candidates: shuffled, bpmTolerance: 4)
            .sequence.map(\.vinylID)
        #expect(actual == expected)
    }
}

// MARK: - The verdict on the original half-written test

/// **This is what Q1 actually caught.** The WIP test compared whole `SequenceResult` values
/// (`actual == expected`). When every vinyl makes the set that comparison holds — the sequence
/// is a pure function of the candidate SET. When some vinyl is excluded it does not, and not
/// because the algorithm wavered: `notIncluded` is deliberately built in **input first-appearance
/// order** so the not-included bucket reads in the order the user added the records. Shuffle the
/// input and that ORDER moves, while its membership does not.
///
/// So Q1's possibility 2 ("the sequencer is genuinely order-dependent") is **not** what is
/// happening: membership and the running order are both stable. The comparison was too wide.
@Test("Q1 verdict: a fully-included crate is identical as a WHOLE result after shuffling")
func test_givenEveryVinylIncluded_whenShuffled_thenTheWholeResultIsIdentical() {
    let candidates = makeVinyl(1, bpms: [170], camelots: ["8A"])
        + makeVinyl(2, bpms: [178], camelots: ["9A"])
        + makeVinyl(3, bpms: [174], camelots: ["8B"])

    let expected = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(expected.notIncluded.isEmpty)

    for shuffled in shuffles(candidates, count: 10) {
        #expect(BeamSearchSequencer().sequence(candidates: shuffled, bpmTolerance: 4) == expected)
    }
}

@Test("Q1 verdict: with exclusions, membership and running order hold — only notIncluded ORDER moves")
func test_givenExcludedVinyls_whenShuffled_thenOnlyTheNotIncludedORDERMoves() {
    // Three isolated islands 20 BPM apart: vinyl 1 makes the set, vinyls 2 and 3 cannot.
    let candidates = makeVinyl(1, bpms: [150], camelots: ["8A"])
        + makeVinyl(2, bpms: [180], camelots: ["9A"])
        + makeVinyl(3, bpms: [210], camelots: ["8B"])

    let expected = BeamSearchSequencer().sequence(candidates: candidates, bpmTolerance: 4)
    #expect(expected.notIncluded.count == 2, "the fixture must actually exclude something")

    var orderMoved = false
    for shuffled in shuffles(candidates, count: 10) {
        let actual = BeamSearchSequencer().sequence(candidates: shuffled, bpmTolerance: 4)

        // Stable: which records are in, in what order, and which are out.
        #expect(actual.sequence.map(\.vinylID) == expected.sequence.map(\.vinylID))
        #expect(Set(actual.notIncluded) == Set(expected.notIncluded))
        #expect(actual.totalCamelotDistance == expected.totalCamelotDistance)

        if actual.notIncluded != expected.notIncluded { orderMoved = true }
    }

    // Presence is not evidence: if the order never moved, this test would prove nothing about
    // why the whole-result comparison in the WIP file failed.
    #expect(orderMoved, "notIncluded order never moved — the diagnosis is unproven")
}

// MARK: - Degenerate inputs stay deterministic too

@Test("Q1: degenerate crates are stable under shuffling and do not crash")
func test_givenDegenerateCrates_whenShuffled_thenTheResultIsStable() {
    let allNil = makeVinyl(1, bpms: [nil, nil]) + makeVinyl(2, bpms: [nil])
    let single = makeVinyl(1, bpms: [150, 151, 152, 153])
    let mixed = makeVinyl(1, bpms: [nil, 170]) + makeVinyl(2, bpms: [172, nil])

    for crate in [allNil, single, mixed] {
        let expected = BeamSearchSequencer().sequence(candidates: crate, bpmTolerance: 4)
        for shuffled in shuffles(crate, count: 10) {
            let actual = BeamSearchSequencer().sequence(candidates: shuffled, bpmTolerance: 4)
            #expect(actual.sequence.map(\.vinylID) == expected.sequence.map(\.vinylID))
            #expect(Set(actual.notIncluded) == Set(expected.notIncluded))
        }
    }

    #expect(BeamSearchSequencer().sequence(candidates: [], bpmTolerance: 4) == .empty)
}
