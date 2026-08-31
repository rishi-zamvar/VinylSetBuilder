import Foundation
import Testing
@testable import VinylSetBuilderCore

/// **V19.** The not-included bucket reported the wrong exclusion reason: a row showing a
/// resolved BPM *and* a key still read "no SoundCloud upload matched", which is impossible —
/// it obviously matched, or those badges could not exist.
///
/// The root cause is structural, and it is visible in the source rather than only in the
/// photograph. `CrateRows.bestKnownBadges` picks the candidate with the HIGHEST KNOWN BPM;
/// `CrateRows.reason` used to pick the FIRST candidate carrying any `failureReason`. On a
/// multi-candidate vinyl those are two different tracks, so the badges described one candidate
/// and the sentence described another. Both halves are fixed here: the precedence below, and a
/// single representative candidate that the badges, the reason and the edit target all share.
///
/// Precedence, evaluated 2 → 3 → 4 → 1 (see 09-PLAN.md for why that is the order the ledger's
/// own invariant implies), with every one of the four strings reachable.

private func track(_ position: Int, artist: String? = nil, title: String? = nil,
                   bpm: Double? = nil, camelot: String? = nil, failure: String? = nil,
                   vinyl: UUID) -> Track {
    Track(vinylID: vinyl, position: position, rawOCRText: "LINE \(position)",
          artist: artist, title: title, bpm: bpm, camelot: camelot, failureReason: failure)
}

private func rows(_ candidates: [Track], vinyl: UUID, sequencerSaid: String,
                  tolerance: Double = 4.0) -> NotIncludedRow {
    let entry = VinylEntry(id: vinyl, candidates: candidates)
    let crate = Crate(name: "V19", vinyls: [entry], bpmTolerance: tolerance)
    let result = SequenceResult(sequence: [],
                                notIncluded: [NotIncluded(vinylID: vinyl, reason: sequencerSaid)],
                                totalCamelotDistance: 0)
    return CrateRows.make(result: result, crate: crate).notIncluded[0]
}

// MARK: - The defect itself, reproduced from the screenshot

@Test("V19: a row with a BPM and a key never says the audio route failed")
func test_givenAVinylWithAKnownTempoAndAStaleLadderNote_whenTheRowIsBuilt_thenItNamesTheTempoWindow() {
    let vinyl = UUID()
    // Exactly the shape of Artifacts/screenshots/03-walk-07-done-sequenced.png:
    // "The Accidental Heroes — Dragstar  136  4B" labelled "no SoundCloud upload matched".
    let answered = track(0, artist: "The Accidental Heroes", title: "Dragstar",
                         bpm: 136, camelot: "4B", vinyl: vinyl)
    let unanswered = track(1, artist: "The Accidental Heroes", title: "B Side",
                           failure: ExclusionReason.noSoundCloudMatch, vinyl: vinyl)

    let row = rows([answered, unanswered], vinyl: vinyl,
                   sequencerSaid: ExclusionReason.outsideWindow(tolerance: 4))

    #expect(row.badges.bpm == "136")
    #expect(row.badges.key == "4B")
    #expect(row.reason == "No track within 4 BPM of the set")
    #expect(row.reason != ExclusionReason.noSoundCloudMatch)
}

// MARK: - One test per row of the precedence table

@Test("V19 reason 2: a known tempo means the window is the terminal cause, whatever else was recorded")
func test_givenAnyCandidateWithATempo_whenTheRowIsBuilt_thenTheWindowIsTheReason() {
    let vinyl = UUID()
    let row = rows([track(0, artist: "A", title: "B", bpm: 178, vinyl: vinyl)], vinyl: vinyl,
                   sequencerSaid: "something else entirely", tolerance: 5.5)
    #expect(row.reason == "No track within 5.5 BPM of the set")
}

@Test("V19 reason 3: nothing was ever identified, so there was nothing to look up")
func test_givenNoIdentityOnAnyCandidate_whenTheRowIsBuilt_thenItSaysThereIsNothingToLookUp() {
    let vinyl = UUID()
    let row = rows([track(0, vinyl: vinyl), track(1, title: "half an identity", vinyl: vinyl)],
                   vinyl: vinyl, sequencerSaid: ExclusionReason.noBPM)
    #expect(row.reason == "No identity to look up")
}

@Test("V19 reason 4: identified, and the ladder's own sentence explains the empty audio route")
func test_givenAnIdentifiedTrackTheLadderCouldNotAnswer_whenTheRowIsBuilt_thenTheLadderSpeaks() {
    let vinyl = UUID()
    let row = rows([track(0, artist: "Abstract", title: "The Message",
                          failure: ExclusionReason.noSoundCloudMatch, vinyl: vinyl)],
                   vinyl: vinyl, sequencerSaid: ExclusionReason.noBPM)
    #expect(row.reason == "No SoundCloud upload matched")
}

@Test("V19 reason 1: identified, no tempo, nothing recorded — the generic fallback still stands")
func test_givenAnIdentifiedTrackWithNoRecordedCause_whenTheRowIsBuilt_thenTheFallbackStands() {
    let vinyl = UUID()
    let row = rows([track(0, artist: "A", title: "B", vinyl: vinyl)], vinyl: vinyl,
                   sequencerSaid: ExclusionReason.noBPM)
    #expect(row.reason == "No BPM yet — resolve it or enter it by hand")
}

