import Foundation

/// RES-03 and RES-08. Discogs identifies a record; it has no BPM field at all, which is why
/// the BPM ladder is a separate climb.
///
/// The catalogue number is the PRIMARY key and artist-plus-title is the fallback, not the
/// other way round: a white label prints a catalogue number and often nothing else, and the
/// spike read one cleanly on six of the twelve sleeves.
public struct DiscogsClient: Sendable {
    private let transport: any HTTPFetching
    private let token: String
    private let sleeper: HTTPRetry.Sleeper

    public init(transport: any HTTPFetching, token: String,
                sleeper: @escaping HTTPRetry.Sleeper = HTTPRetry.realSleeper) {
        self.transport = transport
        self.token = token
        self.sleeper = sleeper
    }

    /// RES-08. The results are filtered to those whose catalogue number IS the one asked for.
    ///
    /// This is not defensive tidying: `catno=0-44904` returns a USSR Tchaikovsky pressing as
    /// result ONE, carrying catalogue number `C 0449-0450`. Discogs treats `catno` as a fuzzy
    /// hint. Taking the first result is how a symphony ends up in a jungle set.
    public func searchByCatalogueNumber(_ catalogueNumber: String) async throws -> [ReleaseCandidate] {
        try await searchByCatalogueNumberUnfiltered(catalogueNumber)
            .filter { Self.catalogueMatches($0.catalogueNumber ?? "", catalogueNumber) }
    }

    /// Exactly what Discogs said, filter and all removed.
    ///
    /// Public because the acceptance gate uses it as its own negative control: a gate that only
    /// ever sees filtered output cannot show that the filter does anything. Run live, this
    /// returns the Tchaikovsky pressing first for `0-44904` — and that is the proof.
    public func searchByCatalogueNumberUnfiltered(_ catalogueNumber: String) async throws -> [ReleaseCandidate] {
        try await search([URLQueryItem(name: "catno", value: catalogueNumber)])
    }

    public func searchByArtistTitle(artist: String, title: String) async throws -> [ReleaseCandidate] {
        try await search([URLQueryItem(name: "artist", value: artist),
                          URLQueryItem(name: "release_title", value: title)])
    }

    private func search(_ query: [URLQueryItem]) async throws -> [ReleaseCandidate] {
        var components = URLComponents(string: "https://api.discogs.com/database/search")!
        components.queryItems = query + [URLQueryItem(name: "type", value: "release"),
                                         URLQueryItem(name: "per_page", value: "10")]
        // The token is a header, not a query item: query strings end up in proxy logs and
        // crash reports, and this repo is public.
        let request = HTTPRequest(url: components.url!,
                                  headers: ["Authorization": "Discogs token=\(token)",
                                            "User-Agent": Self.userAgent])
        let response = try await HTTPRetry.send(request, via: transport, sleeper: sleeper)
        return Self.parse(response.body)
    }

    public static let userAgent = "VinylSetBuilder/1.0 +https://github.com/rishi-zamvar"

    static func parse(_ data: Data) -> [ReleaseCandidate] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else { return [] }
        return results.compactMap { row in
            guard let combined = row["title"] as? String else { return nil }
            let (artist, title) = splitTitle(combined)
            return ReleaseCandidate(
                artist: artist,
                title: title,
                catalogueNumber: row["catno"] as? String,
                label: (row["label"] as? [String])?.first,
                format: (row["format"] as? [String])?.joined(separator: ", "),
                year: (row["year"] as? String).flatMap(Int.init) ?? row["year"] as? Int,
                source: "discogs")
        }
    }

    /// Discogs writes a release as `Artist - Title`, and a title may itself contain a dash.
    /// Only the FIRST separator divides the two.
    static func splitTitle(_ combined: String) -> (artist: String, title: String) {
        guard let range = combined.range(of: " - ") else { return ("", combined) }
        return (cleanArtist(String(combined[combined.startIndex..<range.lowerBound])),
                String(combined[range.upperBound...]).trimmingCharacters(in: .whitespaces))
    }

    /// `Abstract*` and `Nucleus (2)` are Discogs disambiguators for two artists who share a
    /// name. They are database bookkeeping, not part of anybody's name, and leaving them in
    /// costs two edits against the sleeve on every comparison.
    public static func cleanArtist(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespaces)
        if name.hasSuffix("*") { name.removeLast() }
        if let range = name.range(of: #" \(\d+\)$"#, options: .regularExpression) {
            name.removeSubrange(range)
        }
        return name.trimmingCharacters(in: .whitespaces)
    }

    /// `EMF-2029` is `EMF2029` and `CSi 006` is `CSI006`; `Tech 008-5` is NOT `TECH008`.
    /// Spacing and punctuation are noise, extra digits are a different record.
    public static func catalogueMatches(_ a: String, _ b: String) -> Bool {
        !a.isEmpty && TrackTextFilter.alphanumeric(a) == TrackTextFilter.alphanumeric(b)
    }
}
