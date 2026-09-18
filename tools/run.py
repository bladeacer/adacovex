#!/usr/bin/env python3
"""Run the assessment targets (prove / self / sbom / ada-crdt).

The old Makefile repeated the same adacovex invocation shape in four
targets (prove, run-self, sbom, run-ada-crdt) and passed the gate flags
to release.py separately -- so a gate change had to land in several
places at once.  This script is the single owner of that shape:

  python3 tools/run.py prove       -- adacovex prove -t=. <gates> --svg-path=docs/badges/
  python3 tools/run.py self        -- adacovex -t=. <gates> --svg-path=docs/badges/
  python3 tools/run.py sbom        -- adacovex sbom -t=. --dal=C
  python3 tools/run.py ada-crdt    -- adacovex -t=../Ada_CRDT --dal=C
  python3 tools/run.py assess-args -- print the acceptance-gate flags
                                     (consumed by tools/release.py)

Every adacovex invocation runs with SOURCE_DATE_EPOCH set to the target
repository's HEAD commit timestamp (0 when the target has no HEAD), so the
SVG badges and SBOM output are reproducible across runs.

Exit code is adacovex's.
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import List

ROOT: Path = Path(__file__).resolve().parent.parent

# docs/test_result.md is the single source of truth for the native test count:
# `make test` writes it and tools/update-test-count.py syncs every other file
# from it.  The acceptance gate derives --require-tests from this file at run
# time, so the gate can never drift from the suite again.
TEST_RESULT: Path = ROOT / "docs" / "test_result.md"


def native_test_count() -> int:
    """Return the passing native-test count from docs/test_result.md.

    Raises SystemExit with a clear message when the file is missing or
    unreadable, so a release never silently drops the test gate.
    """
    rel: str = str(TEST_RESULT.relative_to(ROOT))
    if not TEST_RESULT.is_file():
        raise SystemExit(f"error: {rel} is missing; run `make test` first")
    m = re.search(r"Passed:\s*(\d+)", TEST_RESULT.read_text(errors="replace"))
    if m is None:
        raise SystemExit(f"error: no 'Passed: N' line in {rel}")
    return int(m.group(1))


def self_assess_args() -> str:
    """The self-assessment acceptance gates, defined once for every caller.

    These flags match the AGENTS.md "Dogfood target" section.  Every token is
    a single -flag=value / --flag=value word so the string can be shell-split
    without knowing which flags take a separate value; the shorthand spellings
    (--spark, --docstrs, -r) are the ones the CLI parser expands into the
    canonical long flags.  --require-tests comes from docs/test_result.md, so
    a suite-size change updates the gate automatically.
    """
    return (
        "--standard=all --dal=C --spark=Platinum "
        f"--docstrs=100 --require-tests={native_test_count()} -r=100"
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
            ["prove", "-t=.", "-l=4"] + self_assess_args().split()
            + ["--svg-path=docs/badges/"],
        )
    if command == "self":
        return adacovex(
            ROOT,
            ["-t=."] + self_assess_args().split()
            + ["--svg-path=docs/badges/"],
        )
    if command == "sbom":
        return adacovex(ROOT, ["sbom", "-t=.", "--dal=C"])
    if command == "ada-crdt":
        return adacovex(
            ROOT.parent / "Ada_CRDT", ["-t=../Ada_CRDT", "--dal=C"]
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
        print(self_assess_args())
        return 0
    return run(args.command)


if __name__ == "__main__":
    sys.exit(main())
