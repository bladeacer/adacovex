#!/usr/bin/env python3
"""Run the assessment targets (prove / self / sbom / ada-crdt).

The old Makefile repeated the same adacovex invocation shape in four
targets (prove, run-self, sbom, run-ada-crdt) and passed the gate flags
to release.py separately -- so a gate change had to land in several
places at once.  This script is the single owner of that shape:

  python3 tools/run.py prove       -- adacovex prove --target=. <gates> --emit-svg=docs/badges/
  python3 tools/run.py self        -- adacovex --target=. <gates> --emit-svg=docs/badges/
  python3 tools/run.py sbom        -- adacovex sbom --target=. --dal=C
  python3 tools/run.py ada-crdt    -- adacovex --target=../Ada_CRDT --dal=C
  python3 tools/run.py assess-args -- print the acceptance-gate flags
                                     (consumed by tools/release.py)

Every adacovex invocation runs with SOURCE_DATE_EPOCH set to the target
repository's HEAD commit timestamp (0 when the target has no HEAD), so the
SVG badges and SBOM output are reproducible across runs.

Exit code is adacovex's.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import List

ROOT: Path = Path(__file__).resolve().parent.parent

# Self-assessment acceptance gates, defined once so prove / self / release /
# CI stay in sync (and match the AGENTS.md "Dogfood target" section).
# --require-tests is the current native test-suite size (docs/test_result.md).
SELF_ASSESS_ARGS: str = (
    "--dal=C --standard=all --require-spark=Platinum "
    "--require-docstrings=100 --require-tests=973 --require-proof=100"
)


def source_date_epoch(target: Path) -> str:
    """HEAD commit timestamp for reproducible output (0 when there is no HEAD)."""
    result = subprocess.run(
        ["git", "-C", str(target), "show", "-s", "--format=%ct", "HEAD"],
        capture_output=True, text=True,
    )
    return result.stdout.strip() or "0"


def adacovex(target: Path, args: List[str]) -> int:
    """Run bin/adacovex from the repo root against target with the gates env."""
    env = dict(os.environ)
    env["SOURCE_DATE_EPOCH"] = source_date_epoch(target)
    cmd = [str(ROOT / "bin" / "adacovex")] + args
    return subprocess.run(cmd, env=env).returncode


def run(command: str) -> int:
    if command == "prove":
        return adacovex(
            ROOT,
            ["prove", "--target=."] + SELF_ASSESS_ARGS.split()
            + ["--emit-svg=docs/badges/"],
        )
    if command == "self":
        return adacovex(
            ROOT,
            ["--target=."] + SELF_ASSESS_ARGS.split()
            + ["--emit-svg=docs/badges/"],
        )
    if command == "sbom":
        return adacovex(ROOT, ["sbom", "--target=.", "--dal=C"])
    if command == "ada-crdt":
        return adacovex(
            ROOT.parent / "Ada_CRDT", ["--target=../Ada_CRDT", "--dal=C"]
        )
    # assess-args is handled in main() before dispatch.
    raise SystemExit(f"error: unknown command: {command}")


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "command",
        choices=["prove", "self", "sbom", "ada-crdt", "assess-args"],
        help="assessment to run (assess-args prints the gate flags)",
    )
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])
    if args.command == "assess-args":
        print(SELF_ASSESS_ARGS)
        return 0
    return run(args.command)


if __name__ == "__main__":
    sys.exit(main())
