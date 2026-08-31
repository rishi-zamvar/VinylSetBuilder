import SwiftUI
import VinylSetBuilderCore

/// CRATE-03/04/05/06 + SEQ-07/SEQ-11. Holds no rules: every ordering decision was made and
/// tested in `CrateDetailModel`. This screen renders the order it is handed and forwards taps.
struct CrateDetailView: View {
    let model: AppModel
    let crateID: UUID

    @State private var detail: CrateDetailModel?
    @State private var editMode: EditMode = .inactive

    /// **MAN-05.** The track the hand-entry sheet is open on. One piece of state for BOTH
    /// entry points — the sequenced list and the not-included bucket present the same sheet, so
    /// there is no second presentation to keep in step, and no failure dialog is involved.
    @State private var editing: Track?

    /// SEQ-09: off the main actor. `AsyncSequencer` wraps the beam search in a
    /// `Task.detached` — this target defaults `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a
    /// plain `Task` here would inherit this screen's isolation and sequence on the main thread.
    /// Measured 100 vinyls / 400 candidates: 0.27 s optimised, 4.44 s in a debug test build.
    private let sequencer = AsyncSequencer()

    /// **Swap 3.** The resolution and BPM ladders, shared across the app so the cache and the
    /// SoundCloud token outlive one visit to one crate.
    private let pipeline = SleevePipeline.shared

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
                // NOT `EditButton()`. Measured 2026-08-30: toolbar content is hosted outside
                // this view's environment, so `EditButton` toggled the navigation controller's
                // own edit binding, flipped its label to "Done", and left `editMode` here
                // untouched — the List never entered edit mode. Driving the same state the
                // List reads is the whole fix.
                Button(editMode == .active ? "Done" : "Edit") {
                    editMode = editMode == .active ? .inactive : .active
                }
                .accessibilityIdentifier("edit-button")
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Add More") { model.store.addMore(to: crateID) }   // CRATE-05
                    .accessibilityIdentifier("add-more-button")
            }
        }
        .sheet(item: $editing) { track in
            ManualEntrySheet(track: track,
                             // The rest of the crate, so MAN-03 can offer this crate's own median
                             // rather than a global guess. The track itself is excluded or it
                             // would interpolate from the value being replaced.
                             neighbours: (detail?.crate.allCandidates ?? []).filter { $0.id != track.id },
                             onSave: commitEdit)
        }
        .task(id: crateID) {
            await load()
            await resolvePending()
        }
    }

    // MARK: Sections

    private func list(_ detail: CrateDetailModel) -> some View {
        List {
            runningOrder(detail)
            if detail.rows.showsNotIncludedSection {      // SEQ-07: one bucket, and the
                Section {                                 // caller owns its visibility.
                    // MAN-05, half two — and this is the half that matters, because after the
                    // last live run 9 of 12 records were in this bucket and none of them was
                    // reachable for correction at all.
                    NotIncludedSectionView(rows: detail.rows.notIncluded,
                                           header: detail.rows.notIncludedHeader,
                                           resolving: model.resolving,
                                           onEdit: { editing = track($0) })
                }
            }
        }
        .accessibilityIdentifier("crate-detail-list")
    }

    /// CRATE-03 (the order), CRATE-04 (drag to override), CRATE-06 (delete), SEQ-11 (badges).
    @ViewBuilder
    private func runningOrder(_ detail: CrateDetailModel) -> some View {
        Section {
            // The ForEach is deliberately NOT inside an `if` — measured 2026-08-30: wrapping
            // it in a conditional left the section with no movable ForEach, so edit mode
            // rendered no reorder grabbers and no delete circles at all. An empty ForEach
            // renders nothing, so the placeholder below covers the empty case instead.
            ForEach(detail.rows.sequenced) { row in
                SequencedRowView(row: row)
                    // Without .combine the identifier lands on all four leaf Texts (index,
                    // title, BPM, key) and every query matches four elements — measured, not
                    // assumed. One element per row is also the only thing a drag can grab.
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("sequenced-row-\(row.indexLabel)")
                    // MAN-05, half one. The ROW is the button: no mode to enter, no menu, no
                    // long press. `.contentShape` is load-bearing — without it only the text
                    // glyphs are hit-testable and the gaps between them do nothing.
                    .contentShape(Rectangle())
                    .onTapGesture { editing = track(row.id) }
            }
            .onMove { offsets, offset in                             // CRATE-04
                var edited = detail
                edited.moveRows(fromOffsets: offsets, toOffset: offset)
                commit(edited)
            }
            .onDelete { offsets in                                   // CRATE-06
                // A row is a track; removing it removes the whole VINYL, because a crate
                // holds vinyls and the sequencer picks one track from each.
                removeVinyls(offsets.map { detail.rows.sequenced[$0].vinylID })
            }

            if detail.rows.sequenced.isEmpty {
                // A newly created crate lands here, and a blank screen reads as a crash.
                Text("Nothing sequenced yet")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("empty-running-order")
            }
        } header: {
            HStack {
                // The count is in the header for the same reason the bucket's is: a `List`
                // only puts the rows it has drawn into the accessibility tree, so on a crate of
                // twelve there is no way — for a person scrolling or for a test — to know how
                // many are in the set without adding them up by eye.
                Text("\(detail.orderingMode == .manual ? "Custom order" : "Running order") "
                     + "(\(detail.rows.sequenced.count))")
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
    private func load() async {
        guard let crate = model.store.crate(crateID) else { model.store.closeToList(); return }
        var rebuilt = CrateDetailModel(crate: crate)
        let result = await sequencer.sequence(candidates: rebuilt.sequencerInput,
                                              bpmTolerance: crate.bpmTolerance)
        // Re-check: the crate can be deleted while the search is off-actor. Applying to a
        // screen whose crate is gone would render a set for a crate that no longer exists.
        guard model.store.crate(crateID) != nil else { model.store.closeToList(); return }
        rebuilt.apply(result)
        detail = rebuilt
    }

    /// **RES-02 and swap 4's missing edge, in one function.**
    ///
    /// Every record that nothing has yet put a name to goes down the two ladders, one record at
    /// a time. Sequential on purpose: `TrackResolver` already holds RES-02's three-in-flight
    /// bound WITHIN a sleeve, and running sleeves concurrently on top of that would multiply it
    /// and make the throttles fight each other for no gain — the whole crate is twelve records.
    ///
    /// **The crate re-sequences as each record lands**, rather than once at the end. That is
    /// the edge swap 4 was missing: the running order was derived once, on appear, before
    /// anything had a tempo, so a resolved crate sat in the not-included bucket looking broken.
    private func resolvePending() async {
        guard let crate = model.store.crate(crateID) else { return }
        let pending = crate.vinyls.filter(\.needsResolution)
        guard !pending.isEmpty else { return }

        model.resolving.formUnion(pending.map(\.id))
        defer { model.resolving.subtract(pending.map(\.id)) }

        for vinyl in pending {
            // The crate can be deleted, or left, while the network is busy.
            guard !Task.isCancelled, model.store.crate(crateID) != nil else { return }
            let resolved = await pipeline.process(vinyl)
            guard model.store.crate(crateID) != nil else { return }
            model.apply(resolved, toVinyl: vinyl.id, in: crateID)
            // **`load()` first, THEN clear the status.** Clearing it beforehand made
            // "nothing says Resolving" mean "the network is quiet", when what a person — and
            // the walk — reads it as is "the set on screen is the answer". The re-sequence
            // takes a few hundred milliseconds after the record lands, and in that window the
            // crate showed a running order it was about to replace. Measured: a walk read a
            // header saying two next to three drawn rows, one of them 36 BPM outside the gate,
            // because the two came from different renders.
            await load()
            model.resolving.remove(vinyl.id)
        }
    }

    /// MAN-05. Both lists identify their edit target by TRACK id — the sequenced row IS a track,
    /// and V19 gave the not-included row a `trackID` naming the same candidate its badges
    /// describe — so one lookup serves both.
    private func track(_ id: UUID?) -> Track? {
        guard let id else { return nil }
        return detail?.crate.allCandidates.first { $0.id == id }
    }

    /// MAN-01/MAN-04. Commit a hand-entered track through the store's one candidate mutator and
    /// re-derive the set: a record that has just been given a tempo may now belong in it, and
    /// SEQ-08's rejoin is a property of a full re-derivation, never of a merge.
    private func commitEdit(_ edited: Track) {
        model.store.updateTrack(edited, in: crateID)
        Task { await load() }
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
        Task { await load() }
    }
}
