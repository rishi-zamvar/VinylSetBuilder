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
            CaptureView(model: model, crateID: crateID)
        case .crateDetail(let crateID):
            CrateDetailView(model: model, crateID: crateID)
        }
    }
}
