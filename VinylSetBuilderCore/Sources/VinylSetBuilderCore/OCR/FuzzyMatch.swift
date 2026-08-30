import Foundation

/// Character-level tolerance for text that came off a photograph.
///
/// A reader misreads a letter or two, it does not misread a word: `WIDE OPEN` comes back as
/// `WIDE OPBY`, `SIDE ONE` as `Gide One`, `DJ KANE` as `DI KANE`. Every comparison in the
/// segmenter that has to survive that goes through here.
public enum FuzzyMatch {
    /// Levenshtein distance, two rows of state.
    public static func distance(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        let left = Array(a), right = Array(b)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }
        var previous = Array(0...right.count)
        var current = previous
        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                current[j] = min(previous[j] + 1,
                                 current[j - 1] + 1,
                                 previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1))
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }

    /// One edit per four characters, floored.
    ///
    /// The ratio is calibrated on the spike's own worst accepted read: `WIDE OPBY` for
    /// `WIDE OPEN` is two edits in eight. It is deliberately tight enough to still reject
    /// `JA22` for `JAZZ` — two edits in four — which the spike scored as a partial, not a hit.
    /// Empty never matches anything, including empty.
    public static func isClose(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return distance(a, b) <= max(a.count, b.count) / 4
    }
}
