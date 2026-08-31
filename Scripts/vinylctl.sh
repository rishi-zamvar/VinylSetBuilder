#!/usr/bin/env bash
# vinylctl — the Vinyl Set Builder pipeline, headless, over the SAME Core package and the SAME
# app adapters the phone runs.
#
#     ./Scripts/vinylctl.sh sequence Tests/Fixtures/Labels/*.HEIC
#     ./Scripts/vinylctl.sh ocr      Tests/Fixtures/Labels/IMG_0498.HEIC
#     ./Scripts/vinylctl.sh sequence --tolerance 6 Tests/Fixtures/Labels/*.HEIC
#
# Built exactly like Scripts/resolve-score.sh: Core is LINKED as objects and the shipping app
# files are compiled from source. Nothing is re-implemented and nothing is vendored, so a change
# to the reader, the ladder or the sequencer changes what this prints on the next run.
#
# `sequence`, `resolve` and `analyze` use the LIVE network (MusicBrainz, Discogs, SoundCloud).
# `ocr` and `segment` are fully offline.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD=VinylSetBuilderCore/.build/arm64-apple-macosx/debug
OUT=build/vinylctl

echo "==> 1/4 secrets" >&2
./Scripts/generate-secrets.sh >/dev/null
echo "==> 2/4 corpus" >&2
./Scripts/generate-corpus.sh >/dev/null 2>&1 || echo "    (no corpus — the tier-0 rung will be skipped)" >&2
echo "==> 3/4 building VinylSetBuilderCore for macOS" >&2
swift build --package-path VinylSetBuilderCore >/dev/null

echo "==> 4/4 compiling vinylctl against the shipping reader, ladders and pipeline" >&2
mkdir -p build
swiftc -swift-version 6 -O \
    -I "$BUILD/Modules" \
    App/Generated/Secrets.swift \
    App/OCR/SleeveTextRecognizer.swift \
    App/Network/URLSessionTransport.swift \
    App/Audio/AVAudioFileDecoder.swift \
    App/Resolution/SleevePipeline.swift \
    Tools/vinylctl/main.swift \
    "$BUILD"/VinylSetBuilderCore.build/*.o \
    -o "$OUT"

exec "./$OUT" "$@"
