import Foundation

/// What one photographed sleeve knows about itself, beyond its track lines.
///
/// The catalogue number is a property of the RECORD, not of a track, and it is the primary
/// resolution key — so the seam takes a whole sleeve at a time. Resolving track-by-track
/// would throw the strongest key away at the boundary, which is the same mistake
/// `LabelSegmentation` exists to avoid.
public struct SleeveContext: Sendable, Hashable {
    public let catalogueNumber: String?
    /// Everything the reader returned for this sleeve, at every confidence. The cross-check
    /// wants the widest possible corroboration, not the trusted tier only.
    public let text: [String]

    public init(catalogueNumber: String?, text: [String]) {
        self.catalogueNumber = catalogueNumber
        self.text = text
    }
}

public protocol MetadataResolving: Sendable {
    /// Every track comes back `.resolved`, `.pending` with a confidence to confirm, or
    /// `.failed` with a reason. Nothing is ever silently dropped (RES-01).
    func resolve(_ tracks: [Track], sleeve: SleeveContext) async -> [Track]
}
