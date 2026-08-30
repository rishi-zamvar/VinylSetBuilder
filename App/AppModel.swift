import Foundation
import Observation
import VinylSetBuilderCore

/// The single stateful object in the app. Holds a `CrateStore` value; every rule that
/// decides *what is true* lives in Core and was tested there — this wrapper only makes
/// mutation observable to SwiftUI.
@Observable
@MainActor
final class AppModel {
    var store: CrateStore = FixtureCrates.demoStore

    /// **RES-02's "per-item status visible in the UI".** The vinyls whose resolution is in
    /// flight right now. A set of ids rather than a status ON the record, because it is a
    /// property of what the app is doing at this instant and not of the record — persisting it
    /// would leave a crate permanently "Resolving…" after a crash.
    var resolving: Set<UUID> = []

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
