import Foundation

/// RES-04: how close is close enough, and what happens in between.
public enum MatchBand: String, Sendable, Hashable, Codable {
    case accepted, needsConfirmation, rejected
}

public enum MatchScoring {
    public static let acceptThreshold = 0.75
    public static let confirmThreshold = 0.50

    /// Strictly ABOVE 0.75 accepts. The boundary value itself asks, deliberately: 0.75 is two
    /// edits in eight characters, which is the reader's own worst accepted misread, and
    /// silently resolving on it would make the confirmation band unreachable from below.
    public static func band(_ similarity: Double) -> MatchBand {
        if similarity > acceptThreshold { return .accepted }
        if similarity >= confirmThreshold { return .needsConfirmation }
        return .rejected
    }

    /// Levenshtein ratio over the A-Z0-9 normalisation the segmenter already uses. Punctuation,
    /// case and diacritics are not differences: `the  message!` IS `The Message`.
    public static func similarity(_ a: String, _ b: String) -> Double {
        let left = TrackTextFilter.alphanumeric(a)
        let right = TrackTextFilter.alphanumeric(b)
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        let distance = Double(FuzzyMatch.distance(left, right))
        return max(0, 1 - distance / Double(max(left.count, right.count)))
    }

    /// The title carries more weight than the artist because a sleeve prints the artist once
    /// and the titles per side, and because the measured false positive — a Tchaikovsky record
    /// returned for catalogue `0-44904` — is exactly a right-shaped title with a wrong artist.
    public static func pairSimilarity(artist: String, title: String,
                                      candidateArtist: String, candidateTitle: String) -> Double {
        0.4 * similarity(artist, candidateArtist) + 0.6 * similarity(title, candidateTitle)
    }

    /// The duration sanity bound. Measured failure: a **79-minute DJ mix** came back as the
    /// second hit for a correct artist query. Taking the first plausible hit without this is
    /// how a set gets a 79-minute record in it.
    ///
    /// Absolute bounds of 30 s and 15 min apply even with nothing to compare against — below
    /// the first is a snippet, above it is a mix.
    public static func durationPlausible(candidateSeconds: Double, expectedSeconds: Double?) -> Bool {
        guard candidateSeconds >= 30, candidateSeconds <= 900 else { return false }
        guard let expected = expectedSeconds, expected > 0 else { return true }
        let ratio = candidateSeconds / expected
        return ratio >= 0.5 && ratio <= 2.0
    }
}
