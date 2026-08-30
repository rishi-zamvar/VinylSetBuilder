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

---

## Added at Phase 4 close (plan 04-04, 2026-08-30)

**Nothing in Phase 4 stopped for a UAT item.** Every plan in the phase ran to completion, and
every item on this page is *recorded*, not blocking. That is CONTEXT.md's autonomy rule made
auditable rather than asserted — the proof is U8 itself, which has been open since Phase 2
while three consecutive phases carried V3 forward unfixed rather than guessing an answer.

| # | Check | Why it can't be automated | Phase |
|---|-------|---------------------------|-------|
| U11 | **Should the capture strip count the session, or the crate?** Add More opens the capture screen reading `0 records` for a crate that already holds four — `Artifacts/screenshots/02-walk-11-add-more-capture.png` (Friday Warehouse, four records in it, `0 records` on the strip). The number is **correct as specified**: CAP-03's own wording is *"scanned so far in this session"*, and decision D-03-3 fixed it that way deliberately. The question is not whether it is right, it is whether it is the right number to **show**. Session count, or crate total? | It is a taste call about your own workflow, exactly like U8. Every automated measurement can confirm the number is 0 and that 0 is what the session contains; **none can say 0 is the right thing to put in front of a DJ** who is standing over a four-record crate. Filed now because V11 had sat as "informational" since Phase 3 with no mechanism to ever get answered — an unanswered question with no U-number is not a question, it is a shrug. | 4 |

**U11 changes nothing until it is answered, and blocks nothing.** Phase 11 re-runs both walks
and re-photographs this exact screen after each of its five stub swaps, so whichever number you
pick lands in a set that is being regenerated anyway. Defect **V11** is carried against it —
see `.planning/VISUAL-DEFECTS.md`, owner `Phase 4 / U11`.

### U8 — what Phase 4 learned, and deliberately did not do

U8 is unchanged as a question. Phase 4 **did not fix V3** — decision D-04-1, taken before any
plan in the phase ran a command, precisely so that no plan could drift into answering it.

What Phase 4 adds is one measured fact, and it is offered as **input to your decision, not as a
recommendation**: the two candidate fixes are **not equivalent in their side effects.**

| Candidate fix | What it costs elsewhere |
|---|---|
| **A — code side.** Give `VinylEntry.label` the same first-candidate `Track.displayName` fallback that `SequencedRow.title` already has | Nothing measured moves. The capture strip's tally is untouched. |
| **B — fixture side.** Mark the fixture tracks `.resolved` | **Moves Phase 3's measured `6 Read / 5 Partial / 1 Unread` strip tally**, which is a committed baseline with a negative control behind it (mutation I reddens on exactly that tally). |

That asymmetry is a fact about the two fixes. It is **not** an argument for A: which reading is
right — "which record got left out must be legible in Act I" versus "it can wait until real
resolution lands in Act III" — is still the product judgement only you can make, and a baseline
being inconvenient to move is not a reason to prefer one product answer over another. Phase 4
implements whichever you pick, in one plan, either way.

Second sighting obtained since U8 was filed, on a screen that did not exist then:
`03-walk-07-done-sequenced.png` shows twelve records in the bucket as `Vinyl 1` … `Vinyl 8`
while `03-walk-04-strip-twelve.png`, four frames earlier **in the same session**, names the same
records `HIGHER` / `Zzz.` / `inckatecks*`. One record, two names, two screens.

### U9 — unchanged by Phase 4, and now the named blocker on a carried defect

Phase 4 measured nothing that answers U9; the question is still a stopwatch and a thumb on a
real layout. What changed is that U9 is now **named as the blocker on defect V15** in the
adjudicated ledger, so the two cannot drift apart:

- **V15** (the correction field truncates a 44-character line to `EXCLUSIVE NEW MIXES FR…`) is
  carried to **Phase 6**, not to Phase 4, and the reason is written down: whether the truncation
  matters depends on your answer to U9, **and** the population of long lines changes before any
  layout fix would be designed, because SEG-03's filter drops the price-sticker, address and URL
  fragments that make the longest lines long.
- **V16** (the draft carries `SIMON BASSLINE SMITH` twice) is carried to Phase 6 for the same
  reason and is part of the same question: U9 asks whether merge-up, split and hand-type are the
  right three operations, and deleting a line you cannot tell apart from the one you are keeping
  is a fourth thing the sheet currently asks of you.

Nothing about the sheet was changed in Phase 4. The two frames U9 names are unchanged apart from
the simulator clock and the badge-pair restyle that closed V4 elsewhere on other screens.

### U10 — explicitly unchanged, said out loud rather than left to go quiet

Phase 4 built no camera, touched no capture view geometry, and measured nothing new about
`FramingGuide.sleeve`. **U10 is exactly as it was at the close of Phase 3**: the guide is
verified as *geometry* (`290.67 × 291 pt`, square to within half a point, on three runs) and
unanswerable as *ergonomics* until a camera is behind it.

Recorded here rather than left silent because a UAT item that stops being mentioned reads, a
phase later, like one that was resolved. It was not. Defect **V10** — the guide resizing when
the flip prompt appears — is carried to **Phase 10** against the same wall, for the same reason:
the preview is a black rectangle until an `AVCaptureSession` is behind it.

### What Phase 4 needs from you

**U8 (defect V3) and U11 (defect V11).** Both are product calls, both have a defect carried
against them in `.planning/VISUAL-DEFECTS.md`, and neither blocks anything: Act I signs off with
them open, and the verdict says so in those words rather than quietly re-wording the criterion.

**U1, U4, U6, U9 and U10 remain open from earlier phases, and Phase 4 did not change them.**
U1 needs the phone connected and Xcode signed into your Apple ID; U4 and U6 need you to look at
a set and say whether you would play it; U9 needs a stopwatch on the correction sheet; U10 needs
a camera. **U2, U3, U5 and U7 are resolved** and are struck through above.

**Cross-reference audit, run in both directions by plan 04-04**, because a one-directional check
passes on a dangling reference:

- Every U-number cited in `VISUAL-DEFECTS.md` — U8 (V3), U9 (V15), U10 (V10's section), U11 (V11)
  — exists here. **4 of 4, no dangling reference.**
- Every U-number here whose phase is 4 — U4, U6, U8, U9, U11 — is cited by a ledger row, except
  **U4 and U6**, and that is legitimate and is named rather than assumed: *"is this a set you
  would actually play"* is not a visual defect, has no screenshot that could evidence it, and
  therefore correctly has no V-row. **3 of 5 cited, 2 named as deliberately uncited.**
