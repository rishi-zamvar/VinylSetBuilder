import Foundation
import Testing
@testable import VinylSetBuilderCore

// RES-04. The bands are 0.75 and 0.50 and the interesting cases are AT the boundaries, so
// the boundaries are what is tested. A band test that only tries 0.9 and 0.1 proves nothing.

@Test("RES-04: above 0.75 is accepted")
func test_givenSimilarityAbove075_whenBanded_thenAccepted() {
    #expect(MatchScoring.band(0.76) == .accepted)
    #expect(MatchScoring.band(1.0) == .accepted)
}

@Test("RES-04: exactly 0.75 needs confirming, not accepting")
func test_givenSimilarityExactly075_whenBanded_thenNeedsConfirmation() {
    #expect(MatchScoring.band(0.75) == .needsConfirmation)
}

@Test("RES-04: the 0.50 edge belongs to the confirmation band, not to rejection")
func test_givenSimilarityExactly050_whenBanded_thenNeedsConfirmation() {
    #expect(MatchScoring.band(0.50) == .needsConfirmation)
    #expect(MatchScoring.band(0.4999) == .rejected)
}

@Test("RES-04: below 0.50 is rejected")
func test_givenSimilarityBelow050_whenBanded_thenRejected() {
    #expect(MatchScoring.band(0.0) == .rejected)
    #expect(MatchScoring.band(0.3) == .rejected)
}

@Test("similarity is 1 for an identical string once normalised")
func test_givenSameTextDifferentPunctuation_whenScored_thenOne() {
    #expect(MatchScoring.similarity("The Message", "the  message!") == 1.0)
}

@Test("the reader's worst accepted misread lands in the confirmation band, not the accept band")
func test_givenOCRMisread_whenScored_thenExactlyOnTheConfirmBoundary() {
    // WIDE OPBY for WIDE OPEN — the spike's own worst accepted read — is two edits in eight,
    // which is 0.75 exactly. It therefore asks the user rather than resolving silently.
    // This is not a tuning failure, it is the measurement: raw sleeve text rarely clears 0.75
    // against a database title, which is precisely why the catalogue number is the primary key.
    #expect(MatchScoring.similarity("WIDE OPBY", "Wide Open") == 0.75)
    #expect(MatchScoring.band(MatchScoring.similarity("WIDE OPBY", "Wide Open")) == .needsConfirmation)
}

@Test("similarity is 0 for unrelated text and never negative")
func test_givenUnrelatedText_whenScored_thenClampedToZero() {
    #expect(MatchScoring.similarity("Tchaikovsky", "Abstract") >= 0.0)
    #expect(MatchScoring.similarity("Tchaikovsky", "Abstract") < 0.5)
    #expect(MatchScoring.similarity("", "anything") == 0.0)
}

@Test("RES-04: a candidate is scored on artist AND title, weighted toward the title")
func test_givenRightTitleWrongArtist_whenScoredAsPair_thenBelowTheAcceptBand() {
    let right = MatchScoring.pairSimilarity(artist: "Abstract", title: "The Message",
                                            candidateArtist: "Abstract", candidateTitle: "The Message")
    let wrongArtist = MatchScoring.pairSimilarity(artist: "Abstract", title: "The Message",
                                                  candidateArtist: "Tchaikovsky", candidateTitle: "The Message")
    #expect(right == 1.0)
    #expect(wrongArtist < right)
    #expect(wrongArtist < 0.75)
}

// The duration sanity bound. The measured failure mode: a 79-minute DJ mix returned as the
// second hit for a correct artist query.
@Test("BPM-03: a 79-minute mix is not a candidate for a 5-minute track")
func test_givenDJMixDuration_whenBoundChecked_thenRejected() {
    #expect(MatchScoring.durationPlausible(candidateSeconds: 4740, expectedSeconds: 300) == false)
    #expect(MatchScoring.durationPlausible(candidateSeconds: 320, expectedSeconds: 300) == true)
}

@Test("BPM-03: with no expected duration, only absurd lengths are excluded")
func test_givenNoExpectedDuration_whenBoundChecked_thenOnlyAbsurdLengthsExcluded() {
    #expect(MatchScoring.durationPlausible(candidateSeconds: 4740, expectedSeconds: Double?.none) == false)
    #expect(MatchScoring.durationPlausible(candidateSeconds: 210, expectedSeconds: Double?.none) == true)
    #expect(MatchScoring.durationPlausible(candidateSeconds: 12, expectedSeconds: Double?.none) == false)
}
