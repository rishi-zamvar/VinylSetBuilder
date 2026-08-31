// vinylctl — the whole pipeline, from the command line, over the SAME code the app runs.
//
// **One pipeline, two front ends.** Nothing here is an implementation of anything. Every stage
// is a call into either `VinylSetBuilderCore` or the app's own adapters, in the same order and
// with the same arguments the app uses:
//
//   | stage      | what runs                            | the app's call site                |
//   | ---------- | ------------------------------------ | ---------------------------------- |
//   | read       | App/OCR/SleeveTextRecognizer         | SleevePhotoSource.read             |
//   | segment    | Core/AngleClusterSegmenter          | CaptureView.shoot                  |
//   | status     | Core/SleeveStatus                    | SleevePhotoSource.read             |
//   | entry      | Core/CaptureSession.vinylEntry       | CaptureView.shoot                  |
//   | resolve    | App/SleevePipeline.process           | CrateDetailView.resolvePending     |
//   | sequence   | Core/AsyncSequencer.sequence         | CrateDetailView.load               |
//   | rows       | Core/CrateRows.make                  | CrateDetailModel.apply             |
//
// If a stage is wrong here it is wrong on the phone, and vice versa. That is the point of the
// CLI: the pipeline becomes bisectable without a simulator, and its answer becomes diffable.
//
// Run it with Scripts/vinylctl.sh.

import Foundation
import VinylSetBuilderCore

// MARK: - Arguments

