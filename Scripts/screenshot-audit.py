#!/usr/bin/env python3
"""Three gates over Artifacts/screenshots/: flow coverage, distinctness, classification.

Phase 4's central claim is a counting claim, and V14 already proved a naive count lies:
`02-walk-08-detail-edit-mode` and `02-walk-10-detail-restored` are the same screen by
construction, so the crate walk photographs 14 materially distinct states, not 15. This script
replaces the count with a measurement.

It does not measure anything itself. Every number comes from `Scripts/probe-frames.py --json`
(shelled out, below) so there is one probe and one set of numbers, comparable with every
number this repo's history already records.

    Gate A  coverage        every row of FLOW_MAP has at least one existing frame
    Gate B  distinctness    every measured near-duplicate pair is declared, with a reason
    Gate C  classification  every file is regenerable, historical-with-a-citation, or an orphan

    Scripts/screenshot-audit.py [--write-manifest]

WHY GATE B HAS TWO MEASUREMENTS AND NOT ONE
-------------------------------------------
`NEAR_DUPLICATE_FRACTION` was fixed in advance at 0.005 and is NOT re-fitted here — that is the
rule `.planning/VISUAL-DEFECTS.md` leaves behind and it applies to this file's own gates.

But a whole-frame differing-pixel fraction is a candidate generator, not a decider. On this set
it flags six pairs and three of them are materially different screens: "Friday Warehouse —
3 records" against "4 records" is one digit on a 3,162,132-pixel frame, which is 0.03% of the
frame and 100% of the state. So every flagged pair is adjudicated BY LOOKING AT IT and recorded
in `DECLARED_DUPLICATES` with a kind:

    IDENTICAL  the same screen state; collapses in the distinct-state count
    DISTINCT   a measured false positive of the fraction metric; does NOT collapse

`CONTENT_TOP` supports that adjudication with a second number — differing pixels BELOW the
status-bar band, so a pair that differs only in the simulator clock is visibly separable from a
pair that differs in the app's own content. The band was measured, not guessed: the diff bbox of
`02-smoke-crate-list` vs `02-walk-01-crate-list`, the one pair known to differ only in the
clock, is (167, 79)-(277, 117).
"""

from __future__ import annotations

import datetime
import importlib.util
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "Artifacts", "screenshots")
PROBE = os.path.join(ROOT, "Scripts", "probe-frames.py")

NEAR_DUPLICATE_FRACTION = 0.005   # fixed in advance by 04-01-PLAN.md. Never re-fitted.
MEAN_BAND = 0.1                   # two frames are only compared if their means are this close
CONTENT_TOP = 150                 # px; below this row is app content, above it is the status bar

# Globs the current UI suite writes. Scripts/screenshots.sh purges exactly this list.
REGENERABLE_PREFIXES = ("02-smoke-", "02-walk-", "03-03-", "03-04-", "03-walk-", "04-badge-")

# Citation search excludes this phase's own directory: a file cited only by the plan that
# classifies it is not independently cited, and counting it would be circular.
CITATION_ROOTS = (".planning", "docs")
CITATION_EXCLUDE = os.path.join(".planning", "phases", "04-act-i-signoff")

