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
                        Text("\(summary.recordCount) records")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        model.store.deleteCrate(summary.id)
                    }
                }
            }
        }
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
            }
        }
        .sheet(isPresented: $showingNewCrateSheet) {
            NewCrateSheet(model: model)
        }
    }
}
