import Foundation

public struct VinylEntry: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public var capturedAt: Date
    public var photoRefs: [String]       // D9: scalar array, order preserved as inserted
    public var sidesScanned: Set<Side>
    public var candidates: [Track]
    public var position: Int             // D9: order within its crate
    /// SEG-03. The number printed on the record, canonical and space-free: `TYME012`.
    /// A stronger resolution key than artist-plus-title, which is why it is kept rather than
    /// filtered away as noise.
    public var catalogueNumber: String?

    public init(id: UUID = UUID(), capturedAt: Date = .now, photoRefs: [String] = [],
                sidesScanned: Set<Side> = [], candidates: [Track] = [], position: Int = 0,
                catalogueNumber: String? = nil) {
        self.id = id
        self.capturedAt = capturedAt
        self.photoRefs = photoRefs
        self.sidesScanned = sidesScanned
        self.candidates = candidates
        self.position = position
        self.catalogueNumber = catalogueNumber
    }

    public var orderedCandidates: [Track] { candidates.sorted { $0.position < $1.position } }

    /// Best-effort display name for the vinyl: first resolved candidate, else "Vinyl N".
    public var label: String {
        orderedCandidates.first(where: { $0.resolutionState == .resolved })?.displayName
            ?? "Vinyl \(position + 1)"
    }
}
