import Foundation
import Testing
@testable import VinylSetBuilderCore

// MARK: - SEQ-11: BPM + Camelot badge text, formatted once

@Test("A resolved track carries both badges")
func test_givenAResolvedTrack_whenBadged_thenBothBadgesCarryValues() {
    let badges = TrackBadges(bpm: 174, camelot: "8A")
    #expect(badges.bpm == "174")
    #expect(badges.key == "8A")
    #expect(badges.bpm != TrackBadges.placeholder)
    #expect(badges.key != TrackBadges.placeholder)
}

@Test("A whole-number BPM shows no decimal point")
func test_givenAWholeNumberBPM_whenBadged_thenNoDecimalPointIsShown() {
    #expect(TrackBadges(bpm: 174.0, camelot: nil).bpm == "174")
}

@Test("A fractional BPM shows one decimal, rounded not truncated")
func test_givenAFractionalBPM_whenBadged_thenOneDecimalIsShown() {
    #expect(TrackBadges(bpm: 173.5, camelot: nil).bpm == "173.5")
    #expect(TrackBadges(bpm: 173.46, camelot: nil).bpm == "173.5")
}

@Test("A half-time BPM shows the folded value")
func test_givenAHalfTimeBPM_whenBadged_thenTheFoldedValueIsShown() {
    #expect(TrackBadges(bpm: 87, camelot: nil).bpm == "174")
}

@Test("Exactly 100 BPM is not doubled")
func test_givenExactlyOneHundredBPM_whenBadged_thenItIsNotDoubled() {
    #expect(TrackBadges(bpm: 100, camelot: nil).bpm == "100")
}

@Test("No BPM shows the placeholder, never empty")
func test_givenNoBPM_whenBadged_thenThePlaceholderIsShown() {
    #expect(TrackBadges(bpm: nil, camelot: nil).bpm == TrackBadges.placeholder)
    #expect(TrackBadges(bpm: nil, camelot: nil).bpm != "")
}

@Test("A musical key is normalised to Camelot")
func test_givenAMusicalKeyRatherThanACamelotCode_whenBadged_thenItIsNormalised() {
    #expect(TrackBadges(bpm: nil, camelot: "Am").key == "8A")
    #expect(TrackBadges(bpm: nil, camelot: "F#m").key == "11A")
}

@Test("An unparseable key degrades to the placeholder, never throws")
func test_givenAnUnparseableKey_whenBadged_thenThePlaceholderIsShownAndNothingThrows() {
    #expect(TrackBadges(bpm: nil, camelot: "banana").key == TrackBadges.placeholder)
    #expect(TrackBadges(bpm: nil, camelot: "").key == TrackBadges.placeholder)
    #expect(TrackBadges(bpm: nil, camelot: nil).key == TrackBadges.placeholder)
}

@Test("Badging is a pure function of the track — no shared state between calls")
func test_givenTwoTracks_whenBadged_thenBadgesDependOnlyOnTheTrack() {
    let a = makeTrack(vinyl: 1, bpm: 174, camelot: "8A")
    let b = makeTrack(vinyl: 2, bpm: 87, camelot: "Am")
    #expect(TrackBadges(track: a) == TrackBadges(bpm: 174, camelot: "8A"))
    #expect(TrackBadges(track: b) == TrackBadges(bpm: 87, camelot: "Am"))
    #expect(TrackBadges(track: a) == TrackBadges(track: a))
}
