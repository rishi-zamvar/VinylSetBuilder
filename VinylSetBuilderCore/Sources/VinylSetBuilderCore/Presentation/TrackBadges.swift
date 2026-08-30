import Foundation

/// SEQ-11: the BPM + Camelot badge text for one track, formatted exactly once so every
/// row in the app renders the same number for the same track. Plain `String`s only —
/// Core owns no `Color`/`Font`/`Text` (D8); the app target decides how these look.
public struct TrackBadges: Sendable, Hashable {
    public static let placeholder = "—"     // U+2014 em dash — never an empty string

    public let bpm: String      // "174", "173.5", or the placeholder — never empty
    public let key: String      // "8A" or the placeholder — never empty

    public init(track: Track) {
        self.init(bpm: track.bpm, camelot: track.camelot)
    }

    public init(bpm rawBPM: Double?, camelot rawKey: String?) {
        if let rawBPM {
            // D6: the sequencer gates on the FOLDED bpm; the badge must show that same
            // number, never the raw pre-fold read, or the screen contradicts the ordering.
            let folded = BPMRules.fold(rawBPM)
            let rounded = (folded * 10).rounded() / 10
            bpm = rounded == rounded.rounded()
                ? String(Int(rounded.rounded()))
                : String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        } else {
            bpm = Self.placeholder
        }
        key = Camelot.parse(rawKey)?.code ?? Self.placeholder
    }

    /// True when either badge is a placeholder — the views dim those rather than hiding them.
    public var isIncomplete: Bool { bpm == Self.placeholder || key == Self.placeholder }
}
