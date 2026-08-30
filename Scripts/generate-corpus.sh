#!/usr/bin/env bash
# GENERATED FILE PRODUCER — see App/Generated/bpmkey.tsv (gitignored, like Secrets.swift).
#
# The tier-0 corpus is 6,608 rows of the owner's own music library. It never goes in a public
# repo, and it never goes in the app as SQLite either: the lookup BPM-02 needs is
# punctuation-normalised, which no index on `(artist_norm, title_norm)` can serve, so the whole
# table is read into memory once whatever the file format is. A tab-separated file is therefore
# the honest bundling format — it also sidesteps the WAL/journal-mode read-only bundle trap
# entirely, because there is no journal.
#
#   Scripts/generate-corpus.sh          write App/Generated/bpmkey.tsv from .local/bpmkey.db
#   Scripts/generate-corpus.sh --check  verify it is gitignored and untracked
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="App/Generated"
OUT_FILE="$OUT_DIR/bpmkey.tsv"
SOURCE=".local/bpmkey.db"

if [ "${1:-}" = "--check" ]; then
    ok=true
    git check-ignore -q "$OUT_FILE" || { echo "LEAK CHECK FAILED: $OUT_FILE is not gitignored." >&2; ok=false; }
    [ -z "$(git ls-files "$OUT_DIR" 2>/dev/null)" ] || { echo "LEAK CHECK FAILED: git tracks $OUT_DIR." >&2; ok=false; }
    [ "$ok" = true ] || exit 1
    echo "Leak check passed: $OUT_FILE is ignored and untracked."
    exit 0
fi

mkdir -p "$OUT_DIR"
if [ ! -f "$SOURCE" ]; then
    # An absent corpus is a tier-0 miss on every lookup, not a build failure: the ladder's
    # whole point is that a missing rung falls through to the next one.
    echo "warning: $SOURCE not found — writing an empty corpus" >&2
    : > "$OUT_FILE"
    exit 0
fi

tmp="$(mktemp "$OUT_DIR/.bpmkey.XXXXXX")"
sqlite3 -noheader -separator "$(printf '\t')" "$SOURCE" \
    "SELECT replace(artist, char(9), ' '), replace(title, char(9), ' '), bpm, camelot FROM track;" > "$tmp"
mv "$tmp" "$OUT_FILE"
echo "wrote $OUT_FILE ($(wc -l < "$OUT_FILE" | tr -d ' ') rows)"
