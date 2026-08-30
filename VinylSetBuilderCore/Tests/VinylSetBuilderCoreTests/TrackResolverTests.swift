import Foundation
import Testing
@testable import VinylSetBuilderCore

/// Counts, and records how many requests were in flight AT ONCE. RES-02 is a claim about
/// simultaneity, and a transport that only counts totals cannot see it.
actor ConcurrencyTransport: HTTPFetching {
    private(set) var total = 0
    private(set) var peak = 0
    private var inFlight = 0
    private let payload: HTTPResponse
    private let hold: Double

    init(payload: HTTPResponse, hold: Double = 0.02) {
        self.payload = payload
        self.hold = hold
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        total += 1
        inFlight += 1
        peak = max(peak, inFlight)
        // The requests must OVERLAP or the peak is meaningless — an instant transport would
        // report a peak of 1 however wide the bound was.
        try? await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))
        inFlight -= 1
        return payload
    }
}

private func sleeveTracks(_ lines: [String]) -> [Track] {
    let vinyl = UUID()
    return lines.enumerated().map { Track(vinylID: vinyl, position: $0.offset, rawOCRText: $0.element) }
}

private func resolver(_ transport: any HTTPFetching, cache: ResolutionCache = ResolutionCache()) -> TrackResolver {
    TrackResolver(musicBrainz: MusicBrainzClient(transport: transport, sleeper: { _ in }),
                  discogs: DiscogsClient(transport: transport, token: "t", sleeper: { _ in }),
                  cache: cache)
}

private let timelessSleeve = SleeveContext(catalogueNumber: "TYME012",
                                           text: ["A: HIGH DOWN", "AAA: STRANGE NAT URE"])

@Test("RES-01: a resolved sleeve gives every track an artist and a title")
func test_givenCatalogueNumberThatResolves_whenResolved_thenEveryTrackNamed() async {
    let response = json(timelessPayload())
    let tracks = await resolver(RecordingTransport([{ _ in response }]))
        .resolve(sleeveTracks(["A: HIGH DOWN", "AAA: STRANGE NAT URE"]), sleeve: timelessSleeve)
    #expect(tracks.count == 2)
    #expect(tracks.allSatisfy { $0.artist == "Cause 4 Concern" })
    // The release title is BOTH titles: "High Down / Strange Nature". Each line takes its own.
    #expect(tracks[0].title == "High Down")
    #expect(tracks[1].title == "Strange Nature")
    #expect(tracks.allSatisfy { $0.resolutionState == .resolved })
}

@Test("RES-01: a track nothing can identify is marked failed with a reason, never dropped")
func test_givenNothingMatches_whenResolved_thenFailedWithAReasonAndStillPresent() async {
    let empty = json(["releases": [] as [Any]])
    let tracks = await resolver(RecordingTransport([{ _ in empty }]))
        .resolve(sleeveTracks(["SONIC", "\"SMADON MIND"]),
                 sleeve: SleeveContext(catalogueNumber: nil, text: ["SONIC"]))
    #expect(tracks.count == 2)
    #expect(tracks.allSatisfy { $0.resolutionState == .failed })
    #expect(tracks.allSatisfy { ($0.failureReason ?? "").isEmpty == false })
}

@Test("the frugality rule: MusicBrainz answering means Discogs is never asked")
func test_givenMusicBrainzAnswers_whenResolved_thenExactlyOneRequestAndNoDiscogsCall() async {
    let response = json(timelessPayload())
    let transport = RecordingTransport([{ _ in response }])
    _ = await resolver(transport).resolve(sleeveTracks(["A: HIGH DOWN"]), sleeve: timelessSleeve)
    #expect(await transport.count == 1)
    #expect(await transport.urls.allSatisfy { $0.contains("musicbrainz") })
}

@Test("RES-06: the second pass over the same crate issues ZERO requests")
func test_givenAlreadyResolvedSleeve_whenResolvedAgain_thenNoRequestIsIssued() async {
    let response = json(timelessPayload())
    let transport = RecordingTransport([{ _ in response }])
    let cache = ResolutionCache()
    let subject = resolver(transport, cache: cache)
    let tracks = sleeveTracks(["A: HIGH DOWN", "AAA: STRANGE NAT URE"])

    _ = await subject.resolve(tracks, sleeve: timelessSleeve)
    let after = await transport.count
    _ = await subject.resolve(tracks, sleeve: timelessSleeve)

    #expect(after == 1)
    #expect(await transport.count == after)   // the measurement RES-06 actually asks for
    #expect(await cache.hits == 1)
}

@Test("RES-06: a MISS is cached as hard as a hit — nothing found is not re-asked")
func test_givenNothingFound_whenResolvedAgain_thenNoRequestIsIssued() async {
    let empty = json(["releases": [] as [Any]])
    let transport = RecordingTransport([{ _ in empty }])
    let subject = resolver(transport)
    let sleeve = SleeveContext(catalogueNumber: "NOSUCH001", text: ["NOTHING HERE"])

    _ = await subject.resolve(sleeveTracks(["NOTHING HERE"]), sleeve: sleeve)
    let after = await transport.count
    _ = await subject.resolve(sleeveTracks(["NOTHING HERE"]), sleeve: sleeve)
    #expect(after > 0)
    #expect(await transport.count == after)
}

@Test("RES-02: at most three requests are ever in flight at once")
func test_givenTenTracks_whenResolved_thenPeakInFlightIsThree() async {
    let transport = ConcurrencyTransport(payload: json(["releases": [] as [Any]]))
    let lines = (1...10).map { "TRACK NUMBER \($0) TITLE" }
    _ = await resolver(transport).resolve(sleeveTracks(lines),
                                          sleeve: SleeveContext(catalogueNumber: nil, text: lines))
    #expect(await transport.peak == 3)
    #expect(await transport.total >= 10)
}

@Test("RES-07: cancelling the crate stops the work")
func test_givenCancellation_whenResolving_thenStopsEarly() async {
    let transport = ConcurrencyTransport(payload: json(["releases": [] as [Any]]), hold: 0.05)
    let lines = (1...40).map { "TRACK NUMBER \($0) TITLE" }
    let subject = resolver(transport)
    let work = Task {
        await subject.resolve(sleeveTracks(lines),
                              sleeve: SleeveContext(catalogueNumber: nil, text: lines))
    }
    try? await Task.sleep(nanoseconds: 60_000_000)
    work.cancel()
    let tracks = await work.value
    // Every track still comes back — cancelling abandons the lookups, it does not lose records.
    #expect(tracks.count == 40)
    // And it stopped: 40 tracks unhindered would be 80 requests.
    #expect(await transport.total < 80)
}

@Test("a release title that is not two titles is not split")
func test_givenSingleTitleRelease_whenAssigned_thenUsedWhole() {
    let release = ReleaseCandidate(artist: "Goldie", title: "Terminator", source: "musicbrainz")
    #expect(TrackResolver.titlePart(of: release, matching: "TERMINATOR") == "Terminator")
}

@Test("the side marker is stripped before searching")
func test_givenSideMarkedLine_whenQueryBuilt_thenMarkerRemoved() {
    let track = Track(vinylID: UUID(), rawOCRText: "AA: ELEMENTZ")
    #expect(TrackResolver.queryText(for: track) == "ELEMENTZ")
}
