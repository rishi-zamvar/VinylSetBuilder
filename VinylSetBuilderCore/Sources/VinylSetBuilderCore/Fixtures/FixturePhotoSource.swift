import Foundation

/// The owner's twelve photographed sleeves, dealt one shutter press at a time.
///
/// The verdict and side-marker columns below are transcribed verbatim from CONTEXT.md §3,
/// where they were hand-scored against the real OCR run. They are this phase's ground truth,
/// not something to re-derive: `sideMarkers` is normalised and de-duplicated by hand because
/// deriving markers from raw text is SEG-04/SEG-06 and belongs to Phase 6 (D-03-4).
///
/// An actor rather than a struct because `capture()` advances a counter, and the capture screen
/// calls it from the main actor.
public actor FixturePhotoSource: PhotoCapturing {
    /// The crate these captures are destined for. Held so a caller can build the session and
    /// the source from one value.
    public let crateID: UUID

    private var shotsTaken = 0

    public init(crateID: UUID) {
        self.crateID = crateID
    }

    /// Wraps past the twelfth, so a 21-item session is reachable for the CAP-03 scroll test.
    /// `index` keeps counting upward — a wrapped shot is a new record, not the old one again.
    public func capture() async -> CaptureItem? {
        let fixture = Self.table[shotsTaken % Self.table.count]
        // Looked up by filename, not by a parallel index: the two tables are generated and
        // hand-written respectively, and pairing them positionally would silently mis-attribute
        // a record's text if either ever reordered.
        let observations = FixtureObservations.all.first { $0.file == fixture.file }?.observations
        shotsTaken += 1
        return CaptureItem(index: shotsTaken,
                           photoRef: fixture.file,
                           observations: observations ?? [],
                           sideMarkers: fixture.sideMarkers,
                           status: fixture.status)
    }

    /// CONTEXT.md §3, verbatim. Tally: 6 read / 5 partial / 1 unread. Flip prompt suppressed on
    /// exactly fixtures 2, 6 and 9 — the three where one photograph already read both sides.
    static let table: [(file: String, status: CaptureItemStatus, sideMarkers: [String])] = [
        ("IMG_0498.HEIC", .read, []),
        ("IMG_0499.HEIC", .read, ["A", "AA"]),
        ("IMG_0500.HEIC", .partial, ["ONE"]),        // "Gide One /" — a misread "Side One"
        ("IMG_0501.HEIC", .partial, []),
        ("IMG_0502.HEIC", .partial, []),
        ("IMG_0503.HEIC", .read, ["A", "AA"]),       // "SIDE A" + "A:" dedupe; "AAA:" is "AA:"
        ("IMG_0504.HEIC", .read, []),
        ("IMG_0505.HEIC", .read, []),
        ("IMG_0506.HEIC", .read, ["COLD", "STEEL"]), // "COLD SIDE:" / "STEEL SIDE:"
        ("IMG_0507.HEIC", .unread, []),              // the dubplate nothing reads
        ("IMG_0508.HEIC", .partial, []),
        ("IMG_0509.HEIC", .partial, []),
    ]
}
