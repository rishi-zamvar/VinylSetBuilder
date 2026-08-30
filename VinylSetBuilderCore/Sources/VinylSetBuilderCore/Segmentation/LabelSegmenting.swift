import Foundation

public protocol LabelSegmenting: Sendable {
    /// Pure geometry and text rules. No I/O, no image.
    ///
    /// Returns a `LabelSegmentation` rather than bare tracks because a sleeve says more than
    /// its track list: the catalogue number is the strongest resolution key on it (SEG-03) and
    /// the stated sides are what SEG-06 infers a flip side from. Returning `[Track]` threw both
    /// away at this boundary.
    func segment(_ observations: [TextObservation], vinylID: UUID, side: Side) -> LabelSegmentation
}
