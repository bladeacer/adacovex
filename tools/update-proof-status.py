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

The "proved" count reported and written here is the honest total proved VCs
(flow + provers), computed the same way as Adacovex.Parsers.GNATprove sets
Types.Proof_Summary.Proved_VCs:

    proved = total - justified - unproved

This keeps the docs consistent with the adacovex CLI's proved-VC coverage
percentage (Proved_VCs * 100 / Total_VCs) and the Markdown renderer's
"Total | Proved" table.  It deliberately does NOT reuse the raw "Provers"
summary column, which excludes the VCs discharged by flow analysis.

The file set is derived from the tree (tools/live_files.py) rather than a
hardcoded list, so a new doc file carrying a proof metric is picked up
automatically and can never go stale.  Historical records (past-release
changelogs, past proof ledgers) and generated outputs are excluded there.

Usage:
  python3 tools/update-proof-status.py [--run-prove] [--out=obj/gnatprove/gnatprove.out] [--dry-run] [--check]

--run-prove  Run `./bin/adacovex prove --target=. --no-svg` first to refresh
             obj/gnatprove/gnatprove.out (takes several minutes).
--out        Path to the gnatprove summary to parse (default
             obj/gnatprove/gnatprove.out).
--dry-run    Parse and report the new metrics without editing any file.
--check      Verify every live file already carries the current metrics;
             exit 1 (without editing) when any file is stale.

Exit code 0 when every anchored pattern matched and was updated (or, with
--dry-run/--check, would be / already is), 1 when a metric could not be
parsed or a pattern did not match any file.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Pattern, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

from live_files import live_files  # noqa: E402  (same-tools import)

LEVELS: List[str] = ["Stone", "Bronze", "Silver", "Gold", "Platinum"]
LEVEL_RE: str = "(?:Stone|Bronze|Silver|Gold|Platinum)"

# gnatprove summary rows we read.  Label prefix -> count/proved column pair.
CATEGORY_ROWS: Dict[str, str] = {
    "Flow Dependencies": "flow",
    "Run-time Checks": "runtime",
    "Assertions": "assert",
    "Functional Contracts": "functional",
}

# Metrics parsed from a gnatprove.out summary.
Metrics = Dict[str, int]


def numbers(s: str) -> List[int]:
    return [int(m) for m in re.findall(r"\d+", s)]


def parse_summary(path: Path) -> Metrics:
    """Return a metrics dict parsed from a gnatprove.out summary.

    "proved" is the honest total proved VCs (flow + provers), matching
    Adacovex.Parsers.GNATprove's Proved_VCs = Total - Justified - Unproved.
    """
    text: str = Path(path).read_text(errors="replace")
    total: Optional[int] = None
    flow: Optional[int] = None
    provers: Optional[int] = None
    justified: Optional[int] = None
    unproved: Optional[int] = None
    units: Optional[int] = None
    cats: Dict[str, Tuple[int, int]] = {
        "flow": (0, 0),
        "runtime": (0, 0),
        "assert": (0, 0),
        "functional": (0, 0),
    }

    for line in text.splitlines():
        if line.startswith("Total"):
            n: List[int] = numbers(line)
            # Columns: Total | Flow | Provers | Justified | Unproved
            # (runs of 2+ spaces separate them; '.' means zero/none).
            vals: List[str] = re.split(r" {2,}", line.strip())

            def col(i: int) -> int:
                v: str = vals[i] if i < len(vals) else "."
                m: Optional[re.Match] = re.match(r"\d+", v)
                return int(m.group(0)) if m else 0

            total = col(1)
            flow = col(2)
            provers = col(3)
            justified = col(4)
            unproved = col(5)
        m: Optional[re.Match] = re.match(
            r"(Flow Dependencies|Run-time Checks|Assertions|Functional Contracts)"
            r"\s+(.*)",
            line,
        )
        if m:
            n = numbers(m.group(2))
            cats[CATEGORY_ROWS[m.group(1)]] = (n[0], n[1]) if n else (0, 0)
        if "Analyzed" in line and "units" in line:
            u: List[int] = numbers(line)
            if u:
                units = u[0]

    if total is None:
        raise SystemExit(f"error: no 'Total' row found in {path}")

    # The summary's own invariant: Total == Flow + Provers + Justified +
    # Unproved.  The "proved" figure we write to the docs is flow + provers
    # (== total - justified - unproved), i.e. the same value adacovex derives.
    if total != (flow or 0) + (provers or 0) + (justified or 0) + (unproved or 0):
        raise SystemExit(
            f"error: inconsistent gnatprove totals in {path}: "
            f"total {total} != flow {flow} + provers {provers} + "
            f"justified {justified} + unproved {unproved}"
        )

    proved: int = total - (justified or 0) - (unproved or 0)

    # Same rules as Determine_SPARK_Level in
    # src/parsers/adacovex-parsers-gnatprove.adb.
    if total == 0 and (unproved or 0) == 0 and not any(c[0] for c in cats.values()):
        level: str = "Stone"
    elif (unproved or 0) > 0:
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
        "total": total,
        "proved": proved,
        "flow": flow or 0,
        "justified": justified or 0,
        "unproved": unproved or 0,
        "units": units or 0,
        "level": level,
    }


