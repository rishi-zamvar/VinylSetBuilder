import CoreGraphics
import Foundation
import ImageIO
import Vision
import VinylSetBuilderCore

/// OCR-01/02/03/05 — the only file in this project that names the recognition framework.
///
/// It is deliberately thin. Everything that can be reasoned about without an image — the
/// orientation transform, the trusted tier, the noise rules, the clustering — lives in Core and
/// is unit-tested with no camera and no photographs. What is left here is the framework call.
///
/// Three things about that call are load-bearing, and all three are measured, not assumed
/// (`.planning/research/OCR-SPIKE.md`):
///
/// 1. **The EXIF orientation must be passed explicitly.** `VNImageRequestHandler(cgImage:options:)`
///    ignores it, and all twelve of the owner's fixtures are orientation 6. Passing it turned
///    `ENICATTONAPE` into `EDUCATION` and newly surfaced `SIDE A`.
/// 2. **Coordinates still come back in the original unrotated buffer.** They are handed on with
///    the orientation attached; `ObservationGeometry.upright` corrects them exactly once, in
///    Core (OCR-02). Nothing is rotated here.
/// 3. **`usesLanguageCorrection` is off.** Record titles are not English words; correction turns
///    `xtasia` into something else.
///
/// The older request type is used rather than the Swift-native `RecognizeTextRequest`
/// deliberately: the spike's measured baseline of 6 clean / 5 partial / 1 fail was produced by
/// this exact call, and Phase 6's gate is a REGRESSION gate against that baseline. Swapping the
/// reader would confound the measurement it exists to make. `RecognizeTextRequest` is available
/// at the iOS 26 target and is the right move once the baseline is re-measured under it.
public struct SleeveTextRecognizer: TextRecognizing {
    private let vocabulary: [String]

    public init(vocabulary: [String] = RecognitionVocabulary.sleeveTerms) {
        self.vocabulary = vocabulary
    }

    public func recognise(imageAt url: URL) async throws -> RecognizedSleeve {
        let vocabulary = self.vocabulary
        // OCR-05. `Task.detached` and not a plain `Task`: this project builds with
        // SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, so an inheriting task would run
        // recognition on the very actor it is trying to leave — and at ~130 ms an image, twenty
        // records would stall the shutter for nearly three seconds.
        return try await Task.detached(priority: .userInitiated) {
            try Self.read(url, vocabulary: vocabulary)
        }.value
    }

    /// Errors are typed so a caller can tell "that file is not an image" from "the reader
    /// failed", rather than reading a string.
    public enum Failure: Error, Equatable {
        case unreadableImage(URL)
    }

    private static func read(_ url: URL, vocabulary: [String]) throws -> RecognizedSleeve {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure.unreadableImage(url)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let orientation = PhotoOrientation(rawValue: rawOrientation) ?? .up

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.customWords = vocabulary                                    // OCR-03

        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up,
            options: [:])                                                   // OCR-02, half one
        try handler.perform([request])

        // Fully qualified: the recognition framework ships its OWN `TextObservation` at this
        // SDK level, and an unqualified reference here is ambiguous rather than wrong-but-working.
        let observations = (request.results ?? [])
            .compactMap { observation -> VinylSetBuilderCore.TextObservation? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            // The baseline angle comes from the observation's own bottom edge, which is the
            // only thing that survives rotation intact — the axis-aligned box does not.
            let angle = atan2(observation.bottomRight.y - observation.bottomLeft.y,
                              observation.bottomRight.x - observation.bottomLeft.x)
            return VinylSetBuilderCore.TextObservation(text: candidate.string,
                                                       boundingBox: observation.boundingBox,
                                                       confidence: candidate.confidence,
                                                       baselineAngle: angle)
        }
        return RecognizedSleeve(observations: observations, orientation: orientation)
    }
}
