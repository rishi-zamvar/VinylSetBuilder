import SwiftUI
import VinylSetBuilderCore

/// CRATE-02: naming and routing happen in one `CrateStore.createCrate` call, so this sheet
/// never navigates itself — it dismisses, and the root stack follows the route the store set.
struct NewCrateSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Crate name", text: $name)
                    .accessibilityIdentifier("new-crate-name-field")
            }
            .navigationTitle("New Crate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("new-crate-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        model.store.createCrate(named: name)
                        dismiss()
                    }
                    .accessibilityIdentifier("new-crate-create-button")
                }
            }
        }
    }
}
