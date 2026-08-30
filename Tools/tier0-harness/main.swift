// GATE 3 — the tier-0 hit rate, measured and stated.
//
// This gate has NO baseline and cannot fail. That is deliberate. The bundled corpus is the
// owner's house/techno library and only 12% of it sits in the 160-184 BPM jungle band, so a low
// hit rate on a crate of jungle twelves is an EXPECTED result, not a defect — it reallocates
// weight onto manual entry and says so. Tuning this number would be tuning the wrong thing.
//
// Two denominators, because they measure two different things and only one of them is honest:
//
//   A. the twelve real photographs, resolved live — the number that matters
//   B. the 40-track ground-truth set — CIRCULAR, and reported only to prove the reader works:
//      truth.tsv and bpmkey.db were both derived from the same library, so anything other than
//      a near-perfect score here would mean the lookup is broken
//
// Run it with Scripts/tier0-score.sh.

import Foundation
import VinylSetBuilderCore

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
guard let corpus = TierZeroCorpus(contentsOf: root.appendingPathComponent("App/Generated/bpmkey.tsv")) else {
    FileHandle.standardError.write(Data("no corpus — run Scripts/generate-corpus.sh\n".utf8))
    exit(2)
}

// ---------------------------------------------------------------- B, the circular control
let truthText = (try? String(contentsOf: root.appendingPathComponent(".local/truth.tsv"),
                             encoding: .utf8)) ?? ""
var controlTotal = 0, controlHits = 0
for line in truthText.split(separator: "\n") {
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
    guard fields.count >= 2 else { continue }
    controlTotal += 1
    if corpus.lookup(artist: String(fields[0]), title: String(fields[1])) != nil { controlHits += 1 }
}

// ---------------------------------------------------------------- A, the real collection
let raw = URLSessionTransport()
let resolver = TrackResolver(
    musicBrainz: MusicBrainzClient(transport: ThrottledTransport(
        wrapping: raw, minimumInterval: ThrottledTransport.musicBrainzInterval)),
    discogs: DiscogsClient(transport: ThrottledTransport(
        wrapping: raw, minimumInterval: ThrottledTransport.discogsInterval),
                           token: Secrets.discogsToken),
    cache: ResolutionCache())
let recognizer = SleeveTextRecognizer()
let labels = root.appendingPathComponent("Tests/Fixtures/Labels")

struct Row: Encodable {
    let file: String, rawLine: String
    let artist: String?, title: String?, state: String
    let tier0BPM: Double?, tier0Camelot: String?
}

var rows: [Row] = []
let files = try FileManager.default.contentsOfDirectory(atPath: labels.path)
    .filter { $0.hasSuffix(".HEIC") }.sorted()
for file in files {
    let sleeve = try await recognizer.recognise(imageAt: labels.appendingPathComponent(file))
    let segmentation = AngleClusterSegmenter(orientation: sleeve.orientation)
        .segment(sleeve.observations, vinylID: UUID(), side: .a)
    let resolved = await resolver.resolve(
        segmentation.tracks,
        sleeve: SleeveContext(catalogueNumber: segmentation.catalogueNumber,
                              text: sleeve.observations.map(\.text)))
    for track in resolved {
        let hit = (track.artist).flatMap { artist in
            (track.title).flatMap { corpus.lookup(artist: artist, title: $0) }
        }
        rows.append(Row(file: file, rawLine: track.rawOCRText, artist: track.artist,
                        title: track.title, state: track.resolutionState.rawValue,
                        tier0BPM: hit.map(\.bpm), tier0Camelot: hit?.camelot))
    }
}

func pad(_ v: String, _ w: Int) -> String { v.count >= w ? v : v + String(repeating: " ", count: w - v.count) }

print("fixture         state     identity                                        tier-0")
print(String(repeating: "-", count: 100))
for row in rows {
    let identity = row.artist.map { "\($0) — \(row.title ?? "")" } ?? "(unresolved: \(row.rawLine))"
    print("\(pad(row.file, 15)) \(pad(row.state, 9)) \(pad(String(identity.prefix(46)), 47)) "
          + (row.tier0BPM.map { String(format: "%.1f %@", $0, row.tier0Camelot ?? "-") } ?? "miss"))
}

let identified = rows.count { $0.artist != nil && $0.title != nil }
let hits = rows.count { $0.tier0BPM != nil }
func percent(_ n: Int, _ d: Int) -> String { d == 0 ? "-" : String(format: "%.0f%%", 100 * Double(n) / Double(d)) }

print("")
print("GATE 3  tier-0 hit rate on the real collection: \(hits) of \(identified) identified tracks"
      + "  (\(percent(hits, identified)))   — \(rows.count) track lines in all")
print("        control, the corpus's own source library: \(controlHits) of \(controlTotal)"
      + "  (\(percent(controlHits, controlTotal))) — CIRCULAR, it only proves the reader works")
print("        corpus: \(corpus.rowCount) rows, \(corpus.keyCollisions) normalised keys holding a key conflict")
print("")
print("NO BASELINE. A low number here is a valid measurement of a house/techno corpus meeting a")
print("crate of jungle twelves, and it moves weight onto manual entry (BPM-07, Phase 12).")

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let out = root.appendingPathComponent("Artifacts/bpm")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let stamp = ProcessInfo.processInfo.environment["TIER0_RUN_LABEL"] ?? "latest"
try encoder.encode(rows).write(to: out.appendingPathComponent("tier0-\(stamp).json"))
print("wrote Artifacts/bpm/tier0-\(stamp).json")
