import CoreGraphics

public struct TextObservation: Sendable, Hashable {
    public let text: String
    public let boundingBox: CGRect      // normalized [0,1], top-left origin per platform OCR convention
    public let confidence: Float
    public let baselineAngle: Double    // radians; Phase 3 clusters on this

    public init(text: String, boundingBox: CGRect, confidence: Float, baselineAngle: Double) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.baselineAngle = baselineAngle
    }
}
