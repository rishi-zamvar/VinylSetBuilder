#!/usr/bin/env bash
# GATE 1 — catalogue-number resolution, in one command.
#
#     ./Scripts/resolve-score.sh [run-label]
#
# Compiles the SHIPPING reader, segmenter, resolution ladder and URLSession transport into one
# macOS binary and resolves the owner's twelve photographs LIVE against MusicBrainz and
# Discogs. It reads no recorded response. Needs the network and the twelve gitignored fixtures.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:-latest}"
BUILD=VinylSetBuilderCore/.build/arm64-apple-macosx/debug
OUT=build/resolve-harness

if [ "$(ls -1 Tests/Fixtures/Labels/*.HEIC 2>/dev/null | wc -l)" -ne 12 ]; then
    echo "Tests/Fixtures/Labels needs the twelve .HEIC fixtures" >&2
    exit 2
fi

echo "==> 1/4 secrets"
./Scripts/generate-secrets.sh >/dev/null

echo "==> 2/4 building VinylSetBuilderCore for macOS"
swift build --package-path VinylSetBuilderCore >/dev/null

echo "==> 3/4 compiling the harness against the shipping reader, ladder and transport"
mkdir -p build
swiftc -swift-version 6 -O \
    -I "$BUILD/Modules" \
    App/Generated/Secrets.swift App/OCR/SleeveTextRecognizer.swift \
    App/Network/URLSessionTransport.swift Tools/resolve-harness/main.swift \
    "$BUILD"/VinylSetBuilderCore.build/*.o \
    -o "$OUT"

echo "==> 4/4 resolving live"
RESOLVE_RUN_LABEL="$LABEL" "./$OUT"
