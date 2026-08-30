import Foundation

/// The Phase-1 stub library every screen binds to until Phase 6 supplies real on-device
/// persistence — this file gets deleted then. Built from fixed UUIDs and a fixed date so a
/// screenshot or bug report is reproducible across launches.
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
}