# --------------------------------------------------------------------------------------------
# The canonical flow map. MVP-SPEC §2 is prose and prose is not a gate, so it lives here as a
# literal table. Every frame named below was opened and looked at on 2026-08-30 before its row
# was written; coverage is not inferred from a filename.
# --------------------------------------------------------------------------------------------
FLOW_MAP = [
    ("§2.1", "Crates screen — list of saved playlists, + for new", "COVERED", [
        "02-walk-01-crate-list.png",
        "02-smoke-crate-list.png",
    ], "Both show Sunday Chill / Friday Warehouse and the + button."),

    ("§2.1", "Crates screen — empty state", "COVERED", [
        "02-walk-15-crate-list-empty.png",
    ], "'No Crates Yet — Tap + to start a new crate.'"),

    ("§2.1", "Crates screen — after a crate is deleted", "COVERED", [
        "02-walk-14-crate-list-after-delete.png",
        "02-03-crate-list-after-delete.png",
    ], "02-03 frame reads 'Friday Warehouse — 3 records' after a vinyl was removed."),

    ("§2.2", "New Crate — name it", "COVERED", [
        "02-walk-02-new-crate-sheet.png",
    ], "Sheet with Cancel / Create, name field holding 'Test Crate', keyboard up."),

    ("§2.3a", "Capture loop — camera with the sleeve framing guide, empty", "COVERED", [
        "02-walk-03-capture-empty.png",
        "03-walk-01-capture-guide.png",
        "03-03-capture-empty.png",
    ], "Stroked square guide, 'Fill the square with the whole sleeve', shutter, Done."),

    ("§2.3b", "Capture loop — thumbnail strip with per-item resolution status", "COVERED", [
        "02-walk-04-capture-with-vinyl.png",
        "03-03-capture-one-item.png",
        "03-walk-04-strip-twelve.png",
        "03-walk-08-strip-twentyone.png",
        "03-walk-09-strip-scrolled-to-end.png",
    ], "Tiles carry Read / Partial / Unread pills; 1, 2, 12 and 21 records photographed."),

    ("§2.3c", "Capture loop — inline flip-side prompt, Scan / Skip", "COVERED", [
        "03-03-capture-flip-prompt.png",
        "02-walk-04-capture-with-vinyl.png",
        "03-walk-02-flip-prompt-fires.png",
    ], "'Only one side read / HIGHER' banner with Skip and Scan, camera never left."),

    ("§2.3c", "Capture loop — flip prompt correctly suppressed", "COVERED", [
        "03-03-capture-flip-suppressed.png",
        "03-walk-03-flip-suppressed.png",
    ], "Same screen at 2 records with no banner — CAP-05's suppression case."),

    ("§2.3d", "Capture loop — Done leaves the loop", "COVERED", [
        "03-walk-07-done-sequenced.png",
        "02-walk-05-new-crate-detail.png",
    ], "Done lands on the crate detail; 03-walk-07 is the twelve-record result."),

    ("§2.4", "Sequencing — ordered running order plus an Excluded section", "COVERED", [
        "02-walk-06-crate-detail-sequenced.png",
        "02-walk-07-not-included-expanded.png",
        "03-walk-07-done-sequenced.png",
    ], "'Running order' 1..2 with BPM/key badges; 'Not in the set (N)' collapsed and expanded."),

    ("§2.4", "Sequencing — nothing sequenced yet", "COVERED", [
        "02-walk-05-new-crate-detail.png",
        "03-walk-07-done-sequenced.png",
    ], "'Nothing sequenced yet' with the excluded bucket carrying the records."),

    ("§2.5", "Crate detail — per-track BPM/key badges", "COVERED", [
        "02-walk-06-crate-detail-sequenced.png",
        "02-walk-13-second-crate-different-selection.png",
    ], "170/5A, 172/8A, 174/9A rendered as capsules beside each row."),

    ("§2.5", "Crate detail — reorderable list, edit mode", "COVERED", [
        "02-walk-08-detail-edit-mode.png",
        "02-walk-10-detail-restored.png",
    ], "Delete circles and drag handles; Done replaces Edit."),

    ("§2.5", "Crate detail — manual order applied, Restore offered", "COVERED", [
        "02-walk-09-detail-manual-order.png",
    ], "Header becomes 'Custom order' with a Restore action; rows 1 and 2 swapped."),

    ("§2.5", "Crate detail — a vinyl removed from the crate", "COVERED", [
        "02-walk-12-detail-after-remove-vinyl.png",
        "02-03-crate-detail-after-delete.png",
    ], "Running order drops to a single row."),

    ("§2.5", "Crate detail — Add More re-enters the capture loop", "COVERED", [
        "02-walk-11-add-more-capture.png",
    ], "Capture screen titled 'Friday Warehouse', reached from the detail's Add More."),

    ("§4", "Inspect / correct sheet — editable segmentation (split, merge, hand-type)", "COVERED", [
        "03-walk-05-inspect-sheet.png",
        "03-04-sheet-lines.png",
        "03-04-sheet-after-split.png",
        "03-04-sheet-after-merge.png",
        "03-04-sheet-hand-typed.png",
    ], "Numbered track lines, scissors per line, 'Add a line', Apply."),

    ("§4", "Inspect / correct sheet — raw recognised text with confidences", "COVERED", [
        "03-walk-06-inspect-raw-text.png",
        "03-04-sheet-raw-text.png",
    ], "'Raw recognised text (12)' expanded, each row badged 1.00 / 0.30."),

    # ------------------------------------------------------------------------------------
    # Deferrals. Each names a phase and a one-line reason, or it is a gap pretending to be a
    # decision.
    # ------------------------------------------------------------------------------------
    ("§6", "Manual-entry sheet — type artist/title/BPM, tap a Camelot grid",
     "DEFERRED — Phase 12", [],
     "MAN-01…05 sit in Act III per the mandated act structure; recorded in REQUIREMENTS.md as "
     "a decision, not a gap. Act I deliberately does not build this screen."),
]

