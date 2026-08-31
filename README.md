# Vinyl Set Builder

Personal-use iOS app. Photograph vinyl labels, resolve the metadata, auto-sequence a mixable DJ set.

Point the camera at a record label. On-device Vision OCR reads the track listing,
the tracks are resolved against music metadata services, and a BPM-gated,
harmonically-aware sequencer orders the crate into a set you can actually play.

**Platform:** iOS 26, SwiftUI, Swift 6.2 (Xcode 26.0.1)
**Scope:** single user, on-device only. Not distributed.
**Two front ends, one pipeline:** the iOS app, and `vinylctl` — a macOS command-line tool over
the same `VinylSetBuilderCore` package and the same adapters.

## How it works

1. **Capture** — shoot each vinyl label, one side at a time
2. **OCR** — Apple Vision reads the label text with bounding boxes
3. **Segment** — deterministic geometric clustering splits the label into individual tracks
4. **Resolve** — each track is matched to artist, title, BPM and musical key
5. **Sequence** — a beam search finds the longest playable run under a BPM tolerance gate,
   minimising Camelot-wheel distance between neighbours

## Data sources

Track metadata and audio attributes are provided by these services:

- **[GetSongBPM](https://getsongbpm.com)** — BPM and musical key data.
  Tempo and key information powering the set sequencer is provided by
  [GetSongBPM.com](https://getsongbpm.com).
- **[Discogs](https://www.discogs.com)** — release, artist, label and pressing metadata
- **[MusicBrainz](https://musicbrainz.org)** — open music encyclopedia, used as a resolution fallback

## Build and run it

You need Xcode 26.0.1 (iOS 26 SDK) and `xcodegen`. Everything below runs from the repo root and
none of it needs Xcode to be open.

```bash
git clone https://github.com/rishi-zamvar/VinylSetBuilder && cd VinylSetBuilder

./Scripts/test.sh        # the Core suite — no simulator, no device, no network
./Scripts/hygiene.sh     # 9 structural gates: work markers, Core purity, dead code, the ledger
./Scripts/build-app.sh   # compiles the app against the iOS 26 DEVICE SDK, signing-free
./Scripts/ui-test.sh     # the XCUITest walks against the booted iOS 26 simulator (slow, live network)
```

To run the app itself, `open VinylSetBuilder.xcodeproj`, set your team under Signing &
Capabilities, and ⌘R. The simulator has no camera, so the twelve bundled label photographs are
dealt out through the identical Vision and segmentation path a live capture takes.

### Secrets

No key is ever committed. `Scripts/generate-secrets.sh` writes a gitignored
`App/Generated/Secrets.swift` at build time from `~/.config/keys/`, and
`Scripts/generate-corpus.sh` writes the gitignored bundled BPM/key corpus the same way. Both run
automatically as Xcode pre-build phases. Without them the app still builds and runs; the network
rungs simply return nothing.

## `vinylctl` — the whole pipeline, headless

The app and `vinylctl` are two front ends over one pipeline. The CLI links the same Core package
and compiles the same app adapters, so a stage that is wrong in one is wrong in the other. It
exists so any regression is bisectable to a single stage from a terminal, with no simulator
involved.

```bash
./Scripts/vinylctl.sh sequence ~/Desktop/test/*.HEIC       # all of it, and the sequenced set
./Scripts/vinylctl.sh ocr      photo.HEIC                  # what Vision returned        (offline)
./Scripts/vinylctl.sh segment  photo.HEIC                  # track lines, sides, cat. no. (offline)
./Scripts/vinylctl.sh resolve  photo.HEIC                  # identity per line, and which rung answered
./Scripts/vinylctl.sh analyze  photo.HEIC                  # the BPM and key ladder's answer
./Scripts/vinylctl.sh sequence --tolerance 6 photo.HEIC    # SEQ-05, from the command line
./Scripts/vinylctl.sh sequence --json photo.HEIC           # machine-readable, for diffing
```

`sequence` prints, per record, the OCR'd text, the extracted catalogue number and the resolved
artist and title — **or an explicit reason it failed** — then the sequenced set with BPM and
Camelot per row, then the not-included bucket with each row's terminal cause.

The run over the owner's own twelve photographs is committed as
`Artifacts/vinylctl/sequence-baseline.txt` (and `.json`), so any future change to the reader, the
segmenter, the resolver, the ladder or the sequencer is a diff rather than an argument.

`./Scripts/vinylctl-vs-app.sh` runs the same twelve through **both** front ends and diffs the
running orders. It is measured, not asserted: on 2026-08-30 the two produced identical sets.

### What it honestly does on real records

`.planning/phases/10-vinylctl-dod/DEFINITION-OF-DONE.md` walks MVP-SPEC §9 item by item with the
numbers. The short version, on twelve real jungle twelves: the reader and segmenter work
(**6 of 6** catalogue numbers recovered, **11 of 12** records segmented), and the metadata does
not — **5 of 12** records get a usable tempo and **1 of 21** track lines gets a key, because nine
of the twelve are white labels and dubplates that are in no public database. Manual entry is a
routine path, not an error path, and is measured at **13.3 s** for a full four-field correction.

## Status

**v1.0 — 66 of 67 requirements.** The one outstanding requirement is CAP-04's device half
(20 records without memory growth or thermal throttling), which needs a physical iPhone: the
simulator has no camera. Everything still needing a human, a device or a judgement is in
`.planning/UAT-PENDING.md`.

## Licence

Personal project. Not for redistribution.
