import Foundation
import Testing
@testable import VinylSetBuilderCore

/// SEQ-10. The measured gate: **beam 50 against beam 150 and beam 400, over 5 seeds x 4
/// tolerances = 20 runs each.**
///
/// The gate is *"width 50 never returns fewer vinyls than a wider beam"*, not *"the two answers
/// are identical"*, and the difference is a measurement rather than a concession.
///
/// Beam search is **not monotone in width**. Pruning keeps the top `k` by rank, and for `k' > k`
/// the wide beam's survivors are not a superset of the narrow beam's — an element in the
/// narrow's top-`k` is beaten by at most `k−1` of its own peers but can be beaten by more than
/// `k'` newcomers in the wider pool, and drop out. So a wider beam can legitimately land
/// somewhere worse. Measured here, and it does: at seed 7 / tolerance 3, width 150 returns
/// **39** vinyls while widths 50, 400 and 1000 all return **40**.
///
/// What matters for the product is that the SHIPPED default is not the one losing records, and
/// that is what these assertions say.
private let divergenceSeeds: [UInt64] = [7, 42, 1234, 99, 2026]
private let divergenceTolerances: [Double] = [3, 4, 5, 6]

@Test("SEQ-10 measured: width 50 never loses records to width 150 across 20 runs")
func test_givenTwentyCrates_whenRunAtTwoBeamWidths_thenWidthFiftyNeverLoses() {
    var runs = 0, identicalCounts = 0, sameOrder = 0, worstCountDelta = 0

    for seed in divergenceSeeds {
        let candidates = makeCrateFixture(vinylCount: 40, seed: seed)
        for tolerance in divergenceTolerances {
            let report: BeamDivergenceCheck.Report =
                BeamDivergenceCheck().run(candidates: candidates, bpmTolerance: tolerance)
            runs += 1
            if report.countDelta == 0 { identicalCounts += 1 }
            if report.agrees { sameOrder += 1 }
            worstCountDelta = max(worstCountDelta, report.countDelta)

            // Presence is not evidence: a check over an empty crate would also "agree".
            #expect(report.narrow.sequence.count > 1, "seed \(seed) tol \(tolerance): vacuous")

            let lost = "seed \(seed) tol \(tolerance): width 50 LOST records to width 150 — "
                + report.summary
            #expect(report.countDelta <= 0, "\(lost)")
        }
    }

    print("SEQ-10 measured (50 vs 150): \(runs) runs, \(identicalCounts) identical counts, "
          + "\(sameOrder) identical vinyl order, worst count delta \(worstCountDelta)")

    #expect(runs == 20)
    #expect(identicalCounts == 19)      // the seed 7 / tolerance 3 anomaly is the twentieth
    #expect(worstCountDelta == 0)       // width 50 is never the loser
}

@Test("SEQ-10 measured: width 50 matches a beam EIGHT times wider on every one of 20 runs")
func test_givenTwentyCrates_whenRunAgainstAMuchWiderBeam_thenTheCountsAreIdentical() {
    let check = BeamDivergenceCheck(narrowWidth: 50, wideWidth: 400)
    var runs = 0, identicalCounts = 0

    for seed in divergenceSeeds {
        let candidates = makeCrateFixture(vinylCount: 40, seed: seed)
        for tolerance in divergenceTolerances {
            let report = check.run(candidates: candidates, bpmTolerance: tolerance)
            runs += 1
            if report.countDelta == 0 { identicalCounts += 1 }
            #expect(report.countDelta == 0,
                    "seed \(seed) tol \(tolerance): \(report.summary)")
        }
    }

    print("SEQ-10 measured (50 vs 400): \(runs) runs, \(identicalCounts) identical counts")
    #expect(runs == 20)
    #expect(identicalCounts == 20)
}

@Test("The check reports the widths it actually ran, so a mis-configured run is visible")
func test_givenCustomWidths_whenRun_thenTheReportCarriesThem() {
    let check = BeamDivergenceCheck(narrowWidth: 2, wideWidth: 200)
    #expect(check.narrowWidth == 2)
    #expect(check.wideWidth == 200)

    let report = check.run(candidates: makeCrateFixture(vinylCount: 40, seed: 7),
                           bpmTolerance: 4)
    #expect(report.narrowWidth == 2)
    #expect(report.wideWidth == 200)
    #expect(report.summary.contains("beam 2 vs 200"))
    #expect(report.distanceDelta == report.wide.totalCamelotDistance
                - report.narrow.totalCamelotDistance)
}

/// A divergence check that can never report a divergence is decoration. This is the negative
/// control for the gate — a brand-new gate, so RIGOR-POLICY still requires one. A beam of 1 is
/// pure greedy and genuinely differs from a beam of 150 on this fixture.
@Test("A deliberately starved beam DOES diverge — the check can detect what it claims to")
func test_givenABeamOfOne_whenComparedToAWideBeam_thenTheCheckReportsDivergence() {
    let starved = BeamDivergenceCheck(narrowWidth: 1, wideWidth: 150)
    var diverged = 0
    for seed in divergenceSeeds {
        let report = starved.run(candidates: makeCrateFixture(vinylCount: 40, seed: seed),
                                 bpmTolerance: 4)
        if !report.agrees { diverged += 1 }
    }
    #expect(diverged > 0, "beam 1 vs beam 150 agreed everywhere — the check is not comparing")
}