# --------------------------------------------------------------------------------------------
# Every pair Gate B flags must appear here, adjudicated by looking at both frames.
# --------------------------------------------------------------------------------------------
IDENTICAL, DISTINCT = "IDENTICAL", "DISTINCT"

DECLARED_DUPLICATES = [
    ("02-walk-08-detail-edit-mode.png", "02-walk-10-detail-restored.png", IDENTICAL,
     "V14: Restore's job IS to return to state 8, so the identity is semantically correct. "
     "Restore's effect is legible only by comparing 02-walk-09 to 02-walk-10."),

    ("02-smoke-crate-list.png", "02-walk-01-crate-list.png", IDENTICAL,
     "Two tests photograph the identical crate-list state (Sunday Chill 1 record / Friday "
     "Warehouse 4 records). Every differing pixel is inside the status-bar clock band, 4:11 "
     "against 4:08 — zero differ below y=150. Kept because SmokeUITests and CrateWalkUITests "
     "are separately cited evidence paths."),

    ("02-03-crate-list-after-delete.png", "02-smoke-crate-list.png", DISTINCT,
     "FALSE POSITIVE of the fraction metric. 02-03's frame reads 'Friday Warehouse — 3 "
     "records', the smoke frame reads '4 records'. One digit is 0.03% of a 3.16 Mpx frame and "
     "100% of the state. 1026 pixels differ below y=150."),

    ("02-03-crate-list-after-delete.png", "02-walk-01-crate-list.png", DISTINCT,
     "FALSE POSITIVE, same digit as the row above ('3 records' against '4 records'). "
     "1026 pixels differ below y=150."),

    ("03-04-sheet-after-split.png", "03-04-sheet-lines.png", DISTINCT,
     "FALSE POSITIVE. The split moved the word 'Cause' from line 2 to line 1: 'Zzz.' / 'Cause 4 "
     "Concern-' becomes 'Zzz. Cause' / '4 Concern-'. That difference IS the frame's purpose. "
     "All 8719 differing pixels sit in the two text fields, bbox (149,436)-(564,600)."),

    ("02-01-crate-list-pluralised.png", "sim-settled-crate-list.png", DISTINCT,
     "FALSE POSITIVE, and historical: 02-01 reads '1 record' (V1 fixed), sim-settled reads "
     "'1 records' (V1 unfixed). Retained as a declaration in case sim-settled is ever restored; "
     "the file was deleted by 04-01 as an orphan."),
]


# --------------------------------------------------------------------------------------------


