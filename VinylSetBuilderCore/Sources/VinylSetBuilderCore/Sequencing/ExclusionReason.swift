/// **V19.** Every sentence a not-included row can print, in one place.
///
/// The defect this type exists to prevent: the reason string used to be assembled in three
/// separate layers — the sequencer, the BPM ladder and the row projection — and the row
/// projection preferred whichever of them had spoken most recently rather than whichever had
/// named the *terminal* cause. A record showing a resolved BPM and a resolved key was therefore
/// labelled "no SoundCloud upload matched", which cannot be true: it plainly matched, or those
/// badges could not exist.
///
/// SEQ-07 collapsed two sections into one *because* the reason string carries the distinction
/// between "I could not identify this" (go and type it in) and "I identified it fine, it just
/// does not fit" (widen the tolerance, or nothing). Those demand opposite responses from the
/// owner, so a wrong string is not cosmetic — it makes the bucket an undifferentiated pile and
/// takes the design decision's basis with it.
///
/// The precedence is applied in `CrateRows`; the words live here.
public enum ExclusionReason {
    /// Terminal cause 1 — identified, no tempo, and no rung recorded why. The generic fallback.
    public static let noBPM = "No BPM yet — resolve it or enter it by hand"

    /// Terminal cause 3 — no candidate on the record carries both an artist and a title, so
    /// there was never anything for the corpus or SoundCloud to be keyed on.
    public static let noIdentity = "No identity to look up"

    /// Terminal cause 4 — identity resolved, audio route came up empty. Sentence case, because
    /// it is printed in the same slot as the three sentences above it.
    public static let noSoundCloudMatch = "No SoundCloud upload matched"

    /// Terminal cause 2 — the record has a tempo and the tempo does not fit. **The only reason
    /// a row with a visible BPM badge may ever give**, and `CrateRows.make` asserts exactly that.
    ///
    /// Renders 4.0 as "4" and 4.5 as "4.5" — the sentence reads like a human wrote it. This was
    /// a private duplicate inside `BeamSearchSequencer`; there is now one definition, so the
    /// sequencer's own exclusion and the row's derived one cannot drift apart by a decimal point.
    public static func outsideWindow(tolerance: Double) -> String {
        let formatted = tolerance.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(tolerance)) : String(tolerance)
        return "No track within \(formatted) BPM of the set"
    }
}
