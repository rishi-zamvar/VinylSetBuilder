import Foundation

/// SEQ-11: one row per track that made the running order.
public struct SequencedRow: Identifiable, Sendable, Hashable {
    public let id: UUID              // the Track's id
    public let vinylID: UUID
    public let indexLabel: String    // "1", "2", ... — one-based
    public let title: String         // Track.displayName
    public let badges: TrackBadges
}

/// SEQ-07: one row per vinyl that did NOT make the running order — unresolved and
/// excluded share this single row type. D7: there is no second, differently-named row.
public struct NotIncludedRow: Identifiable, Sendable, Hashable {
    public let id: UUID              // the vinylID
    public let label: String         // VinylEntry.label
    public let reason: String        // V19: the TERMINAL cause, not the last rung touched
    public let badges: TrackBadges   // the representative candidate, or placeholders

    /// **V19, the structural half.** The candidate this row is *about* — the one whose badges
    /// are shown, whose tempo the exclusion concerns, and the one MAN-05's sheet opens on.
    ///
    /// Before this existed, `badges` was derived from the candidate with the highest known BPM
    /// while `reason` was derived from the first candidate carrying any failure note. On a
    /// multi-candidate record those are two different tracks, which is how a row came to show
    /// 136 BPM and 4B next to "no SoundCloud upload matched". One representative, chosen once,
    /// makes that class of contradiction unconstructible rather than merely fixed.
    ///
    /// `nil` only when the record carries no candidate lines at all — there is then nothing to
    /// badge, nothing to blame and nothing to edit.
    public let trackID: UUID?
}

/// A `SequenceResult` projected into rows a screen can render. Pure function of
/// (SequenceResult, Crate) — no view is instantiated to test this.
public struct CrateRows: Sendable, Hashable {
    public let sequenced: [SequencedRow]
    public let notIncluded: [NotIncludedRow]      // D7: ONE bucket. There is no second array.

    public var showsNotIncludedSection: Bool { !notIncluded.isEmpty }
    public var notIncludedHeader: String { "Not in the set (\(notIncluded.count))" }

    public static let empty = CrateRows(sequenced: [], notIncluded: [])

    public static func make(result: SequenceResult, crate: Crate) -> CrateRows {
        let sequenced = result.sequence.enumerated().map { index, track in
            SequencedRow(id: track.id, vinylID: track.vinylID, indexLabel: String(index + 1),
                         title: track.displayName, badges: TrackBadges(track: track))
        }

        let vinylsByID = Dictionary(uniqueKeysWithValues: crate.vinyls.map { ($0.id, $0) })
        let notIncluded = result.notIncluded.compactMap { entry -> NotIncludedRow? in
            guard let vinyl = vinylsByID[entry.vinylID] else { return nil }   // stale ID: skip, don't trap
            // ONE candidate, chosen once, for the badges AND the reason AND the edit target.
            let representative = Self.representative(of: vinyl)
            return NotIncludedRow(
                id: entry.vinylID,
                label: vinyl.label,
                reason: Self.reason(for: vinyl, representative: representative,
                                    tolerance: crate.bpmTolerance, sequencerSaid: entry.reason),
                badges: representative.map(TrackBadges.init(track:))
                    ?? TrackBadges(bpm: nil, camelot: nil),
                trackID: representative?.id)
        }

        let rows = CrateRows(sequenced: sequenced, notIncluded: notIncluded)
        assert(rows.invariantHolds(tolerance: crate.bpmTolerance),
               "V19 INVARIANT BROKEN: a not-included row shows a BPM badge but does not name the "
               + "tempo window — " + rows.invariantViolations(tolerance: crate.bpmTolerance)
                   .joined(separator: "; "))
        return rows
    }

    /// **V19's invariant, executable.** `bpm != nil` implies the tempo-window sentence: if the
    /// app knows a record's tempo, the only honest thing left to say about its exclusion is that
    /// the tempo does not fit. Every other sentence is about *not knowing* something.
    ///
    /// Checked by `assert` on every build of every row set, so a regression trips inside the
    /// test suite and inside a debug run of the app itself — not months later in a screenshot,
    /// which is how V19 was actually found.
    func invariantViolations(tolerance: Double) -> [String] {
        notIncluded
            .filter { $0.badges.bpm != TrackBadges.placeholder }
            .filter { $0.reason != ExclusionReason.outsideWindow(tolerance: tolerance) }
            .map { "\($0.label) [\($0.badges.bpm)] says '\($0.reason)'" }
    }

    func invariantHolds(tolerance: Double) -> Bool {
        invariantViolations(tolerance: tolerance).isEmpty
    }

    /// **V19 — the terminal cause, in strict precedence.** BPM-07 on screen.
    ///
    /// The ladder only ever knows why a tempo is *missing*. When one is present the ladder's
    /// sentence is stale by definition, and printing it is what made a 136 BPM record claim no
    /// SoundCloud upload had matched. Evaluated 2 → 3 → 4 → 1:
    ///
    ///   2. a tempo is known anywhere on the record → the window is the terminal cause, and it
    ///      is derived here from the crate's own tolerance rather than trusted from upstream,
    ///      so the invariant holds by construction and not by the sequencer's good behaviour
    ///   3. no candidate carries both an artist and a title → nothing was ever lookup-able. A
    ///      record with no candidate lines at all lands here too, which is correct
    ///   4. identified, and a rung wrote down why the audio route came up empty → its words
    ///   1. identified, no tempo, nothing recorded → the sequencer's generic sentence stands
    ///
    /// The ledger lists these 1, 2, 3, 4 "most specific first". Taken literally as a cascade
    /// that makes 3 and 4 unreachable — every case in them also has no BPM — so the order above
    /// is the one the ledger's own invariant implies. All four strings are reachable and
    /// `ExclusionReasonTests` proves it.
    private static func reason(for vinyl: VinylEntry, representative: Track?,
                               tolerance: Double, sequencerSaid: String) -> String {
        if vinyl.candidates.contains(where: { $0.bpm != nil }) {
            return ExclusionReason.outsideWindow(tolerance: tolerance)
        }
        if !vinyl.candidates.contains(where: { $0.artist != nil && $0.title != nil }) {
            return ExclusionReason.noIdentity
        }
        return representative?.failureReason
            ?? vinyl.orderedCandidates.compactMap(\.failureReason).first
            ?? sequencerSaid
    }

    /// The candidate the row is *about*: the one with the highest known tempo — that is the one
    /// the sequencer came closest to using — falling back to the first candidate so at least a
    /// key can show, falling back to nothing on a record with no lines at all.
    private static func representative(of vinyl: VinylEntry) -> Track? {
        let candidates = vinyl.orderedCandidates
        return candidates.filter { $0.bpm != nil }.max { $0.bpm! < $1.bpm! } ?? candidates.first
    }
}
