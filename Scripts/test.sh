#!/bin/sh
# SETUP-04: full test suite from the command line. No device, no simulator, no network.
set -e
cd "$(dirname "$0")/.."
swift test --package-path VinylSetBuilderCore "$@"
