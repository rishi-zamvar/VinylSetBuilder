// GATE 2 — the SoundCloud match rate, measured against the 40-track ground truth.
//
// It drives the SHIPPING `SoundCloudClient` and the SHIPPING `SoundCloudMatcher` over the
// SHIPPING URLSession transport. The only thing here that is not shipped is the cache, and the
// cache is why the second run is offline: every search response is written to
// .local/sc_cache/ and read back afterwards, so this gate costs the API once.
//
// Run it with Scripts/sc-score.sh.

import Foundation
import VinylSetBuilderCore

/// Reads from disk if it can, hits the network if it must, and never caches the token request —
/// a cached bearer token is an expired bearer token.
struct CachingTransport: HTTPFetching {
    let inner: URLSessionTransport
    let directory: URL

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard request.method == .get else { return try await inner.send(request) }
        let name = Data(request.url.absoluteString.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_") + ".json"
        let file = directory.appendingPathComponent(name)
        if let cached = try? Data(contentsOf: file) {
            return HTTPResponse(status: 200, body: cached)
        }
        let response = try await inner.send(request)
        if response.isOK {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? response.body.write(to: file)
        }
        return response
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let truthText = try String(contentsOf: root.appendingPathComponent(".local/truth.tsv"), encoding: .utf8)

struct Want { let artist: String, title: String }
let wants: [Want] = truthText.split(separator: "\n").compactMap { line in
    let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
    guard fields.count >= 2 else { return nil }
    return Want(artist: String(fields[0]), title: String(fields[1]))
}

/// What the earlier, throwaway probe matched. Kept as a SECOND observation of the same
/// quantity — if this implementation matches a wholly different 72%, that is worth knowing.
struct Previous: Decodable { let artist: String, title: String, sc_id: Int }
let previous = (try? JSONDecoder().decode([Previous].self, from: Data(contentsOf: root
    .appendingPathComponent(".local/mu_dataset.json")))) ?? []
let previousByTrack = Dictionary(previous.map { ("\($0.artist)|\($0.title)", $0.sc_id) },
                                 uniquingKeysWith: { first, _ in first })

guard !Secrets.soundCloudClientID.isEmpty else {
    FileHandle.standardError.write(Data("no SoundCloud credentials — run Scripts/generate-secrets.sh\n".utf8))
    exit(2)
}

let transport = CachingTransport(inner: URLSessionTransport(),
                                 directory: root.appendingPathComponent(".local/sc_cache"))
let client = SoundCloudClient(transport: ThrottledTransport(wrapping: transport, minimumInterval: 0.5),
                              clientID: Secrets.soundCloudClientID,
                              clientSecret: Secrets.soundCloudClientSecret)

struct Row: Encodable {
    let artist: String, title: String
    let matched: Bool, chosenID: Int?, chosenTitle: String?, chosenUser: String?
    let score: Double?, seconds: Double?, candidates: Int
    let previousID: Int?, agreesWithPrevious: Bool?
}

var rows: [Row] = []
for want in wants {
    let candidates = (try? await client.search("\(want.artist) \(want.title)")) ?? []
    let chosen = SoundCloudMatcher.best(among: candidates, artist: want.artist, title: want.title)
    let previousID = previousByTrack["\(want.artist)|\(want.title)"]
    rows.append(Row(artist: want.artist, title: want.title,
                    matched: chosen != nil, chosenID: chosen?.track.id,
                    chosenTitle: chosen?.track.title, chosenUser: chosen?.track.username,
                    score: chosen.map { ($0.score * 100).rounded() / 100 },
                    seconds: chosen?.track.seconds, candidates: candidates.count,
                    previousID: previousID,
                    agreesWithPrevious: previousID.map { $0 == chosen?.track.id }))
}

func pad(_ v: String, _ w: Int) -> String { v.count >= w ? v : v + String(repeating: " ", count: w - v.count) }

print("track                                     cand  score  dur    chosen")
print(String(repeating: "-", count: 100))
for row in rows {
    let name = "\(row.artist) — \(row.title)"
    print("\(pad(String(name.prefix(40)), 41)) \(pad("\(row.candidates)", 5)) "
          + "\(pad(row.score.map { String(format: "%.2f", $0) } ?? "-", 6)) "
          + "\(pad(row.seconds.map { String(format: "%.0fs", $0) } ?? "-", 6)) "
          + (row.chosenTitle.map { "\($0) — \(row.chosenUser ?? "")" } ?? "NO MATCH"))
}

let matched = rows.count(where: \.matched)
let total = rows.count
let rate = total == 0 ? 0 : 100.0 * Double(matched) / Double(total)
let comparable = rows.filter { $0.previousID != nil }
let agree = comparable.count { $0.agreesWithPrevious == true }
let baseline = 72.0

print("")
print(String(format: "GATE 2  SoundCloud match rate  %d of %d = %.1f%%   (baseline %.0f%%)",
             matched, total, rate, baseline))
print("        agrees with the earlier probe's pick on \(agree) of \(comparable.count) it also matched")

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let out = root.appendingPathComponent("Artifacts/bpm")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let stamp = ProcessInfo.processInfo.environment["SC_RUN_LABEL"] ?? "latest"
try encoder.encode(rows).write(to: out.appendingPathComponent("soundcloud-\(stamp).json"))
print("wrote Artifacts/bpm/soundcloud-\(stamp).json")

if rate + 1e-9 < baseline {
    print(String(format: "\nBASELINE NOT MET: %.1f%% < %.0f%%", rate, baseline))
    exit(1)
}
print("\nBASELINE HELD")
