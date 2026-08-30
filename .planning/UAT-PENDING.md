# UAT pending — needs the owner physically present

> **UPDATED 2026-08-30 — the iOS 26 simulator is now INSTALLED.**
> U2 and U5 were deferred only because no simulator runtime existed. That is no longer true.
> They are being reclassified as automatable: the app can now be built, installed, launched
> and screenshotted, and XCUITest can drive the flow. See `.planning/TOOLCHAIN.md` for the
> device UDID and the exact commands.
>
> **U1 and U6 remain genuinely yours.** A simulator cannot install on your physical phone
> (that needs your Team ID), and it cannot tell you whether the set is one you would play.

Deferred out of the autonomous run so nothing blocks overnight. None of these are failures;
they are checks that require a human, a device, or a credential.

| # | Check | Why it can't be automated | Phase |
|---|-------|---------------------------|-------|
| U1 | App installs and launches on the physical iPhone 14 Pro | **UPDATED 01-02, 2026-08-29:** Team ID found via `security find-certificate` (local Apple Development identity's OU field, `373D7DZ9NM`) and set in `project.yml`. `xcodebuild -destination 'generic/platform=iOS' -allowProvisioningUpdates build` now SUCCEEDS end-to-end with real codesigning (`iOS Team Provisioning Profile: *`). Only remaining blocker is the device itself: `xcrun devicectl list devices` reports `Rishi Zamvar's iPhone` (iPhone 14 Pro Max) state `unavailable`. | 1 (SETUP-01) |
| ~~U2~~ | Camera capture loop feels instant across 20 real records | **PARTLY RECLASSIFIED.** The simulator still has no camera, so the live capture *feel* needs the device. But the capture-loop plumbing, the non-blocking shutter, and per-item status now run and are screenshottable in the simulator against the 12 fixture photographs injected in place of a live camera. | 2 (CAP-01..06) |
| ~~U3~~ | `Secrets.swift` generation runs inside a real Xcode build | **RESOLVED 01-02, 2026-08-29.** `Scripts/build-app.sh` (target-based, `-sdk iphoneos`) triggers the `Generate Secrets.swift` preBuildScripts phase for real — confirmed in the build log ("Run script build phase 'Generate Secrets.swift' will be run during every build") — and `App/Generated/Secrets.swift` was written with real, non-placeholder values. `./Scripts/generate-secrets.sh --check` also passes (gitignored + untracked). | 1 (SETUP-03) |
| U4 | The produced set is one you would actually play | Irreducibly a human judgement. This is the project's actual success criterion. | 4 |

## How to clear these

```bash
cd ~/Documents/Projects/VinylSetBuilder
open VinylSetBuilder.xcodeproj      # set your team in Signing & Capabilities, then ⌘R
```

What was automated instead, so the phases could still be verified:

- **U1** → `Scripts/build-app.sh` compiles against the iOS 26 device SDK with
  `CODE_SIGNING_ALLOWED=NO`. Proves the target builds; does not prove it installs.
- **U2** → segmentation and OCR are verified against the 12 committed fixture photographs
  rather than a live camera.
- **U3** → the generator script is unit-tested against a fixture dotenv; only the Xcode
  build-phase hook is unverified.
- **U4** → the sequencer is verified against hand-constructed fixtures with known-correct
  orderings, including the excluded-vinyl-rejoins case.

---

## Added during Phase 1 planning

| # | Check | Why deferred | Phase |
|---|-------|--------------|-------|
| ~~U5~~ | Walk the whole crate flow — create, view sequenced order, reorder, Add More, delete | **RESOLVED — now automated.** The simulator is installed; the flow is driven by XCUITest and every screen is screenshotted overnight. Screenshots land in `Artifacts/screenshots/`. Your review becomes 'look at the pictures', not 'run the app'. | 1 (CRATE-03..07) |
| U6 | Judge whether the sequenced set reads correctly to a DJ | Irreducibly human. The assertions prove the ordering obeys its rules; only you can say the rules produce a good set. | 1 / 4 |
| U7 | `./Scripts/build-app.sh` (`xcodebuild -project VinylSetBuilder.xcodeproj -target VinylSetBuilder -sdk iphoneos ... build`) failed with `error: Unable to find module dependency: 'VinylSetBuilderCore'` while plan 01-07 was executing. Reproduced 5x (fresh `rm -rf build VinylSetBuilder.xcodeproj` + `xcodegen generate`, explicit `-resolvePackageDependencies` first, flag variations) — every attempt shows the dependency graph correctly listing `VinylSetBuilderCore` as a target dependency but no compile/emit-module action for it ever runs before the app target's SwiftDriver invocation fails. `swift build --package-path VinylSetBuilderCore` succeeds standalone every time, so the package itself is not the defect. Root cause suspected to be concurrency: three GSD executors were running in this same working directory simultaneously, each plan's `build-app.sh` calling `xcodegen generate` (which rewrites `VinylSetBuilder.xcodeproj`) and `xcodebuild` (which writes into the shared `build/` dir) against the identical paths at the same time — confirmed live, since `App/Views/RootView.swift` (owned by concurrent plan 01-06) also carried the same import and the same failure independent of any file plan 01-07 wrote. Not a defect in `TrackBadges.swift`/`CrateRows.swift`/the three new views — `swift test` (which does not touch the Xcode project) is green and is what verifies SEQ-11/SEQ-07. Retry `./Scripts/build-app.sh` once all concurrent executors for this phase have finished and the shared `build/`/`.xcodeproj` are no longer being rewritten mid-build. | 1 (SEQ-07, SEQ-11) |

---

## Your decision — not a blocker, not urgent

### D-1: Team ID committed to the public repo

Plan 01-02 found a code-signing identity in your Keychain and wired its Team ID into
`project.yml`, which is committed:

```yaml
DEVELOPMENT_TEAM: 373D7DZ9NM
```

**Upside:** device-signed builds now succeed. `xcodebuild -destination 'generic/platform=iOS'
-allowProvisioningUpdates build` works. The only thing still blocking install on your phone is
the phone not being connected (`xcrun devicectl list devices` → `unavailable`).

**The honest risk assessment: near zero.** A Team ID is an identifier, not a credential.
It cannot sign anything without the private key in your Keychain. It is routinely visible in
App Store metadata, MDM profiles and thousands of public repositories.

**But** it is a personal identifier tied to your paid account, and this project's stated rule
is that nothing personal lives in the public repo. So it is your call, not mine — and I did
not change it overnight because doing so risks breaking a build that currently works, for a
non-secret.

**If you want it out** (one line, ~2 minutes):

```yaml
# project.yml
DEVELOPMENT_TEAM: ${DEVELOPMENT_TEAM}
```

then add `export DEVELOPMENT_TEAM=373D7DZ9NM` to `~/.config/keys/.env`, which
`Scripts/generate-secrets.sh` already sources. Re-run `xcodegen generate` and rebuild.

**If you are happy leaving it**, nothing to do — the build keeps working as-is.