def probe(paths: list[str]) -> list[dict]:
    """One probe, one set of numbers. Shelled out on purpose — see the module docstring."""
    out = subprocess.run([sys.executable, PROBE, "--json", *paths],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def _probe_module():
    sys.dont_write_bytecode = True   # do not litter Scripts/ with __pycache__
    spec = importlib.util.spec_from_file_location("probe_frames", PROBE)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def frames() -> list[str]:
    return sorted(f for f in os.listdir(SHOTS) if f.endswith(".png"))


def markdown_docs() -> dict[str, str]:
    """Every .md under .planning/ and docs/, minus this phase's own directory."""
    docs = {}
    for root_name in CITATION_ROOTS:
        for dirpath, _dirs, files in os.walk(os.path.join(ROOT, root_name)):
            rel = os.path.relpath(dirpath, ROOT)
            if rel.startswith(CITATION_EXCLUDE):
                continue
            for f in files:
                if f.endswith(".md"):
                    p = os.path.join(dirpath, f)
                    with open(p, encoding="utf-8", errors="replace") as fh:
                        docs[os.path.relpath(p, ROOT)] = fh.read()
    return docs


def classify(names: list[str]) -> dict[str, tuple[str, list[str]]]:
    docs = markdown_docs()
    out = {}
    for n in names:
        if n.startswith(REGENERABLE_PREFIXES):
            out[n] = ("regenerable", [])
            continue
        cites = sorted(path for path, body in docs.items() if n in body)
        out[n] = ("historical" if cites else "orphan", cites)
    return out


def candidate_pairs(records: list[dict]) -> list[tuple[dict, dict]]:
    """Only frames of equal size whose means are within MEAN_BAND are ever compared.

    The plan specified buckets of round(mean, 1). A band is used instead because rounding has a
    boundary hole: means of 243.649 and 243.651 round to different buckets and would never be
    compared, which is a gate a new near-duplicate could walk straight through. The band is a
    strict superset of the buckets and costs 17 comparisons instead of 12, against 990 for the
    naive all-pairs sweep.
    """
    pairs = []
    for i, a in enumerate(records):
        for b in records[i + 1:]:
            if (a["w"], a["h"]) == (b["w"], b["h"]) and abs(a["mean"] - b["mean"]) <= MEAN_BAND:
                pairs.append((a, b))
    return pairs


def measure_pairs(records: list[dict]) -> list[dict]:
    from PIL import Image, ImageChops
    pf = _probe_module()
    out = []
    for a, b in candidate_pairs(records):
        differing, total, frac = pf.diff(a["path"], b["path"])
        ia, ib = Image.open(a["path"]).convert("RGB"), Image.open(b["path"]).convert("RGB")
        d = ImageChops.difference(ia, ib).convert("L")
        bbox = d.getbbox()
        below = d.crop((0, CONTENT_TOP, ia.size[0], ia.size[1]))
        content = sum(c for v, c in enumerate(below.histogram()) if v and c)
        out.append({
            "a": os.path.basename(a["path"]), "b": os.path.basename(b["path"]),
            "differing": differing, "total": total, "fraction": frac,
            "content_differing": content, "bbox": bbox,
            "near_duplicate": frac < NEAR_DUPLICATE_FRACTION,
        })
    return sorted(out, key=lambda r: r["fraction"])


def declared_lookup() -> dict[frozenset, tuple[str, str]]:
    return {frozenset((a, b)): (kind, why) for a, b, kind, why in DECLARED_DUPLICATES}


def collapse(names: list[str], pairs: list[dict]) -> tuple[int, list[list[str]]]:
    """Union-find over IDENTICAL pairs only. Three mutually-identical frames are ONE state, not
    three pairs' worth of subtraction."""
    dec = declared_lookup()
    parent = {n: n for n in names}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for p in pairs:
        if not p["near_duplicate"]:
            continue
        entry = dec.get(frozenset((p["a"], p["b"])))
        if entry and entry[0] == IDENTICAL and p["a"] in parent and p["b"] in parent:
            parent[find(p["a"])] = find(p["b"])

    groups: dict[str, list[str]] = {}
    for n in names:
        groups.setdefault(find(n), []).append(n)
    multi = sorted([sorted(g) for g in groups.values() if len(g) > 1])
    return len(names) - sum(len(g) - 1 for g in multi), multi


# --------------------------------------------------------------------------------------------


def audit() -> tuple[list[str], dict]:
    names = frames()
    if not names:
        return ["Gate A: Artifacts/screenshots/ holds no PNGs at all"], {}
    records = probe([os.path.join(SHOTS, n) for n in names])
    on_disk = set(names)
    failures, notes = [], []

    # Gate A -------------------------------------------------------------------------------
    coverage = []
    for step, state, status, expected, note in FLOW_MAP:
        present = [f for f in expected if f in on_disk]
        missing = [f for f in expected if f not in on_disk]
        if status == "COVERED" and not present:
            failures.append(
                f"Gate A: flow row {step} '{state}' has NO existing frame "
                f"(expected any of: {', '.join(expected) or 'none listed'})")
        elif status.startswith("DEFERRED") and "Phase" not in status:
            failures.append(f"Gate A: flow row {step} '{state}' is deferred without a phase number")
        elif status == "COVERED" and missing:
            # Not a failure: the gate is "at least one photograph per state", so a row backed by
            # five frames still holds with four. But silent erosion of evidence is how a set
            # rots, so it is printed.
            notes.append(f"note: flow row {step} '{state}' lost "
                         f"{len(missing)} of {len(expected)} frames — {', '.join(missing)}")
        coverage.append((step, state, status, present, missing, note))

    # Gate B -------------------------------------------------------------------------------
    pairs = measure_pairs(records)
    dec = declared_lookup()
    for p in pairs:
        if not p["near_duplicate"]:
            continue
        if frozenset((p["a"], p["b"])) not in dec:
            failures.append(
                f"Gate B: UNDECLARED near-duplicate {p['a']} vs {p['b']} — "
                f"fraction={p['fraction']:.6f} ({p['differing']}/{p['total']} px, "
                f"{p['content_differing']} below y={CONTENT_TOP}) is under "
                f"NEAR_DUPLICATE_FRACTION={NEAR_DUPLICATE_FRACTION}. Look at both frames and "
                f"add a DECLARED_DUPLICATES entry with a kind and a reason.")

    stale = [f"{a} / {b}" for a, b, _k, _w in DECLARED_DUPLICATES
             if a in on_disk and b in on_disk
             and not any(frozenset((p["a"], p["b"])) == frozenset((a, b)) and p["near_duplicate"]
                         for p in pairs)]

    # Gate C -------------------------------------------------------------------------------
    classes = classify(names)
    for n, (kind, _cites) in sorted(classes.items()):
        if kind == "orphan":
            failures.append(
                f"Gate C: ORPHAN {n} — not written by the current suite and cited by no .md "
                f"under {'/'.join(CITATION_ROOTS)} (excluding {CITATION_EXCLUDE}). "
                f"Look at it, then delete it or fix the document that should cite it.")

    # Arithmetic ---------------------------------------------------------------------------
    distinct, groups = collapse(names, pairs)
    walk = [n for n in names if n.startswith("02-walk-")]
    walk_distinct, walk_groups = collapse(walk, [p for p in pairs
                                                 if p["a"] in walk and p["b"] in walk])

    return failures, {
        "names": names, "records": records, "coverage": coverage, "pairs": pairs,
        "classes": classes, "stale": stale,
        "distinct": distinct, "groups": groups, "notes": notes,
        "walk": walk, "walk_distinct": walk_distinct, "walk_groups": walk_groups,
    }


def write_manifest(d: dict) -> str:
    n = len(d["names"])
    counts = {k: sum(1 for _f, (kind, _c) in d["classes"].items() if kind == k)
              for k in ("regenerable", "historical", "orphan")}
    flagged = [p for p in d["pairs"] if p["near_duplicate"]]
    dec = declared_lookup()
    ident = [p for p in flagged if dec.get(frozenset((p["a"], p["b"])), ("", ""))[0] == IDENTICAL]

    L = []
    L.append("# Screenshot manifest — Artifacts/screenshots/")
    L.append("")
    L.append("**Generated by** `python3 Scripts/screenshot-audit.py --write-manifest` on "
             f"{datetime.date.today().isoformat()}. **Do not hand-edit** — every number below "
             "is measured by `Scripts/probe-frames.py` and regenerating overwrites the file.")
    L.append("")
    L.append("## Headline numbers")
    L.append("")
    # NOT "all NxM px": 04-badge-*.png are ELEMENT screenshots (one badge pair each), so the
    # set stopped being uniform the moment V4 became measurable. Printing a single size would
    # have been a false claim in a document whose whole job is to carry true numbers.
    sizes: dict[tuple[int, int], int] = {}
    for r in d["records"]:
        sizes[(r["w"], r["h"])] = sizes.get((r["w"], r["h"]), 0) + 1
    L.append(f"- **{n} files** on disk, in "
             + ", ".join(f"{c}x {w}x{h} px" for (w, h), c in
                         sorted(sizes.items(), key=lambda kv: -kv[1])))
    L.append(f"- **{len(ident)} declared IDENTICAL pairs**, collapsing into "
             f"{len(d['groups'])} duplicate group(s)")
    L.append(f"- **{d['distinct']} distinct screen states**")
    L.append(f"- crate walk: **{len(d['walk'])} files, {len(d['walk_groups'])} declared pair, "
             f"{d['walk_distinct']} distinct states** — V14's arithmetic, produced by a command")
    L.append(f"- classification: {counts['regenerable']} regenerable, "
             f"{counts['historical']} historical evidence, {counts['orphan']} orphan")
    L.append(f"- thresholds, fixed in advance and never re-fitted: "
             f"`NEAR_DUPLICATE_FRACTION={NEAR_DUPLICATE_FRACTION}`, "
             f"`MIN_DARK=110`, `MIN_BRIGHT=200`")
    L.append("")
    L.append("## Gate A — flow coverage against MVP-SPEC §2 and §4")
    L.append("")
    L.append("| Step | Screen state | Status | Frames | What was looked at |")
    L.append("|---|---|---|---|---|")
    for step, state, status, present, _missing, note in d["coverage"]:
        cells = "<br>".join(f"`{f}`" for f in present) or "—"
        L.append(f"| {step} | {state} | {status} | {cells} | {note} |")
    L.append("")
    L.append("## Gate B — distinctness, measured")
    L.append("")
    L.append(f"Frames are compared only when their dimensions match and their means are within "
             f"{MEAN_BAND}; {len(d['pairs'])} pairs qualified out of "
             f"{n * (n - 1) // 2} possible. A pair under "
             f"`NEAR_DUPLICATE_FRACTION` must be declared or the gate reddens.")
    L.append("")
    L.append("| Fraction | Differing px | Below y=%d | bbox | Pair | Verdict |" % CONTENT_TOP)
    L.append("|---|---|---|---|---|---|")
    for p in d["pairs"]:
        entry = dec.get(frozenset((p["a"], p["b"])))
        verdict = entry[0] if (p["near_duplicate"] and entry) else (
            "UNDECLARED" if p["near_duplicate"] else "above threshold")
        L.append(f"| {p['fraction']:.6f} | {p['differing']} | {p['content_differing']} | "
                 f"{p['bbox']} | `{p['a']}`<br>`{p['b']}` | {verdict} |")
    L.append("")
    L.append("### Declared duplicates, with the reason each was adjudicated that way")
    L.append("")
    L.append("| Kind | Pair | Reason |")
    L.append("|---|---|---|")
    for a, b, kind, why in DECLARED_DUPLICATES:
        L.append(f"| {kind} | `{a}`<br>`{b}` | {why} |")
    L.append("")
    L.append("Only `IDENTICAL` pairs collapse in the distinct-state count. `DISTINCT` entries "
             "are measured false positives of the whole-frame fraction and are counted as "
             "separate states.")
    L.append("")
    L.append("## Gate C — classification")
    L.append("")
    L.append("| File | Class | Cited by |")
    L.append("|---|---|---|")
    for f in d["names"]:
        kind, cites = d["classes"][f]
        L.append(f"| `{f}` | {kind} | {', '.join(f'`{c}`' for c in cites) or '— (regenerable)'} |")
    L.append("")
    L.append("## Per-frame measurement")
    L.append("")
    L.append("| Frame | w | h | mean | min | max | bytes | md5 |")
    L.append("|---|---|---|---|---|---|---|---|")
    for r in d["records"]:
        L.append(f"| `{os.path.basename(r['path'])}` | {r['w']} | {r['h']} | {r['mean']:.4f} | "
                 f"{r['min']} | {r['max']} | {r['bytes']} | `{r['md5']}` |")
    L.append("")
    body = "\n".join(L)
    path = os.path.join(SHOTS, "MANIFEST.md")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body)
    return path


