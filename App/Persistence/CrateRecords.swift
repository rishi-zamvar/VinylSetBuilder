import Foundation
import SwiftData
import VinylSetBuilderCore

/// **The storage half of the Core boundary, and the boundary is the point.**
///
/// `VinylSetBuilderCore` owns `Crate`, `VinylEntry` and `Track` as pure `Codable` value types and
/// may not so much as NAME a persistence framework — `CorePurityTests` scans its sources for the
/// substring and fails the build, comments included. The `@Model` classes therefore live here, in
/// the app target, and these two functions are the only place the two representations meet.
///
/// **Three rules, each of them paid for by a documented gotcha rather than a preference:**
///
/// 1. **Order is never a relationship's job.** A to-many relationship is backed by an `NSSet` and
///    does not preserve insertion order. `position: Int` on both `VinylRecord` and `TrackRecord`
///    is the source of truth and is sorted at the call site on the way out (PERS-02).
/// 2. **Ordered *references* are scalar arrays, not object relationships.** `manualOrder` is
///    `[UUID]` stored as one attribute — a single Codable value whose array order is preserved
///    exactly — never a `@Relationship` to `TrackRecord`.
/// 3. **Parent into the context before the children.** Relationship setup is order-sensitive, and
///    every relationship property here is `Optional` for the same reason.
@Model
final class CrateRecord {
    // Defaults on every stored property. A model whose properties have no default cannot be
    // added to later without a migration plan, and at one schema version that cost buys nothing.
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.distantPast
    var bpmTolerance: Double = 4.0

    /// PERS-02 at the top level too: the crate LIST is ordered (newest first) and a fetch does
    /// not promise an order either. This is that order, written down.
    var listPosition: Int = 0

    /// CRATE-04's override. A scalar `[UUID]`, so its order survives; a `@Relationship` here
    /// would be exactly the bug this app is trying not to have.
    var manualOrder: [UUID]?

    /// CRATE-07's per-crate selection, flattened to `"<vinylUUID>:<trackUUID>"`. **One array
    /// rather than two parallel ones** — parallel arrays can desynchronise and a desynchronised
    /// selection silently pins the wrong track — and a plain `[String]` rather than a
    /// `[UUID: UUID]` attribute, because a dictionary's iteration order is not stable and the
    /// dump that proves PERS-01 is compared between processes.
    var selectionPairs: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \VinylRecord.crate)
    var vinyls: [VinylRecord]?

    init(id: UUID, name: String, createdAt: Date, bpmTolerance: Double,
         listPosition: Int, manualOrder: [UUID]?, selectionPairs: [String]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.bpmTolerance = bpmTolerance
        self.listPosition = listPosition
        self.manualOrder = manualOrder
        self.selectionPairs = selectionPairs
    }
}

@Model
final class VinylRecord {
    var id: UUID = UUID()
    var capturedAt: Date = Date.distantPast
    var photoRefs: [String] = []
    /// `Side` is a Core enum; stored as its raw values so the schema does not depend on a type
    /// the storage layer is not allowed to reach for.
    var sidesScanned: [String] = []
    var position: Int = 0
    var catalogueNumber: String?

    @Relationship(deleteRule: .cascade, inverse: \TrackRecord.vinyl)
    var candidates: [TrackRecord]?
    var crate: CrateRecord?

    init(id: UUID, capturedAt: Date, photoRefs: [String], sidesScanned: [String],
         position: Int, catalogueNumber: String?) {
        self.id = id
        self.capturedAt = capturedAt
        self.photoRefs = photoRefs
        self.sidesScanned = sidesScanned
        self.position = position
        self.catalogueNumber = catalogueNumber
    }
}

@Model
final class TrackRecord {
    var id: UUID = UUID()
    var vinylID: UUID = UUID()
    var sideRaw: String = "a"
    var position: Int = 0
    var rawOCRText: String = ""
    var artist: String?
    var title: String?
    var bpm: Double?
    var camelot: String?
    var matchConfidence: Double = 0
    /// Includes `.manual`, which is MAN-04's mark. If this did not persist, a hand-entered
    /// record would be protected only until the app was closed — which is the same as not being
    /// protected, since the automatic pass runs on the NEXT launch.
    var stateRaw: String = "pending"
    var failureReason: String?
    var vinyl: VinylRecord?

