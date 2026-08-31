import Foundation
import Testing
@testable import VinylSetBuilderCore

/// **MAN-04, and it is a gate, not a green tick.**
///
/// This is the bug class that quietly destroys a user's work: they hand-type an artist for a
/// white label that is in no database, a later automatic pass runs over the same crate, and the
/// typing is gone with no error and nothing on screen to say it happened. Phase 7 measured
/// tier-0 at 0 of 35 on this collection and the last end-to-end run put 8 of 12 records outside
/// the set, so the hand-typed half of a crate is the half that matters most.
///
/// The gate is therefore not "a flag is set". It is: **run the REAL `TrackResolver` and the REAL
/// `BPMLadder`, against stubs that answer with a DIFFERENT value for every single field, and
/// assert field by field that nothing a person typed moved.** A stub that agreed with the
/// hand-entered values would make this test pass while proving nothing.

/// Every field deliberately contradicts what the person typed below. The sleeve text and the
/// catalogue number are made to MATCH the automatic answer on purpose — the cross-check has to
/// pass, or the resolver never gets far enough to overwrite anything and the test would be
/// green for the wrong reason.
private func contradictingTransport() -> RecordingTransport {
    let release = json([
        "count": 1,
        "releases": [[
            "score": 100,
            "title": "AUTOMATIC TITLE",
            "artist-credit": [["name": "AUTOMATIC ARTIST"]],
            "date": "2001",
            "label-info": [["catalog-number": "AUTO 001", "label": ["name": "Automatic Records"]]],
            "media": [["format": "12\" Vinyl"]],
        ]],
    ])
    let token = json(["access_token": "abc"])
    // Two uploads, one per artist name this file uses, so the same stub serves both the
    // protected case and the unprotected one without either being tuned to pass.
    let results = json([
        ["id": 1, "title": "AUTOMATIC TITLE", "duration": 300_000,
         "user": ["username": "Hidden Agenda"]],
        ["id": 2, "title": "AUTOMATIC TITLE", "duration": 300_000,
         "user": ["username": "AUTOMATIC ARTIST"]],
    ])
    let audio = HTTPResponse(status: 200, body: Data(repeating: 7, count: 1024))
    return RecordingTransport([{ request in
        if request.method == .post { return token }
        let url = request.url.absoluteString
        if url.contains("/stream") || url.contains("/download") { return audio }
        if url.contains("soundcloud") { return results }
        return release
    }])
}

private let automaticSleeve = SleeveContext(catalogueNumber: "AUTO001",
                                            text: ["AUTOMATIC TITLE"])

private func realResolver(_ transport: any HTTPFetching) -> TrackResolver {
    TrackResolver(musicBrainz: MusicBrainzClient(transport: transport, sleeper: { _ in }),
                  discogs: DiscogsClient(transport: transport, token: "t", sleeper: { _ in }),
                  cache: ResolutionCache())
}

/// Answers 199 BPM in 12B — values no hand entry in this suite uses, so an overwrite is
/// unmissable rather than a plausible-looking near-match.
private func realLadder(_ transport: any HTTPFetching) -> BPMLadder {
    BPMLadder(corpus: nil,
              soundCloud: SoundCloudClient(transport: transport, clientID: "i", clientSecret: "s",
                                           sleeper: { _ in }),
              decoder: BoxingDecoder(),
              analyser: StubAnalyser(AudioAnalysis(bpm: 199, camelot: "12B", keyConfidence: 1.0)))
}

// MARK: - The whole-track case

@Test("MAN-04: a fully hand-entered track survives the real resolver and the real ladder unchanged")
func test_givenAFullyManualTrack_whenAutomaticResolutionRuns_thenNotOneFieldMoves() async {
    let typed = Track(vinylID: UUID(), position: 0, rawOCRText: "AUTOMATIC TITLE",
                      artist: "Hidden Agenda", title: "Is It Love",
                      bpm: 172, camelot: "6A", resolutionState: .manual)
    let transport = contradictingTransport()

    let resolved = await realResolver(transport)
        .resolve([typed], sleeve: automaticSleeve)
    let filled = await realLadder(transport).fill(resolved[0])

    // Field by field, not `==` on the whole struct: a whole-struct compare that fails tells you
    // nothing about WHICH field was clobbered, and that is the only useful thing to know here.
    #expect(filled.artist == "Hidden Agenda")
    #expect(filled.title == "Is It Love")
    #expect(filled.bpm == 172)
    #expect(filled.camelot == "6A")
    #expect(filled.id == typed.id)
    #expect(filled.position == typed.position)
    // MAN-04's "marked as such": the mark has to survive too, or the NEXT automatic pass
    // overwrites everything this one respected.
    #expect(filled.resolutionState == .manual)
    #expect(filled.isManual)
}

