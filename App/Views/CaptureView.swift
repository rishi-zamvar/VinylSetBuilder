import SwiftUI
import VinylSetBuilderCore

/// CAP-02 (the sleeve framing guide), CAP-03 (the thumbnail strip), CAP-05 (the inline flip
/// prompt) and CAP-06 (Done lands on the crate).
///
/// Holds no rules. Every decision it renders — how big the guide is, what a captured sleeve is
/// called, whether the flip prompt should fire, what status it carries — was made and tested in
/// `VinylSetBuilderCore`'s `Capture/` in plan 03-01. This screen shows what it is handed and
/// forwards taps, exactly the way `CrateDetailView` does.
///
/// **The preview is live on a device, and a dark rectangle only where no camera exists.**
/// It was a rectangle everywhere until 2026-08-30, which on a real phone meant a framing guide
/// drawn over nothing at all. The simulator
/// has no camera, so there is nothing to draw there; `SleevePhotoSource` supplies the frames
/// either way and nothing else on this screen moves — that is the whole point of the seam
/// being `async` from day one.
struct CaptureView: View {
    let model: AppModel
    let crateID: UUID

    /// **A fresh session on every entry to this screen is deliberate, not a lost-state bug.**
    /// CAP-03's own wording is "every vinyl scanned so far in *this session*", and CRATE-05's
    /// Add More is a new session by definition. What persists is the crate: every capture is
    /// committed to the store immediately, so leaving and returning loses nothing real.
    @State private var session: CaptureSession

    /// One source per screen appearance, so the strip fills in order rather than restarting or
    /// skipping. An `actor` — `capture()` advances a counter and holds the unread photographs.
    @State private var source: SleevePhotoSource

    /// The captured item whose inspect/correct sheet is open, if any. OCR-04 / SEG-07.
    @State private var inspecting: CaptureItem?

    init(model: AppModel, crateID: UUID) {
        self.model = model
        self.crateID = crateID
        _session = State(initialValue: CaptureSession(crateID: crateID))
        _source = State(initialValue: SleevePhotoSource())
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(model.store.crate(crateID)?.name ?? "Crate")
                .font(.title2.bold())
                .accessibilityIdentifier("capture-crate-name")

            previewArea

            // The spike measured the die-cut label at under a tenth of the frame. A big square
            // guide with no explanation invites exactly the label close-up it is trying to
            // prevent, so the guide says what it wants.
            Text("Fill the square with the whole sleeve — not just the label.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            flipPrompt

            CaptureThumbnailStrip(items: session.items) { item in
                inspecting = item
            }

            controls
        }
        .padding(.vertical, 12)
        .navigationTitle("Capture")
        .sheet(item: $inspecting) { item in
            // OCR-04 / SEG-07. Presented from the tap target the strip already had, so this
            // screen gained a sheet and not another button.
            InspectCorrectSheet(model: model, crateID: crateID, item: item)
        }
        .task(id: crateID) {
            // Same pattern as `CrateDetailView.load()`: rebuild the screen's own state from
            // scratch whenever the crate it is about changes.
            session = CaptureSession(crateID: crateID)
            source = SleevePhotoSource()
        }
    }

    // MARK: CAP-02 — the framing guide

    /// The guide's side length is read off `FramingGuide.sleeve`, never retyped. 03-01 tested
    /// that geometry (sleeve-sized, > 0.6 of the edge, against a label-sized control) precisely
    /// so this view cannot drift away from the number that was tested.
    private var previewArea: some View {
        GeometryReader { proxy in
            let guide = FramingGuide.sleeve
            let shorterEdge = min(proxy.size.width, proxy.size.height)
            let height = shorterEdge * guide.edgeCoverage
            let width = height * guide.aspectRatio

            ZStack {
                // The live camera where there is one; a dark rectangle only where there is
                // genuinely nothing to show (every simulator). Drawing black on a real device
                // was the bug: a framing guide over nothing.
                if let camera = source.camera {
                    CameraPreview(session: camera.session)
                        .accessibilityHidden(true)
                } else {
                    Rectangle().fill(Color.black)
                }
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: width, height: height)
                    .accessibilityElement()
                    .accessibilityLabel("Sleeve framing guide")
                    .accessibilityIdentifier("capture-framing-guide")
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minHeight: 220)
    }

    // MARK: CAP-05 — the inline prompt

    /// Inline, inside this screen's own body: no sheet, no alert, no push. CAP-05's wording is
    /// "without leaving the camera", and every one of those three is leaving it.
    @ViewBuilder
    private var flipPrompt: some View {
        if let pendingID = session.pendingFlipPrompt,
           let item = session.items.first(where: { $0.id == pendingID }) {
            FlipSidePromptView(
                item: item,
                onScan: {
                    session.dismissFlipPrompt()
                    Task { await shoot() }
                },
                onSkip: { session.dismissFlipPrompt() }
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: The shutter and Done

    /// The prompt above never gates either of these: a person who ignores it keeps shooting.
    private var controls: some View {
        ZStack {
            Button {
                Task { await shoot() }
            } label: {
                ZStack {
                    Circle().strokeBorder(Color.primary, lineWidth: 4)
                    Circle().fill(Color.primary).padding(7)
                }
                .frame(width: 68, height: 68)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shutter")
            .accessibilityIdentifier("capture-shutter-button")

            HStack {
                Spacer()
                Button("Done") { model.store.open(crateID) }   // CAP-06
                    .accessibilityIdentifier("capture-done-button")
            }
        }
        .padding(.horizontal, 24)
    }

    /// One shutter press, in two phases, and the split IS **CAP-01**.
    ///
    /// The tile is in the strip after `capture()` — bytes only, no recognition — so the shutter
    /// is live again immediately and nothing blocks. The read follows and the tile updates in
    /// place. There is no spinner anywhere in this function because there is nothing to wait on.
    ///
    /// The vinyl reaches the crate at the END, when there is something to put in it: committing
    /// a `.reading` item would file a record with no candidate lines and then have to correct it.
    ///
    /// **Swap 1 (Phase 8).** `FixtureLineSegmenter` — one line per trusted observation — is gone.
    /// This is the segmenter Phase 6 measured at 9 of 12 usable track counts and 6 of 6 catalogue
    /// numbers, built with the orientation the READER returned rather than the corpus's, so a
    /// photograph taken any other way up still segments (OCR-02).
    ///
    /// Names come from `CaptureItem.displayLabel` — the vinyl entry's own `label` is never
    /// called from this screen (D-03-6, defect V3).
    private func shoot() async {
        guard let item = await source.capture() else { return }
        session.append(item)

        guard let read = await source.read(item.id, index: item.index) else { return }
        session.replace(read)

        let segmenter = AngleClusterSegmenter(orientation: read.orientation)
        guard let entry = session.vinylEntry(for: read.id, segmenter: segmenter) else { return }
        model.store.addVinyl(entry, to: crateID)
    }
}
