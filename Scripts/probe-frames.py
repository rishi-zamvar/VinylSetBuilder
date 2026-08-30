#!/usr/bin/env python3
"""Photometric + hash + dimension probe for the committed screenshot set.

This tool was written ad-hoc and run six times across plans 02-05 and 03-05 and never
committed. Decision D-04-4 (`.planning/phases/04-act-i-signoff/CONTEXT.md`) lands it on disk.
Nothing in it is new; what is new is that it exists.

WHY THE THRESHOLDS ARE CONSTANTS AND NOT COMMAND-LINE FLAGS
-----------------------------------------------------------
A tunable threshold is a threshold that gets tuned to make a red frame green, which is exactly
the failure `.planning/VISUAL-DEFECTS.md` forbids in writing ("No threshold may be narrowed,
filtered or re-thresholded to change which verdict is reached"). `MIN_DARK` and `MIN_BRIGHT`
are therefore module constants with no override path. If a frame is red, it is red.

The three thresholds are the V2 photometric signature, frozen at the value V2 was closed on:

    a genuinely black pixel exists   ->  min <= MIN_DARK   (110)
    a white ground exists            ->  max >= MIN_BRIGHT (200)
    the frame is not flat            ->  min != max

MEASUREMENT CONVENTION
----------------------
Mean is `PIL.ImageStat.Stat(img.convert("L")).mean[0]`; min/max are
`img.convert("L").getextrema()`. This is the same convention plans 02-05 and 03-05 used, so
every number in this repo's history stays comparable. Do not switch to a different luminance
formula — the recorded per-frame means would stop meaning the same thing.

md5 is of the file bytes, not of the decoded pixels.

USAGE
-----
    Scripts/probe-frames.py [--json] [--check] [--diff A B] [--selftest] [PATHS...]

With no PATHS, measures every PNG in Artifacts/screenshots/.
"""

from __future__ import annotations

import glob
import hashlib
import json
import os
import sys

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError as exc:  # a probe that silently no-ops is worse than one that refuses
    print(f"probe-frames: Pillow is required: {exc}", file=sys.stderr)
    sys.exit(2)

MIN_DARK = 110      # min must be at or below this: a genuinely black pixel exists
MIN_BRIGHT = 200    # max must be at or above this: a white ground exists

DEFAULT_GLOB = "Artifacts/screenshots/*.png"


def measure(path: str) -> dict:
    """One frame -> one record. The only place pixels are read."""
    with open(path, "rb") as fh:
        raw = fh.read()
    img = Image.open(path)
    w, h = img.size
    grey = img.convert("L")
    lo, hi = grey.getextrema()
    return {
        "path": path,
        "w": w,
        "h": h,
        "mean": round(ImageStat.Stat(grey).mean[0], 4),
        "min": lo,
        "max": hi,
        "md5": hashlib.md5(raw).hexdigest(),
        "bytes": len(raw),
    }


def failures(rec: dict) -> list[str]:
    """The V2 signature, applied. Empty list means the frame is healthy."""
    out = []
    if rec["min"] > MIN_DARK:
        out.append(f"min={rec['min']} > {MIN_DARK} (no genuinely dark pixel)")
    if rec["max"] < MIN_BRIGHT:
        out.append(f"max={rec['max']} < {MIN_BRIGHT} (no white ground)")
    if rec["min"] == rec["max"]:
        out.append(f"min == max == {rec['min']} (flat frame)")
    return out


def diff(a: str, b: str) -> tuple[int, int, float]:
    """Differing pixel count between two frames, and that count as a fraction."""
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if ia.size != ib.size:
        raise SystemExit(f"probe-frames: dimension mismatch {ia.size} vs {ib.size}")
    d = ImageChops.difference(ia, ib).convert("L")
    differing = sum(count for value, count in enumerate(d.histogram()) if value and count)
    total = ia.size[0] * ia.size[1]
    return differing, total, differing / total


def markdown_table(records: list[dict]) -> str:
    lines = ["| frame | w | h | mean | min | max | bytes | md5 |",
             "|---|---|---|---|---|---|---|---|"]
    for r in records:
        lines.append(
            f"| `{os.path.basename(r['path'])}` | {r['w']} | {r['h']} | {r['mean']:.4f} "
            f"| {r['min']} | {r['max']} | {r['bytes']} | `{r['md5']}` |"
        )
    return "\n".join(lines)


def selftest() -> int:
    """The negative control this plan mandates, made permanently runnable.

    A gate that has never been red is a decoration. This builds the two synthetic frames that
    carry the failure signatures and asserts --check's logic reddens on both.
    """
    import tempfile

    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        pale = os.path.join(tmp, "pale.png")
        flat = os.path.join(tmp, "flat.png")
        good = os.path.join(tmp, "good.png")
        Image.new("RGB", (100, 100), (200, 200, 200)).save(pale)
        Image.new("RGB", (100, 100), (0, 0, 0)).save(flat)
        img = Image.new("RGB", (100, 100), (255, 255, 255))
        img.paste((0, 0, 0), (0, 0, 50, 50))
        img.save(good)

        for path, want in ((pale, "min=200 > 110"), (flat, "flat frame")):
            got = failures(measure(path))
            hit = any(want in f for f in got)
            print(f"selftest {'PASS' if hit else 'FAIL'}: {os.path.basename(path)} -> {got}")
            ok &= hit
        got = failures(measure(good))
        print(f"selftest {'PASS' if not got else 'FAIL'}: good.png -> {got or 'healthy'}")
        ok &= not got

        differing, total, frac = diff(pale, flat)
        hit = differing == total
        print(f"selftest {'PASS' if hit else 'FAIL'}: diff pale/flat -> "
              f"differing={differing} total={total} fraction={frac:.6f}")
        ok &= hit
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    args = argv[1:]
    if "--selftest" in args:
        return selftest()

    if "--diff" in args:
        i = args.index("--diff")
        operands = args[i + 1:i + 3]
        if len(operands) != 2:
            print("probe-frames: --diff needs exactly two paths", file=sys.stderr)
            return 2
        differing, total, frac = diff(*operands)
        print(f"differing={differing} total={total} fraction={frac:.6f}")
        return 0

    as_json = "--json" in args
    check = "--check" in args
    paths = sorted(a for a in args if not a.startswith("--"))
    if not paths:
        paths = sorted(glob.glob(DEFAULT_GLOB))
    if not paths:
        print(f"probe-frames: no PNGs matched {DEFAULT_GLOB}", file=sys.stderr)
        return 2

    records = [measure(p) for p in paths]

    if check:
        suspect = [(r, f) for r in records if (f := failures(r))]
        if not suspect:
            print(f"SUSPECT: none ({len(records)} frames measured, "
                  f"thresholds MIN_DARK={MIN_DARK} MIN_BRIGHT={MIN_BRIGHT})")
            return 0
        for rec, why in suspect:
            print(f"SUSPECT: {rec['path']} — {'; '.join(why)}")
        print(f"{len(suspect)} of {len(records)} frames failed the V2 signature")
        return 1

    if as_json:
        print(json.dumps(records, indent=2))
    else:
        print(markdown_table(records))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
