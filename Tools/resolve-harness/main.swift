// GATE 1 — catalogue-number resolution, made runnable.
//
// It compiles the SHIPPING reader, the SHIPPING segmenter, the SHIPPING resolution ladder and
// the SHIPPING URLSession transport into one macOS binary, reads the owner's twelve real
// photographs, and resolves live against MusicBrainz and Discogs. Nothing here is a
// re-implementation and nothing here reads a recorded response: a gate that scored a fixture
// file would pass with the network unplugged.
//
// Run it with Scripts/resolve-score.sh.

import Foundation
import VinylSetBuilderCore

struct ExpectedCatalogue: Decodable {
    let file: String
    let catalogue: String
    let artist: String
}

struct Baseline: Decodable { let correct: Int; let of: Int }
struct Expected: Decodable { let fixtures: [ExpectedCatalogue]; let baseline: Baseline }

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let expected = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: root
    .appendingPathComponent(".planning/phases/07-resolution-bpm/expected-catalogue.json")))

guard !Secrets.discogsToken.isEmpty else {
    FileHandle.standardError.write(Data("no Discogs token — run Scripts/generate-secrets.sh\n".utf8))
    exit(2)
}

// The two throttles are separate on purpose: they are two different services with two
// different allowances, and sharing one would make MusicBrainz pay Discogs' spacing.
let raw = URLSessionTransport()
let musicBrainz = MusicBrainzClient(
    transport: ThrottledTransport(wrapping: raw, minimumInterval: ThrottledTransport.musicBrainzInterval))
let discogs = DiscogsClient(
    transport: ThrottledTransport(wrapping: raw, minimumInterval: ThrottledTransport.discogsInterval),
    token: Secrets.discogsToken)
let cache = ResolutionCache()
let resolver = TrackResolver(musicBrainz: musicBrainz, discogs: discogs, cache: cache)

/// Correct when the expected artist is findable inside what came back. Discogs writes
/// `Phunckateck's Juju vs. UFO! / Juju Featuring Lisa Talev` where the record says
/// Phunckateck; demanding string equality would score a right answer wrong.
func namesTheRightArtist(_ resolved: String?, expected: String) -> Bool {
    guard let resolved, !resolved.isEmpty else { return false }
    return FuzzyMatch.containsApproximately(TrackTextFilter.alphanumeric(expected),
                                            in: TrackTextFilter.alphanumeric(resolved))
}

struct Row: Encodable {
    let file: String, catalogue: String
    let expectedArtist: String
    let resolvedArtist: String?, resolvedTitle: String?
    let source: String?, correct: Bool, milliseconds: Int
    let segmentedCatalogue: String?
}

let recognizer = SleeveTextRecognizer()
let labels = root.appendingPathComponent("Tests/Fixtures/Labels")
var rows: [Row] = []

for row in expected.fixtures.sorted(by: { $0.file < $1.file }) {
    let url = labels.appendingPathComponent(row.file)
    guard FileManager.default.fileExists(atPath: url.path) else {
        FileHandle.standardError.write(Data("missing fixture \(row.file)\n".utf8)); exit(2)
    }
    // OCR and segmentation are re-run rather than read back, so this gate measures the whole
    // chain — a segmenter that stopped extracting catalogue numbers would fail HERE too.
    let sleeve = try await recognizer.recognise(imageAt: url)
    let segmentation = AngleClusterSegmenter(orientation: sleeve.orientation)
        .segment(sleeve.observations, vinylID: UUID(), side: .a)
    let context = SleeveContext(catalogueNumber: segmentation.catalogueNumber,
                                text: sleeve.observations.map(\.text))

    let started = Date()
    let resolved = await resolver.resolve(segmentation.tracks, sleeve: context)
    let milliseconds = Int(Date().timeIntervalSince(started) * 1000)

    let artist = resolved.compactMap(\.artist).first
    let source = await cache.snapshot()["catno:" + TrackTextFilter.alphanumeric(row.catalogue)]??.source
    rows.append(Row(file: row.file, catalogue: row.catalogue, expectedArtist: row.artist,
                    resolvedArtist: artist, resolvedTitle: resolved.compactMap(\.title).first,
                    source: source,
                    correct: namesTheRightArtist(artist, expected: row.artist),
                    milliseconds: milliseconds,
                    segmentedCatalogue: segmentation.catalogueNumber))
}

// MARK: - the negative control, run live

// This gate is brand new, so it has to be shown able to fail. `0-44904` is the measured false
// positive: Discogs answers it with a USSR Tchaikovsky pressing FIRST. Two independent guards
// stop it, and both are exercised here against the live response, not a recorded one.
let unfiltered = (try? await discogs.searchByCatalogueNumberUnfiltered("0-44904")) ?? []
let firstRaw = unfiltered.first
let controlA = firstRaw.map { !$0.artist.lowercased().contains("abstract") } ?? false
let filtered = (try? await discogs.searchByCatalogueNumber("0-44904")) ?? []
let controlB = filtered.allSatisfy { $0.artist.lowercased().contains("abstract") } && !filtered.isEmpty
let img0498 = ["Abstract", "The Message - Brown Gtauno Originat Mix!"]
let controlC = firstRaw.map { SleeveCrossCheck.support(for: $0, sleeveText: img0498) == 0 } ?? false

// MARK: - the report

func pad(_ v: String, _ w: Int) -> String { v.count >= w ? v : v + String(repeating: " ", count: w - v.count) }

print("fixture         catalogue   resolved artist                        want            ms")
print(String(repeating: "-", count: 96))
for row in rows {
    print("\(pad(row.file, 15)) \(pad(row.catalogue, 11)) "
          + "\(pad(row.resolvedArtist ?? "(unresolved)", 38)) \(pad(row.expectedArtist, 15)) "
          + "\(pad("\(row.milliseconds)", 6)) \(row.correct ? "ok" : "MISS")")
    if let title = row.resolvedTitle { print("                title: \(title)  [\(row.source ?? "?")]") }
}

let correct = rows.filter(\.correct).count
let requests = await cache.count
print("")
print("GATE 1  catalogue resolution  \(correct) of \(rows.count) correct"
      + "   (baseline \(expected.baseline.correct) of \(expected.baseline.of))")
let free = rows.filter { $0.source == "musicbrainz" }.count
print("        distinct lookups cached: \(requests);  answered free by MusicBrainz: \(free) of \(rows.count)")
print("controls  raw Discogs result 1 for 0-44904 is NOT the record: \(controlA)")
print("          the catalogue-number filter leaves only the record:  \(controlB)")
print("          the sleeve gives that raw result zero support:       \(controlC)")

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let out = root.appendingPathComponent("Artifacts/resolution")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let stamp = ProcessInfo.processInfo.environment["RESOLVE_RUN_LABEL"] ?? "latest"
try encoder.encode(rows).write(to: out.appendingPathComponent("catalogue-\(stamp).json"))
print("wrote Artifacts/resolution/catalogue-\(stamp).json")

var failures: [String] = []
if correct < expected.baseline.correct {
    failures.append("catalogue \(correct) < \(expected.baseline.correct)")
}
if !controlA || !controlB || !controlC { failures.append("the negative control did not hold") }
if failures.isEmpty { print("\nBASELINE HELD") }
else { print("\nBASELINE NOT MET: \(failures.joined(separator: "; "))"); exit(1) }
