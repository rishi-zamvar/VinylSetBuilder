import Foundation
import Testing
@testable import VinylSetBuilderCore

/// Records what it was asked to WAIT, so the rate limit can be measured without spending the
/// wall-clock time it describes.
final class SleepLog: @unchecked Sendable {
    private let lock = NSLock()
    private var waits: [Double] = []
    func record(_ seconds: Double) { lock.lock(); waits.append(seconds); lock.unlock() }
    var all: [Double] { lock.lock(); defer { lock.unlock() }; return waits }
}

@Test("the first request is not delayed; the second waits out the interval")
func test_givenTwoRequests_whenSent_thenOnlyTheSecondWaits() async throws {
    let log = SleepLog()
    let response = HTTPResponse(status: 200, body: Data())
    let inner = RecordingTransport([{ _ in response }])
    let throttle = ThrottledTransport(wrapping: inner, minimumInterval: 1.0,
                                      sleeper: { log.record($0) })
    let request = HTTPRequest(url: URL(string: "https://example.test/a")!)
    _ = try await throttle.send(request)
    #expect(log.all.isEmpty)
    _ = try await throttle.send(request)
    #expect(log.all.count == 1)
    #expect(log.all[0] > 0.9 && log.all[0] <= 1.0)
    #expect(await inner.count == 2)
}

@Test("the two documented intervals are the two documented intervals")
func test_givenTheRateLimits_whenRead_thenTheyMatchWhatTheServicesAsk() {
    #expect(ThrottledTransport.discogsInterval > 1.0)      // 60/min needs > 1s spacing
    #expect(ThrottledTransport.musicBrainzInterval == 1.0)
}
