import Observation
import VinylSetBuilderCore

/// The single stateful object in the app. Holds a `CrateStore` value; every rule that
/// decides *what is true* lives in Core and was tested there — this wrapper only makes
/// mutation observable to SwiftUI.
@Observable
@MainActor
final class AppModel {
    var store: CrateStore = FixtureCrates.demoStore
}
