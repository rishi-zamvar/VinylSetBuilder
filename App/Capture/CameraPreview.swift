import SwiftUI
@preconcurrency import AVFoundation

/// The live camera preview.
///
/// **Why this exists.** `CaptureView` originally drew `Rectangle().fill(Color.black)` where the
/// preview belongs, with a comment saying that was deliberate — and on the simulator it was,
/// because there is no camera to show. But it was never replaced for the device, so on a real
/// phone the owner got a black box with a framing guide on it: permissions granted, the session
/// running, photographs actually being captured, and nothing to aim at.
///
/// A framing guide over a black rectangle is worse than no guide at all — it tells you to line
/// something up while showing you nothing to line up with.
///
/// The layer attaches to the SAME `AVCaptureSession` the shutter uses. A second session would
/// contend with the first for the capture device.
struct CameraPreview: UIViewRepresentable {
    /// Stated explicitly rather than inferred. `UIViewRepresentable` would infer this from
    /// `makeUIView`'s return type, but an inferred associated type is invisible to the
    /// unreferenced-declaration sweep in `hygiene.sh`, which then reports `PreviewView` as dead
    /// code. It is not dead — it is this representable's entire reason to exist.
    typealias UIViewType = PreviewView

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        // .resizeAspectFill matches what the framing guide assumes: the shorter edge fills, so
        // a square guide at 0.88 of it frames a square sleeve.
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.videoPreviewLayer.session !== session {
            view.videoPreviewLayer.session = session
        }
    }

    /// Backing the layer directly, rather than adding a sublayer, is what keeps the preview
    /// correctly sized on rotation and on every layout pass — a manually added sublayer needs
    /// its frame maintained by hand and drifts the moment it is not.
    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
