#!/usr/bin/env python3
"""Update the current proof metrics (VC counts, SPARK level, units analyzed)
in the repo documentation after a proof run.

The proof numbers in AGENTS.md, README.md, the proof ledger, and the current
dev changelog were edited by hand and went stale on every proof change.  This
script parses the current gnatprove summary (obj/gnatprove/gnatprove.out),
derives the SPARK level with the same rules as
Adacovex.Parsers.GNATprove.Determine_SPARK_Level, and rewrites the anchored
proof-metric phrases across the docs.  Historical notes (the pre-audit
"369 total checks" row in the ledger, past-release changelogs) are left
untouched because they do not match the anchored patterns.

Usage:
  python3 tools/update-proof-status.py [--run-prove] [--out=obj/gnatprove/gnatprove.out] [--dry-run]

--run-prove  Run `./bin/adacovex prove --target=. --no-svg` first to refresh
             obj/gnatprove/gnatprove.out (takes several minutes).
--out        Path to the gnatprove summary to parse (default
             obj/gnatprove/gnatprove.out).
--dry-run    Parse and report the new metrics without editing any file.

Exit code 0 when every anchored pattern matched and was updated (or, with
--dry-run, would be), 1 when a metric could not be parsed or a pattern did
not match any file.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

LEVELS = ["Stone", "Bronze", "Silver", "Gold", "Platinum"]
LEVEL_RE = "(?:Stone|Bronze|Silver|Gold|Platinum)"

# gnatprove summary rows we read.  Label prefix -> count/proved column pair.
CATEGORY_ROWS = {
    "Flow Dependencies": "flow",
    "Run-time Checks": "runtime",
    "Assertions": "assert",
    "Functional Contracts": "functional",
}


def numbers(s):
    return [int(m) for m in re.findall(r"\d+", s)]


def parse_summary(path):
    """Return a metrics dict parsed from a gnatprove.out summary."""
    text = Path(path).read_text(errors="replace")
    total = proved = flow = justified = unproved = units = None
    cats = {"flow": (0, 0), "runtime": (0, 0), "assert": (0, 0),
            "functional": (0, 0)}

    for line in text.splitlines():
        if line.startswith("Total"):
            n = numbers(line)
            # Columns: Total | Flow | Provers | Justified | Unproved
            # (runs of 2+ spaces separate them; '.' means zero/none).
            vals = re.split(r" {2,}", line.strip())
            def col(i):
                v = vals[i] if i < len(vals) else "."
                m = re.match(r"\d+", v)
                return int(m.group(0)) if m else 0
            total = col(1)
            flow = col(2)
            proved = col(3)
            justified = col(4)
            unproved = col(5)
        m = re.match(r"(Flow Dependencies|Run-time Checks|Assertions|Functional Contracts)\s+(.*)", line)
        if m:
            n = numbers(m.group(2))
            cats[CATEGORY_ROWS[m.group(1)]] = (n[0], n[1]) if n else (0, 0)
        if "Analyzed" in line and "units" in line:
            u = numbers(line)
            if u:
                units = u[0]

    if total is None:
        raise SystemExit(f"error: no 'Total' row found in {path}")

    if total != flow + proved + justified + unproved:
        raise SystemExit(
            f"error: inconsistent gnatprove totals in {path}: "
            f"total {total} != flow {flow} + proved {proved} + "
            f"justified {justified} + unproved {unproved}")

    # Same rules as Determine_SPARK_Level in
    # src/parsers/adacovex-parsers-gnatprove.adb.
    if total == 0 and unproved == 0 and not any(c[0] for c in cats.values()):
        level = "Stone"
    elif unproved > 0:
        level = "Silver"
    elif cats["functional"][0] > 0 \
            and cats["functional"][1] == cats["functional"][0]:
        level = "Platinum"
    elif cats["runtime"][1] >= cats["runtime"][0]:
        level = "Gold" if cats["assert"][1] >= cats["assert"][0] else "Silver"
    elif cats["flow"][1] >= cats["flow"][0]:
        level = "Bronze"
    else:
        level = "Stone"

    return {
        "total": total, "proved": proved, "flow": flow,
        "justified": justified, "unproved": unproved,
        "units": units or 0, "level": level,
    }


def replacements(m):
    """Ordered (pattern, format) pairs applied across the doc files.
    Anchored to proof context so historical numbers are never touched."""
    lvl = m["level"]
    t, p, u, n = m["total"], m["proved"], m["unproved"], m["units"]
    return [
        # "Platinum (369 VCs)" -- level + total together.
        (re.compile(rf"{LEVEL_RE} \((\d+) VCs\)"), f"{lvl} ({t} VCs)"),
        # "Platinum (369 VCs, 0 unproved under gnatprove 16.1.0)".
        (re.compile(rf"{LEVEL_RE} \((\d+) VCs, (\d+) unproved under gnatprove"),
         f"{lvl} ({t} VCs, {u} unproved under gnatprove"),
        # "Platinum under `gnatprove` 16.1.0".
        (re.compile(rf"{LEVEL_RE} under `gnatprove`"), f"{lvl} under `gnatprove`"),
        # "369 VCs total, 310 proved, 0 unproved" (ledger status line).
        (re.compile(r"(\d+) VCs total, (\d+) proved, (\d+) unproved"),
         f"{t} VCs total, {p} proved, {u} unproved"),
        # "369 VCs, 310 proved, 0 unproved".
        (re.compile(r"(\d+) VCs, (\d+) proved, (\d+) unproved"),
         f"{t} VCs, {p} proved, {u} unproved"),
        # "369 VCs, 0 unproved" (no proved count).
        (re.compile(r"(\d+) VCs, (\d+) unproved"),
         f"{t} VCs, {u} unproved"),
        # "369 VCs under gnatprove 16.1.0".
        (re.compile(r"(\d+) VCs under gnatprove"), f"{t} VCs under gnatprove"),
        # "all checks proved (369 checks)".
        (re.compile(r"all checks proved \((\d+) checks\)"),
         f"all checks proved ({t} checks)"),
        # "38 analyzed units".
        (re.compile(r"(\d+) analyzed units"), f"{n} analyzed units"),
    ]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-prove", action="store_true",
                    help="refresh obj/gnatprove/gnatprove.out via adacovex prove")
    ap.add_argument("--out", default=str(ROOT / "obj/gnatprove/gnatprove.out"))
    ap.add_argument("--dry-run", action="store_true",
                    help="report new metrics without editing files")
    args = ap.parse_args()

    if args.run_prove:
        exe = ROOT / "bin" / "adacovex"
        subprocess.run([str(exe), "prove", "--target=.", "--no-svg"],
                       check=True, cwd=str(ROOT))

    m = parse_summary(args.out)
    print(f"gnatprove: {m['total']} VCs, {m['proved']} proved, "
          f"{m['flow']} flow, {m['unproved']} unproved, "
          f"{m['units']} units -> {m['level']}")

    files = [
        ROOT / "AGENTS.md",
        ROOT / "README.md",
        ROOT / "docs/proof/16.1.0-ledger.md",
        ROOT / "docs/changelogs/adacovex-1.9.0.md",
    ]

    if args.dry_run:
        return 0

    matched = 0
    for f in files:
        if not f.exists():
            print(f"skip (missing): {f.name}")
            continue
        text = f.read_text()
        orig = text
        for pat, rep in replacements(m):
            text, cnt = pat.subn(rep, text)
            matched += cnt
        if text != orig:
            f.write_text(text)
            print(f"updated: {f.relative_to(ROOT)}")

    if matched == 0:
        print("error: no proof-metric pattern matched; docs may be out of sync",
              file=sys.stderr)
        return 1
    print(f"updated {matched} metric occurrence(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