let arguments = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    vinylctl — the Vinyl Set Builder pipeline, headless

      vinylctl ocr       <photo…>              what the reader returned
      vinylctl segment   <photo…>              the track lines, sides and catalogue number
      vinylctl resolve   <photo…>              identity per line, and the rung that answered
      vinylctl analyze   <photo…>              the BPM ladder's answer per identified track
      vinylctl sequence  <photo…>              all of it, and the sequenced set

    options
      --tolerance <3…6>   BPM tolerance for `sequence` (default 4.0, SEQ-05)
      --label <name>      names the artefact written to Artifacts/vinylctl/ (default "latest")
      --json              print the machine-readable form to stdout instead of the report

    Every stage is the code the app runs. Nothing here is a re-implementation.
    """)
    exit(2)
}

guard let command = arguments.first, !command.hasPrefix("-") else { usage() }

var photoPaths: [String] = []
var tolerance = BPMRules.defaultTolerance
var label = "latest"
var wantsJSON = false

var index = 1
while index < arguments.count {
    switch arguments[index] {
    case "--tolerance":
        index += 1
        guard index < arguments.count, let value = Double(arguments[index]) else { usage() }
        tolerance = value
    case "--label":
        index += 1
        guard index < arguments.count else { usage() }
        label = arguments[index]
    case "--json":
        wantsJSON = true
    case let other where other.hasPrefix("-"):
        usage()
    case let path:
        photoPaths.append(path)
    }
    index += 1
}

guard !photoPaths.isEmpty else {
    FileHandle.standardError.write(Data("vinylctl: no photographs given\n".utf8))
    usage()
}

let photos = photoPaths.map(URL.init(fileURLWithPath:)).sorted { $0.lastPathComponent < $1.lastPathComponent }
for photo in photos where !FileManager.default.fileExists(atPath: photo.path) {
    FileHandle.standardError.write(Data("vinylctl: no such file: \(photo.path)\n".utf8))
    exit(2)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

// MARK: - Formatting

func pad(_ value: String, _ width: Int) -> String {
    let trimmed = value.count > width ? String(value.prefix(width - 1)) + "…" : value
    return trimmed + String(repeating: " ", count: max(0, width - trimmed.count))
}

func rule(_ width: Int = 92) { print(String(repeating: "-", count: width)) }

func heading(_ text: String) {
    print("")
    print(text)
    print(String(repeating: "=", count: text.count))
}

/// One line, one field — deliberately the same discipline `CrateDump` uses, because this file's
/// output is committed as a baseline and a baseline is only useful if a diff points at a field.
func oneLine(_ text: String) -> String {
    text.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
}

// MARK: - Stage 1 and 2 — read and segment, per photograph

/// Everything one photograph became on the way to being a record. Held so each subcommand can
/// stop at the rung it cares about without a second pass over the images.
struct ReadSleeve {
    let url: URL
    let item: CaptureItem
    let segmentation: LabelSegmentation
    let entry: VinylEntry
    let milliseconds: Int
}

let recognizer = SleeveTextRecognizer()

func readAll() async throws -> [ReadSleeve] {
    // `CaptureSession` is the app's own accumulator, not a local array: `vinylEntry(for:)` —
    // including the candidate renumbering and the catalogue-number handoff — lives on it, and a
    // hand-rolled equivalent here would be exactly the second implementation this tool exists
    // to avoid.
    var session = CaptureSession(crateID: UUID())
    var sleeves: [ReadSleeve] = []

    for (offset, url) in photos.enumerated() {
        let started = Date()
        // The two-phase shape of CAP-01, kept even though nothing here is waiting on a shutter:
        // the reading item is what the app puts in the strip, and skipping it would mean this
        // tool exercised a path the app does not take.
        let pending = CaptureItem(index: offset + 1, photoRef: url.lastPathComponent,
                                  observations: [], sideMarkers: [], status: .reading)
        session.append(pending)

        let sleeve = try? await recognizer.recognise(imageAt: url)
        let segmentation = sleeve.map {
            AngleClusterSegmenter(orientation: $0.orientation)
                .segment($0.observations, vinylID: pending.id, side: .a)
        }
        let read = CaptureItem(
            id: pending.id, index: pending.index, photoRef: url.lastPathComponent,
            observations: sleeve?.observations ?? [],
            sideMarkers: segmentation?.sides ?? [],
            status: segmentation.map(SleeveStatus.status(for:)) ?? .unread,
            orientation: sleeve?.orientation ?? .right)
        session.replace(read)

        guard let segmentation,
              let entry = session.vinylEntry(
                for: read.id,
                segmenter: AngleClusterSegmenter(orientation: read.orientation))
        else {
            FileHandle.standardError.write(
                Data("vinylctl: \(url.lastPathComponent) could not be read at all\n".utf8))
            continue
        }
        sleeves.append(ReadSleeve(url: url, item: read, segmentation: segmentation, entry: entry,
                                  milliseconds: Int(Date().timeIntervalSince(started) * 1000)))
    }
    return sleeves
}

// MARK: - Reports, per subcommand

func reportOCR(_ sleeves: [ReadSleeve]) {
    heading("OCR — what the reader returned (OCR-01/02/03)")
    print(pad("photograph", 18) + pad("obs", 5) + pad("trusted", 9) + pad("orient", 8)
          + pad("ms", 6) + "first trusted reading")
    rule()
    for sleeve in sleeves {
        let trusted = sleeve.item.observations.filter(TrackTextFilter.isTrusted)
        print(pad(sleeve.url.lastPathComponent, 18)
              + pad("\(sleeve.item.observations.count)", 5)
              + pad("\(trusted.count)", 9)
              + pad("\(sleeve.item.orientation.rawValue)", 8)
              + pad("\(sleeve.milliseconds)", 6)
              + oneLine(trusted.first?.text ?? "(nothing trusted)"))
    }
    let total = sleeves.reduce(0) { $0 + $1.item.observations.count }
    print("")
    print("\(sleeves.count) photographs, \(total) observations, "
          + "\(sleeves.reduce(0) { $0 + $1.item.observations.filter(TrackTextFilter.isTrusted).count }) trusted")
}

func reportSegment(_ sleeves: [ReadSleeve]) {
    heading("Segmentation — track lines, sides and catalogue numbers (SEG-01…08)")
    for sleeve in sleeves {
        print("\(sleeve.url.lastPathComponent)  [\(sleeve.item.status.label)]"
              + "  catalogue=\(sleeve.segmentation.catalogueNumber ?? "-")"
              + "  sides=\(sleeve.segmentation.sides.isEmpty ? "-" : sleeve.segmentation.sides.joined(separator: "|"))")
        for track in sleeve.entry.orderedCandidates {
            print("    \(track.position + 1). \(oneLine(track.rawOCRText))")
        }
        if sleeve.entry.candidates.isEmpty { print("    (no track lines)") }
    }
    let usable = sleeves.filter { !$0.entry.candidates.isEmpty }.count
    let catalogued = sleeves.filter { $0.segmentation.catalogueNumber != nil }.count
    print("")
    print("\(usable) of \(sleeves.count) records yielded at least one track line; "
          + "\(catalogued) of \(sleeves.count) carry a catalogue number")
}

// MARK: - Stage 3 and 4 — the two ladders, through the app's own composition root

/// **`SleevePipeline` — the file `CrateDetailView` holds as `SleevePipeline.shared`.** Not a
/// rebuilt resolver and a rebuilt BPM ladder side by side: the same actor, with the same
/// throttles, the same cache and the same tier-0 corpus. The only argument it does not get from
/// `Bundle.main` is the corpus path, because a command-line tool has no bundle.
let pipeline = SleevePipeline(
    corpusURL: root.appendingPathComponent("App/Generated/bpmkey.tsv"))

struct ResolvedRecord {
    let sleeve: ReadSleeve
    let tracks: [Track]
    let milliseconds: Int

    var entry: VinylEntry {
        var filled = sleeve.entry
        filled.candidates = tracks
        return filled
    }
}

func resolveAll(_ sleeves: [ReadSleeve]) async -> [ResolvedRecord] {
    var records: [ResolvedRecord] = []
    for sleeve in sleeves {
        // Sequential, exactly as `CrateDetailView.resolvePending` is, and for its reason:
        // `TrackResolver` already holds RES-02's three-in-flight bound WITHIN a sleeve, and
        // running sleeves concurrently on top of it would multiply the bound and make the two
        // throttles fight.
        let started = Date()
        let tracks = await pipeline.process(sleeve.entry)
        records.append(ResolvedRecord(sleeve: sleeve, tracks: tracks,
                                      milliseconds: Int(Date().timeIntervalSince(started) * 1000)))
    }
    return records
}

/// Why this line has no identity, in the record's own words rather than a shrug. A line the
/// ladder never reached says so; a line it reached and could not answer prints what it wrote
/// down.
func identityOrReason(_ track: Track) -> String {
    if let artist = track.artist, let title = track.title { return "\(artist) — \(title)" }
    if let artist = track.artist { return "\(artist) — (no title)" }
    if let reason = track.failureReason { return "(unresolved: \(reason))" }
    return "(unresolved: nothing matched '\(oneLine(track.rawOCRText))')"
}

func reportResolve(_ records: [ResolvedRecord]) {
    heading("Resolution — identity per track line (RES-01…08)")
    for record in records {
        print("\(record.sleeve.url.lastPathComponent)  "
              + "catalogue=\(record.sleeve.segmentation.catalogueNumber ?? "-")  "
              + "\(record.milliseconds) ms")
        for track in record.tracks {
            print("    " + pad(track.resolutionState.rawValue, 10)
                  + pad(oneLine(track.rawOCRText), 34) + "-> " + identityOrReason(track))
        }
        if record.tracks.isEmpty { print("    (no track lines to resolve)") }
    }
    let lines = records.flatMap(\.tracks)
    let identified = lines.filter { $0.artist != nil && $0.title != nil }.count
    let records6 = records.filter { r in r.tracks.contains { $0.artist != nil && $0.title != nil } }.count
    print("")
    print("\(identified) of \(lines.count) track lines identified, "
          + "across \(records6) of \(records.count) records")
}

func reportAnalyze(_ records: [ResolvedRecord]) {
    heading("BPM & key — the ladder's answer per track (BPM-01…08)")
    print(pad("photograph", 18) + pad("identity", 42) + pad("bpm", 8) + pad("key", 5) + "note")
    rule()
    for record in records {
        for track in record.tracks {
            let badges = TrackBadges(track: track)
            print(pad(record.sleeve.url.lastPathComponent, 18)
                  + pad(identityOrReason(track), 42)
                  + pad(badges.bpm, 8) + pad(badges.key, 5)
                  + (track.bpm == nil ? (track.failureReason ?? "") : ""))
        }
    }
    let lines = records.flatMap(\.tracks)
    let tempos = lines.filter { $0.bpm != nil }.count
    let keys = lines.filter { $0.camelot != nil }.count
    print("")
    print("\(tempos) of \(lines.count) track lines carry a tempo; \(keys) carry a key")
}

// MARK: - Stage 5 — the set

func reportSequence(_ records: [ResolvedRecord], crate: Crate, rows: CrateRows,
                    result: SequenceResult) {
    heading("Records — what each photograph became")
    for record in records {
        print("")
        print("\(record.sleeve.url.lastPathComponent)   [\(record.sleeve.item.status.label)]"
              + "   catalogue: \(record.sleeve.segmentation.catalogueNumber ?? "none found")")
        let trusted = record.sleeve.item.observations.filter(TrackTextFilter.isTrusted)
        print("  read      \(trusted.count) trusted of \(record.sleeve.item.observations.count) observations"
              + "  — " + oneLine(trusted.prefix(4).map(\.text).joined(separator: " / ")))
        if record.tracks.isEmpty {
            print("  tracks    none — nothing on this sleeve segmented into a track line")
            continue
        }
        for track in record.tracks {
            let badges = TrackBadges(track: track)
            print("  track \(track.position + 1)   " + pad(oneLine(track.rawOCRText), 32)
                  + "-> " + identityOrReason(track)
                  + "   [\(badges.bpm) / \(badges.key)]")
        }
    }

    heading("The set — \(rows.sequenced.count) records, tolerance ±\(ExclusionReason.outsideWindow(tolerance: crate.bpmTolerance).split(separator: " ")[3])")
    if rows.sequenced.isEmpty {
        print("(empty — no two records were within the tolerance of each other)")
    } else {
        print(pad("#", 4) + pad("track", 56) + pad("bpm", 8) + "key")
        rule(76)
        for row in rows.sequenced {
            print(pad(row.indexLabel, 4) + pad(oneLine(row.title), 56)
                  + pad(row.badges.bpm, 8) + row.badges.key)
        }
        print("")
        print("total Camelot distance across the set: \(result.totalCamelotDistance)")
    }

    heading(rows.notIncludedHeader)
    if rows.notIncluded.isEmpty {
        print("(nothing — every record made the set)")
    } else {
        print(pad("record", 34) + pad("bpm", 8) + pad("key", 5) + "why not")
        rule()
        for row in rows.notIncluded {
            print(pad(oneLine(row.label), 34) + pad(row.badges.bpm, 8)
                  + pad(row.badges.key, 5) + row.reason)
        }
    }
}

// MARK: - The machine-readable form, so a future change is diffable

struct JSONTrack: Encodable {
    let raw: String, artist: String?, title: String?
    let bpm: Double?, camelot: String?, state: String, failure: String?
}
struct JSONRecord: Encodable {
    let photo: String, status: String, catalogue: String?
    let observations: Int, trusted: Int, tracks: [JSONTrack]
}
struct JSONRow: Encodable { let index: String, title: String, bpm: String, key: String }
struct JSONBucketRow: Encodable { let label: String, bpm: String, key: String, reason: String }
struct JSONReport: Encodable {
    let tolerance: Double
    let records: [JSONRecord]
    let sequence: [JSONRow]
    let notIncluded: [JSONBucketRow]
    let totalCamelotDistance: Int
}

func jsonReport(_ records: [ResolvedRecord], rows: CrateRows, result: SequenceResult,
                tolerance: Double) -> JSONReport {
    JSONReport(
        tolerance: tolerance,
        records: records.map { record in
            JSONRecord(
                photo: record.sleeve.url.lastPathComponent,
                status: record.sleeve.item.status.rawValue,
                catalogue: record.sleeve.segmentation.catalogueNumber,
                observations: record.sleeve.item.observations.count,
                trusted: record.sleeve.item.observations.filter(TrackTextFilter.isTrusted).count,
                tracks: record.tracks.map {
                    JSONTrack(raw: $0.rawOCRText, artist: $0.artist, title: $0.title,
                              bpm: $0.bpm, camelot: $0.camelot,
                              state: $0.resolutionState.rawValue, failure: $0.failureReason)
                })
        },
        sequence: rows.sequenced.map {
            JSONRow(index: $0.indexLabel, title: $0.title, bpm: $0.badges.bpm, key: $0.badges.key)
        },
        notIncluded: rows.notIncluded.map {
            JSONBucketRow(label: $0.label, bpm: $0.badges.bpm, key: $0.badges.key, reason: $0.reason)
        },
        totalCamelotDistance: result.totalCamelotDistance)
}

// MARK: - Run

let sleeves = try await readAll()

switch command {
case "ocr":
    reportOCR(sleeves)

case "segment":
    reportSegment(sleeves)

case "resolve":
    reportResolve(await resolveAll(sleeves))

case "analyze", "analyse":
    reportAnalyze(await resolveAll(sleeves))

case "sequence":
    let records = await resolveAll(sleeves)
    // The crate the app would hold after the same twelve shutter presses. `bpmTolerance` is
    // clamped through the same function `CrateStore.setBPMTolerance` uses, so `--tolerance 9`
    // means on the command line exactly what dragging the slider past its stop means.
    let crate = Crate(name: "vinylctl",
                      vinyls: records.enumerated().map { offset, record in
                          var entry = record.entry
                          entry.position = offset
                          return entry
                      },
                      bpmTolerance: BPMRules.clampTolerance(tolerance))
    // **The app's two calls, in the app's order.** `CrateDetailView.load()` is:
    //     AsyncSequencer().sequence(candidates: model.sequencerInput, bpmTolerance: …)
    //     model.apply(result)          -> CrateRows.make(result:crate:)
    // `CrateDetailModel` is used rather than `crate.allCandidates` because CRATE-07's pinning
    // lives in `sequencerInput`, and sequencing the raw candidate list is a DIFFERENT question
    // from the one the screen asks.
    var model = CrateDetailModel(crate: crate)
    let result = await AsyncSequencer().sequence(candidates: model.sequencerInput,
                                                 bpmTolerance: crate.bpmTolerance)
    model.apply(result)
    let rows = model.rows

    if wantsJSON {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(data: try encoder.encode(jsonReport(records, rows: rows, result: result, tolerance: crate.bpmTolerance)),
                     encoding: .utf8) ?? "{}")
    } else {
        reportSequence(records, crate: crate, rows: rows, result: result)
    }

    let out = root.appendingPathComponent("Artifacts/vinylctl")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(jsonReport(records, rows: rows, result: result, tolerance: crate.bpmTolerance))
        .write(to: out.appendingPathComponent("sequence-\(label).json"))
    if !wantsJSON {
        print("")
        print("wrote Artifacts/vinylctl/sequence-\(label).json")
    }

default:
    usage()
}