    init(id: UUID, vinylID: UUID, sideRaw: String, position: Int, rawOCRText: String,
         artist: String?, title: String?, bpm: Double?, camelot: String?,
         matchConfidence: Double, stateRaw: String, failureReason: String?) {
        self.id = id
        self.vinylID = vinylID
        self.sideRaw = sideRaw
        self.position = position
        self.rawOCRText = rawOCRText
        self.artist = artist
        self.title = title
        self.bpm = bpm
        self.camelot = camelot
        self.matchConfidence = matchConfidence
        self.stateRaw = stateRaw
        self.failureReason = failureReason
    }
}

// MARK: - The only place the two representations meet

extension CrateRecord {
    /// Storage to domain. **Every collection is sorted here**, so nothing downstream depends on
    /// the order a fetch happened to return.
    var domain: Crate {
        var selection: [UUID: UUID] = [:]
        for pair in selectionPairs {
            let halves = pair.split(separator: ":", maxSplits: 1)
            guard halves.count == 2,
                  let vinylID = UUID(uuidString: String(halves[0])),
                  let trackID = UUID(uuidString: String(halves[1])) else { continue }
            selection[vinylID] = trackID
        }
        return Crate(id: id, name: name, createdAt: createdAt,
                     vinyls: (vinyls ?? []).sorted { $0.position < $1.position }.map(\.domain),
                     bpmTolerance: bpmTolerance,
                     manualOrder: manualOrder,
                     selectedTrackByVinyl: selection)
    }

    /// Domain to storage. The caller inserts the returned record into the context **before**
    /// this function's children are reachable through it — see `CrateArchive.save`.
    static func make(from crate: Crate, listPosition: Int) -> CrateRecord {
        CrateRecord(id: crate.id, name: crate.name, createdAt: crate.createdAt,
                    bpmTolerance: crate.bpmTolerance, listPosition: listPosition,
                    manualOrder: crate.manualOrder,
                    selectionPairs: crate.selectedTrackByVinyl
                        .map { "\($0.key.uuidString):\($0.value.uuidString)" }
                        .sorted())
    }
}

extension VinylRecord {
    var domain: VinylEntry {
        VinylEntry(id: id, capturedAt: capturedAt, photoRefs: photoRefs,
                   sidesScanned: Set(sidesScanned.compactMap(Side.init(rawValue:))),
                   // PERS-03: every candidate, selected or not. The sequencer re-derives
                   // membership from the whole set on every run, so dropping the unselected ones
                   // would look correct on screen until the moment a record was added.
                   candidates: (candidates ?? []).sorted { $0.position < $1.position }.map(\.domain),
                   position: position, catalogueNumber: catalogueNumber)
    }

    static func make(from vinyl: VinylEntry) -> VinylRecord {
        VinylRecord(id: vinyl.id, capturedAt: vinyl.capturedAt, photoRefs: vinyl.photoRefs,
                    sidesScanned: vinyl.sidesScanned.map(\.rawValue).sorted(),
                    position: vinyl.position, catalogueNumber: vinyl.catalogueNumber)
    }
}

extension TrackRecord {
    var domain: Track {
        Track(id: id, vinylID: vinylID, side: Side(rawValue: sideRaw) ?? .a, position: position,
              rawOCRText: rawOCRText, artist: artist, title: title, bpm: bpm, camelot: camelot,
              matchConfidence: matchConfidence,
              resolutionState: ResolutionState(rawValue: stateRaw) ?? .pending,
              failureReason: failureReason)
    }

    static func make(from track: Track) -> TrackRecord {
        TrackRecord(id: track.id, vinylID: track.vinylID, sideRaw: track.side.rawValue,
                    position: track.position, rawOCRText: track.rawOCRText,
                    artist: track.artist, title: track.title, bpm: track.bpm,
                    camelot: track.camelot, matchConfidence: track.matchConfidence,
                    stateRaw: track.resolutionState.rawValue, failureReason: track.failureReason)
    }
}
