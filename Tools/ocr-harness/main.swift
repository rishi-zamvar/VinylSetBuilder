// Phase 6's measured acceptance gate, made runnable.
//
// It compiles the SHIPPING recogniser (App/OCR/SleeveTextRecognizer.swift) and the SHIPPING
// segmenter (VinylSetBuilderCore) into one macOS binary and runs them over the owner's twelve
// real photographs. It is not a re-implementation and it does not read ocr2_out.json: the
// point is to measure the code that ships, live, against the committed ground truth.
//
// Run it with Scripts/ocr-score.sh, never directly — the script is what builds Core first.

import Foundation
import VinylSetBuilderCore

// MARK: - the committed ground truth

struct ExpectedFixture: Decodable {
    let file: String
    let verdict: String
    let artist: String?
    let titles: [String?]
    let tracks: Int
    let catalogue: String?
}

struct Baseline: Decodable {
    let clean: Int, partial: Int, fail: Int, usableTrackCounts: Int, catalogueOf: Int
}

struct ExpectedScores: Decodable {
    let fixtures: [ExpectedFixture]
    let baseline: Baseline
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let expected = try JSONDecoder().decode(
    ExpectedScores.self,
    from: Data(contentsOf: root.appendingPathComponent(
        ".planning/phases/06-ocr-segmentation/expected-scores.json")))

// MARK: - scoring

/// Everything the reader returned, at every confidence, normalised to A-Z0-9 and run together.
/// All confidences on purpose: this mirrors how OCR-SPIKE.md itself scored, and OCR-04 already
/// ships the untrusted reads to the screen. SEG-08's trusted tier governs segmentation only.
func haystack(_ sleeve: RecognizedSleeve) -> String {
    sleeve.observations.map { TrackTextFilter.alphanumeric($0.text) }.joined()
}

func slots(_ row: ExpectedFixture) -> [String?] { [row.artist] + row.titles }

/// clean = every slot recovered, fail = none, partial = between. A `null` slot is an element
/// the record carries that the spike could not read; it can never be recovered and so can
/// never be scored as found.
func verdict(found: Int, total: Int) -> String {
    if total > 0, found == total { return "clean" }
    return found == 0 ? "fail" : "partial"
}

func score(_ row: ExpectedFixture, in text: String) -> (found: Int, total: Int, missing: [String]) {
    var found = 0
    var missing: [String] = []
    for slot in slots(row) {
        guard let slot else { missing.append("(unread)"); continue }
        if FuzzyMatch.containsApproximately(TrackTextFilter.alphanumeric(slot), in: text) {
            found += 1
        } else {
            missing.append(slot)
        }
    }
    return (found, slots(row).count, missing)
}

// MARK: - the run

let recognizer = SleeveTextRecognizer()
let labels = root.appendingPathComponent("Tests/Fixtures/Labels")

struct Row: Encodable {
    let file: String
    let observations: Int, trusted: Int, milliseconds: Int, orientation: UInt32
    let expectedVerdict: String, actualVerdict: String
    let slotsFound: Int, slotsTotal: Int, missing: [String]
    let expectedTracks: Int, actualTracks: Int, trackLines: [String]
    let expectedCatalogue: String?, actualCatalogue: String?
}

var rows: [Row] = []
for row in expected.fixtures.sorted(by: { $0.file < $1.file }) {
    let url = labels.appendingPathComponent(row.file)
    guard FileManager.default.fileExists(atPath: url.path) else {
        FileHandle.standardError.write(Data("missing fixture \(row.file)\n".utf8))
        exit(2)
    }
    let started = Date()
    let sleeve = try await recognizer.recognise(imageAt: url)
    let milliseconds = Int(Date().timeIntervalSince(started) * 1000)

    let text = haystack(sleeve)
    let scored = score(row, in: text)
    let segmentation = AngleClusterSegmenter(orientation: sleeve.orientation)
        .segment(sleeve.observations, vinylID: UUID(), side: .a)

    rows.append(Row(file: row.file,
                    observations: sleeve.observations.count,
                    trusted: sleeve.observations.filter(TrackTextFilter.isTrusted).count,
                    milliseconds: milliseconds,
                    orientation: sleeve.orientation.rawValue,
                    expectedVerdict: row.verdict,
                    actualVerdict: verdict(found: scored.found, total: scored.total),
                    slotsFound: scored.found, slotsTotal: scored.total, missing: scored.missing,
                    expectedTracks: row.tracks, actualTracks: segmentation.tracks.count,
                    trackLines: segmentation.tracks.map(\.rawOCRText),
                    expectedCatalogue: row.catalogue,
                    actualCatalogue: segmentation.catalogueNumber))
}

// MARK: - negative controls (this gate is brand new, so it has to be shown able to fail)

let junk = ExpectedFixture(file: "-", verdict: "fail", artist: "Cause 4 Concern",
                           titles: ["High Down"], tracks: 0, catalogue: nil)
let junkScore = score(junk, in: "QQQQWWWWEEEERRRRTTTTYYYY")
let controlA = verdict(found: junkScore.found, total: junkScore.total) == "fail"
let realScore = score(junk, in: "CAUSE4CONCERNAHIGHDOWNTYME012")
let controlB = verdict(found: realScore.found, total: realScore.total) == "clean"

// MARK: - the report

func pad(_ value: String, _ width: Int) -> String {
    value.count >= width ? value : value + String(repeating: " ", count: width - value.count)
}

print("fixture         obs trust   ms  verdict            slots  tracks   catalogue")
print(String(repeating: "-", count: 92))
for row in rows {
    let verdictCell = row.expectedVerdict == row.actualVerdict
        ? pad(row.actualVerdict, 18)
        : pad("\(row.actualVerdict) (want \(row.expectedVerdict))", 18)
    let tracksCell = "\(row.actualTracks)/\(row.expectedTracks)"
        + (row.actualTracks == row.expectedTracks ? " ok " : " MISS")
    let catalogueCell = (row.actualCatalogue ?? "-")
        + (row.actualCatalogue == row.expectedCatalogue ? "" : " (want \(row.expectedCatalogue ?? "nil"))")
    print("\(pad(row.file, 15)) \(pad("\(row.observations)", 3)) \(pad("\(row.trusted)", 5)) "
          + "\(pad("\(row.milliseconds)", 4)) \(verdictCell) \(pad("\(row.slotsFound)/\(row.slotsTotal)", 6)) "
          + "\(pad(tracksCell, 8)) \(catalogueCell)")
    if !row.missing.isEmpty { print("                not recovered: \(row.missing.joined(separator: ", "))") }
    print("                lines: \(row.trackLines.joined(separator: " | "))")
}

let clean = rows.filter { $0.actualVerdict == "clean" }.count
let partial = rows.filter { $0.actualVerdict == "partial" }.count
let failed = rows.filter { $0.actualVerdict == "fail" }.count
let usable = rows.filter { $0.actualTracks == $0.expectedTracks }.count
let catalogues = rows.filter { $0.expectedCatalogue != nil && $0.actualCatalogue == $0.expectedCatalogue }.count
let carrying = rows.filter { $0.expectedCatalogue != nil }.count
let invented = rows.filter { $0.expectedCatalogue == nil && $0.actualCatalogue != nil }.count
let drift = rows.filter { $0.expectedVerdict != $0.actualVerdict }

print("")
print("GATE 1  OCR         \(clean) clean / \(partial) partial / \(failed) fail"
      + "   (baseline \(expected.baseline.clean)/\(expected.baseline.partial)/\(expected.baseline.fail))")
print("GATE 2  segmentation \(usable) of 12 usable track counts   (baseline \(expected.baseline.usableTrackCounts))")
print("GATE 3  catalogue    \(catalogues) of \(carrying) recovered, \(invented) invented"
      + "   (baseline \(expected.baseline.catalogueOf))")
print("controls            junk scores fail: \(controlA);  a real read scores clean: \(controlB)")
if !drift.isEmpty {
    print("per-fixture verdict drift: " + drift.map { "\($0.file) \($0.expectedVerdict)->\($0.actualVerdict)" }
        .joined(separator: ", "))
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let out = root.appendingPathComponent("Artifacts/ocr")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let stamp = ProcessInfo.processInfo.environment["OCR_RUN_LABEL"] ?? "latest"
try encoder.encode(rows).write(to: out.appendingPathComponent("score-\(stamp).json"))
print("wrote Artifacts/ocr/score-\(stamp).json")

var failures: [String] = []
if clean < expected.baseline.clean { failures.append("clean \(clean) < \(expected.baseline.clean)") }
if failed > expected.baseline.fail { failures.append("fail \(failed) > \(expected.baseline.fail)") }
if usable < expected.baseline.usableTrackCounts {
    failures.append("usable \(usable) < \(expected.baseline.usableTrackCounts)")
}
if catalogues < expected.baseline.catalogueOf {
    failures.append("catalogue \(catalogues) < \(expected.baseline.catalogueOf)")
}
if invented > 0 { failures.append("\(invented) invented catalogue number(s)") }
if !controlA || !controlB { failures.append("the scorer's own negative control did not hold") }

if failures.isEmpty {
    print("\nBASELINE HELD")
} else {
    print("\nBASELINE NOT MET: \(failures.joined(separator: "; "))")
    exit(1)
}