def main(argv: list[str]) -> int:
    failures, d = audit()
    if d:
        counts = {k: sum(1 for _f, (kind, _c) in d["classes"].items() if kind == k)
                  for k in ("regenerable", "historical", "orphan")}
        print(f"{len(d['names'])} files — {d['distinct']} distinct screen states "
              f"({len(d['groups'])} duplicate group(s))")
        print(f"crate walk: {len(d['walk'])} files, {len(d['walk_groups'])} declared pair, "
              f"{d['walk_distinct']} distinct states")
        print(f"classification: {counts['regenerable']} regenerable, "
              f"{counts['historical']} historical, {counts['orphan']} orphan")
        print(f"gate B: {len(d['pairs'])} pairs compared, "
              f"{sum(1 for p in d['pairs'] if p['near_duplicate'])} under threshold")
        for line in d["notes"]:
            print(line)
        for stale in d["stale"]:
            print(f"note: stale DECLARED_DUPLICATES entry no longer flagged — {stale}")

    if failures:
        for f in failures:
            print(f)
        print(f"AUDIT FAILED — {len(failures)} problem(s)")
        return 1

    if "--write-manifest" in argv:
        print(f"wrote {os.path.relpath(write_manifest(d), ROOT)}")
    print("AUDIT PASSED — gates A, B and C green")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