def replacements(m: Metrics) -> List[Tuple[Pattern[str], str]]:
    """Ordered (pattern, format) pairs applied across the doc files.
    Anchored to proof context so historical numbers are never touched."""
    lvl: str = m["level"]
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
        # "(401/401 VCs proved)" -- crate-description phrasing (proved/total).
        (re.compile(r"\((\d+)/(\d+) VCs proved\)"),
         f"({p}/{t} VCs proved)"),
        # "398/398 VCs proved across 39 analyzed units" (CONTRIBUTING.md).
        (re.compile(r"(\d+)/(\d+) VCs proved across (\d+) analyzed units"),
         f"{p}/{t} VCs proved across {n} analyzed units"),
        # "369 VCs under gnatprove 16.1.0".
        (re.compile(r"(\d+) VCs under gnatprove"), f"{t} VCs under gnatprove"),
        # "all checks proved (369 checks)".
        (re.compile(r"all checks proved \((\d+) checks\)"),
         f"all checks proved ({t} checks)"),
        # "38 analyzed units".
        (re.compile(r"(\d+) analyzed units"), f"{n} analyzed units"),
        # CI threshold gates pinned to the assessed SPARK level:
        # "--require-spark=Platinum" (Makefile, docs) and
        # "require-spark: Platinum" (workflows).
        (re.compile(rf"--require-spark={LEVEL_RE}"), f"--require-spark={lvl}"),
        (re.compile(rf"require-spark: {LEVEL_RE}"), f"require-spark: {lvl}"),
    ]


def main() -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-prove", action="store_true",
                    help="refresh obj/gnatprove/gnatprove.out via adacovex prove")
    ap.add_argument("--out", default=str(ROOT / "obj/gnatprove/gnatprove.out"))
    ap.add_argument("--dry-run", action="store_true",
                    help="report new metrics without editing files")
    ap.add_argument("--check", action="store_true",
                    help="verify live files carry the current metrics (exit 1 when stale)")
    args: argparse.Namespace = ap.parse_args()

    if args.run_prove:
        exe: Path = ROOT / "bin" / "adacovex"
        subprocess.run([str(exe), "prove", "--target=.", "--no-svg"],
                       check=True, cwd=str(ROOT))

    m: Metrics = parse_summary(Path(args.out))
    print(f"gnatprove: {m['total']} VCs, {m['proved']} proved, "
          f"{m['flow']} flow, {m['unproved']} unproved, "
          f"{m['units']} units -> {m['level']}")

    # Every live file under the tree (see tools/live_files.py): generated
    # outputs, past changelogs/ledgers, and the tools themselves are
    # excluded there, so a stale reference anywhere in the repo is caught.
    files: List[Path] = live_files()

    if args.dry_run:
        print(f"would scan {len(files)} live file(s)")
        return 0

    matched: int = 0
    stale: int = 0
    for f in files:
        text: str = f.read_text(errors="replace")
        orig: str = text
        for pat, rep in replacements(m):
            text, cnt = pat.subn(rep, text)
            matched += cnt
        if text != orig:
            if args.check:
                stale += 1
                print(f"STALE: {f.relative_to(ROOT)}")
            else:
                f.write_text(text)
                print(f"updated: {f.relative_to(ROOT)}")

    if args.check:
        if stale:
            print(f"error: {stale} file(s) carry stale proof metrics "
                  f"(run `make proof-status` to refresh)", file=sys.stderr)
            return 1
        print("proof metrics in sync across all live files")
        return 0

    if matched == 0:
        print("error: no proof-metric pattern matched; docs may be out of sync",
              file=sys.stderr)
        return 1
    print(f"updated {matched} metric occurrence(s) across {len(files)} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
