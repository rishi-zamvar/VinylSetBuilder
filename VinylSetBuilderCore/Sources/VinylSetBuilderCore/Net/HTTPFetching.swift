import Foundation

/// The one hole this package leaves for the network.
///
/// Everything ABOVE this line — the ladder, the ranking, the retry policy, the rate limit and
/// every JSON parse — lives in Core and is tested here. Only the ~40 lines that actually open
/// a socket live in the app target, because Core may not name the framework that does it.
/// Drawing the seam at "the app owns the clients" instead would have moved the entire
/// resolution algorithm into the one target with no test bundle.
public protocol HTTPFetching: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public struct HTTPRequest: Sendable, Hashable {
    public enum Method: String, Sendable { case get = "GET", post = "POST" }

    public let url: URL
    public let method: Method
    public let headers: [String: String]
    public let body: Data?

    public init(url: URL, method: Method = .get, headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable, Hashable {
    public let status: Int
    public let body: Data
    public let headers: [String: String]

    public init(status: Int, body: Data, headers: [String: String] = [:]) {
        self.status = status
        self.body = body
        self.headers = headers
    }

    public var isOK: Bool { (200..<300).contains(status) }

    /// 429 is a rate limit and 503 is MusicBrainz saying "busy, come back" — both are
    /// transient and must be retried rather than reported as a failed resolution (RES-05).
    public var isTransient: Bool { status == 429 || status == 503 || status == 502 || status == 504 }

    /// `Retry-After`, in seconds, when the server names its own backoff. Case-insensitive
    /// because header casing is not guaranteed across transports.
    public var retryAfterSeconds: Double? {
        for (name, value) in headers where name.lowercased() == "retry-after" {
            return Double(value.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
}

public enum HTTPError: Error, Sendable {
    case status(Int)
    case malformedResponse
}
