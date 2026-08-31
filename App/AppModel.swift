import Foundation
import Observation
import VinylSetBuilderCore

/// The single stateful object in the app. Holds a `CrateStore` value; every rule that
/// decides *what is true* lives in Core and was tested there — this wrapper only makes
/// mutation observable and, from Phase 9, durable.
@Observable
@MainActor
final class AppModel {
    /// PERS-01. Written back on every change that actually changes a crate.
    ///
    /// The guard matters: `CrateStore` carries `route`, so without it every navigation would
    /// rewrite the whole store. Comparing the crate array is a cheap value compare on a handful
    /// of records and it means a save happens when data changes rather than when a screen does.
    var store: CrateStore {
        didSet {
            guard store.crates != oldValue.crates else { return }
            archive.save(store.crates)
        }
    }

    /// **RES-02's "per-item status visible in the UI".** The vinyls whose resolution is in
    /// flight right now. A set of ids rather than a status ON the record, because it is a
    /// property of what the app is doing at this instant and not of the record — persisting it
    /// would leave a crate permanently "Resolving…" after a crash.
    var resolving: Set<UUID> = []

    private let archive: CrateArchive

    init(archive: CrateArchive = CrateArchive()) {
        self.archive = archive

        if LaunchOptions.seedProbe {
            archive.wipe()
            store = CrateStore(crates: [FixtureCrates.probeCrate(vinylCount: 20)])
            archive.save(store.crates)
        } else if LaunchOptions.reset {
            archive.wipe()
            store = CrateStore(crates: FixtureCrates.all)
            archive.save(store.crates)
        } else {
            let saved = archive.load()
            // An empty store is a first launch, not an empty crate list — the fixtures are the
            // seed, and they are written straight back so the second launch loads exactly what
            // the first one showed rather than re-seeding and looking identical by accident.
            store = CrateStore(crates: saved.isEmpty ? FixtureCrates.all : saved)
            if saved.isEmpty { archive.save(store.crates) }
        }

        if let label = LaunchOptions.dumpLabel {
            LaunchOptions.writeDump(store.crates, label: label)
        }
    }

    /// The one write path for a resolved record, so a screen never rebuilds a `Crate` by hand.
    /// A crate or vinyl that has gone while the network was busy is dropped, not resurrected.
    func apply(_ tracks: [Track], toVinyl vinylID: UUID, in crateID: UUID) {
        guard var crate = store.crate(crateID),
              let index = crate.vinyls.firstIndex(where: { $0.id == vinylID })
        else { return }
        crate.vinyls[index].candidates = tracks
        store.update(crate)
    }
}
