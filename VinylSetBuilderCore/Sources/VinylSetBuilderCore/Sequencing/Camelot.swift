/// The Camelot wheel: hour 1...12 plus a letter (A = minor, B = major).
/// Distance and the pitch tables are ported value-for-value from the owner's
/// working Python (walkman-dj `camelot.py`) — see SEQ-01.
public struct Camelot: Equatable, Hashable, Sendable, Codable {
    public let hour: Int      // 1...12
    public let isMinor: Bool  // A = minor, B = major

    public init?(_ code: String) {
        guard let last = code.last, last == "A" || last == "B",
              let n = Int(code.dropLast()), (1...12).contains(n) else { return nil }
        self.hour = n; self.isMinor = (last == "A")
    }

    private init(hour: Int, isMinor: Bool) {
        self.hour = hour
        self.isMinor = isMinor
    }

    public var code: String { "\(hour)\(isMinor ? "A" : "B")" }

    /// D1: flat hop count around the 12-ring, +1 for a letter change. No extra letter
    /// weighting — that is a v2 concern (SEQ2-03), not this distance.
    public func distance(to other: Camelot) -> Int {
        let d = abs(hour - other.hour)
        return min(d, 12 - d) + (isMinor == other.isMinor ? 0 : 1)
    }
}

extension Camelot {
    /// Ported verbatim from walkman-dj/src/walkman_dj/camelot.py `_MAJOR`.
    static let majorTable: [String: Int] = [
        "B": 1, "F#": 2, "Gb": 2, "Db": 3, "C#": 3, "Ab": 4, "G#": 4, "Eb": 5,
        "D#": 5, "Bb": 6, "A#": 6, "F": 7, "C": 8, "G": 9, "D": 10, "A": 11, "E": 12,
    ]
    /// Ported verbatim from `_MINOR`.
    static let minorTable: [String: Int] = [
        "Ab": 1, "G#": 1, "Eb": 2, "D#": 2, "Bb": 3, "A#": 3, "F": 4, "C": 5,
        "G": 6, "D": 7, "A": 8, "E": 9, "B": 10, "F#": 11, "Gb": 11, "Db": 12, "C#": 12,
    ]

    /// Ported `to_camelot(pitch, mode)`.
    public static func from(pitch: String, mode: String) -> Camelot? {
        let isMinor = mode.lowercased().hasPrefix("min")
        let table = isMinor ? minorTable : majorTable
        guard let hour = table[pitch] else { return nil }
        return Camelot(hour: hour, isMinor: isMinor)
    }

    /// Accepts either a Camelot code ("4A") or a musical key ("Am", "C", "F#m").
    /// This is the single entry point the sequencer and the UI both use — a stray
    /// malformed `Track.camelot` string degrades to `nil` (no badge), never a crash.
    public static func parse(_ value: String?) -> Camelot? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }

        if let code = Camelot(trimmed) { return code }

        // ponytail: bare "A" collides with an incomplete Camelot code ("A" with no hour) and
        // is rejected as garbage, while bare "B" is a genuine musical key (B major) and must
        // still resolve — this asymmetry is deliberate, not a bug. See SEQ-01 test coverage.
        if trimmed == "A" { return nil }

        var remainder = trimmed
        var isMinor = false
        for suffix in ["minor", "min", "m"] where remainder.count > suffix.count
            && remainder.lowercased().hasSuffix(suffix) {
            remainder = String(remainder.dropLast(suffix.count))
            isMinor = true
            break
        }

        let pitch = normalizeAccidental(remainder)
        let table = isMinor ? minorTable : majorTable
        guard let hour = table[pitch] else { return nil }
        return Camelot(hour: hour, isMinor: isMinor)
    }

    /// "eb" -> "Eb", "f#" -> "F#", "c" -> "C".
    private static func normalizeAccidental(_ pitch: String) -> String {
        guard let first = pitch.first else { return pitch }
        return String(first).uppercased() + pitch.dropFirst().lowercased()
    }
}
