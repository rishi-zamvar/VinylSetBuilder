import Foundation

/// One thing a database offered as an answer. Deliberately flat and `Codable`: it is what the
/// gate harnesses serialise and what the cache stores.
public struct ReleaseCandidate: Sendable, Hashable, Codable {
    public let artist: String
    public let title: String
    public let catalogueNumber: String?
    public let label: String?
    public let format: String?
    public let year: Int?
    /// `discogs` or `musicbrainz`. Kept because a summary that cannot say WHERE an answer came
    /// from cannot report which rung of the ladder is carrying the work.
    public let source: String

    public init(artist: String, title: String, catalogueNumber: String? = nil,
                label: String? = nil, format: String? = nil, year: Int? = nil, source: String) {
        self.artist = artist
        self.title = title
        self.catalogueNumber = catalogueNumber
        self.label = label
        self.format = format
        self.year = year
        self.source = source
    }
}