@Test("V19: all four strings are reachable — none of the table's rows is dead")
func test_givenTheFourTerminalCauses_whenRowsAreBuilt_thenFourDistinctStringsAppear() {
    let ids = (0..<4).map { _ in UUID() }
    let reasons = [
        rows([track(0, artist: "A", title: "B", bpm: 178, vinyl: ids[0])], vinyl: ids[0],
             sequencerSaid: "x").reason,
        rows([track(0, vinyl: ids[1])], vinyl: ids[1], sequencerSaid: "x").reason,
        rows([track(0, artist: "A", title: "B", failure: ExclusionReason.noSoundCloudMatch,
                    vinyl: ids[2])], vinyl: ids[2], sequencerSaid: "x").reason,
        rows([track(0, artist: "A", title: "B", vinyl: ids[3])], vinyl: ids[3],
             sequencerSaid: ExclusionReason.noBPM).reason,
    ]
    #expect(Set(reasons).count == 4, "a precedence row is unreachable: \(reasons)")
    #expect(reasons == ["No track within 4 BPM of the set", "No identity to look up",
                        "No SoundCloud upload matched",
                        "No BPM yet — resolve it or enter it by hand"])
}

// MARK: - The invariant, swept

@Test("V19 invariant: across a whole crate, a visible BPM badge always means the tempo window")
func test_givenACrateOfEveryShape_whenRowsAreBuilt_thenABPMBadgeAlwaysMeansTheWindow() {
    // Every combination of (tempo, identity, ladder note) on 3-candidate vinyls, so the sweep
    // covers the multi-candidate case the defect actually lived in.
    var vinyls: [VinylEntry] = []
    for hasBPM in [false, true] {
        for hasIdentity in [false, true] {
            for ladderNote in [nil, ExclusionReason.noSoundCloudMatch] {
                let id = UUID()
                vinyls.append(VinylEntry(id: id, candidates: [
                    track(0, artist: hasIdentity ? "A" : nil, title: hasIdentity ? "B" : nil,
                          bpm: hasBPM ? 200 : nil, camelot: hasBPM ? "8A" : nil, vinyl: id),
                    track(1, artist: hasIdentity ? "A" : nil, title: hasIdentity ? "C" : nil,
                          failure: ladderNote, vinyl: id),
                    track(2, vinyl: id),
                ], position: vinyls.count))
            }
        }
    }
    let crate = Crate(name: "sweep", vinyls: vinyls, bpmTolerance: 4)
    let result = SequenceResult(sequence: [],
                                notIncluded: vinyls.map { NotIncluded(vinylID: $0.id,
                                                                      reason: ExclusionReason.noBPM) },
                                totalCamelotDistance: 0)
    let built = CrateRows.make(result: result, crate: crate)
    #expect(built.notIncluded.count == 8)
    for row in built.notIncluded where row.badges.bpm != TrackBadges.placeholder {
        #expect(row.reason == ExclusionReason.outsideWindow(tolerance: 4),
                "V19 INVARIANT BROKEN: badge \(row.badges.bpm) with reason '\(row.reason)'")
    }
}

// MARK: - The structural half: badges, reason and edit target share one candidate

@Test("V19: the row's edit target is the same candidate its badges describe")
func test_givenAMultiCandidateVinyl_whenTheRowIsBuilt_thenTheEditTargetIsTheBadgedCandidate() {
    let vinyl = UUID()
    let quiet = track(0, artist: "A", title: "Quiet", failure: "something", vinyl: vinyl)
    let loud = track(1, artist: "A", title: "Loud", bpm: 136, camelot: "4B", vinyl: vinyl)
    let row = rows([quiet, loud], vinyl: vinyl, sequencerSaid: "x")
    #expect(row.badges.bpm == "136")
    #expect(row.trackID == loud.id, "the badges describe one candidate and the sheet would edit another")
}

@Test("V19: a vinyl with no candidates at all has no edit target and still reads sensibly")
func test_givenAVinylWithNoCandidates_whenTheRowIsBuilt_thenThereIsNothingToEdit() {
    let vinyl = UUID()
    let row = rows([], vinyl: vinyl, sequencerSaid: ExclusionReason.noBPM)
    #expect(row.trackID == nil)
    #expect(row.reason == "No identity to look up")
}

// MARK: - One definition of the tolerance sentence

@Test("The tolerance sentence is formatted in exactly one place, for whole and fractional values")
func test_givenATolerance_whenTheSentenceIsBuilt_thenItReadsLikeAHumanWroteIt() {
    #expect(ExclusionReason.outsideWindow(tolerance: 4.0) == "No track within 4 BPM of the set")
    #expect(ExclusionReason.outsideWindow(tolerance: 4.5) == "No track within 4.5 BPM of the set")
    #expect(ExclusionReason.outsideWindow(tolerance: 6.0) == "No track within 6 BPM of the set")
}
