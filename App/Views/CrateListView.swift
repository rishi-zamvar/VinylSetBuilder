import SwiftUI
import VinylSetBuilderCore

/// CRATE-01: a thin projection of `CrateSummary`. Every decision (what counts as a record,
/// what order crates appear in, what a delete does) was tested in `CrateStoreTests` — this
/// view only renders the result and forwards taps.
struct CrateListView: View {
    let model: AppModel
    @State private var showingNewCrateSheet = false

    var body: some View {
        List {
            ForEach(model.store.summaries) { summary in
                Button {
                    model.store.open(summary.id)
                } label: {
                    HStack {
                        Text(summary.name)
                        Spacer()
                        // V1: automatic grammar agreement — "1 record" / "4 records".
                        Text("^[\(summary.recordCount) record](inflect: true)")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("record-count-\(summary.name)")
                    }
                    // Measured 2026-08-30, not guessed: without this, a tap landing in the
                    // HStack's Spacer gap hit-tests to nothing and the row does not open. The
                    // XCUITest tapped the button's centre and stayed on the list; a tap on the
                    // name text navigated. Hit-testing only — no visual or structural change,
                    // so V2's evidence is intact.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("crate-row-\(summary.name)")
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        model.store.deleteCrate(summary.id)
                    }
                }
            }
        }
        .accessibilityIdentifier("crate-list")
        .overlay {
            if model.store.summaries.isEmpty {
                ContentUnavailableView("No Crates Yet", systemImage: "square.stack",
                                        description: Text("Tap + to start a new crate."))
            }
        }
        .navigationTitle("Crates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewCrateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("new-crate-button")
            }
        }
        .sheet(isPresented: $showingNewCrateSheet) {
            NewCrateSheet(model: model)
        }
    }
}
