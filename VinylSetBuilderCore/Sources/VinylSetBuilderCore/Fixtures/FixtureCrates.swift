import Foundation

/// The stub library every screen binds to. Built from fixed UUIDs and a fixed date so a
/// screenshot or bug report is reproducible across launches.
///
/// **Phase 9 changed what this is for and it is worth saying so.** Phase 1 called this "the stub
/// library until persistence exists — this file gets deleted then". It is not deleted, because
/// persistence needs a first-launch seed and a UI walk needs a known starting state it can reset
/// to. It is now the seed, not a stand-in.
public enum FixtureCrates {

    private static let fixedDate = Date(timeIntervalSince1970: 1_750_000_000)

    private static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "F19ED000-0000-0000-0000-%012d", n))!
    }

    /// The same vinyl that also appears in `secondCrate`, so CRATE-07 is visible on screen,
    /// not only in a test: two candidate tracks, selected differently in each crate.
    private static let sharedVinylTrackX = Track(id: id(900), vinylID: id(90), position: 0,
                                                  artist: "Photek", title: "Ni Ten Ichi Ryu",
                                                  bpm: 172, camelot: "8A")
    private static let sharedVinylTrackY = Track(id: id(901), vinylID: id(90), position: 1,
                                                  artist: "Photek", title: "The Hidden Camera",
                                                  bpm: 174, camelot: "9A")
    private static let sharedVinyl = VinylEntry(id: id(90), capturedAt: fixedDate,
                                                 candidates: [sharedVinylTrackX, sharedVinylTrackY],
                                                 position: 2)

    /// A crate designed so the sequenced list, the excluded bucket AND the unresolved
    /// bucket are all non-empty at the default 4.0 tolerance — otherwise the UI's hardest
    /// states are unreachable by hand and go unlooked-at.
    public static var mixedResultsCrate: Crate {
        // Two in-window candidates on one vinyl — SEQ-02's "several candidates, pick one".
        let inWindowTrackA = Track(id: id(100), vinylID: id(10), position: 0,
                                    artist: "Source Direct", title: "Snake Style", bpm: 170, camelot: "5A")
        let inWindowTrackB = Track(id: id(101), vinylID: id(10), position: 1,
                                    artist: "Source Direct", title: "The Snake", bpm: 172, camelot: "5A")
        let inWindowVinyl = VinylEntry(id: id(10), capturedAt: fixedDate,
                                        candidates: [inWindowTrackA, inWindowTrackB], position: 0)

        // Outside the default 4.0 window relative to the 170/172 vinyl above.
        let excludedTrack = Track(id: id(200), vinylID: id(20), position: 0,
                                   artist: "Dillinja", title: "Angels Fell", bpm: 178, camelot: "6A")
        let excludedVinyl = VinylEntry(id: id(20), capturedAt: fixedDate,
                                        candidates: [excludedTrack], position: 1)

        // No BPM at all — the unresolved bucket.
        // V5: position 3, not 2. `sharedVinyl` below already holds 2, and `VinylEntry.label`
        // falls back to "Vinyl \(position + 1)", so both rendered "Vinyl 3". Only one of the
        // two ever reaches the not-included bucket, which is why no photograph caught it.
        // `FixtureCratesTests` now asserts label uniqueness across every crate here.
        let unresolvedTrack = Track(id: id(300), vinylID: id(30), position: 0,
                                     artist: "Unknown Artist", title: "Untitled")
        let unresolvedVinyl = VinylEntry(id: id(30), capturedAt: fixedDate,
                                          candidates: [unresolvedTrack], position: 3)

        return Crate(id: id(1), name: "Friday Warehouse", createdAt: fixedDate,
                      vinyls: [inWindowVinyl, excludedVinyl, unresolvedVinyl, sharedVinyl],
                      bpmTolerance: BPMRules.defaultTolerance,
                      selectedTrackByVinyl: [
                          inWindowVinyl.id: inWindowTrackA.id,
                          sharedVinyl.id: sharedVinylTrackX.id,
                      ])
    }

    /// Carries the same shared vinyl as `mixedResultsCrate`, with a DIFFERENT selection.
    public static var secondCrate: Crate {
        Crate(id: id(2), name: "Sunday Chill", createdAt: fixedDate.addingTimeInterval(3600),
              vinyls: [sharedVinyl],
              bpmTolerance: BPMRules.defaultTolerance,
              selectedTrackByVinyl: [sharedVinyl.id: sharedVinylTrackY.id])
    }

    /// Every fixture crate, in the order the crate list shows them. ONE list, so a crate added
    /// to the app is automatically a crate `FixtureCratesTests` checks — a second hand-written
    /// list in the tests is a list someone forgets to update, which is how V5's duplicate
    /// position survived being read past twice.
    public static var all: [Crate] { [secondCrate, mixedResultsCrate] }

    public static var demoStore: CrateStore {
        CrateStore(crates: all)
    }

    // MARK: - PERS-01's probe material

    /// A deterministic crate of `vinylCount` records, built to be the hardest thing the store
    /// has to carry rather than the easiest. Every property that has ever been a persistence
    /// gotcha is present in it on purpose:
    ///
    /// - **several candidates per vinyl, only ONE of them selected** — PERS-03: an unselected
    ///   candidate must survive, because the sequencer re-derives membership from all of them on
    ///   every run and a store that kept only the selected one would look right until a record
    ///   was added
    /// - **explicit non-trivial `position` on both vinyls and tracks** — PERS-02
    /// - **a `manualOrder`**, which is an ordered array of references and the exact shape that
    ///   an object relationship would scramble
    /// - **a `.manual` track**, so MAN-04's mark is proved to survive a relaunch. If it did not,
    ///   hand entry would be protected only until the app was closed — and the automatic pass
    ///   runs on the next launch
    /// - **multi-line OCR text, a catalogue number, and both sides scanned**
    public static func probeCrate(vinylCount: Int) -> Crate {
        var vinyls: [VinylEntry] = []
        var selection: [UUID: UUID] = [:]
        var manualOrder: [UUID] = []

        for index in 0..<max(0, vinylCount) {
            let vinylUUID = id(5000 + index)
            // Two or three candidates, deterministically alternating, so both the "extra
            // unselected candidate" case and the "one spare" case are present.
            let candidateCount = index % 3 == 0 ? 3 : 2
            var candidates: [Track] = []
            for slot in 0..<candidateCount {
                let bpm = 168.0 + Double((index * 2 + slot) % 12)
                candidates.append(Track(
                    id: id(6000 + index * 10 + slot),
                    vinylID: vinylUUID,
                    side: slot == 0 ? .a : .b,
                    position: slot,
                    rawOCRText: "SIDE \(slot == 0 ? "A" : "B")\nTRACK \(index + 1)-\(slot + 1)",
                    artist: "Probe Artist \(index + 1)",
                    title: "Probe Title \(index + 1)-\(slot + 1)",
                    bpm: slot == 0 ? bpm : nil,
                    camelot: slot == 0 ? "\((index % 12) + 1)A" : nil,
                    matchConfidence: 0.8,
                    // Every fourth record is hand-entered, so MAN-04's mark is carried across
                    // the kill on a meaningful fraction of the crate rather than on one row.
                    resolutionState: index % 4 == 0 ? .manual : .resolved))
            }
            vinyls.append(VinylEntry(id: vinylUUID, capturedAt: fixedDate.addingTimeInterval(Double(index)),
                                     photoRefs: ["probe-\(index).heic"],
                                     sidesScanned: candidateCount > 2 ? [.a, .b] : [.a],
                                     candidates: candidates, position: index,
                                     catalogueNumber: index % 2 == 0 ? "PRB\(index)" : nil))
            selection[vinylUUID] = candidates[0].id
            manualOrder.append(candidates[0].id)
        }

        return Crate(id: id(5999), name: "Persistence Probe", createdAt: fixedDate,
                     vinyls: vinyls, bpmTolerance: BPMRules.defaultTolerance,
                     manualOrder: manualOrder.reversed(),   // deliberately NOT the stored order
                     selectedTrackByVinyl: selection)
    }
}
