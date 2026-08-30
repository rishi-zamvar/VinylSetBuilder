import Foundation

/// What one photograph yielded (OCR-01).
///
/// The orientation travels with the observations because the platform reader returns
/// coordinates in the ORIGINAL, UNROTATED buffer even when it is told the orientation
/// (research/OCR-SPIKE.md, Finding 3). Dropping it here would leave the segmenter guessing,
/// and OCR-02 exists precisely so nobody has to guess.
public struct RecognizedSleeve: Sendable, Equatable {
    /// Every reading, at every confidence. The trusted tier is SEG-08's decision to make and
    /// OCR-04 renders the rest on screen so a bad read can be seen.
    public let observations: [TextObservation]
    public let orientation: PhotoOrientation

    public init(observations: [TextObservation], orientation: PhotoOrientation) {
        self.observations = observations
        self.orientation = orientation
    }
}

/// OCR-01 — the seam the real reader plugs into.
///
/// Core declares it and never implements it: text recognition needs a framework Core is
/// structurally forbidden from linking (SETUP-02), so the implementation lives in the app
/// target. That is the whole point of the seam.
public protocol TextRecognizing: Sendable {
    /// Read one photograph. `async` because OCR-05 requires this off the main thread; the
    /// caller's actor is never blocked.
    func recognise(imageAt url: URL) async throws -> RecognizedSleeve
}
