import Foundation

/// The free, unlimited rung — and by the project's frugality rule, therefore the rung ABOVE
/// Discogs, not below it.
///
/// Measured 2026-08-30 on the six catalogue numbers the shipped segmenter extracts:
/// MusicBrainz knew five of the six (all but `EMF2029`), for zero quota. Placing it first
/// takes five of six catalogue lookups off Discogs' 60-per-minute allowance entirely.
///
/// It needs a User-Agent and no key. It also answers `503 currently busy` freely — a live
/// probe hit that on attempt one and succeeded on attempt two — so retrying is not optional.
public struct MusicBrainzClient: Sendable {
    private let transport: any HTTPFetching
    private let sleeper: HTTPRetry.Sleeper

    public init(transport: any HTTPFetching,
                sleeper: @escaping HTTPRetry.Sleeper = HTTPRetry.realSleeper) {
        self.transport = transport
        self.sleeper = sleeper
    }

    public func searchByCatalogueNumber(_ catalogueNumber: String) async throws -> [ReleaseCandidate] {
        try await search(#"catno:"\#(catalogueNumber)""#)
    }

    public func searchByArtistTitle(artist: String, title: String) async throws -> [ReleaseCandidate] {
        try await search(#"artist:"\#(artist)" AND release:"\#(title)""#)
    }

    private func search(_ luceneQuery: String) async throws -> [ReleaseCandidate] {
        var components = URLComponents(string: "https://musicbrainz.org/ws/2/release/")!
        components.queryItems = [URLQueryItem(name: "query", value: luceneQuery),
                                 URLQueryItem(name: "fmt", value: "json"),
                                 URLQueryItem(name: "limit", value: "10")]
        let request = HTTPRequest(url: components.url!,
                                  headers: ["User-Agent": DiscogsClient.userAgent,
                                            "Accept": "application/json"])
        let response = try await HTTPRetry.send(request, via: transport, sleeper: sleeper)
        return Self.parse(response.body)
    }

    static func parse(_ data: Data) -> [ReleaseCandidate] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let releases = root["releases"] as? [[String: Any]] else { return [] }
        return releases.compactMap { row in
            guard let title = row["title"] as? String else { return nil }
            let credit = (row["artist-credit"] as? [[String: Any]])?.first?["name"] as? String
            let labelInfo = (row["label-info"] as? [[String: Any]])?.first
            return ReleaseCandidate(
                artist: credit ?? "",
                title: title,
                catalogueNumber: labelInfo?["catalog-number"] as? String,
                label: (labelInfo?["label"] as? [String: Any])?["name"] as? String,
                format: ((row["media"] as? [[String: Any]])?.first?["format"] as? String),
                // MusicBrainz dates are "2001" or "2001-06-04"; only the year is wanted.
                year: (row["date"] as? String).flatMap { Int($0.prefix(4)) },
                source: "musicbrainz")
        }
    }
}
