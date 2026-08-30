import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - Fold (D6: half-time -> double, unconditional, applied once)

@Test("Half-time BPM below 100 doubles")
func test_givenHalfTimeBPM_whenFolded_thenDoubled() {
    #expect(BPMRules.fold(87) == 174)
    #expect(BPMRules.fold(85.5) == 171)
}

@Test("BPM exactly at 100 is unchanged — the boundary is '< 100', not '<= 100'")
func test_givenBPMExactlyAtHundred_whenFolded_thenUnchanged() {
    #expect(BPMRules.fold(100) == 100)
}

@Test("BPM just below 100 still folds")
func test_givenBPMJustBelowHundred_whenFolded_thenDoubled() {
    #expect(BPMRules.fold(99.9) == 199.8)
}

@Test("Normal BPM is unchanged")
func test_givenNormalBPM_whenFolded_thenUnchanged() {
    #expect(BPMRules.fold(174) == 174)
}

@Test("Very low BPM folds only once, not iteratively")
func test_givenVeryLowBPM_whenFolded_thenFoldsOnlyOnce() {
    #expect(BPMRules.fold(50) == 100)
}

// MARK: - Gate (SEQ-03, revised 2026-08-30: |Δbpm| ≤ tolerance, in EITHER direction.
//         See .planning/SEQUENCER-SPEC.md. The old rule also demanded b >= a; it is retired.)

@Test("A gap exactly at tolerance is allowed going UP")
func test_givenExactToleranceGapUpward_whenGated_thenAllowed() {
    #expect(BPMRules.canFollow(170, 174, tolerance: 4) == true)
}

@Test("A gap exactly at tolerance is allowed going DOWN — the direction is no longer a gate")
func test_givenExactToleranceGapDownward_whenGated_thenAllowed() {
    #expect(BPMRules.canFollow(174, 170, tolerance: 4) == true)
}

@Test("A gap just over tolerance is rejected going UP")
func test_givenGapJustOverToleranceUpward_whenGated_thenRejected() {
    #expect(BPMRules.canFollow(170, 174.01, tolerance: 4) == false)
}

@Test("A gap just over tolerance is rejected going DOWN — the boundary is symmetric")
func test_givenGapJustOverToleranceDownward_whenGated_thenRejected() {
    #expect(BPMRules.canFollow(174.01, 170, tolerance: 4) == false)
}

@Test("The gate is exactly symmetric — canFollow(a,b) == canFollow(b,a) across a swept grid")
func test_givenAnyPair_whenGatedBothWays_thenTheVerdictIsIdentical() {
    // Swept rather than sampled: any asymmetry left anywhere in the tolerance range shows up.
    for tolerance in [3.0, 4.0, 5.0, 6.0] {
        for a in stride(from: 160.0, through: 186.0, by: 0.5) {
            for b in stride(from: 160.0, through: 186.0, by: 0.5) {
                #expect(BPMRules.canFollow(a, b, tolerance: tolerance)
                        == BPMRules.canFollow(b, a, tolerance: tolerance))
            }
        }
    }
}

@Test("Identical BPM is allowed")
func test_givenIdenticalBPM_whenGated_thenAllowed() {
    #expect(BPMRules.canFollow(174, 174, tolerance: 4) == true)
}

@Test("Both ends of the tolerance slider range behave correctly, in both directions")
func test_givenToleranceAtSliderBounds_whenGated_thenBothEndsBehave() {
    #expect(BPMRules.canFollow(170, 173.5, tolerance: 3) == false)
    #expect(BPMRules.canFollow(173.5, 170, tolerance: 3) == false)
    #expect(BPMRules.canFollow(170, 173.5, tolerance: 6) == true)
    #expect(BPMRules.canFollow(173.5, 170, tolerance: 6) == true)
}
