import Foundation
import VinylSetBuilderCore

/// The three switches the measured gates need, and nothing else.
///
/// **Deliberately not `-flag value` pairs.** iOS parses any launch argument beginning with `-`
/// into `UserDefaults`, which would both pollute the domain and swallow the following argument.
/// These are bare tokens, read straight out of `ProcessInfo`.
///
/// None of them does anything on a normally launched app: `ProcessInfo.arguments` carries only
/// the executable path unless a harness put something there.
enum LaunchOptions {
    /// Wipe the store and reseed the fixture crates. **Every UI test launches with this**, or
    /// the crate walk's final delete-everything step would poison the next run — which is
    /// precisely the state Phase 2 could rely on for free while nothing persisted.
    static var reset: Bool { has("vsb-reset") }

    /// PERS-01's probe: wipe, then seed one deterministic 20-vinyl crate.
    static var seedProbe: Bool { has("vsb-seed20") }

    /// `vsb-dump=1` writes the canonical `CrateDump` to `Documents/dump-1.txt`, which
    /// `Scripts/persistence-check.sh` reads out of the simulator container with
    /// `simctl get_app_container`. The label makes the before and after two named files rather
    /// than one file the script has to move between launches.
    static var dumpLabel: String? {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("vsb-dump=") }
            .map { String($0.dropFirst("vsb-dump=".count)) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    static func writeDump(_ crates: [Crate], label: String) {
        guard let directory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = directory.appendingPathComponent("dump-\(label).txt")
        try? CrateDump.text(crates).write(to: url, atomically: true, encoding: .utf8)
    }

    private static func has(_ token: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(token)
    }
}
