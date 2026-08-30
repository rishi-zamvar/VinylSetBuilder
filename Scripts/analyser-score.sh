#!/usr/bin/env bash
# GATE 4 — the vDSP analyser scored against the 29-track cached ground truth.
#
#     ./Scripts/analyser-score.sh [run-label]
#
# Offline. It reads .local/mu_dataset.json and .local/mu_audio/*.mp3, which are already on
# disk and cost real API calls to build — it never re-fetches them. It compiles the SHIPPING
# analyser and the SHIPPING decoder, so what is scored is what runs on the phone.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:-latest}"
BUILD=VinylSetBuilderCore/.build/arm64-apple-macosx/debug
OUT=build/mu-validate

if [ ! -f .local/mu_dataset.json ] || [ ! -d .local/mu_audio ]; then
    echo ".local/mu_dataset.json and .local/mu_audio/ are required and are gitignored" >&2
    exit 2
fi

echo "==> 1/3 building VinylSetBuilderCore for macOS"
swift build --package-path VinylSetBuilderCore >/dev/null

echo "==> 2/3 compiling the harness against the shipping analyser and decoder"
mkdir -p build
swiftc -swift-version 6 -O \
    -I "$BUILD/Modules" \
    App/Audio/AVAudioFileDecoder.swift Tools/mu-validate/main.swift \
    "$BUILD"/VinylSetBuilderCore.build/*.o \
    -o "$OUT"

echo "==> 3/3 scoring"
ANALYSER_RUN_LABEL="$LABEL" "./$OUT" .local/mu_dataset.json .local/mu_audio
