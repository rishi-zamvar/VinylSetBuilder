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

    /// RES-01/RES-02 — a record nothing has put a name to yet, and therefore the only kind the
    /// resolver has any work to do on.
    ///
    /// **Identity, not `resolutionState`.** A hand-entered record and a fixture record both
    /// carry an artist and a title while sitting at `.pending`, and re-resolving those would
    /// spend quota re-deriving what is already known — and would overwrite a correction the
    /// owner typed, which RES-06 forbids. A record with no candidate lines at all is not
    /// resolvable either: there is nothing to look up.
    public var needsResolution: Bool {
        !candidates.isEmpty && candidates.allSatisfy { $0.artist == nil || $0.title == nil }
    }

    /// Best-effort display name for the vinyl: first resolved candidate, else "Vinyl N".
    public var label: String {
        orderedCandidates.first(where: { $0.resolutionState == .resolved })?.displayName
            ?? "Vinyl \(position + 1)"
    }
}
