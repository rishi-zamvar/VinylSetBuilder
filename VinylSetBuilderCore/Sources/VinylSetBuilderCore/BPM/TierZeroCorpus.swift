import Foundation

/// One row of the bundled corpus: what the owner's own library already knows.
public struct BPMKeyEntry: Sendable, Hashable, Codable {
    public let artist: String
    public let title: String
    public let bpm: Double
    /// Nil when two rows that normalise to the same track disagree about the key. Losing the
    /// key is honest; picking one of two contradictory answers is not.
    public let camelot: String?

    public init(artist: String, title: String, bpm: Double, camelot: String?) {
        self.artist = artist
        self.title = title
        self.bpm = bpm
        self.camelot = camelot
    }
}

/// BPM-02, the free rung below every network call.
///
/// 6,608 rows, tab-separated, read once. The matching BPM-02 asks for is
/// punctuation-normalised — `The Rapture Pt. II` must find `The Rapture, Pt. II` — and no
/// SQLite index on the raw normalised columns can serve that, so the table is read into memory
/// whatever its on-disk format is. Which is why it is not SQLite: no GRDB dependency, no
/// `sqlite3_step` lifecycle, and no read-only WAL bundling trap.
///
/// **Known skew, stated up front:** this corpus is the owner's house/techno library. Only 12%
/// of it sits in the 160-184 BPM jungle band. Its hit rate on a crate of jungle twelves is
/// measured by `Scripts/tier0-score.sh` and is expected to be low.
public struct TierZeroCorpus: Sendable {
    private let byArtistAndTitle: [String: [BPMKeyEntry]]
    private let byTitle: [String: [BPMKeyEntry]]
    public let rowCount: Int
    /// Distinct normalised keys holding rows that disagree about the Camelot key.
    public let keyCollisions: Int

    public init(tsv: String) {
        var rows: [BPMKeyEntry] = []
        for line in tsv.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 4, let bpm = Double(fields[2]) else { continue }
            rows.append(BPMKeyEntry(artist: String(fields[0]), title: String(fields[1]),
                                    bpm: bpm, camelot: String(fields[3])))
        }
        rowCount = rows.count
        byArtistAndTitle = Dictionary(grouping: rows) { Self.key($0.artist, $0.title) }
        byTitle = Dictionary(grouping: rows) { TrackTextFilter.alphanumeric($0.title) }
        keyCollisions = byArtistAndTitle.values.count { Set($0.map(\.camelot)).count > 1 }
    }

    public init?(contentsOf url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        self.init(tsv: text)
    }

    static func key(_ artist: String, _ title: String) -> String {
        TrackTextFilter.alphanumeric(artist) + "|" + TrackTextFilter.alphanumeric(title)
    }

    /// Exact on the normalised pair, then title-only with a fuzzy artist. Nil is a miss and a
    /// miss is a legitimate answer — it is what sends the ladder to the next rung.
    public func lookup(artist: String, title: String) -> BPMKeyEntry? {
        if let rows = byArtistAndTitle[Self.key(artist, title)] {
            return resolve(rows, rawTitle: title)
        }
        guard let rows = byTitle[TrackTextFilter.alphanumeric(title)] else { return nil }
        let close = rows.filter {
            FuzzyMatch.isClose(TrackTextFilter.alphanumeric($0.artist),
                               TrackTextFilter.alphanumeric(artist))
        }
        return close.isEmpty ? nil : resolve(close, rawTitle: title)
    }

    /// THE DOCUMENTED TIE-BREAK, for the case BPM-02 names by name.
    ///
    /// `&ME — The Rapture Pt. II` is 3A and `&ME — The Rapture, Pt. II` is 2B. They are the
    /// same three words and the same 120 BPM, and punctuation-normalising makes them one key
    /// holding two contradictory answers.
    ///
    /// 1. If one row's RAW title is exactly what was asked for, that row wins outright.
    /// 2. Otherwise the tempo — which both rows agree on — is kept and the key is DROPPED.
    ///
    /// Rule 2 is the point. Half a right answer beats a coin flip, and the sequencer is built
    /// for it: Camelot only ORDERS survivors, so a missing key costs ordering quality and
    /// excludes nothing.
    private func resolve(_ rows: [BPMKeyEntry], rawTitle: String) -> BPMKeyEntry? {
        guard let first = rows.first else { return nil }
        guard rows.count > 1 else { return first }
        if let exact = rows.first(where: { $0.title.compare(rawTitle, options: .caseInsensitive) == .orderedSame }) {
            return exact
        }
        let keys = Set(rows.map(\.camelot))
        return BPMKeyEntry(artist: first.artist, title: first.title, bpm: first.bpm,
                           camelot: keys.count == 1 ? first.camelot : nil)
    }
}
