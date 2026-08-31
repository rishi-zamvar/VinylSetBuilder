@preconcurrency import AVFoundation
import Foundation

/// CAP-01 — the camera, and the ONLY file in this project that names the capture framework.
///
/// Three decisions, all of them from the toolchain notes in `CLAUDE.md` §3 rather than from
/// taste, and all three are the reason this is a dedicated type instead of code in a view:
///
/// 1. **`startRunning()` blocks**, so configuration and start happen on this object's own
///    serial queue and never on the actor the shutter button is on.
/// 2. **The delegate callback is bridged with a `CheckedContinuation`**, so the call site is
///    `try await camera.capturePhoto()` — one line, no completion handler, no state machine in
///    the view.
/// 3. **`@preconcurrency import AVFoundation`, at this one boundary and nowhere else.** This
///    target defaults `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; AVFoundation's delegate
///    types are not `Sendable`-audited, and fighting that is a phase spent on warnings Apple's
///    own samples have not resolved.
///
/// **One capture in flight at a time.** `AVCapturePhotoOutput` queues or rejects overlapping
/// `capturePhoto` calls unpredictably, so a second request before the first callback lands is
/// refused here, where the refusal is legible, rather than in the framework where it is not.
final class SleeveCamera: NSObject, @unchecked Sendable {
    enum Failure: Error, Equatable {
        case noCaptureDevice
        case captureAlreadyInFlight
        case noPhotoData
    }

    /// Exposed read-only so the preview layer can attach to the SAME session the shutter uses.
    /// Without this the screen shows a black rectangle while the session runs unseen — which is
    /// exactly the bug the owner hit on the device: permissions granted, capture working, and
    /// nothing to aim at.
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    /// Guards `pending` as well as serialising session work: every touch of it happens here.
    private let queue = DispatchQueue(label: "com.rishizamvar.VinylSetBuilder.camera")
    private var pending: CheckedContinuation<Data, Error>?

    /// nil where there is no camera — which is every simulator, and is why this returns an
    /// optional instead of throwing at the call site on a condition that never changes.
    static func makeIfAvailable() -> SleeveCamera? {
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
        else { return nil }
        return SleeveCamera()
    }

    /// Fire and forget: the session comes up on its own queue while the screen is already drawn.
    /// CAP-01 is about the shutter, and a shutter cannot be non-blocking if the screen it sits
    /// on blocked to get there.
    func start() {
        queue.async { [self] in
            guard !session.isRunning else { return }
            configure()
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configure() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output)
        else { return }
        session.addInput(input)
        session.addOutput(output)
    }

    /// One shutter press. Returns the photograph's bytes; the caller owns them and this object
    /// keeps nothing.
    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(throwing: Failure.noCaptureDevice); return
                }
                guard pending == nil else {
                    continuation.resume(throwing: Failure.captureAlreadyInFlight); return
                }
                pending = continuation
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    /// Resume exactly once, whatever happened. A continuation left un-resumed hangs the shutter
    /// for the rest of the session, and one resumed twice traps.
    private func finish(_ result: Result<Data, Error>) {
        queue.async { [self] in
            guard let continuation = pending else { return }
            pending = nil
            continuation.resume(with: result)
        }
    }
}

extension SleeveCamera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error { finish(.failure(error)); return }
        guard let data = photo.fileDataRepresentation() else {
            finish(.failure(Failure.noPhotoData)); return
        }
        finish(.success(data))
    }
}
