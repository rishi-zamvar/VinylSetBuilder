import Foundation
import Testing
@testable import VinylSetBuilderCore

// The sleeve text in every case below is what the SHIPPED segmenter returned from the SHIPPED
// reader on the owner's own photographs — copied out of Artifacts/ocr/score-run1.json, not
// invented. A cross-check tested against imagined OCR proves nothing about real OCR.

private let tchaikovsky = ReleaseCandidate(
    artist: "P. Tchaikovsky", title: "Leningrad Philharmonic Orchestra, Symphony No 5",
    catalogueNumber: "C 0449-0450", label: "Мелодия", source: "discogs")
private let abstract = ReleaseCandidate(
    artist: "Abstract", title: "The Message – Fuck Willie Brown",
    catalogueNumber: "0-44904", label: "Higher Education", source: "discogs")
private let img0498 = ["Abstract", "The Message - Brown Gtauno Originat Mix!"]

@Test("RES-08 NEGATIVE CONTROL: the sleeve rejects the Tchaikovsky record outright")
func test_givenTchaikovskyCandidate_whenCrossChecked_thenZeroSupportAndNotChosen() {
    // Nothing on IMG_0498 says Tchaikovsky, Leningrad, Philharmonic or Мелодия.
    #expect(SleeveCrossCheck.support(for: tchaikovsky, sleeveText: img0498) == 0)
    // And with Tchaikovsky as the ONLY candidate, the answer is no answer — not "the best of
    // a bad lot". This assertion is the one that fails if `best` ever returns its argmax
    // unconditionally.
    #expect(SleeveCrossCheck.best(among: [tchaikovsky], sleeveText: img0498) == nil)
}

@Test("RES-08: the supported candidate wins even when the database returned it last")
func test_givenTchaikovskyFirstAndAbstractLast_whenCrossChecked_thenAbstractChosen() {
    let chosen = SleeveCrossCheck.best(among: [tchaikovsky, abstract], sleeveText: img0498)
    #expect(chosen?.candidate.artist == "Abstract")
    #expect((chosen?.support ?? 0) >= 3)   // ABSTRACT, MESSAGE, BROWN
}

@Test("RES-08: two real records share catalogue number TECH008 and only the sleeve separates them")
func test_givenTwoReleasesSharingTECH008_whenCrossChecked_thenTheSleeveDecides() {
    let drumsound = ReleaseCandidate(artist: "Drumsound And Simon Bassline Smith",
                                     title: "Dubtrack / Supersonic", catalogueNumber: "TECH008",
                                     label: "Technique Recordings", source: "discogs")
    let mlobo = ReleaseCandidate(artist: "MLOBO / Xentrix", title: "Indian Summer / Typhoon",
                                 catalogueNumber: "TECH008", label: "Brotech Records",
                                 source: "discogs")
    let sleeve = ["DUBTRACK", "SUPERSONIC"]                 // IMG_0505, as shipped
    #expect(SleeveCrossCheck.support(for: mlobo, sleeveText: sleeve) == 0)
    #expect(SleeveCrossCheck.best(among: [mlobo, drumsound], sleeveText: sleeve)?
        .candidate.artist == "Drumsound And Simon Bassline Smith")
}

@Test("RES-08: CSI006 likewise — the M.I.O.S. record is returned first and is not the record")
func test_givenTwoReleasesSharingCSI006_whenCrossChecked_thenGSquadChosen() {
    let mios = ReleaseCandidate(artist: "M.I.O.S.",
                                title: "Live at Festival of Industrial Music, Prague 1989",
                                catalogueNumber: "CSi 006", label: "CS Industrial", source: "musicbrainz")
    let gsquad = ReleaseCandidate(artist: "G Squad", title: "Wide Open Spaces / Monitor",
                                  catalogueNumber: "CSI 006", label: "Cold Steel", source: "musicbrainz")
    let sleeve = ["COLD: WIDE OPBY", "STEEL"]               // IMG_0506, as shipped
    #expect(SleeveCrossCheck.support(for: mios, sleeveText: sleeve) == 0)
    #expect(SleeveCrossCheck.best(among: [mios, gsquad], sleeveText: sleeve)?.candidate.artist == "G Squad")
}

@Test("the cross-check survives the reader's misspellings")
func test_givenMisreadSleeveWords_whenCrossChecked_thenSupportedByTheWordsThatSurvive() {
    let heroes = ReleaseCandidate(artist: "The Accidental Heroes", title: "Dragstar / Elements",
                                  catalogueNumber: "EMF2029", label: "Emotif Recordings", source: "discogs")
    // ELEMENTS against the reader's ELEMENTZ — one edit in eight.
    #expect(SleeveCrossCheck.support(for: heroes, sleeveText: ["A: DRAGSTAR", "AA: ELEMENTZ"]) == 2)

    let juju = ReleaseCandidate(artist: "Phunckateck's Juju vs. UFO!", title: "Invocación / B-Juice",
                                catalogueNumber: "0-44845", label: "Higher Education", source: "musicbrainz")
    // MEASURED, not hoped for: support is exactly ONE. `INVOCACION` carries it, folded past
    // its accent. `PHUNCKATECK` against the reader's `INCKATECKS` is four edits in eleven and
    // does NOT match — one edit per four characters is a tight ratio and this is what it costs.
    // One word of corroboration is still corroboration, and it is what separates this record
    // from a Tchaikovsky pressing that has none.
    #expect(SleeveCrossCheck.support(
        for: juju,
        sleeveText: ["JUvS. Invocación inckatecks* Gide One / Oríginal Versionk"]) == 1)
}

@Test("three-letter fragments are not evidence")
func test_givenShortWords_whenTokenised_thenDropped() {
    let tokens = SleeveCrossCheck.words("The Message - Brown Gtauno Originat Mix!")
    #expect(tokens.contains("MESSAGE"))
    #expect(tokens.contains("THE") == false)
    #expect(tokens.contains("MIX") == false)
}

@Test("an empty sleeve supports nothing — a fixture that read nothing cannot confirm a record")
func test_givenNoSleeveText_whenCrossChecked_thenNoSupport() {
    #expect(SleeveCrossCheck.support(for: abstract, sleeveText: []) == 0)
    #expect(SleeveCrossCheck.best(among: [abstract], sleeveText: [""]) == nil)
}
