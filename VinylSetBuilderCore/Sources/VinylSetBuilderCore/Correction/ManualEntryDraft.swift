import Foundation

/// **MAN-01, MAN-02 and MAN-03 as a value.** The sheet that renders this holds no rules; every
/// decision below was made and tested here.
///
/// Hand entry is not a fallback in this app. Phase 7 measured the bundled tier-0 corpus at
/// **0 of 35** against this collection — it is the owner's house library and this is a crate of
/// jungle twelves, so the two share nothing — and the artist-plus-title rung produces confident
/// wrong answers on records with no catalogue number. The last end-to-end run put **8 of 12**
/// records outside the set. This screen is therefore used more often than the camera is, and it
/// is designed for the twelfth use of an evening: **one tap per operation, no dialogs, no modes,
/// and no field that starts empty.**
public struct ManualEntryDraft: Sendable, Equatable {
    /// **The genre centre.** Not a magic number: this app only ever sees jungle and drum & bass,
    /// where 174 is the floor tempo of essentially every record in the crate. It is used only
    /// when a crate is brand new and there is genuinely nothing to interpolate from.
    /// ponytail: one constant, not a preference. Make it settable when a second genre exists.
    public static let genreCentreBPM: Double = 174

    /// MAN-02. The whole wheel as data — 24 codes, minor block then major block, so the sheet
    /// renders a grid and a key is **one tap**, comfortably inside the two-tap bound. Typing
    /// "11B" on a phone keyboard is three keystrokes and a chance to type "1B" by mistake, and
    /// a wrong key is worse than no key because the sequencer cannot know it is wrong.
    public static let camelotGrid: [String] =
        (1...12).map { "\($0)A" } + (1...12).map { "\($0)B" }

    public let trackID: UUID
    public var artist: String
    public var title: String
    /// Held as text, not `Double?`, because it is bound straight to a field and a half-typed
    /// "17" must not round-trip into 17 BPM behind the typist's back.
    public var bpmText: String
    public var camelot: String?

    public init(track: Track, neighbours: [Track]) {
        trackID = track.id
        artist = track.artist ?? ""
        title = track.title ?? ""
        bpmText = Self.format(Self.prefillBPM(for: track, neighbours: neighbours))
        // Normalised through the same parser the badge uses, so a key that came off a database
        // as "Am" shows as SELECTED in the grid rather than as an empty grid over a filled row.
        camelot = Camelot.parse(track.camelot)?.code
    }

    /// **MAN-03.** In precedence: the record's own tempo, then the **median** of every tempo the
    /// crate already knows, then the genre centre.
    ///
    /// Median rather than mean, and that is the whole reason this is a function rather than an
    /// average: one 87 BPM half-time read drags a mean out of the genre entirely. Every
    /// neighbour is folded first for the same reason — `BPMRules.fold` is what makes an 87 read
    /// mean 174, and interpolating from unfolded reads would offer a number this collection
    /// never contains.
    public static func prefillBPM(for track: Track, neighbours: [Track]) -> Double {
        if let own = track.bpm { return BPMRules.fold(own) }
        let known = neighbours.compactMap(\.bpm).map(BPMRules.fold).sorted()
        guard !known.isEmpty else { return genreCentreBPM }
        // The lower of the two middles on an even count — deterministic, so the same crate always
        // offers the same number however the neighbours happen to arrive.
        return known[(known.count - 1) / 2]
    }

    /// The −1 / +1 controls. One tap moves the tempo by one, which is the correction actually
    /// made in practice; typing is for when the prefill is nowhere near.
    public mutating func nudgeBPM(by delta: Double) {
        let base = Double(bpmText) ?? Self.genreCentreBPM
        bpmText = Self.format(max(1, base + delta))
    }

    /// Fold the draft back onto the track, marked `.manual` — **the only place that mark is
    /// set.** MAN-04's protection keys on it, so anything else setting it would be granting
    /// permanence to a value nobody typed.
    public func applied(to track: Track) -> Track {
        var edited = track
        edited.artist = Self.cleaned(artist)
        edited.title = Self.cleaned(title)
        // D6, applied here exactly as the badge and the sequencer apply it: a typed 87 is a 174
        // record. Without this the badge would render 174 while the gate used 87 and the screen
        // would contradict the running order.
        edited.bpm = Double(bpmText.trimmingCharacters(in: .whitespaces)).map(BPMRules.fold)
        edited.camelot = camelot.flatMap { Camelot.parse($0)?.code }
        edited.resolutionState = .manual
        // A rung's note about why it could not find a tempo is stale the moment a person
        // supplies one — and it would otherwise still be printed in the not-included bucket.
        edited.failureReason = nil
        return edited
    }

    private static func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// "174" not "174.0", "172.5" as itself — the same shape `TrackBadges` prints, so the field
    /// and the badge never disagree about the same number.
    private static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(Int(rounded.rounded()))
            : String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }
}
