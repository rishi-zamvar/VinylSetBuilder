import Foundation
import Testing
@testable import VinylSetBuilderCore

/// Real rows, copied out of the owner's own corpus.
private let sample = """
&ME\tThandaza\t123.0\t11A
&ME\tThe Rapture Pt. II\t120.0\t3A
&ME\tThe Rapture, Pt. II\t120.0\t2B
&ME, Rampa & Adam Port\tThe Rapture, Pt. III\t117.5\t9A
03 Greedo\tRun For Yo Life\t96.0\t12A
Goldie\tTerminator\t168.0\t5A
"""

@Test("BPM-02: an exact row is found with its BPM and its key")
func test_givenExactArtistAndTitle_whenLookedUp_thenBPMAndKeyReturned() {
    let entry = TierZeroCorpus(tsv: sample).lookup(artist: "Goldie", title: "Terminator")
    #expect(entry?.bpm == 168.0)
    #expect(entry?.camelot == "5A")
}

@Test("BPM-02: matching is punctuation- and case-normalised")
func test_givenPunctuationDifference_whenLookedUp_thenStillFound() {
    let corpus = TierZeroCorpus(tsv: sample)
    #expect(corpus.lookup(artist: "&me", title: "thandaza")?.bpm == 123.0)
    #expect(corpus.lookup(artist: "&ME", title: "Thandaza!!")?.bpm == 123.0)
}

@Test("BPM-02 THE DOCUMENTED TIE-BREAK: the exact raw title wins outright")
func test_givenTheRaptureConflict_whenAskedByExactTitle_thenThatRowWins() {
    let corpus = TierZeroCorpus(tsv: sample)
    #expect(corpus.lookup(artist: "&ME", title: "The Rapture Pt. II")?.camelot == "3A")
    #expect(corpus.lookup(artist: "&ME", title: "The Rapture, Pt. II")?.camelot == "2B")
}

@Test("BPM-02 THE DOCUMENTED TIE-BREAK: an inexact ask keeps the agreed tempo and drops the key")
func test_givenTheRaptureConflict_whenAskedInexactly_thenTempoKeptAndKeyDropped() {
    // "The Rapture Pt II" — no comma, no full stop — is neither raw title, so nothing
    // distinguishes 3A from 2B. Both rows say 120 BPM, so 120 BPM is known and the key is not.
    let entry = TierZeroCorpus(tsv: sample).lookup(artist: "&ME", title: "The Rapture Pt II")
    #expect(entry?.bpm == 120.0)
    #expect(entry?.camelot == nil)
}

@Test("the collision is counted rather than discovered at runtime")
func test_givenCorpus_whenBuilt_thenKeyCollisionsCounted() {
    #expect(TierZeroCorpus(tsv: sample).keyCollisions == 1)
    #expect(TierZeroCorpus(tsv: sample).rowCount == 6)
}

@Test("a title that matches but an artist that does not is a MISS, not a wrong answer")
func test_givenWrongArtist_whenLookedUp_thenMiss() {
    #expect(TierZeroCorpus(tsv: sample).lookup(artist: "Roni Size", title: "Terminator") == nil)
}

@Test("an empty or absent corpus misses cleanly instead of failing")
func test_givenEmptyCorpus_whenLookedUp_thenMiss() {
    #expect(TierZeroCorpus(tsv: "").rowCount == 0)
    #expect(TierZeroCorpus(tsv: "").lookup(artist: "Goldie", title: "Terminator") == nil)
    #expect(TierZeroCorpus(contentsOf: URL(fileURLWithPath: "/nope/nope.tsv")) == nil)
}
