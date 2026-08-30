import Foundation

/// What one photograph of a sleeve turned into.
///
/// The catalogue number is a FIELD, not a discarded string. `MVP-SPEC` §4 throws it away as
/// noise; the spike measured it as the strongest resolution key on the six sleeves that carry
/// one, stronger than artist-plus-title, so Phase 7 gets to spend it.
public struct LabelSegmentation: Sendable, Equatable {
    public let tracks: [Track]
    /// Canonical, space-free: `TYME012`, `TECH008`, `0-44904`.
    public let catalogueNumber: String?
    /// Distinct side names the sleeve stated, in the order they were first read: `["A", "AA"]`,
    /// `["COLD", "STEEL"]`. Empty when the sleeve stated none.
    public let sides: [String]

    public init(tracks: [Track], catalogueNumber: String? = nil, sides: [String] = []) {
        self.tracks = tracks
        self.catalogueNumber = catalogueNumber
        self.sides = sides
    }

    /// SEG-06. One flat sleeve routinely reads BOTH sides, so the honest signal for "there is
    /// probably a side you have not scanned" is having read fewer than two of them — not
    /// having taken fewer than two photographs.
    public var expectsFlipSide: Bool { sides.count < 2 }
}
