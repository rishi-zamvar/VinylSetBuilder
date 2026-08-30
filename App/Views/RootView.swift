import SwiftUI
import VinylSetBuilderCore

struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        NavigationStack {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.store.route {
        case .crateList:
            CrateListView(model: model)
        case .capture(let crateID):
            CapturePlaceholderView(model: model, crateID: crateID)
        case .crateDetail:
            // TODO(01-08): CrateDetailView — see 01-08-PLAN.md, which owns this file's
            // .crateDetail case and App/Views/CrateDetailView.swift.
            Text("Crate detail")
        }
    }
}
