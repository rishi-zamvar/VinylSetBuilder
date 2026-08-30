import Foundation

/// RES-08's second half, and the reason a symphony does not end up in a jungle set.
///
/// A catalogue number is the strongest key on a white label, but it is not unique. Measured on
/// the six numbers the shipped segmenter extracts: `TECH008` names two different records on two
/// different labels, `CSI006` names two more, and Discogs answers `0-44904` with a USSR
/// Tchaikovsky pressing FIRST. Filtering to an exact catalogue-number match kills the
/// Tchaikovsky; it cannot touch the other two, because both really do carry that number.
///
/// So the sleeve itself adjudicates. A candidate is supported by the number of its own words —
/// artist, title, label — that the reader actually saw on the record, fuzzily. Nothing
/// supported by nothing is ever accepted, however confident the database sounded.
public enum SleeveCrossCheck {
    /// Words of four characters or more, uppercased, diacritics folded, ASCII alphanumerics
    /// only. Four because that is `TrackTextFilter.isNoise`'s own floor and because three-letter
    /// fragments (`THE`, `MIX`, `ONE`) match everything and therefore mean nothing.
    public static func words(_ text: String) -> Set<String> {
        let folded = TrackTextFilter.normalised(text)
        let pieces = folded.split(whereSeparator: { !($0.isASCII && ($0.isLetter || $0.isNumber)) })
        return Set(pieces.map(String.init).filter { $0.count >= 4 })
    }

    /// How many of the candidate's own words the sleeve corroborates.
    ///
    /// `FuzzyMatch.isClose` allows one edit per four characters, which is what carries
    /// `ELEMENTS` against the reader's `ELEMENTZ` and `PHUNCKATECKS` against its `INCKATECKS`.
    public static func support(for candidate: ReleaseCandidate, sleeveText: [String]) -> Int {
        let sleeve = words(sleeveText.joined(separator: " "))
        guard !sleeve.isEmpty else { return 0 }
        let claimed = words([candidate.artist, candidate.title, candidate.label ?? ""]
            .joined(separator: " "))
        return claimed.count { word in sleeve.contains(where: { FuzzyMatch.isClose(word, $0) }) }
    }

    /// The best-supported candidate, or nil when the sleeve corroborates none of them.
    ///
    /// Returning nil is the point. "Take the highest-scoring result" would still hand back
    /// Tchaikovsky when Tchaikovsky is all there is.
    public static func best(among candidates: [ReleaseCandidate],
                            sleeveText: [String]) -> (candidate: ReleaseCandidate, support: Int)? {
        // A stable max: `max(by:)` keeps the LAST maximal element, and ordering matters here
        // because a database returns its own best guess first.
        var winner: (ReleaseCandidate, Int)?
        for candidate in candidates {
            let score = support(for: candidate, sleeveText: sleeveText)
            if score > (winner?.1 ?? 0) { winner = (candidate, score) }
        }
        return winner.map { (candidate: $0.0, support: $0.1) }
    }
}
