import Foundation

/// CAP-03's read status, derived rather than transcribed.
///
/// Act I carried CONTEXT.md §3's hand-scored verdicts as literals in a twelve-row table, which
/// was honest while nothing in the app actually read a photograph. Phase 8 wires the real
/// reader, so the status has to be computable for a record nobody has ever scored — which is
/// every record after the owner's twelve.
///
/// The rule is one line and it is not tuned to the corpus:
///
///   - a sleeve that yielded no track line at all did not read
///   - a sleeve that yielded lines AND something to resolve them WITH — a catalogue number
///     (SEG-03, the strongest key on the sleeve) or a stated side (SEG-04) — read
///   - anything else is a partial read
///
/// The middle rung is the load-bearing one, and it is the resolver's own criterion rather than
/// a proxy for it: a sleeve with a catalogue number resolved 6 of 6 in Phase 7, and one with
/// neither key is left to the artist+title rung, which Phase 7 measured as the weakest.
public enum SleeveStatus {
    public static func status(for segmentation: LabelSegmentation) -> CaptureItemStatus {
        guard !segmentation.tracks.isEmpty else { return .unread }
        let hasResolutionKey = segmentation.catalogueNumber != nil || !segmentation.sides.isEmpty
        return hasResolutionKey ? .read : .partial
    }
}
