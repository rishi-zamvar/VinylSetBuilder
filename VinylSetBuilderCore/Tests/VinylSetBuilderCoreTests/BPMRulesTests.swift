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

// MARK: - Gate (⚠️ STALE: 'non-decreasing AND within tolerance' is a RETIRED spec.
//         Now bidirectional: |Δ| ≤ tolerance either direction. SEQ-03 reopened, Phase 9 owns it.)

@Test("A gap exactly at tolerance is allowed")
func test_givenExactToleranceGap_whenGated_thenAllowed() {
    #expect(BPMRules.canFollow(170, 174, tolerance: 4) == true)
}

@Test("A gap just over tolerance is rejected")
func test_givenGapJustOverTolerance_whenGated_thenRejected() {
    #expect(BPMRules.canFollow(170, 174.01, tolerance: 4) == false)
}

@Test("A decreasing BPM is rejected even within tolerance")
func test_givenDecreasingBPM_whenGated_thenRejected() {
    #expect(BPMRules.canFollow(174, 170, tolerance: 4) == false)
}

@Test("Identical BPM is allowed")
func test_givenIdenticalBPM_whenGated_thenAllowed() {
    #expect(BPMRules.canFollow(174, 174, tolerance: 4) == true)
}

@Test("Both ends of the tolerance slider range behave correctly")
func test_givenToleranceAtSliderBounds_whenGated_thenBothEndsBehave() {
    #expect(BPMRules.canFollow(170, 173.5, tolerance: 3) == false)
    #expect(BPMRules.canFollow(170, 173.5, tolerance: 6) == true)
}
