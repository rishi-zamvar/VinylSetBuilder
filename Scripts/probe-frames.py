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

--region AND --ink (added by plan 04-03)
----------------------------------------
`--region X,Y,W,H` restricts every measurement to that box. `--ink T` additionally reports,
over whatever region is in force:

    ink        pixels strictly darker than T          -> is there any ink at all
    ink_frac   that count over the region's area
    mode       the most common luminance in the box   -> the background the ink sits on
    contrast   mode - min                              -> how far the darkest ink is FROM it

`contrast` is the number V4 is decided on, and `ink` is the number V9 is decided on. Neither
threshold is fitted: V4's floor (`CONTRAST_MIN = 60`) is asserted in
`UITests/BadgeContrastUITests.swift` and was written down before any badge was measured, and
V9's band is calibrated against two values recorded in `.planning/VISUAL-DEFECTS.md` months
of frames ago (ink 0 on a title-less frame, 9498 on `02-walk-01`) before it is trusted.

`mode` and not `mean` is deliberate: a badge capsule is mostly background, so the modal
luminance IS the background, whereas the mean drags toward the ink and would make a badge look
better-contrasted the more text it carried.

USAGE
-----
    Scripts/probe-frames.py [--json] [--check] [--diff A B] [--selftest]
                            [--region X,Y,W,H] [--ink T] [PATHS...]

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


def measure(path: str, region: tuple[int, int, int, int] | None = None,
            ink: int | None = None) -> dict:
    """One frame -> one record. The only place pixels are read.

    `w`/`h`/`md5`/`bytes` always describe the WHOLE file, so a record stays comparable with
    every number this repo already recorded. Only the photometry moves into `region`.
    """
    with open(path, "rb") as fh:
        raw = fh.read()
    img = Image.open(path)
    w, h = img.size
    grey = img.convert("L")
    if region is not None:
        x, y, rw, rh = region
        if x < 0 or y < 0 or x + rw > w or y + rh > h or rw <= 0 or rh <= 0:
            raise SystemExit(f"probe-frames: region {region} does not fit inside {w}x{h} "
                             f"for {path} — refusing to silently clamp it")
        grey = grey.crop((x, y, x + rw, y + rh))
    lo, hi = grey.getextrema()
    rec = {
        "path": path,
        "w": w,
        "h": h,
        "mean": round(ImageStat.Stat(grey).mean[0], 4),
        "min": lo,
        "max": hi,
        "md5": hashlib.md5(raw).hexdigest(),
        "bytes": len(raw),
    }
    if region is not None:
        rec["region"] = list(region)
    if ink is not None:
        hist = grey.histogram()
        area = grey.size[0] * grey.size[1]
        dark = sum(hist[:ink])
        mode = max(range(256), key=lambda v: hist[v])
        rec.update({
            "ink_threshold": ink,
            "ink": dark,
            "ink_frac": round(dark / area, 6),
            "mode": mode,
            "contrast": mode - lo,
            "area": area,
        })
    return rec


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
    inked = any("ink" in r for r in records)
    head = "| frame | w | h | mean | min | max | bytes | md5 |"
    rule = "|---|---|---|---|---|---|---|---|"
    if inked:
        head = ("| frame | region | area | mean | min | max | mode | contrast "
                "| ink | ink_frac | md5 |")
        rule = "|---|---|---|---|---|---|---|---|---|---|---|"
    lines = [head, rule]
    for r in records:
        name = os.path.basename(r["path"])
        if inked:
            lines.append(
                f"| `{name}` | {r.get('region', 'whole')} | {r.get('area', r['w'] * r['h'])} "
                f"| {r['mean']:.4f} | {r['min']} | {r['max']} | {r.get('mode', '—')} "
                f"| {r.get('contrast', '—')} | {r.get('ink', '—')} "
                f"| {r.get('ink_frac', '—')} | `{r['md5']}` |")
        else:
            lines.append(
                f"| `{name}` | {r['w']} | {r['h']} | {r['mean']:.4f} "
                f"| {r['min']} | {r['max']} | {r['bytes']} | `{r['md5']}` |")
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

        # --region and --ink, added by 04-03. `good.png` is a 100x100 white frame with a black
        # 50x50 patch at the origin, so both flags have arithmetic that is known in advance and
        # the assertions below are not fitted to whatever the code happens to print.
        whole = measure(good, ink=128)
        hit = (whole["ink"] == 2500 and whole["mode"] == 255 and whole["contrast"] == 255
               and whole["area"] == 10000)
        print(f"selftest {'PASS' if hit else 'FAIL'}: --ink 128 on the whole good.png -> "
              f"ink={whole['ink']} (want 2500) mode={whole['mode']} (want 255) "
              f"contrast={whole['contrast']} (want 255)")
        ok &= hit

        black = measure(good, region=(0, 0, 50, 50), ink=128)
        hit = black["ink"] == 2500 and black["area"] == 2500 and black["ink_frac"] == 1.0
        print(f"selftest {'PASS' if hit else 'FAIL'}: --region 0,0,50,50 -> "
              f"ink={black['ink']}/{black['area']} frac={black['ink_frac']} (want 1.0)")
        ok &= hit

        # The one that matters: a region containing NO ink must report 0, or every V9
        # measurement in this repo is meaningless. This is the "provably able to be zero" half.
        white = measure(good, region=(50, 50, 50, 50), ink=128)
        hit = white["ink"] == 0 and white["contrast"] == 0 and white["mode"] == 255
        print(f"selftest {'PASS' if hit else 'FAIL'}: --region 50,50,50,50 (no ink) -> "
              f"ink={white['ink']} (want 0) contrast={white['contrast']} (want 0)")
        ok &= hit

        # A region that does not fit must refuse rather than clamp: a silently clamped region
        # measures a different box than the one named, which is how a fixed band stops being
        # fixed.
        try:
            measure(good, region=(90, 90, 50, 50))
            print("selftest FAIL: an out-of-bounds region was accepted")
            ok = False
        except SystemExit:
            print("selftest PASS: out-of-bounds region refused rather than clamped")
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

    # --region and --ink each consume the argument after them, so those values must not fall
    # through into the path list. A probe that silently measured its own threshold as a frame
    # would be the exact failure mode this file's header warns about.
    region = ink = None
    consumed: set[int] = set()
    for flag in ("--region", "--ink"):
        if flag not in args:
            continue
        i = args.index(flag)
        if i + 1 >= len(args):
            print(f"probe-frames: {flag} needs a value", file=sys.stderr)
            return 2
        consumed |= {i, i + 1}
        value = args[i + 1]
        try:
            if flag == "--region":
                parts = tuple(int(v) for v in value.split(","))
                if len(parts) != 4:
                    raise ValueError("need exactly four comma-separated integers")
                region = parts
            else:
                ink = int(value)
                if not 0 <= ink <= 256:
                    raise ValueError("threshold must be a luminance in 0...256")
        except ValueError as exc:
            print(f"probe-frames: bad {flag} value {value!r}: {exc}", file=sys.stderr)
            return 2

    paths = sorted(a for i, a in enumerate(args)
                   if i not in consumed and not a.startswith("--"))
    if not paths:
        paths = sorted(glob.glob(DEFAULT_GLOB))
    if not paths:
        print(f"probe-frames: no PNGs matched {DEFAULT_GLOB}", file=sys.stderr)
        return 2

    records = [measure(p, region=region, ink=ink) for p in paths]

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
