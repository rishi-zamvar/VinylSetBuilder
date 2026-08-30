#!/usr/bin/env bash
# Phase 6's measured acceptance gate, in one command.
#
#     ./Scripts/ocr-score.sh [run-label]
#
# Compiles the SHIPPING recogniser and the SHIPPING segmenter into one macOS binary and runs
# real text recognition over the owner's twelve photographs. It does NOT read
# .local/ocr/ocr2_out.json — that file is the spike's record, and a gate that scored a
# recording rather than a run would pass with the reader unplugged.
#
# The fixtures are gitignored (public repo). Absent, this exits 2 and says so; it never
# reports a green on a corpus it did not read.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:-latest}"
BUILD=VinylSetBuilderCore/.build/arm64-apple-macosx/debug
OUT=build/ocr-harness

if [ ! -d Tests/Fixtures/Labels ] || [ "$(ls -1 Tests/Fixtures/Labels/*.HEIC 2>/dev/null | wc -l)" -ne 12 ]; then
    echo "Tests/Fixtures/Labels needs the twelve .HEIC fixtures (restore from ~/Desktop/test/)" >&2
    exit 2
fi

echo "==> 1/3 building VinylSetBuilderCore for macOS"
swift build --package-path VinylSetBuilderCore >/dev/null

echo "==> 2/3 compiling the harness against the shipping recogniser"
mkdir -p build
# The Core objects are LINKED rather than recompiled, and App/OCR is compiled from source:
# whatever ships is what is measured. Adding a copy of the reader here would let the gate pass
# while the app was broken.
swiftc -swift-version 6 -O \
    -I "$BUILD/Modules" \
    App/OCR/SleeveTextRecognizer.swift Tools/ocr-harness/main.swift \
    "$BUILD"/VinylSetBuilderCore.build/*.o \
    -o "$OUT"

echo "==> 3/3 running real recognition over the twelve fixtures"
OCR_RUN_LABEL="$LABEL" "./$OUT"
