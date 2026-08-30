// GATE 4 — the analyser's accuracy, measured against known ground truth.
//
// RETARGETED 2026-08-30. It used to drive `MusicUnderstandingSession`, which needs an iOS/macOS
// 27 SDK that is not installed and is therefore banned by hygiene gate G3. It now drives the
// SHIPPING `AudioAnalyzing` implementation — `VDSPAudioAnalyzer` — over the SHIPPING decoder,
// so what is scored is what runs on the phone.
//
// Build and run with Scripts/analyser-score.sh.
//
// The dataset is [{artist,title,bpm,camelot,sc_id}], where bpm/camelot are the ground-truth
// values from the owner's walkman-dj library.db (DSP-derived from FULL audio), and audioDir
// holds <sc_id>.mp3 — 30-SECOND SoundCloud previews. The gap between those two facts is the
// whole question: is thirty seconds enough?

import Foundation
import VinylSetBuilderCore

struct Truth: Codable {
    let artist: String, title: String, bpm: Double, camelot: String, sc_id: Int
}

/// Tempo comparison tolerant of octave errors — 87 and 174 are the same groove, and
/// `BPMRules.fold` turns the first into the second unconditionally.
func tempoVerdict(_ got: Double, _ want: Double, tolerance: Double = 2.0) -> String {
    if abs(got - want) <= tolerance { return "exact" }
    for multiplier in [2.0, 0.5, 3.0, 1.0 / 3.0] where abs(got * multiplier - want) <= tolerance {
        return "octave"
    }
    return "miss"
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: mu-validate <dataset.json> <audioDir>\n".utf8))
    exit(2)
}
let truths = try JSONDecoder().decode([Truth].self,
                                      from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
let audioDirectory = URL(fileURLWithPath: arguments[2])
let analyser = VDSPAudioAnalyzer()
let decoder = AVAudioFileDecoder()

struct Row: Encodable {
    let artist: String, title: String
    let wantBPM: Double, gotBPM: Double?, foldedBPM: Double?, tempo: String
    let wantCamelot: String, gotCamelot: String?, camelotDistance: Int?, keyConfidence: Double
}

var rows: [Row] = []
for truth in truths {
    let url = audioDirectory.appendingPathComponent("\(truth.sc_id).mp3")
    guard FileManager.default.fileExists(atPath: url.path) else { continue }
    let decoded = try await decoder.decodeMono(Data(contentsOf: url))
    let analysis = await analyser.analyse(monoSamples: decoded.samples, sampleRate: decoded.sampleRate)

    // The ground truth is FULL-track DSP at real tempo; the fold is what the app applies, so
    // the fold is what is scored.
    let folded = analysis.bpm.map(BPMRules.fold)
    let verdict = folded.map { tempoVerdict($0, truth.bpm) } ?? "nil"
    let distance = analysis.camelot
        .flatMap { Camelot($0) }
        .flatMap { got in Camelot(truth.camelot).map { got.distance(to: $0) } }

    rows.append(Row(artist: truth.artist, title: truth.title, wantBPM: truth.bpm,
                    gotBPM: analysis.bpm, foldedBPM: folded, tempo: verdict,
                    wantCamelot: truth.camelot, gotCamelot: analysis.camelot,
                    camelotDistance: distance, keyConfidence: analysis.keyConfidence))
}

func pad(_ v: String, _ w: Int) -> String { v.count >= w ? v : v + String(repeating: " ", count: w - v.count) }

print("track                                     got     fold    want    tempo    key            d  conf")
print(String(repeating: "-", count: 104))
for row in rows {
    let name = "\(row.artist) — \(row.title)"
    print("\(pad(String(name.prefix(40)), 41)) "
          + "\(pad(row.gotBPM.map { String(format: "%.1f", $0) } ?? "-", 7)) "
          + "\(pad(row.foldedBPM.map { String(format: "%.1f", $0) } ?? "-", 7)) "
          + "\(pad(String(format: "%.1f", row.wantBPM), 7)) \(pad(row.tempo, 8)) "
          + "\(pad("\(row.gotCamelot ?? "-") vs \(row.wantCamelot)", 14)) "
          + "\(pad(row.camelotDistance.map(String.init) ?? "-", 2)) "
          + String(format: "%.2f", row.keyConfidence))
}

let analysed = rows.count
let exact = rows.count { $0.tempo == "exact" }
let octave = rows.count { $0.tempo == "octave" }
let tempoMiss = rows.count { $0.tempo == "miss" }
let tempoNil = rows.count { $0.tempo == "nil" }
let keyExact = rows.count { $0.camelotDistance == 0 }
let keyClose = rows.count { ($0.camelotDistance ?? 99) == 1 }
let keyFar = rows.count { ($0.camelotDistance ?? 99) > 1 && $0.camelotDistance != nil }
let keyNil = rows.count { $0.camelotDistance == nil }

func percent(_ n: Int) -> String {
    analysed == 0 ? "-" : String(format: "%.0f%%", 100 * Double(n) / Double(analysed))
}

print("""

===========================================================
 vDSP analyser accuracy — \(analysed) tracks, 30-second previews
===========================================================
 TEMPO (after the <100 doubling rule)
   exact (±2 BPM)      \(exact)   \(percent(exact))
   octave error        \(octave)   \(percent(octave))   <- same groove, wrong multiple
   usable (exact+oct)  \(exact + octave)   \(percent(exact + octave))
   miss                \(tempoMiss)   \(percent(tempoMiss))
   no reading          \(tempoNil)

 KEY (from a 30-second preview, Camelot distance)
   exact               \(keyExact)   \(percent(keyExact))
   within 1 hop        \(keyClose)   \(percent(keyClose))   <- still musically usable
   wrong               \(keyFar)   \(percent(keyFar))
   no reading          \(keyNil)
   usable (0 or 1 hop) \(keyExact + keyClose)   \(percent(keyExact + keyClose))
===========================================================

DECISION RULE, fixed in advance
  If key 'exact + within 1 hop' is comfortably the majority, key stays automatic.
  Otherwise key degrades to a soft/manual field and BPM stays automatic — the sequencer
  tolerates this by design, since Camelot distance only ORDERS survivors and never
  excludes them. That is a valid outcome, not a failure.
""")

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Artifacts/bpm")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let stamp = ProcessInfo.processInfo.environment["ANALYSER_RUN_LABEL"] ?? "latest"
try encoder.encode(rows).write(to: out.appendingPathComponent("analyser-\(stamp).json"))
print("wrote Artifacts/bpm/analyser-\(stamp).json")

if analysed == 0 {
    print("\nMEASURED NOTHING — no audio found in \(audioDirectory.path)")
    exit(2)
}
