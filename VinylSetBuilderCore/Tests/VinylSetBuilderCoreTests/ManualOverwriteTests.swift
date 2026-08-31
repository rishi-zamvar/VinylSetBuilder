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

/// Every field deliberately contradicts what the person typed below.
private func contradictingTransport() -> RecordingTransport {
    let release = json([
        "releases": [[
            "id": "r1",
            "title": "AUTOMATIC TITLE",
            "artist-credit": [["name": "AUTOMATIC ARTIST"]],
            "label-info": [["catalog-number": "AUTO001", "label": ["name": "Automatic Records"]]],
        ]],
    ])
    let token = json(["access_token": "abc"])
    let results = HTTPResponse(status: 200, body: try! JSONSerialization.data(withJSONObject: [
        ["id": 1, "title": "AUTOMATIC TITLE", "duration": 300_000,
         "user": ["username": "AUTOMATIC ARTIST"]],
    ]))
    let audio = HTTPResponse(status: 200, body: Data(repeating: 7, count: 1024))
    return RecordingTransport([{ request in
        if request.method == .post { return token }
        if request.url.absoluteString.contains("/stream") { return audio }
        if request.url.absoluteString.contains("soundcloud") { return results }
        return release
    }])
}

private func realResolver(_ transport: any HTTPFetching) -> TrackResolver {
    TrackResolver(musicBrainz: MusicBrainzClient(transport: transport, sleeper: { _ in }),
                  discogs: DiscogsClient(transport: transport, token: "t", sleeper: { _ in }),
                  cache: ResolutionCache())
}

/// Answers 999 BPM in C major — a value no hand entry in this suite uses, so an overwrite is
/// unmissable rather than a plausible-looking near-match.
private func realLadder(_ transport: any HTTPFetching) -> BPMLadder {
    BPMLadder(corpus: TierZeroCorpus(tsv: "AUTOMATIC ARTIST\tAUTOMATIC TITLE\t199.0\t12B"),
              soundCloud: SoundCloudClient(transport: transport, clientID: "i", clientSecret: "s",
                                           sleeper: { _ in }),
              decoder: nil,
              analyser: StubAnalyser(AudioAnalysis(bpm: 199, camelot: "12B", keyConfidence: 1.0)))
}

// MARK: - The whole-track case

@Test("MAN-04: a fully hand-entered track survives the real resolver and the real ladder unchanged")
func test_givenAFullyManualTrack_whenAutomaticResolutionRuns_thenNotOneFieldMoves() async {
    let typed = Track(vinylID: UUID(), position: 0, rawOCRText: "SCRIBBLE",
                      artist: "Hidden Agenda", title: "Is It Love",
                      bpm: 172, camelot: "6A", resolutionState: .manual)
    let transport = contradictingTransport()

    let resolved = await realResolver(transport)
        .resolve([typed], sleeve: SleeveContext(catalogueNumber: "TYME012", text: ["SCRIBBLE"]))
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
    let typed = Track(vinylID: UUID(), position: 0, rawOCRText: "SCRIBBLE",
                      artist: "Hidden Agenda", title: nil,
                      bpm: nil, camelot: "6A", resolutionState: .manual)
    let transport = contradictingTransport()

    let resolved = await realResolver(transport)
        .resolve([typed], sleeve: SleeveContext(catalogueNumber: "TYME012", text: ["SCRIBBLE"]))
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
    let automatic = Track(vinylID: UUID(), position: 0, rawOCRText: "SCRIBBLE",
                          artist: "Wrong Guess", title: "Wrong Guess",
                          camelot: "1A", resolutionState: .pending)
    let transport = contradictingTransport()

    let resolved = await realResolver(transport)
        .resolve([automatic], sleeve: SleeveContext(catalogueNumber: "TYME012", text: ["SCRIBBLE"]))
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
