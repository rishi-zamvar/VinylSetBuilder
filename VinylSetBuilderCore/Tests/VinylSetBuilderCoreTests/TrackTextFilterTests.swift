import Foundation
import Testing
@testable import VinylSetBuilderCore

// Every string in this file is a real read off one of the owner's twelve photographs. Nothing
// here is invented: if a case is not in .local/ocr/ocr2_out.json it is not tested here.

// MARK: - SEG-08: the trusted tier is a tier, not a threshold

@Test("SEG-08: confidence is binary in this corpus, so the trusted tier is 1.00 exactly")
func test_givenTheTwelveFixtures_whenPartitioned_thenEightyNineObservationsAreTrusted() {
    let all = FixtureObservations.all.flatMap(\.observations)
    #expect(all.count == 104)
    #expect(all.filter(TrackTextFilter.isTrusted).count == 89)
    // The measured tiers: nothing sits between 0.50 and 1.00, which is why a fractional
    // threshold would be inventing precision.
    #expect(Set(all.map(\.confidence)) == [1.0, 0.5, 0.3])
}

// MARK: - SEG-03: noise

@Test("SEG-03: every price sticker the spike recorded is filtered")
func test_givenAPriceSticker_whenFiltered_thenItIsNoise() {
    for text in ["$10.007", "·9.99)", "6.00€", "$9.73 [Import]", "8.00%",
                 "$ 10.00g", "$ 10.003", "·009", "#00°L", "15.6-"] {
        #expect(TrackTextFilter.isNoise(text), "\(text) survived the price filter")
    }
}

@Test("SEG-03: sleeve boilerplate, web addresses and genre words are filtered")
func test_givenSleeveBoilerplate_whenFiltered_thenItIsNoise() {
    for text in ["MADE IN", "ENGLAND", "PUBLISHED BY SERIES 3 MUSIC.",
                 "TH TRACKS WRITTENAND PRODUCED BY THE", "EMAIL: ton@spryr",
                 "WWW.TECHNIQUERECORDINGS.CO.UK", "Timeless Recordings", "TimelessRecordings",
                 "RECORDINGS", "EXCLUSIVE NEW MIXES FROM V CLASSIC THE ALBUM",
                 "Drum+ Bass", "DrumBass", "JUNGLE, dib", "12\" 1012816"] {
        #expect(TrackTextFilter.isNoise(text), "\(text) survived the boilerplate filter")
    }
}

@Test("V12: Zzz. is noise — a three-character sticker fragment is not a record's name")
func test_givenThePriceStickerFragment_whenFiltered_thenItIsNoise() {
    #expect(TrackTextFilter.isNoise("Zzz."))
    // Two independent rules reach it, so removing either one does not reopen V12.
    #expect(TrackTextFilter.alphanumeric("Zzz.").count < 4)
    #expect(TrackTextFilter.isNoise("ZZZ"))
    // ...and the trebled-character rule is bounded to short strings, or IMG_0503's own
    // B-side marker would be filtered as a stutter.
    #expect(!TrackTextFilter.isNoise("AAA: Strange Nat ure"))
}

@Test("SEG-03: real track text is NOT filtered — the gate is not simply eating everything")
func test_givenRealTrackText_whenFiltered_thenItSurvives() {
    for text in ["Abstract", "The Message -", "Brown", "Gtauno Originat Mix!", "Invocación",
                 "Remix", "STAY", "eFOCUSED", "LINU ME", "JA22", "DJ KRUST", "Da Lick",
                 "DUBTRACK", "SUPERSONIC", "G SQUAD", "SONIC", "A: High Down",
                 "COLD SIDE: WIDE OPBY", "xtasia", "fellowship", "'sweetness'",
                 "The Accidental Heroes", "DISTORTED MINDS - MC SKIBADEE", "\"SMADON MIND"] {
        #expect(!TrackTextFilter.isNoise(text), "\(text) was wrongly filtered as noise")
    }
}

// MARK: - SEG-03: catalogue numbers are EXTRACTED AND KEPT, not discarded

