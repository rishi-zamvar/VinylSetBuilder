import Foundation
import Testing
@testable import VinylSetBuilderCore

private let corpus = TierZeroCorpus(tsv: """
Goldie\tTerminator\t168.0\t5A
Dillinja\tThe Angels Fell\t88.0\t4A
""")

/// Hands back a fixed answer and counts how many times it was asked. An analyser called twice
/// for one track would be a quota bug hiding behind a correct result.
final class StubAnalyser: AudioAnalyzing, @unchecked Sendable {
    let analysis: AudioAnalysis
    private(set) var calls = 0
    init(_ analysis: AudioAnalysis) { self.analysis = analysis }
    func analyse(monoSamples: [Float], sampleRate: Double) async -> AudioAnalysis {
        calls += 1
        return analysis
    }
}

/// Wraps its samples in a CLASS so the test can watch that object die. If the ladder kept the
/// decoder's buffer alive past `fill`, this reference would survive.
final class SampleBuffer { let samples: [Float]; init(_ s: [Float]) { samples = s } }

final class BoxingDecoder: AudioDecoding, @unchecked Sendable {
    weak var lastBuffer: SampleBuffer?
    func decodeMono(_ data: Data) async throws -> (samples: [Float], sampleRate: Double) {
        let buffer = SampleBuffer([Float](repeating: 0.1, count: 44100))
        lastBuffer = buffer
        return (buffer.samples, 44100)
    }
}

private func soundCloud(_ transport: any HTTPFetching) -> SoundCloudClient {
    SoundCloudClient(transport: transport, clientID: "i", clientSecret: "s", sleeper: { _ in })
}

private func audioTransport() -> RecordingTransport {
    let token = json(["access_token": "abc"])
    let results = HTTPResponse(status: 200, body: try! JSONSerialization.data(withJSONObject: [
        ["id": 1, "title": "Inner City Life", "duration": 300000, "user": ["username": "Goldie"]],
    ]))
    let audio = HTTPResponse(status: 200, body: Data(repeating: 7, count: 1024))
    return RecordingTransport([{ request in
        if request.method == .post { return token }
        return request.url.absoluteString.contains("/stream") ? audio : results
    }])
}

private func track(_ artist: String?, _ title: String?, bpm: Double? = nil) -> Track {
    Track(vinylID: UUID(), artist: artist, title: title, bpm: bpm, resolutionState: .resolved)
}

@Test("BPM-02: the bundled corpus answers before any network call is made")
func test_givenTrackInCorpus_whenFilled_thenNoRequestIsIssued() async {
    let transport = audioTransport()
    let ladder = BPMLadder(corpus: corpus, soundCloud: soundCloud(transport),
                           decoder: BoxingDecoder(), analyser: StubAnalyser(
                            AudioAnalysis(bpm: 999, camelot: "1A", keyConfidence: 1)))
    let filled = await ladder.fill(track("Goldie", "Terminator"))
    #expect(filled.bpm == 168.0)
    #expect(filled.camelot == "5A")
    #expect(await transport.count == 0)
}

@Test("BPM-06: a corpus tempo below 100 is doubled, exactly once")
func test_givenHalfTimeCorpusRow_whenFilled_thenDoubledOnce() async {
    let ladder = BPMLadder(corpus: corpus)
    let filled = await ladder.fill(track("Dillinja", "The Angels Fell"))
    #expect(filled.bpm == 176.0)   // 88 -> 176, not 352
}

@Test("BPM-03: a corpus miss falls through to SoundCloud and the analyser")
func test_givenCorpusMiss_whenFilled_thenAudioRouteUsed() async {
    let analyser = StubAnalyser(AudioAnalysis(bpm: 174, camelot: "6A", keyConfidence: 0.8))
    let ladder = BPMLadder(corpus: corpus, soundCloud: soundCloud(audioTransport()),
                           decoder: BoxingDecoder(), analyser: analyser)
    let filled = await ladder.fill(track("Goldie", "Inner City Life"))
    #expect(filled.bpm == 174)
    #expect(filled.camelot == "6A")
    #expect(analyser.calls == 1)
}

@Test("BPM-04: the decoded audio does not outlive the analysis")
func test_givenAnalysedTrack_whenFillReturns_thenTheDecodedBufferIsGone() async {
    let decoder = BoxingDecoder()
    let ladder = BPMLadder(corpus: corpus, soundCloud: soundCloud(audioTransport()),
                           decoder: decoder,
                           analyser: StubAnalyser(AudioAnalysis(bpm: 174, camelot: nil)))
    _ = await ladder.fill(track("Goldie", "Inner City Life"))
    // The decoder handed out a buffer object. Nothing downstream kept it.
    #expect(decoder.lastBuffer == nil)
}

@Test("a weakly-held key is dropped; a wrong key is worse than no key")
func test_givenLowKeyConfidence_whenFilled_thenTempoKeptAndKeyDropped() async {
    let ladder = BPMLadder(corpus: corpus, soundCloud: soundCloud(audioTransport()),
                           decoder: BoxingDecoder(),
                           analyser: StubAnalyser(AudioAnalysis(bpm: 174, camelot: "6A",
                                                                keyConfidence: 0.1)))
    let filled = await ladder.fill(track("Goldie", "Inner City Life"))
    #expect(filled.bpm == 174)
    #expect(filled.camelot == nil)
}

@Test("BPM-07: a track no route can answer is surfaced for manual entry, not dropped")
func test_givenNoRouteAnswers_whenFilled_thenMarkedForManualEntryAndStillPresent() async {
    let ladder = BPMLadder(corpus: corpus)
    let filled = await ladder.fill(track("Nobody", "Nothing"))
    #expect(filled.bpm == nil)
    #expect(filled.needsManualBPM)
    #expect(filled.artist == "Nobody")          // the identity survives
    #expect((filled.failureReason ?? "").isEmpty == false)
}

@Test("a track that already has a tempo is not looked up again — that IS the cache")
func test_givenTrackWithBPM_whenFilled_thenUntouched() async {
    let transport = audioTransport()
    let ladder = BPMLadder(corpus: corpus, soundCloud: soundCloud(transport),
                           decoder: BoxingDecoder(), analyser: StubAnalyser(AudioAnalysis(bpm: 1, camelot: nil)))
    let filled = await ladder.fill(track("Goldie", "Terminator", bpm: 172))
    #expect(filled.bpm == 172)
    #expect(await transport.count == 0)
}

@Test("a track with no identity cannot be looked up and says so")
func test_givenUnresolvedTrack_whenFilled_thenExplained() async {
    let filled = await BPMLadder(corpus: corpus).fill(track(nil, nil))
    #expect(filled.bpm == nil)
    #expect(filled.failureReason?.contains("identity") == true)
}
