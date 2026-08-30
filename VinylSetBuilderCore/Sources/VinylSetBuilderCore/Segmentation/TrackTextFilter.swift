import Foundation

/// One side of a record, as the sleeve names it: `A`, `AA`, `COLD`, `ONE`.
public struct SideMarker: Sendable, Hashable {
    /// Normalised — uppercase, folded, no punctuation.
    public let name: String
    /// Whatever followed the marker on the same line, normalised. Often empty: `SIDE A` is a
    /// header, `A: High Down` is a header and a title at once.
    public let title: String

    public init(name: String, title: String) {
        self.name = name
        self.title = title
    }
}

/// SEG-03, SEG-04, SEG-05 and SEG-08 — deciding what a string off a sleeve actually IS.
///
/// Every pattern here answers a string the spike measured. Nothing is speculative: if the
/// twelve photographs never produced it, it is not filtered for.
public enum TrackTextFilter {
    /// SEG-08. The spike measured confidence as effectively binary — 1.00, 0.50, 0.30 and
    /// nothing between — so this is a tier, not a threshold, and a fractional cut-off would be
    /// inventing precision the reader does not have.
    public static func isTrusted(_ observation: TextObservation) -> Bool {
        observation.confidence >= 1.0
    }

    /// Uppercased, diacritics folded. `Invocación` and `Oríginal` have to compare as ASCII.
    public static func normalised(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                     locale: nil)
            .uppercased()
    }

    /// Normalised, then reduced to A–Z and 0–9. This is the form lengths are measured in and
    /// the form `FuzzyMatch` compares.
    public static func alphanumeric(_ text: String) -> String {
        normalised(text).filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    // MARK: - SEG-03: noise

    /// True for anything that is demonstrably not a track line.
    ///
    /// The four-character floor is load-bearing and is four rather than three because `Zzz.` —
    /// the price-sticker fragment that titled a record for the whole of Act I, defect V12 — is
    /// three. It also removes the `ick` / `uck` shards IMG_0508 produces around `Da Lick`.
    public static func isNoise(_ text: String) -> Bool {
        let normal = normalised(text)
        let letters = alphanumeric(text)
        if letters.count < 4 { return true }
        if letters.allSatisfy(\.isNumber) { return true }
        if text.contains(/[$€£¥]/) { return true }                       // a price tag
        if normal.contains(/[0-9]+[.,][0-9]{2}/) { return true }         // 6.00, 9.73, 10.00
        if normal.contains(/[0-9]\s*%/) { return true }
        if normal.contains(/WWW\.|\.CO\.UK|\.COM|HTTP|@/) { return true }
        if normal.contains(/^[0-9]{1,2}"/) { return true }               // 12" — a format mark
        if letters.count <= 4, hasTrebledCharacter(letters) { return true }
        // Sleeve furniture. Label names sit here too: a record's own label is printed on every
        // copy and is never one of its tracks. One alternation rather than an array of Regex,
        // because Regex is not Sendable and a stored array of them cannot be a static let.
        return normal.contains(
            /MADE IN|\bENGLAND\b|PUBLISHED BY|WRITTEN\s*AND\s*PRODUCED|ALL RIGHTS|\bRPM\b/)
            || normal.contains(
            /\bEMAIL\b|RECORDINGS|RECORDS|\bMUSIC\b|\bTRACKS\b|\bALBUM\b|EXCLUSIVE|IMPORT/)
            || normal.contains(/\bJUNGLE\b|DRUM\s*[+N]?\s*BASS|DRUMBASS/)
    }

    /// `Zzz`. Three of the same letter in a row inside a SHORT string is a sticker artefact
    /// or a scanner stutter. The length bound is not decoration: `AAA: Strange Nat ure` is
    /// IMG_0503's B-side, and without it the trebled-A side marker is filtered as junk.
    private static func hasTrebledCharacter(_ letters: String) -> Bool {
        let characters = Array(letters)
        guard characters.count >= 3 else { return false }
        for index in 2..<characters.count
        where characters[index] == characters[index - 1] && characters[index] == characters[index - 2] {
            return true
        }
        return false
    }

    // MARK: - SEG-03: catalogue numbers, extracted and KEPT

    /// The stronger resolution key than artist-plus-title, and the spec's instinct to throw it
    /// away is backwards — the spike read one cleanly on six of the twelve sleeves.
    ///
    /// Three letters minimum, deliberately. Two would swallow `JA22`, which is IMG_0502's
    /// misread *title*.
    public static func catalogueNumber(in text: String) -> String? {
        let normal = normalised(text)
        if let match = normal.firstMatch(of: /\b([A-Z]{3,6}\s?[0-9]{2,4})\b/) {
            return String(match.1).replacingOccurrences(of: " ", with: "")
        }
        if let match = normal.firstMatch(of: /\b([0-9]-[0-9]{4,6})\b/) {
            return String(match.1)
        }
        return nil
    }

    // MARK: - SEG-04: side markers

    /// Jungle and drum'n'bass twelves use `A`/`AA`, white labels invent their own
    /// (`COLD SIDE:` / `STEEL SIDE:`), and the reader misreads `Side One` as `Gide One`. All of
    /// that is in the twelve fixtures, so all of it is here.
    public static func sideMarker(in text: String) -> SideMarker? {
        let normal = normalised(text).trimmingCharacters(in: .whitespaces)

        // A: title   AA: title   B. title
        if let match = normal.firstMatch(of: /^(A{1,3}|B{1,2})\s*[:.]\s*(.*)$/) {
            return SideMarker(name: String(match.1), title: trimmed(match.2))
        }
        // A "Dragstar"  — the quote is the separator
        if let match = normal.firstMatch(of: /^(A{1,3}|B{1,2})\s+(["'].*)$/) {
            return SideMarker(name: String(match.1), title: trimmed(match.2))
        }
        // COLD SIDE: WIDE OPBY   STEELSIDE
        if let match = normal.firstMatch(of: /^([A-Z]{3,10})\s?SIDE\s*[:.]?\s*(.*)$/) {
            return SideMarker(name: String(match.1), title: trimmed(match.2))
        }
        // SIDE A, SIDE ONE — and Gide One, which is what the reader actually returned.
        if let match = normal.firstMatch(of: /^(\S+)\s+(A|B|ONE|TWO)\b\s*[:.]?\s*(.*)$/),
           FuzzyMatch.isClose(alphanumeric(String(match.1)), "SIDE") {
            return SideMarker(name: String(match.2), title: trimmed(match.3))
        }
        return nil
    }

    private static func trimmed(_ value: Substring) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: " /-\"'"))
    }

    // MARK: - SEG-05: version qualifiers

    /// `(VIP)`, `(Remix)`, `(Dub)` and their unbracketed cousins attach to the track above
    /// rather than starting a new one.
    ///
    /// `MIX` and `VERSION` match as substrings because the reader returns `Versionk` and
    /// `Mixes`. `DUB`, `VIP` and `EDIT` need word boundaries, or `DUBTRACK` — a real title on
    /// IMG_0505 — would be swallowed by its own first three letters.
    public static func isVersionQualifier(_ text: String) -> Bool {
        let normal = normalised(text)
        if normal.starts(with: "(") || normal.starts(with: "[") { return true }
        return normal.contains(/MIX|VERSION|\bDUB\b|\bVIP\b|\bEDIT\b|INSTRUMENTAL/)
    }
}
