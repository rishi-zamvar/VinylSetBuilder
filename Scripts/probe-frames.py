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

--drift (added by plan 04-06, from 04-05's second finding)
----------------------------------------------------------
A regeneration was checked by comparing per-frame MEAN luminance between runs against a
+/-0.06 bar. On `02-walk-09-detail-manual-order.png` that bar measured **0.0346 — inside it —
on a frame where 22,142 content pixels had changed**, because the two top rows of the list had
swapped and a mean cannot see a permutation. Swapping two rows moves ink from one place to
another and leaves the average exactly where it was.

`--drift A B` therefore reports BOTH numbers and fails if EITHER is breached:

    mean_delta   |mean(A) - mean(B)|                     <= MAX_MEAN_DRIFT   (0.06)
    content_px   differing pixels below CONTENT_BAND_Y   == 0                (y >= 150)

The band excludes the status-bar clock, which legitimately differs between any two runs; that
is the same y=150 cut every content-band measurement in this repo already uses. Thresholds are
module constants for the same reason the three above are: a bar you can pass on the command
line is a bar that gets passed.

`--selftest` builds a synthetic PERMUTATION — two frames with identical means and a swapped
pair of bands — and asserts the mean bar passes it while the positional bar catches it. That
case IS the negative control for the mean-only claim.

USAGE
-----
    Scripts/probe-frames.py [--json] [--check] [--diff A B] [--drift A B] [--selftest]
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

# --drift, plan 04-06. Not flags, for the reason stated in the header.
MAX_MEAN_DRIFT = 0.06   # the bar 02-05 recorded, kept at the value it was recorded at
CONTENT_BAND_Y = 150    # everything below this row is content; above it is the status bar

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


def drift(a: str, b: str) -> dict:
    """Mean drift AND a positional check, because a mean cannot see a permutation.

    Returns both numbers plus the bounding box of whatever changed in the content band, so a
    breach names WHERE it is rather than only that it happened.
    """
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if ia.size != ib.size:
        raise SystemExit(f"probe-frames: dimension mismatch {ia.size} vs {ib.size}")
    mean_a = ImageStat.Stat(ia.convert("L")).mean[0]
    mean_b = ImageStat.Stat(ib.convert("L")).mean[0]

    d = ImageChops.difference(ia, ib).convert("L")
    w, h = d.size
    band = d.crop((0, min(CONTENT_BAND_Y, h), w, h))
    content_px = sum(c for v, c in enumerate(band.histogram()) if v and c)
    box = band.getbbox()
    if box is not None:
        box = (box[0], box[1] + CONTENT_BAND_Y, box[2], box[3] + CONTENT_BAND_Y)
    return {
        "a": a, "b": b,
        "mean_a": round(mean_a, 4), "mean_b": round(mean_b, 4),
        "mean_delta": round(abs(mean_a - mean_b), 4),
        "content_px": content_px,
        "content_bbox": box,
        "mean_ok": abs(mean_a - mean_b) <= MAX_MEAN_DRIFT,
        "content_ok": content_px == 0,
    }


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

        # --drift, plan 04-06. THE case that matters: a PERMUTATION. `left` and `right` hold
        # the same two bands in opposite orders, so their means are identical to the last
        # decimal and the +/-0.06 mean bar passes an image that has been completely rearranged.
        # This is 04-05's finding, made permanently runnable: the mean bar is blind, the
        # positional bar is not, and the assertions below check BOTH halves of that sentence.
        left = os.path.join(tmp, "perm-a.png")
        right = os.path.join(tmp, "perm-b.png")
        a_img = Image.new("RGB", (100, 400), (255, 255, 255))
        a_img.paste((0, 0, 0), (0, 150, 100, 250))          # dark band high, in the content area
        a_img.save(left)
        b_img = Image.new("RGB", (100, 400), (255, 255, 255))
        b_img.paste((0, 0, 0), (0, 250, 100, 350))          # the same band, moved down
        b_img.save(right)

        rec = drift(left, right)
        hit = rec["mean_delta"] == 0.0 and rec["mean_ok"]
        print(f"selftest {'PASS' if hit else 'FAIL'}: --drift on a permutation — the MEAN bar is "
              f"blind to it: mean_delta={rec['mean_delta']} (want 0.0) within "
              f"{MAX_MEAN_DRIFT} -> mean_ok={rec['mean_ok']} (want True)")
        ok &= hit
        hit = rec["content_px"] == 20000 and not rec["content_ok"]
        print(f"selftest {'PASS' if hit else 'FAIL'}: --drift on a permutation — the POSITIONAL "
              f"bar catches it: content_px={rec['content_px']} (want 20000) "
              f"bbox={rec['content_bbox']} -> content_ok={rec['content_ok']} (want False)")
        ok &= hit

        # And it must be able to say "identical", or a gate that always reddens is no gate.
        same = drift(left, left)
        hit = same["mean_delta"] == 0.0 and same["content_px"] == 0 and same["content_ok"]
        print(f"selftest {'PASS' if hit else 'FAIL'}: --drift on a frame against itself -> "
              f"content_px={same['content_px']} (want 0) content_ok={same['content_ok']}")
        ok &= hit

        # A change confined ABOVE the band (the status-bar clock) must NOT redden it — that is
        # the whole reason the band exists, and it is what let 04-05 tell run 2 from run 3.
        clock = os.path.join(tmp, "perm-a-clock.png")
        c_img = a_img.copy()
        c_img.paste((0, 0, 0), (10, 20, 60, 60))
        c_img.save(clock)
        above = drift(left, clock)
        hit = above["content_px"] == 0 and above["content_ok"]
        print(f"selftest {'PASS' if hit else 'FAIL'}: --drift ignores a change above "
              f"y={CONTENT_BAND_Y} -> content_px={above['content_px']} (want 0)")
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

    if "--drift" in args:
        i = args.index("--drift")
        operands = args[i + 1:i + 3]
        if len(operands) != 2:
            print("probe-frames: --drift needs exactly two paths", file=sys.stderr)
            return 2
        rec = drift(*operands)
        print(f"mean_a={rec['mean_a']} mean_b={rec['mean_b']} "
              f"mean_delta={rec['mean_delta']} (bar {MAX_MEAN_DRIFT}) -> "
              f"{'ok' if rec['mean_ok'] else 'BREACHED'}")
        print(f"content_px={rec['content_px']} below y={CONTENT_BAND_Y} "
              f"bbox={rec['content_bbox']} -> "
              f"{'ok' if rec['content_ok'] else 'CHANGED'}")
        if rec["mean_ok"] and rec["content_ok"]:
            print("DRIFT: none")
            return 0
        print("DRIFT: the two frames are NOT the same state")
        return 1

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
