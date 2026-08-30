import Foundation

/// RES-05, in one place. Discogs answers 429 when the 60-per-minute allowance runs out and
/// MusicBrainz answers 503 "currently busy" whenever it feels like it — a live probe hit that
/// on the first attempt and succeeded on the second. Neither is a failed resolution.
///
/// The sleeper is injected so the tests do not actually wait. A retry policy tested through
/// real sleeps is a retry policy nobody runs.
public enum HTTPRetry {
    public typealias Sleeper = @Sendable (Double) async throws -> Void

    public static let realSleeper: Sleeper = { seconds in
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Up to `attempts` sends. Backs off for `Retry-After` when the server names a delay,
    /// otherwise 1 s, 2 s, 4 s. Throws `HTTPError.status` on the last non-OK response.
    public static func send(_ request: HTTPRequest,
                            via transport: any HTTPFetching,
                            attempts: Int = 3,
                            sleeper: Sleeper = realSleeper) async throws -> HTTPResponse {
        var lastStatus = 0
        for attempt in 1...max(1, attempts) {
            try Task.checkCancellation()
            let response = try await transport.send(request)
            if response.isOK { return response }
            lastStatus = response.status
            guard response.isTransient, attempt < attempts else { break }
            let backoff = response.retryAfterSeconds ?? pow(2, Double(attempt - 1))
            try await sleeper(backoff)
        }
        throw HTTPError.status(lastStatus)
    }
}
