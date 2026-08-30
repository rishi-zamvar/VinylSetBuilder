import CoreGraphics
import Foundation

/// The EXIF orientation of a photograph, as the platform reports it.
///
/// Only the two values this project has ever met carry behaviour: `.up`, and `.right`, which is
/// what all twelve of the owner's fixtures are. The rest are declared so a photograph carrying
/// one is not silently mistaken for `.up` — `ObservationGeometry` refuses them by name.
public enum PhotoOrientation: UInt32, Sendable, Hashable, CaseIterable {
    case up = 1, upMirrored = 2, down = 3, downMirrored = 4
    case leftMirrored = 5, right = 6, rightMirrored = 7, left = 8
}

/// **OCR-02 lives here, and only here.**
///
/// The platform text reader returns normalised coordinates in the ORIGINAL, UNROTATED buffer
/// even when it is handed an orientation — the spike measured this (research/OCR-SPIKE.md,
/// Finding 3). Every sleeve line therefore comes back at about -90 degrees. This enum is the
/// single documented place where that is corrected. Nothing downstream rotates anything.
public enum ObservationGeometry {
    /// Rotate one observation out of the raw buffer frame into upright display space.
    ///
    /// For `.right` (EXIF 6) the buffer must be turned 90 degrees to be displayed, which in the
    /// bottom-left-origin normalised frame is the point map `(x, y) -> (1 - y, x)` and the
    /// direction map `(dx, dy) -> (-dy, dx)`, i.e. `angle + 90 degrees`.
    ///
    /// Any other orientation is returned untouched: inventing a transform for a case the corpus
    /// has never produced would be code no measurement covers. If a photograph ever arrives
    /// mirrored or upside down, this is the one function to extend.
    public static func upright(_ observation: TextObservation,
                               orientation: PhotoOrientation) -> TextObservation {
        guard orientation == .right else { return observation }
        let box = observation.boundingBox
        return TextObservation(
            text: observation.text,
            boundingBox: CGRect(x: 1 - box.maxY, y: box.minX,
                                width: box.height, height: box.width),
            confidence: observation.confidence,
            baselineAngle: observation.baselineAngle + .pi / 2)
    }

    /// The true thickness of a text line, recovered from its AXIS-ALIGNED bounding box.
    ///
    /// For text of true width `W` and cap height `H` at angle θ the reported box satisfies
    ///
    ///     w = W·|cos θ| + H·|sin θ|        h = W·|sin θ| + H·|cos θ|
    ///
    /// so `H = (h·|cos θ| - w·|sin θ|) / (cos²θ - sin²θ)`. Taking `min(w, h)` instead overstates
    /// the thickness badly for diagonal text — IMG_0505's `DUBTRACK` measures 0.061 that way
    /// against a true 0.026 — and an overstated thickness merges adjacent track lines.
    ///
    /// Within 15 degrees of the diagonal the denominator vanishes and the inversion is
    /// numerically worthless, so it falls back to `min(w, h)`. Same fallback if the algebra
    /// returns something impossible.
    public static func capHeight(width: CGFloat, height: CGFloat, angle: Double) -> CGFloat {
        let floorValue = min(width, height)
        let c = abs(cos(angle)), s = abs(sin(angle))
        let denominator = c * c - s * s
        guard abs(denominator) >= 0.15 else { return floorValue }
        let derived = (height * c - width * s) / denominator
        guard derived > 0, derived <= floorValue else { return floorValue }
        return derived
    }
}
