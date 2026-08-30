#!/usr/bin/env bash
# GATE 3 — the tier-0 hit rate, reported not gated.
#
#     ./Scripts/tier0-score.sh [run-label]
#
# Runs the whole chain live — reader, segmenter, resolution ladder — then asks the bundled
# corpus for each identified track. Needs the network and the twelve gitignored fixtures.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:-latest}"
BUILD=VinylSetBuilderCore/.build/arm64-apple-macosx/debug
OUT=build/tier0-harness

[ "$(ls -1 Tests/Fixtures/Labels/*.HEIC 2>/dev/null | wc -l)" -eq 12 ] || {
    echo "Tests/Fixtures/Labels needs the twelve .HEIC fixtures" >&2; exit 2; }

echo "==> 1/5 secrets"
./Scripts/generate-secrets.sh >/dev/null
echo "==> 2/5 corpus"
./Scripts/generate-corpus.sh
echo "==> 3/5 building VinylSetBuilderCore for macOS"
swift build --package-path VinylSetBuilderCore >/dev/null
echo "==> 4/5 compiling the harness against the shipping corpus reader and ladder"
mkdir -p build
swiftc -swift-version 6 -O \
    -I "$BUILD/Modules" \
    App/Generated/Secrets.swift App/OCR/SleeveTextRecognizer.swift \
    App/Network/URLSessionTransport.swift Tools/tier0-harness/main.swift \
    "$BUILD"/VinylSetBuilderCore.build/*.o \
    -o "$OUT"
echo "==> 5/5 measuring"
TIER0_RUN_LABEL="$LABEL" "./$OUT"
