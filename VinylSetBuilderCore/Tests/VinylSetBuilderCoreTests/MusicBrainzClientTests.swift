import Foundation
import Testing
@testable import VinylSetBuilderCore

// Real payloads, trimmed. Taken from live calls on 2026-08-30.

func timelessPayload() -> [String: Any] { [
    "count": 1,
    "releases": [[
        "score": 100,
        "title": "High Down / Strange Nature",
        "artist-credit": [["name": "Cause 4 Concern"]],
        "date": "2001",
        "label-info": [["catalog-number": "TYME 012", "label": ["name": "Timeless Recordings"]]],
        "media": [["format": "12\" Vinyl"]],
    ]]
] }

/// `catno:"CSI006"` — TWO releases, the right one second. MusicBrainz has the same ambiguity
/// Discogs does, so the sleeve cross-check is not a Discogs workaround, it is the rule.
func coldSteelPayload() -> [String: Any] { [
    "count": 2,
    "releases": [
        ["score": 100, "title": "Live at Festival of Industrial Music, Prague 1989",
         "artist-credit": [["name": "M.I.O.S."]],
         "label-info": [["catalog-number": "CSi 006", "label": ["name": "CS Industrial"]]]],
        ["score": 100, "title": "Wide Open Spaces / Monitor",
         "artist-credit": [["name": "G Squad"]],
         "label-info": [["catalog-number": "CSI 006", "label": ["name": "Cold Steel"]]]],
    ]
] }

@Test("RES-03: a MusicBrainz release yields artist, title, label and catalogue number")
func test_givenMusicBrainzPayload_whenParsed_thenCarriesTheIdentityFields() async throws {
    let response = json(timelessPayload())
    let client = MusicBrainzClient(transport: RecordingTransport([{ _ in response }]))
    let results = try await client.searchByCatalogueNumber("TYME012")
    let first = try #require(results.first)
    #expect(first.artist == "Cause 4 Concern")
    #expect(first.title == "High Down / Strange Nature")
    #expect(first.label == "Timeless Recordings")
    #expect(first.catalogueNumber == "TYME 012")
    #expect(first.year == 2001)
    #expect(first.source == "musicbrainz")
}

@Test("MusicBrainz needs a User-Agent or it refuses; it never needs a key")
func test_givenSearch_whenRequestBuilt_thenCarriesAUserAgentAndNoCredential() async throws {
    let response = json(timelessPayload())
    let transport = RecordingTransport([{ _ in response }])
    _ = try await MusicBrainzClient(transport: transport).searchByCatalogueNumber("TYME012")
    let sent = await transport.sent[0]
    #expect(sent.headers["User-Agent"]?.contains("VinylSetBuilder") == true)
    #expect(sent.headers["Authorization"] == nil)
}

@Test("RES-05: MusicBrainz's 503 'currently busy' is transient and is retried")
func test_given503ThenSuccess_whenSearched_thenRetriedAndResolved() async throws {
    // Measured: a live probe got 503 on attempt one and 200 on attempt two, same query.
    let attempts = Counter()
    let busy = HTTPResponse(status: 503,
                            body: Data(#"{"error": "The MusicBrainz web server is currently busy."}"#.utf8))
    let ok = json(timelessPayload())
    let transport = RecordingTransport([{ _ in attempts.bump() == 1 ? busy : ok }])
    let client = MusicBrainzClient(transport: transport, sleeper: { _ in })
    #expect(try await client.searchByCatalogueNumber("TYME012").count == 1)
    #expect(await transport.count == 2)
}

@Test("both catalogue-number candidates survive parsing; choosing between them is not the parser's job")
func test_givenTwoReleasesSharingACatalogueNumber_whenParsed_thenBothReturned() async throws {
    let response = json(coldSteelPayload())
    let client = MusicBrainzClient(transport: RecordingTransport([{ _ in response }]))
    #expect(try await client.searchByCatalogueNumber("CSI006").count == 2)
}
