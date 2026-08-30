import Foundation

/// OCR-04: one recognised text observation, ready to render. Plain `String`s only, formatted
/// exactly once — the same rule `TrackBadges` follows, so no screen re-formats a number and
/// two screens can never disagree about it.
public struct RawObservationRow: Identifiable, Sendable, Hashable {
    public let id: Int             // 1-based, reading order
    public let text: String        // the raw read, verbatim
    public let confidence: String  // "1.00" / "0.50" / "0.30"
    public let isTrusted: Bool

    public init(id: Int, text: String, confidence: String, isTrusted: Bool) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.isTrusted = isTrusted
    }
}

/// OCR-04: the recognised text for one photograph, projected into rows a screen can list.
///
/// **Nothing is sorted, filtered, deduplicated or trimmed.** The row worth looking at when a
/// record reads badly is precisely the one the pipeline discarded, so the untrusted reads stay
/// in — and the text stays exactly as it came back, because the garbling is the diagnosis.
public enum RawObservationRows {
    /// The trusted tier, measured: confidence came back as 1.00, 0.50 or 0.30 and nothing
    /// between, across all 104 observations of the owner's twelve records. It is a tier, not a
    /// fraction — 0.50 is no more trustworthy than 0.30.
    public static let trustedConfidence: Float = 1.0

    public static func make(_ observations: [TextObservation]) -> [RawObservationRow] {
        observations.enumerated().map { index, observation in
            RawObservationRow(
                id: index + 1,
                text: observation.text,
                confidence: String(format: "%.2f",
                                   locale: Locale(identifier: "en_US_POSIX"),
                                   observation.confidence),
                isTrusted: observation.confidence >= trustedConfidence
            )
        }
    }
}
