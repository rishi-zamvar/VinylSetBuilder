/// CAP-02 — the shape the viewfinder overlay draws, as pure geometry.
///
/// The measured record: the owner photographs whole 12" sleeves flat, and the die-cut label
/// occupies under a tenth of the frame. So the guide is a large square, not a small reticle.
/// The app target owns the drawing; this type owns the numbers, which is why the rule is
/// testable in milliseconds without a device.
public struct FramingGuide: Sendable, Hashable {
    /// Width over height. A 12" sleeve is square.
    public let aspectRatio: Double

    /// Inset from each side of the frame's SHORTER edge, as a fraction of that edge.
    public let insetFraction: Double

    public init(aspectRatio: Double, insetFraction: Double) {
        self.aspectRatio = aspectRatio
        self.insetFraction = insetFraction
    }

    /// How much of the shorter edge the guide spans. Sleeve-sized is > 0.6; a label-sized
    /// reticle is well under it, which is what the CAP-02 test discriminates on.
    public var edgeCoverage: Double { 1 - 2 * insetFraction }

    public static let sleeve = FramingGuide(aspectRatio: 1.0, insetFraction: 0.06)
}
