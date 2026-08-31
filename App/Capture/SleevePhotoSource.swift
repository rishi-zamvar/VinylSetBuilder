import Foundation
import VinylSetBuilderCore

/// Where the capture screen's photographs come from, and what they turn into.
///
/// **This replaced `FixturePhotoSource`, which dealt out a hand-written table of readings and a
/// hand-scored verdict per record.** Nothing is transcribed here. A shutter press yields a
/// photograph; Vision reads it; `AngleClusterSegmenter` segments it; `SleeveStatus` scores it.
/// The twelve fixture photographs are still involved, but only as IMAGES, on the same footing
/// as anything the camera hands over — they go through the identical code path.
///
/// **CAP-01 is the two-phase shape.** `capture()` returns the moment the photograph exists,
/// with a `.reading` item, so the tile is in the strip and the shutter is live again. `read(_:)`
/// does the expensive part and the strip updates when it lands. There is no spinner because
/// there is nothing to wait for.
///
/// An `actor`: it holds the shot counter and the photographs not yet read.
actor SleevePhotoSource {
    /// Non-private so `CaptureView` can attach a preview layer to the live session.
    let camera: SleeveCamera?
    private let recognizer = SleeveTextRecognizer()
    private let fixtures: [URL]
    private var shotsTaken = 0
    /// The photograph behind each `.reading` item, until its read lands.
    private var awaitingRead: [CaptureItem.ID: URL] = [:]

    init() {
        camera = SleeveCamera.makeIfAvailable()
        fixtures = Self.bundledFixtures()
        camera?.start()
    }

    /// **The simulator has no camera**, so it reads the owner's twelve real photographs out of
    /// the app bundle instead, wrapping past the twelfth exactly as the fixture source did — a
    /// wrapped shot is a new record, not the old one again.
    ///
    /// ponytail: 25 MB of the owner's HEICs ship in the bundle to make the camera-less path
    /// real. Drop the `Tests/Fixtures/Labels` resource from `project.yml` once the device path
    /// is the only one that matters; nothing else references it.
    private static func bundledFixtures() -> [URL] {
        guard let directory = Bundle.main.url(forResource: "Labels", withExtension: nil),
              let contents = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        return contents.filter { $0.pathExtension.uppercased() == "HEIC" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// One shutter press. Nothing here reads anything: this returns as soon as there are bytes.
    func capture() async -> CaptureItem? {
        let url: URL
        if let camera {
            guard let data = try? await camera.capturePhoto(),
                  let written = try? Self.writeTemporary(data) else { return nil }
            url = written
        } else {
            guard !fixtures.isEmpty else { return nil }
            url = fixtures[shotsTaken % fixtures.count]
        }
        shotsTaken += 1
        let item = CaptureItem(index: shotsTaken, photoRef: url.lastPathComponent,
                               observations: [], sideMarkers: [], status: .reading)
        awaitingRead[item.id] = url
        return item
    }

    /// The read, off the main actor (`SleeveTextRecognizer` detaches). Returns the same item
    /// with everything the photograph turned out to say.
    ///
    /// A photograph the CAMERA produced is deleted the moment it has been read — the app keeps
    /// the text, never the image. A bundled fixture is not deleted, because it is a resource.
    func read(_ id: CaptureItem.ID, index: Int) async -> CaptureItem? {
        guard let url = awaitingRead.removeValue(forKey: id) else { return nil }
        defer { if camera != nil { try? FileManager.default.removeItem(at: url) } }

        guard let sleeve = try? await recognizer.recognise(imageAt: url) else {
            return CaptureItem(id: id, index: index, photoRef: url.lastPathComponent,
                               observations: [], sideMarkers: [], status: .unread)
        }
        let segmentation = AngleClusterSegmenter(orientation: sleeve.orientation)
            .segment(sleeve.observations, vinylID: id, side: .a)
        return CaptureItem(id: id, index: index, photoRef: url.lastPathComponent,
                           observations: sleeve.observations,
                           sideMarkers: segmentation.sides,
                           status: SleeveStatus.status(for: segmentation),
                           orientation: sleeve.orientation)
    }

    private static func writeTemporary(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sleeve-\(UUID().uuidString).heic")
        try data.write(to: url)
        return url
    }
}
