import Foundation
import Testing
@testable import VinylSetBuilderCore

// Every payload below is a REAL Discogs response, trimmed to the fields the parser reads and
// pasted from a live call made on 2026-08-30. Inventing a payload shape and then parsing it
// successfully proves only that two guesses agree.

/// `catno=0-44904`. The measured false positive: a USSR Tchaikovsky pressing is result ONE,
/// and the record actually wanted — Abstract's "The Message" — is result three.
func tchaikovskyPayload() -> [String: Any] { [
    "results": [
        ["title": "P. Tchaikovsky* - Leningrad Philharmonic Orchestra , Conductor Evgeny Mravinsky - Symphony No 5",
         "catno": "C 0449-0450", "label": ["Мелодия"], "format": ["Vinyl", "LP"], "year": "1968", "id": 14531213],
        ["title": "The Absolute Featuring Suzanne Palmer - I Believe",
         "catno": "582 075-2", "label": ["AM:PM"], "format": ["CD", "Single"], "id": 2],
        ["title": "Abstract* - The Message ‎– Fuck Willie Brown",
         "catno": "0-44904", "label": ["Higher Education"], "format": ["Vinyl", "12\""], "id": 3],
    ]
] }

/// `catno=TECH008`. TWO releases carry this catalogue number exactly, on two different
/// labels. No amount of catalogue-number filtering can separate them — only the sleeve can.
func techPayload() -> [String: Any] { [
    "results": [
        ["title": "Various - Technique Allstars 02", "catno": "Tech 008-5",
         "label": ["Technique Records"], "format": ["CD"], "id": 1],
        ["title": "Drumsound And Simon Bassline Smith* - Dubtrack / Supersonic", "catno": "TECH008",
         "label": ["Technique Recordings"], "format": ["Vinyl", "12\""], "id": 2],
        ["title": "MLOBO / Xentrix - Indian Summer / Typhoon", "catno": "TECH008",
         "label": ["Brotech Records"], "format": ["Vinyl", "12\""], "id": 3],
    ]
] }

private func discogs(_ payload: [String: Any], status: Int = 200) -> RecordingTransport {
    let response = json(payload, status: status)   // serialised BEFORE the closure: Any is not Sendable
    return RecordingTransport([{ _ in response }])
}

@Test("RES-03: a Discogs search result yields artist, title, label and format")
func test_givenDiscogsPayload_whenParsed_thenCarriesArtistTitleLabelAndFormat() async throws {
    let client = DiscogsClient(transport: discogs(tchaikovskyPayload()), token: "t")
    let results = try await client.searchByCatalogueNumber("0-44904")
    let abstract = try #require(results.first { $0.artist == "Abstract" })
    #expect(abstract.title == "The Message ‎– Fuck Willie Brown")
    #expect(abstract.label == "Higher Education")
    #expect(abstract.format == "Vinyl, 12\"")
    #expect(abstract.catalogueNumber == "0-44904")
    #expect(abstract.source == "discogs")
}

@Test("RES-08: a result whose catalogue number is not the one asked for is not a candidate")
func test_givenWrongCatalogueNumbers_whenSearched_thenOnlyExactMatchesSurvive() async throws {
    let client = DiscogsClient(transport: discogs(tchaikovskyPayload()), token: "t")
    let results = try await client.searchByCatalogueNumber("0-44904")
    // Tchaikovsky's C 0449-0450 and the CD's 582 075-2 are gone; only 0-44904 remains.
    #expect(results.count == 1)
    #expect(results[0].artist == "Abstract")
}

@Test("RES-08: catalogue-number equality ignores spacing, case and hyphens but not extra digits")
func test_givenCatalogueVariants_whenNormalised_thenSpacingIgnoredAndSuffixesNot() {
    #expect(DiscogsClient.catalogueMatches("EMF-2029", "EMF2029"))
    #expect(DiscogsClient.catalogueMatches("CSi 006", "CSI006"))
    #expect(DiscogsClient.catalogueMatches("TYME 012", "TYME012"))
    #expect(DiscogsClient.catalogueMatches("Tech 008-5", "TECH008") == false)
    #expect(DiscogsClient.catalogueMatches("C 0449-0450", "0-44904") == false)
}

@Test("the Discogs artist disambiguator is not part of the artist's name")
func test_givenDisambiguatedArtist_whenParsed_thenSuffixStripped() {
    #expect(DiscogsClient.cleanArtist("Abstract*") == "Abstract")
    #expect(DiscogsClient.cleanArtist("Nucleus (2)") == "Nucleus")
    #expect(DiscogsClient.cleanArtist("Drumsound And Simon Bassline Smith*")
            == "Drumsound And Simon Bassline Smith")
}

@Test("RES-05: a 429 is retried with backoff, not reported as a failed resolution")
func test_given429ThenSuccess_whenSearched_thenRetriedAndResolved() async throws {
    let attempts = Counter()
    let limited = json([:], status: 429, headers: ["Retry-After": "1"])
    let ok = json(tchaikovskyPayload())
    let transport = RecordingTransport([{ _ in attempts.bump() == 1 ? limited : ok }])
    let client = DiscogsClient(transport: transport, token: "t", sleeper: { _ in })
    let results = try await client.searchByCatalogueNumber("0-44904")
    #expect(results.count == 1)
    #expect(await transport.count == 2)
}

@Test("RES-05: a 429 that never clears fails honestly rather than retrying for ever")
func test_givenPersistent429_whenSearched_thenGivesUpAfterBoundedAttempts() async {
    let limited = json([:], status: 429)
    let transport = RecordingTransport([{ _ in limited }])
    let client = DiscogsClient(transport: transport, token: "t", sleeper: { _ in })
    await #expect(throws: HTTPError.self) { try await client.searchByCatalogueNumber("X") }
    #expect(await transport.count == 3)
}

@Test("the token travels as a header, never in the query string a log would keep")
func test_givenSearch_whenRequestBuilt_thenTokenIsAHeaderNotAQueryParameter() async throws {
    let transport = discogs(tchaikovskyPayload())
    _ = try await DiscogsClient(transport: transport, token: "SEKRIT").searchByCatalogueNumber("TYME012")
    let urls = await transport.urls
    #expect(urls[0].contains("SEKRIT") == false)
    #expect(await transport.sent[0].headers["Authorization"] == "Discogs token=SEKRIT")
}

/// A minimal mutable counter for tests that need a request to behave differently the second
/// time. `nonisolated(unsafe)` is honest here: the closure that uses it runs serially inside
/// one actor's `send`.
final class Counter: @unchecked Sendable {
    private var value = 0
    func bump() -> Int { value += 1; return value }
}
