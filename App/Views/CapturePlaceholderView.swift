import SwiftUI
import VinylSetBuilderCore

/// The camera does not exist until Phase 2. This is disposable scaffolding so the
/// create -> capture -> detail flow is walkable end-to-end tonight.
struct CapturePlaceholderView: View {
    let model: AppModel
    let crateID: UUID

    var body: some View {
        VStack(spacing: 16) {
            Text(model.store.crate(crateID)?.name ?? "Crate")
                .font(.title2.bold())
            Text("Camera arrives in Phase 2")
                .foregroundStyle(.secondary)
            Button("Add Fixture Vinyl") {
                let track = Track(vinylID: UUID(), artist: "Fixture Artist",
                                   title: "Fixture Track", bpm: 174, camelot: "5A")
                let vinyl = VinylEntry(id: track.vinylID, candidates: [track])
                model.store.addVinyl(vinyl, to: crateID)
            }
            .buttonStyle(.borderedProminent)
            Button("Done") {
                model.store.open(crateID)
            }
        }
        .padding()
        .navigationTitle("Capture")
    }
}
