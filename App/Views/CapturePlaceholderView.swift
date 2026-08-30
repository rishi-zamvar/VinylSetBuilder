import SwiftUI
import VinylSetBuilderCore

/// The camera does not exist until Phase 3. This is disposable scaffolding so the
/// create -> capture -> detail flow is walkable end-to-end tonight.
struct CapturePlaceholderView: View {
    let model: AppModel
    let crateID: UUID

    var body: some View {
        VStack(spacing: 16) {
            Text(model.store.crate(crateID)?.name ?? "Crate")
                .font(.title2.bold())
                .accessibilityIdentifier("capture-crate-name")
            Text("Camera arrives in Phase 3")
                .foregroundStyle(.secondary)
            Button("Add Fixture Vinyl") {
                let track = Track(vinylID: UUID(), artist: "Fixture Artist",
                                   title: "Fixture Track", bpm: 174, camelot: "5A")
                let vinyl = VinylEntry(id: track.vinylID, candidates: [track])
                model.store.addVinyl(vinyl, to: crateID)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("capture-add-fixture-button")
            Button("Done") {
                model.store.open(crateID)
            }
            .accessibilityIdentifier("capture-done-button")
        }
        .padding()
        .navigationTitle("Capture")
    }
}
