import Foundation

public protocol LabelSegmenting: Sendable {
    /// Pure geometry. No I/O. Phase 3 supplies the real implementation.
    func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> [Track]
}
