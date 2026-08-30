#!/usr/bin/env bash
# GATE 2 — the SoundCloud match rate on the 40-track ground truth.
#
#     ./Scripts/sc-score.sh [run-label]
#
# The FIRST run needs the network; every run after it is offline, because search responses are
# cached to .local/sc_cache/. It compiles the SHIPPING client, matcher and transport.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:-latest}"
BUILD=VinylSetBuilderCore/.build/arm64-apple-macosx/debug
OUT=build/sc-harness

[ -f .local/truth.tsv ] || { echo ".local/truth.tsv is required and is gitignored" >&2; exit 2; }

echo "==> 1/4 secrets"
./Scripts/generate-secrets.sh >/dev/null
echo "==> 2/4 building VinylSetBuilderCore for macOS"
swift build --package-path VinylSetBuilderCore >/dev/null
echo "==> 3/4 compiling the harness against the shipping client and matcher"
mkdir -p build
swiftc -swift-version 6 -O \
    -I "$BUILD/Modules" \
    App/Generated/Secrets.swift App/Network/URLSessionTransport.swift Tools/sc-harness/main.swift \
    "$BUILD"/VinylSetBuilderCore.build/*.o \
    -o "$OUT"
echo "==> 4/4 matching"
SC_RUN_LABEL="$LABEL" "./$OUT"
