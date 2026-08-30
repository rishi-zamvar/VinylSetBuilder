import SwiftUI
import VinylSetBuilderCore

/// CRATE-03/04/05/06 + SEQ-07/SEQ-11. Holds no rules: every ordering decision was made and
/// tested in `CrateDetailModel`. This screen renders the order it is handed and forwards taps.
struct CrateDetailView: View {
    let model: AppModel
    let crateID: UUID

    @State private var detail: CrateDetailModel?
    @State private var editMode: EditMode = .inactive

    /// D2-3: synchronous, deliberately. Off-main-thread sequencing is SEQ-09 and belongs to
    /// Phase 9; at fixture scale a full re-derivation is microseconds.
    private let sequencer = BeamSearchSequencer()

    var body: some View {
        Group {
            if let detail {
                list(detail)
                    .navigationTitle(detail.crateName)
            } else {
                ProgressView()
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // `RootView` swaps content on `Route` rather than pushing, so there is no
                // system back button — this control is the only way off this screen.
                Button("Crates") { model.store.closeToList() }
                    .accessibilityIdentifier("back-to-crates-button")
            }
            ToolbarItem(placement: .primaryAction) {
                // What makes `.onMove`'s drag handles appear: a List outside edit mode
                // offers none, and the walk cannot drag what is not there.
                EditButton()
                    .accessibilityIdentifier("edit-button")
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Add More") { model.store.addMore(to: crateID) }   // CRATE-05
                    .accessibilityIdentifier("add-more-button")
            }
        }
        .task(id: crateID) { load() }
    }

    // MARK: Sections

    private func list(_ detail: CrateDetailModel) -> some View {
        List {
            runningOrder(detail)
            if detail.rows.showsNotIncludedSection {      // SEQ-07: one bucket, and the
                Section {                                 // caller owns its visibility.
                    NotIncludedSectionView(rows: detail.rows.notIncluded,
                                           header: detail.rows.notIncludedHeader)
                        .accessibilityIdentifier("not-included-section")
                }
            }
        }
        .accessibilityIdentifier("crate-detail-list")
    }

    /// CRATE-03 (the order), CRATE-04 (drag to override), CRATE-06 (delete), SEQ-11 (badges).
    @ViewBuilder
    private func runningOrder(_ detail: CrateDetailModel) -> some View {
        Section {
            if detail.rows.sequenced.isEmpty {
                // A newly created crate lands here, and a blank screen reads as a crash.
                Text("Nothing sequenced yet")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("empty-running-order")
            } else {
                ForEach(detail.rows.sequenced) { row in
                    SequencedRowView(row: row)
                        .accessibilityIdentifier("sequenced-row-\(row.indexLabel)")
                }
                .onMove { offsets, offset in                         // CRATE-04
                    var edited = detail
                    edited.moveRows(fromOffsets: offsets, toOffset: offset)
                    commit(edited)
                }
                .onDelete { offsets in                               // CRATE-06
                    // A row is a track; removing it removes the whole VINYL, because a crate
                    // holds vinyls and the sequencer picks one track from each.
                    removeVinyls(offsets.map { detail.rows.sequenced[$0].vinylID })
                }
            }
        } header: {
            HStack {
                Text(detail.orderingMode == .manual ? "Custom order" : "Running order")
                    .accessibilityIdentifier("ordering-mode-label")
                Spacer()
                if detail.orderingMode == .manual {
                    Button("Restore") {
                        var edited = detail
                        edited.clearManualOrder()
                        commit(edited)
                    }
                    .accessibilityIdentifier("restore-sequenced-order-button")
                }
            }
        }
    }

    // MARK: The only three store interactions this screen makes

    /// Rebuild from the store's truth and re-derive the whole sequence. Called on appear and
    /// after any store mutation. A crate that is gone (it was deleted) closes the screen
    /// rather than rendering an empty one.
    private func load() {
        guard let crate = model.store.crate(crateID) else { model.store.closeToList(); return }
        var rebuilt = CrateDetailModel(crate: crate)
        rebuilt.resequence(using: sequencer)
        detail = rebuilt
    }

    /// Write an edited crate value back. One place, so a manual reorder cannot silently fail
    /// to persist across a navigation.
    private func commit(_ edited: CrateDetailModel) {
        model.store.update(edited.crate)
        detail = edited
    }

    /// CRATE-06. Every ID is resolved from one snapshot before any removal, so a multi-row
    /// delete cannot shift indices out from under itself; one re-derivation at the end.
    private func removeVinyls(_ vinylIDs: [UUID]) {
        for vinylID in vinylIDs { model.store.removeVinyl(vinylID, from: crateID) }
        load()
    }
}