@Test("SEG-03: the six catalogue numbers the spike read are all recovered")
func test_givenACatalogueNumber_whenExtracted_thenItIsRecovered() {
    let cases = [("TYME 012", "TYME012"), ("tech008", "TECH008"), ("CSI 006", "CSI006"),
                 ("Emotif/Xstatic EMF2029", "EMF2029"), ("0-44904", "0-44904"),
                 ("0-44845", "0-44845")]
    for (text, expected) in cases {
        #expect(TrackTextFilter.catalogueNumber(in: text) == expected, "\(text)")
    }
}

@Test("SEG-03: a misread title is not mistaken for a catalogue number")
func test_givenTitleLikeText_whenExtracted_thenNoCatalogueNumberIsClaimed() {
    // JA22 is IMG_0502's misread TITLE. Two letters plus two digits is exactly the shape a
    // loose catalogue regex would swallow, which is why the minimum is three letters.
    for text in ["JA22", "STAY", "Da Lick", "SONIC", "G SQUAD", "12\" 1012816",
                 "PUBLISHED BY SERIES 3 MUSIC.", "·009", "DUBTRACK"] {
        #expect(TrackTextFilter.catalogueNumber(in: text) == nil,
                "\(text) was claimed as catalogue \(TrackTextFilter.catalogueNumber(in: text) ?? "")")
    }
}

// MARK: - SEG-04: side markers, far beyond A1/B2

@Test("SEG-04: every side marker form the fixtures actually contain is recognised")
func test_givenARealSideMarker_whenParsed_thenTheSideAndItsTitleComeBack() {
    let cases: [(String, String, String)] = [
        ("A \"Dragstar\"", "A", "DRAGSTAR"),
        ("AA \"Elementz\"", "AA", "ELEMENTZ"),
        ("A: High Down", "A", "HIGH DOWN"),
        ("AAA: Strange Nat ure", "AAA", "STRANGE NAT URE"),
        ("SIDE A", "A", ""),
        ("COLD SIDE: WIDE OPBY", "COLD", "WIDE OPBY"),
        ("STEELSIDE", "STEEL", ""),
    ]
    for (text, side, title) in cases {
        let marker = TrackTextFilter.sideMarker(in: text)
        #expect(marker?.name == side, "\(text) -> \(marker?.name ?? "nil")")
        #expect(marker?.title == title, "\(text) -> \(marker?.title ?? "nil")")
    }
}

@Test("SEG-04: a misread SIDE still reads as a side marker")
func test_givenAMisreadSideWord_whenParsed_thenFuzzyMatchingStillFindsIt() {
    // IMG_0500 reads "Side One" as "Gide One /". One edit in seven.
    #expect(TrackTextFilter.sideMarker(in: "Gide One /")?.name == "ONE")
}

@Test("SEG-04: ordinary track text is not a side marker")
func test_givenTrackText_whenParsed_thenNoSideMarkerIsClaimed() {
    for text in ["ART", "Abstract", "Da Lick", "STAY", "SONIC", "DUBTRACK", "Brown",
                 "SUPERSONIC", "xtasia", "The Accidental Heroes"] {
        #expect(TrackTextFilter.sideMarker(in: text) == nil,
                "\(text) -> \(TrackTextFilter.sideMarker(in: text)?.name ?? "")")
    }
}

// MARK: - SEG-05: a version qualifier attaches, it does not start a track

@Test("SEG-05: version and mix suffixes are qualifiers")
func test_givenAVersionSuffix_whenClassified_thenItIsAQualifier() {
    for text in ["Gtauno Originat Mix!", "•MAIATCIN DAVE ANCEL MIX", "Remix",
                 "Oríginal Versionk", "(VIP)", "(Dub)", "[Instrumental]", "Dave Angel Edit"] {
        #expect(TrackTextFilter.isVersionQualifier(text), "\(text) is not being treated as a version")
    }
}

@Test("SEG-05: DUBTRACK is a title, not a dub — the boundary is a word boundary")
func test_givenATitleContainingAQualifierWord_whenClassified_thenItIsNotAQualifier() {
    for text in ["DUBTRACK", "SUPERSONIC", "Da Lick", "STAY", "A: High Down", "xtasia"] {
        #expect(!TrackTextFilter.isVersionQualifier(text), "\(text) was wrongly read as a version")
    }
}
