import XCTest

/// Every screenshot this phase ships goes through here, so the settle delay lives in exactly
/// one place and cannot be forgotten on one state out of fifteen.
///
/// Defect V2 was closed on 2026-08-30: the "washed-out UI" was the launch fade animation, not
/// styling. Restyling would have damaged correct, well-contrasted code to satisfy an artefact
/// of the capture harness. The rule that incident left behind is enforced here rather than
/// written down and hoped for.
enum ScreenshotRecorder {
    /// MANDATORY minimum, per `.planning/VISUAL-DEFECTS.md`. Do not lower these to make a run
    /// faster — a screenshot taken mid-transition is evidence of nothing, and the last time one
    /// was believed it produced a defect report against code that was already correct.
    static let defaultSettle: TimeInterval = 3.0

    /// Launch has the longest transition of any state in the walk, so it gets the widest margin.
    static let launchSettle: TimeInterval = 4.0

    /// The runner's own Documents directory inside the simulator container.
    /// `Scripts/collect-screenshots.sh` copies PNGs out of here onto the host.
    static var outputDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Writes the screenshot twice on purpose: once as a file (deterministic, and copied out
    /// with `simctl get_app_container`, which does not change spelling between Xcode releases)
    /// and once as an `XCTAttachment` (free, and it makes a *failing* run debuggable, which the
    /// file route cannot do because a failed assertion may abort before the write).
    @discardableResult
    static func capture(_ name: String,
                        settle: TimeInterval = defaultSettle,
                        in testCase: XCTestCase) -> URL? {
        // Correct despite appearances: the app under test is a separate process and keeps
        // running and animating while the *test* process sleeps. This is the settle delay the
        // phase's ship criterion demands, not a workaround for a race.
        Thread.sleep(forTimeInterval: settle)
        let shot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)

        let url = outputDirectory.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            return url
        } catch {
            XCTFail("could not write \(name).png: \(error)")
            return nil
        }
    }
}
