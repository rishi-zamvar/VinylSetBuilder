import Foundation

/// **PERS-01's measuring instrument.** Every field of every crate, vinyl and track as one
/// canonical line, so "the crate survived being killed" is settled by `diff` returning zero
/// differing lines rather than by somebody looking at a screen and being satisfied.
///
/// Three properties earn this its own type rather than a `JSONEncoder` call:
///
/// 1. **Deterministic.** `Crate.selectedTrackByVinyl` is a dictionary and `VinylEntry.sidesScanned`
///    is a `Set`; both iterate in an order that is not stable across processes, so a JSON dump of
///    the same value twice can differ in line order and a diff would report changes that are not
///    changes. Everything unordered here is sorted before it is printed.
/// 2. **One field per line.** "Field-by-field diff == 0" needs the diff's unit to BE a field. A
///    single-line JSON blob answers "did anything change" and nothing else.
/// 3. **Order is data.** Crates, vinyls and tracks are printed in the order they are stored AND
///    carry their `position`, so losing the array order and losing the ordering field are two
///    different diffs rather than one indistinguishable one. That distinction is the whole point
///    of PERS-02 — an ordered relationship is not to be trusted, so both halves get checked.
public enum CrateDump {
    public static func lines(_ crates: [Crate]) -> [String] {
        crates.enumerated().flatMap { index, crate in crateLines(crate, prefix: "c\(index)") }
    }

    public static func text(_ crates: [Crate]) -> String {
        lines(crates).joined(separator: "\n") + "\n"
    }

    private static func crateLines(_ crate: Crate, prefix: String) -> [String] {
        var out = [
            "\(prefix) id=\(crate.id.uuidString)",
            "\(prefix) name=\(escape(crate.name))",
            "\(prefix) createdAt=\(stamp(crate.createdAt))",
            "\(prefix) tolerance=\(number(crate.bpmTolerance))",
            "\(prefix) manualOrder=\(crate.manualOrder.map { $0.map(\.uuidString).joined(separator: "|") } ?? "-")",
            "\(prefix) vinylCount=\(crate.vinyls.count)",
        ]
        // Sorted by key: a dictionary's own iteration order is not stable between processes, and
        // this file is compared BETWEEN PROCESSES. CRATE-07's per-crate selection is exactly the
        // thing PERS-01 must prove survived, so it cannot be left to chance.
        for (vinylID, trackID) in crate.selectedTrackByVinyl.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            out.append("\(prefix) selected \(vinylID.uuidString)=\(trackID.uuidString)")
        }
        for (index, vinyl) in crate.vinyls.enumerated() {
            out += vinylLines(vinyl, prefix: "\(prefix) v\(index)")
        }
        return out
    }

    private static func vinylLines(_ vinyl: VinylEntry, prefix: String) -> [String] {
        var out = [
            "\(prefix) id=\(vinyl.id.uuidString)",
            "\(prefix) position=\(vinyl.position)",
            "\(prefix) capturedAt=\(stamp(vinyl.capturedAt))",
            "\(prefix) catalogue=\(vinyl.catalogueNumber.map(escape) ?? "-")",
            "\(prefix) sides=\(vinyl.sidesScanned.map(\.rawValue).sorted().joined(separator: "|"))",
            "\(prefix) photos=\(vinyl.photoRefs.map(escape).joined(separator: "|"))",
            "\(prefix) candidateCount=\(vinyl.candidates.count)",
        ]
        // PERS-03: EVERY candidate, selected or not. The sequencer needs all of them on every
        // re-run, so a store that quietly kept only the selected one would still look right on
        // screen and be wrong the moment a record was added.
        for (index, track) in vinyl.candidates.enumerated() {
            out += trackLines(track, prefix: "\(prefix) t\(index)")
        }
        return out
    }

    private static func trackLines(_ track: Track, prefix: String) -> [String] {
        [
            "\(prefix) id=\(track.id.uuidString)",
            "\(prefix) vinylID=\(track.vinylID.uuidString)",
            "\(prefix) position=\(track.position)",
            "\(prefix) side=\(track.side.rawValue)",
            "\(prefix) raw=\(escape(track.rawOCRText))",
            "\(prefix) artist=\(track.artist.map(escape) ?? "-")",
            "\(prefix) title=\(track.title.map(escape) ?? "-")",
            "\(prefix) bpm=\(track.bpm.map(number) ?? "-")",
            "\(prefix) camelot=\(track.camelot.map(escape) ?? "-")",
            "\(prefix) confidence=\(number(track.matchConfidence))",
            "\(prefix) state=\(track.resolutionState.rawValue)",
            "\(prefix) failure=\(track.failureReason.map(escape) ?? "-")",
        ]
    }

    /// A newline inside a track line would split one field across two diff lines and make the
    /// count meaningless. OCR text routinely contains them.
    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    /// Fixed precision and a fixed locale: a device set to a comma decimal separator would
    /// otherwise diff against the same number written on a different launch.
    private static func number(_ value: Double) -> String {
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func stamp(_ date: Date) -> String {
        number(date.timeIntervalSince1970)
    }
}
