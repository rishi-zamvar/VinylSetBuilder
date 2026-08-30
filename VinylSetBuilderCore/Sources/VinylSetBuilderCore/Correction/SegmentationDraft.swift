import Foundation

/// One editable line of a segmentation result. `id` is the id of the `Track` the line came
/// from, so a line keeps its identity across an edit and a screen does not lose its selection.
public struct DraftLine: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var text: String
    public var isHandEdited: Bool

    public init(id: UUID = UUID(), text: String, isHandEdited: Bool = false) {
        self.id = id
        self.text = text
        self.isHandEdited = isHandEdited
    }
}

/// SEG-07: a segmentation result made correctable. Six of the owner's twelve records will never
/// resolve automatically — white labels and dubplates are in no database — so correction is a
/// routine path, not an error path. Every operation here is **one call taking one argument**,
/// because every operation in the sheet has to be **one tap**.
///
/// A pure value type, held in a screen's own state and committed by converting back with
/// `tracks()` — the same shape as `CrateDetailModel`. No I/O, no view type, no work in `init`.
public struct SegmentationDraft: Sendable, Equatable {
    public let vinylID: UUID
    public private(set) var lines: [DraftLine]

    /// Carried through rather than defaulted, so correcting a side-B read cannot silently
    /// republish it as side A. The draft edits text; it does not reassign sides.
    private let side: Side

    public init(vinylID: UUID, tracks: [Track]) {
        let ordered = tracks.sorted { $0.position < $1.position }
        self.vinylID = vinylID
        self.side = ordered.first?.side ?? .a
        self.lines = ordered.map { DraftLine(id: $0.id, text: $0.rawOCRText) }
    }

    // MARK: - The three corrections

    /// Split a line in two at its word midpoint. A single-word line has no midpoint, so it is
    /// left alone; an odd word count gives the extra word to the first line.
    ///
    /// ponytail: word-midpoint split; take a character index if the owner asks for finer control.
    /// Cursor-position splitting needs a text-selection round trip the sheet does not have and
    /// the UI test cannot drive.
    public mutating func splitLine(_ id: DraftLine.ID) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        let words = Self.words(in: lines[index].text)
        guard words.count > 1 else { return }

        let midpoint = (words.count + 1) / 2
        let wasHandEdited = lines[index].isHandEdited
        lines[index].text = words[..<midpoint].joined(separator: " ")
        lines.insert(DraftLine(text: words[midpoint...].joined(separator: " "),
                               isHandEdited: wasHandEdited),
                     at: index + 1)
    }

    /// Merge a line into the one above it, joined by a single space. The line above survives —
    /// with its id — and this line disappears. On the first line, and on an id this draft does
    /// not hold, this does nothing: the Act I draft arrives over-split (D-03-4), so merge is the
    /// first tap most records get and it must be safe to press anywhere.
    public mutating func mergeUp(_ id: DraftLine.ID) {
        guard let index = lines.firstIndex(where: { $0.id == id }), index > 0 else { return }
        let absorbed = lines.remove(at: index)
        let above = index - 1
        lines[above].text = Self.words(in: lines[above].text + " " + absorbed.text)
            .joined(separator: " ")
        lines[above].isHandEdited = lines[above].isHandEdited || absorbed.isHandEdited
    }

    /// Hand-type a line. Clearing it to nothing **removes** it — that is how a person deletes a
    /// junk read, and an empty line left behind would become a blank row in the crate.
    ///
    /// The text is stored exactly as typed. Whitespace is normalised by `splitLine`/`mergeUp`,
    /// which have to agree with each other to round-trip, but not here: collapsing a space the
    /// moment it is typed would make the field unusable.
    public mutating func setText(_ id: DraftLine.ID, to text: String) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        guard !Self.isBlank(text) else {
            lines.remove(at: index)
            return
        }
        lines[index].text = text
        lines[index].isHandEdited = true
    }

    /// Append an empty hand-typed line — for a track the read missed entirely.
    public mutating func addLine() {
        lines.append(DraftLine(text: "", isHandEdited: true))
    }

    // MARK: - Back to the domain

    /// The corrected lines as `Track`s, positions renumbered contiguously from zero, so a
    /// corrected vinyl is indistinguishable in shape from a segmented one. Blank lines are
    /// dropped; ids are the lines' own, so calling this twice returns the same tracks.
    public func tracks() -> [Track] {
        lines.filter { !Self.isBlank($0.text) }
            .enumerated()
            .map { index, line in
                Track(id: line.id, vinylID: vinylID, side: side,
                      position: index, rawOCRText: line.text)
            }
    }

    // MARK: - One whitespace rule, not two that drift

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func isBlank(_ text: String) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }
}
