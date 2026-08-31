import Foundation
import SwiftData
import VinylSetBuilderCore

/// PERS-01 and PERS-04: the crate list, on this device and nowhere else, surviving the app being
/// killed. One object, three verbs.
///
/// **Save is a FULL REWRITE.** Every crate is deleted and re-inserted on every change.
/// `ponytail: full rewrite; swap to an upsert diff when a crate list outgrows a phone screen.`
/// At this project's scale — a handful of crates, tens of vinyls, hundreds of tracks — the whole
/// write is a few milliseconds, and an upsert has to reconcile three levels of identity, cascade
/// deletes and relationship reattachment to save none of them. Every merge bug that reconciliation
/// could have is a bug that silently loses a hand-typed record, which is the one failure this
/// phase exists to prevent.
///
/// A container that cannot be opened degrades to **in-memory**: the app still runs, the crate is
/// still usable for the evening, and nothing is claimed to be saved that was not. Refusing to
/// launch over a storage fault would be worse.
@MainActor
final class CrateArchive {
    private let container: ModelContainer?

    /// True when the store is on disk. A caller that says "saved" without checking this would be
    /// lying on the one launch it matters.
    let isPersistent: Bool

    init(inMemory: Bool = false) {
        let schema = Schema([CrateRecord.self, VinylRecord.self, TrackRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        if let opened = try? ModelContainer(for: schema, configurations: [configuration]) {
            container = opened
            isPersistent = !inMemory
        } else {
            // Second attempt, in memory, so a corrupt store on disk cannot brick the app.
            container = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            isPersistent = false
        }
    }

    /// Newest first, matching `CrateStore`'s own contract — from `listPosition`, never from the
    /// order a fetch happened to return.
    func load() -> [Crate] {
        guard let context = container?.mainContext,
              let records = try? context.fetch(FetchDescriptor<CrateRecord>())
        else { return [] }
        return records.sorted { $0.listPosition < $1.listPosition }.map(\.domain)
    }

    func save(_ crates: [Crate]) {
        guard let context = container?.mainContext else { return }
        wipe(context)
        for (index, crate) in crates.enumerated() {
            // Parent into the context FIRST, then the children — relationship setup is
            // order-sensitive and setting a non-inserted parent fails intermittently.
            let crateRecord = CrateRecord.make(from: crate, listPosition: index)
            context.insert(crateRecord)
            var vinylRecords: [VinylRecord] = []
            for vinyl in crate.vinyls {
                let vinylRecord = VinylRecord.make(from: vinyl)
                context.insert(vinylRecord)
                var trackRecords: [TrackRecord] = []
                for track in vinyl.candidates {
                    let trackRecord = TrackRecord.make(from: track)
                    context.insert(trackRecord)
                    trackRecords.append(trackRecord)
                }
                vinylRecord.candidates = trackRecords
                vinylRecords.append(vinylRecord)
            }
            crateRecord.vinyls = vinylRecords
        }
        try? context.save()
    }

    func wipe() {
        guard let context = container?.mainContext else { return }
        wipe(context)
        try? context.save()
    }

    /// Children first, then parents. `.cascade` should make the last call sufficient on its own;
    /// doing all three explicitly costs two lines and removes any dependence on cascade ordering
    /// leaving an orphaned row behind that a later fetch would resurrect.
    private func wipe(_ context: ModelContext) {
        try? context.delete(model: TrackRecord.self)
        try? context.delete(model: VinylRecord.self)
        try? context.delete(model: CrateRecord.self)
    }
}
