import Foundation

/// The rate limit, held in one place rather than sprinkled through the clients.
///
/// Discogs allows 60 authenticated requests a minute; MusicBrainz asks for one a second and
/// answers 503 when it feels crowded. Both are a MINIMUM SPACING between requests, which is a
/// different thing from the max-3 concurrency bound and composes with it: three tasks may be
/// in flight, but their requests still leave one second apart.
public actor ThrottledTransport: HTTPFetching {
    public static let discogsInterval = 1.05     // 60/min, with a little air
    public static let musicBrainzInterval = 1.0  // their documented ask

    private let wrapped: any HTTPFetching
    private let interval: Double
    private let sleeper: HTTPRetry.Sleeper
    private var nextEarliest: Date = .distantPast

    public init(wrapping transport: any HTTPFetching, minimumInterval: Double,
                sleeper: @escaping HTTPRetry.Sleeper = HTTPRetry.realSleeper) {
        self.wrapped = transport
        self.interval = minimumInterval
        self.sleeper = sleeper
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let wait = nextEarliest.timeIntervalSinceNow
        if wait > 0 { try await sleeper(wait) }
        nextEarliest = Date().addingTimeInterval(interval)
        return try await wrapped.send(request)
    }
}
