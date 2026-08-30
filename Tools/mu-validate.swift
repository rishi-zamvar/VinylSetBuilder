// mu-validate.swift — measures Apple Music Understanding accuracy against known ground truth.
//
// Requires macOS 27+ (MusicUnderstanding ships with the OS 27 wave).
// Build: swiftc -O -o mu-validate Tools/mu-validate.swift
// Run:   ./mu-validate dataset.json audioDir/
//
// dataset.json is [{artist,title,bpm,camelot,sc_id}], where bpm/camelot are the
// ground-truth values from the owner's walkman-dj library.db (DSP-derived from full
// audio), and audioDir holds <sc_id>.mp3 — 30-second SoundCloud previews.
//
// Answers the two open questions gating Phase 4:
//   1. Is Music Understanding's tempo accurate on this material?
//   2. Is a 30-SECOND PREVIEW enough for a reliable key, or does it land on an
//      intro/breakdown with no tonal content?

import Foundation
import AVFoundation
import MusicUnderstanding

struct Truth: Codable { let artist: String; let title: String; let bpm: Double; let camelot: String; let sc_id: Int }

// Camelot ← (tonic, mode). Major = B ring, minor = A ring.
let majorCamelot = ["B":"1B","F#":"2B","Gb":"2B","C#":"3B","Db":"3B","G#":"4B","Ab":"4B",
                    "D#":"5B","Eb":"5B","A#":"6B","Bb":"6B","F":"7B","C":"8B",
                    "G":"9B","D":"10B","A":"11B","E":"12B"]
let minorCamelot = ["G#":"1A","Ab":"1A","D#":"2A","Eb":"2A","A#":"3A","Bb":"3A","F":"4A",
                    "C":"5A","G":"6A","D":"7A","A":"8A","E":"9A","B":"10A",
                    "F#":"11A","Gb":"11A","C#":"12A","Db":"12A"]

/// Distance on the Camelot wheel: same 0, ±1 hour 1, relative major/minor 1.
func camelotDistance(_ a: String, _ b: String) -> Int {
    guard let na = Int(a.dropLast()), let nb = Int(b.dropLast()),
          let la = a.last, let lb = b.last else { return 99 }
    let hop = min(abs(na - nb), 12 - abs(na - nb))
    return hop + (la == lb ? 0 : 1)
}

/// Tempo comparison tolerant of octave errors — 87 vs 174 is the same groove.
func tempoMatches(_ got: Double, _ want: Double, tolerance: Double = 2.0) -> (Bool, String) {
    for (mult, label) in [(1.0, "exact"), (2.0, "double-time"), (0.5, "half-time")] {
        if abs(got * mult - want) <= tolerance { return (true, label) }
    }
    return (false, "miss")
}

let args = CommandLine.arguments
guard args.count >= 3 else { fputs("usage: mu-validate <dataset.json> <audioDir>\n", stderr); exit(2) }
let truths = try JSONDecoder().decode([Truth].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let audioDir = URL(fileURLWithPath: args[2])

var tempoOK = 0, tempoOctave = 0, tempoMiss = 0, tempoNil = 0
var keyExact = 0, keyClose = 0, keyFar = 0, keyNil = 0
var analysed = 0

for t in truths {
    let url = audioDir.appendingPathComponent("\(t.sc_id).mp3")
    guard FileManager.default.fileExists(atPath: url.path) else { continue }
    let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    do {
        let session = try await MusicUnderstandingSession(asset: asset)
        let results = try await session.analyze()
        analysed += 1

        // --- tempo ---
        var tempoNote = "nil"
        if let bpm = results.rhythm?.beatsPerMinute.map({ Double($0) }) {
            let (ok, kind) = tempoMatches(bpm, t.bpm)
            tempoNote = String(format: "%.1f vs %.1f (%@)", bpm, t.bpm, kind)
            if ok && kind == "exact" { tempoOK += 1 }
            else if ok { tempoOctave += 1 }
            else { tempoMiss += 1 }
        } else { tempoNil += 1 }

        // --- key: take the longest-held key over the 30s window ---
        var keyNote = "nil"
        if let ranges = results.key?.ranges, let dominant = ranges.max(by: {
            CMTimeGetSeconds($0.range.duration) < CMTimeGetSeconds($1.range.duration) }) {
            let sig = dominant.value
            let tonic = "\(sig.tonic)"
            let table = "\(sig.mode)".lowercased().contains("minor") ? minorCamelot : majorCamelot
            if let cam = table[tonic] {
                let d = camelotDistance(cam, t.camelot)
                keyNote = "\(cam) vs \(t.camelot) (dist \(d))"
                if d == 0 { keyExact += 1 } else if d <= 1 { keyClose += 1 } else { keyFar += 1 }
            } else { keyNil += 1; keyNote = "unmapped tonic \(tonic)" }
        } else { keyNil += 1 }

        print("\(t.artist) — \(t.title)\n    tempo: \(tempoNote)\n    key:   \(keyNote)")
    } catch {
        print("\(t.artist) — \(t.title)\n    FAILED: \(error)")
    }
}

print("""

===========================================================
 Music Understanding accuracy — \(analysed) tracks analysed
===========================================================
 TEMPO
   exact (±2 BPM)      \(tempoOK)
   octave error        \(tempoOctave)   <- recoverable by the <100 doubling rule
   miss                \(tempoMiss)
   nil (too short)     \(tempoNil)

 KEY  (from a 30-second preview)
   exact Camelot       \(keyExact)
   within 1 hop        \(keyClose)   <- still musically usable
   wrong               \(keyFar)
   nil / unmapped      \(keyNil)
===========================================================

DECISION RULE
  If key 'exact + within 1 hop' is comfortably the majority, keep key automatic.
  Otherwise key degrades to a soft/manual field and BPM stays automatic — the
  sequencer tolerates this by design, since Camelot distance only ORDERS
  survivors and never excludes them.
""")