// MARK: - The half-entered case, which is the realistic one

@Test("MAN-04: automatic resolution fills the gaps a person left and touches nothing else")
func test_givenAHalfEnteredTrack_whenAutomaticResolutionRuns_thenOnlyTheGapsAreFilled() async {
    // The realistic shape: the DJ knows the record and its key by ear, and cannot be bothered
    // to guess the tempo or the exact release title.
    let typed = Track(vinylID: UUID(), position: 0, rawOCRText: "AUTOMATIC TITLE",
                      artist: "Hidden Agenda", title: nil,
                      bpm: nil, camelot: "6A", resolutionState: .manual)
    let transport = contradictingTransport()

    let resolved = await realResolver(transport)
        .resolve([typed], sleeve: automaticSleeve)
    let filled = await realLadder(transport).fill(resolved[0])

    #expect(filled.artist == "Hidden Agenda", "a typed artist was overwritten")
    #expect(filled.camelot == "6A", "a typed key was overwritten")
    #expect(filled.title == "AUTOMATIC TITLE", "an empty field was not filled — the guard is too broad")
    #expect(filled.bpm == 199, "an empty tempo was not filled — the guard is too broad")
    #expect(filled.resolutionState == .manual)
}

// MARK: - The mark itself

@Test("MAN-04: only a manual track is protected — an automatic one is still freely rewritten")
func test_givenANonManualTrack_whenAutomaticResolutionRuns_thenItIsRewritten() async {
    let automatic = Track(vinylID: UUID(), position: 0, rawOCRText: "AUTOMATIC TITLE",
                          artist: "Wrong Guess", title: "Wrong Guess",
                          camelot: "1A", resolutionState: .pending)
    let transport = contradictingTransport()

    let resolved = await realResolver(transport)
        .resolve([automatic], sleeve: automaticSleeve)
    let filled = await realLadder(transport).fill(resolved[0])

    #expect(filled.artist == "AUTOMATIC ARTIST")
    #expect(filled.title == "AUTOMATIC TITLE")
    #expect(!filled.isManual)
    // The negative half of the previous test: if the guard applied to everything, the two tests
    // would be indistinguishable and neither would prove the guard keys on the mark.
    #expect(filled.camelot == "12B")
}

@Test("MAN-04: isManual is exactly the .manual state, and nothing else is")
func test_givenEveryResolutionState_whenAsked_thenOnlyManualIsManual() {
    for state in [ResolutionState.pending, .resolved, .failed, .manual] {
        let track = Track(vinylID: UUID(), resolutionState: state)
        #expect(track.isManual == (state == .manual))
    }
}

// MARK: - The failure path, which is the one a hand-entered record actually travels

@Test("MAN-04: a lookup that finds nothing does not strip the manual mark")
func test_givenAManualTrackNothingCanIdentify_whenTheLookupFails_thenTheMarkAndTheTypingSurvive() async {
    // White labels and dubplates are in no database, which is precisely why somebody typed this
    // one in. If a failed lookup could downgrade `.manual` to `.failed`, the protection would
    // last exactly until the next automatic pass — on the very records it exists to protect.
    let typed = Track(vinylID: UUID(), position: 0, rawOCRText: "UNREADABLE SCRIBBLE",
                      artist: "Hidden Agenda", title: "Is It Love",
                      bpm: 172, camelot: "6A", resolutionState: .manual)
    let nothing = RecordingTransport([{ _ in json(["count": 0, "releases": [] as [Any]]) }])

    let resolved = await realResolver(nothing)
        .resolve([typed], sleeve: SleeveContext(catalogueNumber: nil, text: ["UNREADABLE SCRIBBLE"]))

    #expect(resolved[0].resolutionState == .manual)
    #expect(resolved[0].artist == "Hidden Agenda")
    #expect(resolved[0].title == "Is It Love")
    #expect(resolved[0].bpm == 172)
    #expect(resolved[0].camelot == "6A")
    // And it is not labelled a failure on screen either — it is not one.
    #expect(resolved[0].failureReason == nil)
}
