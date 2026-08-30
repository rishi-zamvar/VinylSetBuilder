import Foundation

/// One SoundCloud upload, as far as this app cares.
public struct SoundCloudTrack: Sendable, Hashable, Codable {
    public let id: Int
    public let title: String
    public let username: String
    public let seconds: Double

    public init(id: Int, title: String, username: String, seconds: Double) {
        self.id = id
        self.title = title
        self.username = username
        self.seconds = seconds
    }
}

/// BPM-03. The last rung: when nothing knows a record's tempo, listen to it.
///
/// `client_credentials` returns a **30-second preview** and nothing more — measured, on the
/// owner's own account, on official artist uploads: `downloadable: false`, `access: preview`.
/// Thirty seconds is roughly 85 beats at 170 BPM, which is ample for tempo and thin for key.
///
/// Result selection is NOT "take the first hit". A live probe returned a 79-minute DJ mix as
/// result two for a correct artist query.
public struct SoundCloudClient: Sendable {
    private let transport: any HTTPFetching
    private let clientID: String
    private let clientSecret: String
    private let tokens: TokenStore
    private let sleeper: HTTPRetry.Sleeper

    public init(transport: any HTTPFetching, clientID: String, clientSecret: String,
                sleeper: @escaping HTTPRetry.Sleeper = HTTPRetry.realSleeper) {
        self.transport = transport
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.tokens = TokenStore()
        self.sleeper = sleeper
    }

    /// The bearer token, fetched once and kept. Re-authenticating per request would be a
    /// request per request for a datum that does not change.
    actor TokenStore {
        var value: String?
        func set(_ token: String) { value = token }
    }

    public func authenticate() async throws -> String {
        if let existing = await tokens.value { return existing }
        let body = "grant_type=client_credentials&client_id=\(clientID)&client_secret=\(clientSecret)"
        let request = HTTPRequest(url: URL(string: "https://api.soundcloud.com/oauth2/token")!,
                                  method: .post,
                                  headers: ["Content-Type": "application/x-www-form-urlencoded"],
                                  body: Data(body.utf8))
        let response = try await HTTPRetry.send(request, via: transport, sleeper: sleeper)
        guard let root = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let token = root["access_token"] as? String else { throw HTTPError.malformedResponse }
        await tokens.set(token)
        return token
    }

    public func search(_ query: String, limit: Int = 20) async throws -> [SoundCloudTrack] {
        let token = try await authenticate()
        var components = URLComponents(string: "https://api.soundcloud.com/tracks")!
        components.queryItems = [URLQueryItem(name: "q", value: query),
                                 URLQueryItem(name: "limit", value: String(limit)),
                                 URLQueryItem(name: "access", value: "playable,preview")]
        let request = HTTPRequest(url: components.url!,
                                  headers: ["Authorization": "OAuth \(token)",
                                            "accept": "application/json; charset=utf-8"])
        let response = try await HTTPRetry.send(request, via: transport, sleeper: sleeper)
        return Self.parse(response.body)
    }

    /// The 30-second preview, as bytes. Never written to the app's own storage — BPM-04 says
    /// the audio is not retained, and the surest way to honour that is never to own a file.
    public func preview(of trackID: Int) async throws -> Data {
        let token = try await authenticate()
        let request = HTTPRequest(url: URL(string: "https://api.soundcloud.com/tracks/\(trackID)/stream")!,
                                  headers: ["Authorization": "OAuth \(token)"])
        return try await HTTPRetry.send(request, via: transport, sleeper: sleeper).body
    }

    static func parse(_ data: Data) -> [SoundCloudTrack] {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            guard let id = row["id"] as? Int, let title = row["title"] as? String else { return nil }
            // SoundCloud reports duration in MILLISECONDS. Reading it as seconds would make
            // every upload a four-hour epic and the duration bound would reject everything.
            let milliseconds = (row["duration"] as? Double) ?? 0
            let username = ((row["user"] as? [String: Any])?["username"] as? String) ?? ""
            return SoundCloudTrack(id: id, title: title, username: username,
                                   seconds: milliseconds / 1000)
        }
    }
}

/// BPM-03's result selection, kept apart from the client so it can be measured without a
/// network: the 79-minute DJ mix is a SCORING failure, not a transport failure.
public enum SoundCloudMatcher {
    /// Accepted above this. Set at the confirmation-band floor: below it the pair genuinely
    /// does not look like the record, and analysing the wrong audio is worse than no BPM.
    public static let acceptThreshold = 0.6

    public static func score(_ candidate: SoundCloudTrack, artist: String, title: String) -> Double {
        // The uploader's name is often not the artist ("Upnow #1" uploading Tory Lanez) and the
        // artist is often in the TITLE instead, so both fields are searched as one haystack.
        let haystack = candidate.username + " " + candidate.title
        return 0.4 * MatchScoring.containment(of: artist, in: haystack)
            + 0.6 * MatchScoring.containment(of: title, in: haystack)
    }

    /// The best plausible candidate, or nil.
    public static func best(among candidates: [SoundCloudTrack], artist: String, title: String,
                            expectedSeconds: Double? = nil) -> (track: SoundCloudTrack, score: Double)? {
        var winner: (SoundCloudTrack, Double)?
        for candidate in candidates
        where MatchScoring.durationPlausible(candidateSeconds: candidate.seconds,
                                             expectedSeconds: expectedSeconds) {
            let value = score(candidate, artist: artist, title: title)
            if value > (winner?.1 ?? 0) { winner = (candidate, value) }
        }
        guard let winner, winner.1 >= acceptThreshold else { return nil }
        return (track: winner.0, score: winner.1)
    }
}
