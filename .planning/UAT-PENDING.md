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
| ~~U7~~ | `./Scripts/build-app.sh` failed with `error: Unable to find module dependency: 'VinylSetBuilderCore'` for several attempts while plan 01-07 was executing (5 repro attempts, initially misdiagnosed as executor concurrency contention). **RESOLVED by plan 01-06**, same run: bare `xcodebuild -project` with no derived-data context computes a separate build directory for the local `VinylSetBuilderCore` package sub-project than for the app target, so the app's `swiftc` never sees the package's built `.swiftmodule`. Fix landed in `Scripts/build-app.sh` — pass explicit `SYMROOT="$(pwd)/build" OBJROOT="$(pwd)/build"` to force both into the same build root. Re-ran after the fix: **BUILD SUCCEEDED**, including this plan's three new views (`BadgePairView`, `SequencedRowView`, `NotIncludedSectionView`) compiling cleanly against `VinylSetBuilderCore`. | 1 (SEQ-07, SEQ-11) |

---

## Added at Phase 2 close (plan 02-05, 2026-08-30)

| # | Check | Why it can't be automated | Phase |
|---|-------|---------------------------|-------|
| U8 | **Look at the fifteen photographs and rule on V3.** The not-included bucket names a record `Vinyl 2` even where the app knows it as `Dillinja — Angels Fell` (178 / 6A) — see `Artifacts/screenshots/02-walk-07-not-included-expanded.png` and `.planning/VISUAL-DEFECTS.md` V3. Whether "which record got left out" must be legible in Act I, or can wait until real resolution lands in Act III, is a product judgement about your own workflow. Phase 4 implements whichever you pick. | Irreducibly a taste/priority call, not a correctness one. Both readings are defensible: it is a code defect (`VinylEntry.label` demands `resolutionState == .resolved` while `SequencedRow.title` does not) or a fixture defect (no fixture `Track` is ever marked `.resolved`). | 4 |

**U8 is not the U8 plan 02-04 anticipated.** That one was reserved for a walk state dropped
because the drag gesture would not fire. The drag fired on its first recipe, all fifteen states
were captured, and no state was dropped — so that row was never needed and the number is reused
here deliberately rather than left as a phantom.

**Phase 2 needs nothing else from you.** All nine of its requirements landed and are visible in
the committed photographs; U1 (device install), U4 and U6 (is the set one you would play) remain
open from earlier phases and are unaffected by this one.

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

---

### D-1 update — team ID investigated 2026-08-30

Owner asked to use the team registered to `rishizamvar@icloud.com`. Investigated:

```
security find-identity -p codesigning -v
  1) Apple Development: RISHI RAJESH ZAMVAR (VQBD68K343)      ← the ONLY identity
     cert OU = 373D7DZ9NM      O = RISHI RAJESH ZAMVAR
```

**There is exactly one signing team on this machine, and it is already the one configured**
in `project.yml` (`373D7DZ9NM`). It is a personal team under the owner's own name, so it is
most likely already the `rishizamvar@icloud.com` account's team.

**Cannot be confirmed from here.** Xcode is signed into no Apple ID:

```
defaults read com.apple.dt.Xcode IDEProvisioningTeams   → empty
~/Library/MobileDevice/Provisioning Profiles/           → 0 profiles
```

**If `rishizamvar@icloud.com` has a different team**, it is not on this Mac. Sign in
(Xcode ▸ Settings ▸ Accounts) and the correct team ID appears there; change the one line in
`project.yml` and re-run `xcodegen generate`.

**Consequence for U1 (device install):** blocked on three things, all needing the owner —
(1) Xcode signed into the Apple ID, (2) the iPhone connected and trusted, (3) automatic
provisioning allowed to mint a profile, since there are currently zero. Signing-free
compilation is unaffected and continues to pass.

---

## Added at Phase 3 close (plan 03-05, 2026-08-30)

| # | Check | Why it can't be automated | Phase |
|---|-------|---------------------------|-------|
| U9 | **Is the correction sheet actually fast?** Open `Artifacts/screenshots/03-walk-05-inspect-sheet.png` and `03-walk-06-inspect-raw-text.png` and answer with a stopwatch and a thumb: are **merge-up, split and hand-type** the right three operations, and is one tap each fast enough for a record you will correct dozens of times? SEG-07 exists because six of your twelve records will never resolve automatically, so this sheet is a routine path, not an error path. Two things the pictures now show that may change your answer: a 44-character line is **truncated** in the field (V15), and the draft can carry the **same line twice** (V16, `SIMON BASSLINE SMITH` on IMG_0505). | "Fast" is a stopwatch-and-thumb judgement on a real layout in a real hand, and only the DJ whose workflow it is can say whether three operations are the right three. Every automated measurement here can say the tap count is 1; none can say the sheet is quick. | 4 |
| U10 | **Does the sleeve framing guide frame a real sleeve on a real counter?** `FramingGuide.sleeve` covers **0.88 of the preview's shorter edge** and renders at `290.67 × 291 pt` — square to within half a point, measured off the live accessibility frame on three runs (`03-walk-01-capture-guide.png`). That is verified **as geometry only**. Whether 0.88 is the right fraction for a 12" sleeve held at arm's length over a counter — too tight, too loose, or right — is unanswerable until a camera is behind it. | The simulator has no camera. The preview is a black rectangle by decision D-03-2, so there is nothing in any frame to line a sleeve up against. Phase 10, with a live `AVCaptureSession`, is where this becomes answerable — and defect V10 (the guide resizing when the flip prompt appears) is queued against the same phase for the same reason. | 10 |

**U8 stays open, and Phase 3 strengthened it rather than resolving it.** The second piece of
evidence CONTEXT.md §6 predicted was obtained: `03-walk-07-done-sequenced.png` shows twelve
records the app had just named `HIGHER`, `Emotif/Xstatic EMF2029`, `inckatecks*` and `Zzz.` in
its own thumbnail strip, sitting in the not-included bucket as `Vinyl 1` … `Vinyl 8`. One record,
two names, two screens, one session. **Nothing was fixed** — both defensible fixes (mark the
fixtures `.resolved`, or give `VinylEntry.label` the same first-candidate fallback
`Track.displayName` already has) are product calls, and preempting your answer would waste the
question. Phase 4 implements whichever you pick.

**Phase 3 needs nothing else from you.** All six of its requirements landed and are visible in
the committed photographs. U1 (device install), U4 and U6 remain open from earlier phases and
are unaffected.
