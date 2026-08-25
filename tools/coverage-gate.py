#!/usr/bin/env python3
"""Docstring-coverage gate between the latest two release tags.

The old `make coverage-gate` recipe parsed the tag list with GNU-only
`sort -V`-style shell pipelines and managed a temporary git worktree with
a bare `trap`-less sequence -- a failed assessment left the worktree
behind.  This script owns the same flow:

  python3 tools/coverage-gate.py

1. List release tags (`vX.Y.Z` only), newest first; require at least two.
2. Check out the newest tag into a fresh temporary git worktree (detached),
   without touching the working tree.
3. Run `bin/adacovex --target=. --coverage-delta=<previous-tag>` inside the
   worktree -- the differential mode that fails when docstring coverage
   regressed between the previous release and the current one.
4. Remove the temporary worktree in all cases (success or failure).

Exit code is adacovex's; 1 when there are fewer than two release tags or a
worktree cannot be created.
"""

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

TAG_RE: str = r"^v\d+\.\d+\.\d+$"


def release_tags() -> List[str]:
    """Release tags, newest first (git's version sort)."""
    result = subprocess.run(
        ["git", "tag", "--sort=-version:refname"],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"error: git tag failed: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    return [line.strip() for line in result.stdout.splitlines()
            if re.match(TAG_RE, line.strip())]


def latest_two(tags: List[str]) -> Optional[Tuple[str, str]]:
    """Return (latest, previous) release tags, or None when there are < 2."""
    if len(tags) < 2:
        return None
    return tags[0], tags[1]


def run_coverage_delta(worktree: Path, previous: str, binary: Path) -> int:
    """Assess the latest tag against the previous one from inside worktree."""
    return subprocess.run(
        [str(binary), "--target=.", f"--coverage-delta={previous}"],
        cwd=str(worktree),
    ).returncode


def coverage_gate() -> int:
    tags = release_tags()
    pair = latest_two(tags)
    if pair is None:
        print("  Need at least two release tags to compare.")
        return 1
    latest, previous = pair
    print(f"=== Coverage delta gate: {previous} (base) vs {latest} (current) ===")

    binary = ROOT / "bin" / "adacovex"
    if not binary.is_file():
        print(f"error: {binary} not found; run `make build` first", file=sys.stderr)
        return 1

    worktree = Path(tempfile.mkdtemp(prefix="adacovex-coverage-"))
    added = subprocess.run(
        ["git", "worktree", "add", "--detach", str(worktree), latest],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    if added.returncode != 0:
        print(f"  ERROR: could not check out {latest}: {added.stderr.strip()}",
              file=sys.stderr)
        shutil.rmtree(worktree, ignore_errors=True)
        return 1

    try:
        rc = run_coverage_delta(worktree, previous, binary)
    finally:
        subprocess.run(
            ["git", "worktree", "remove", "--force", str(worktree)],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
        )
        shutil.rmtree(worktree, ignore_errors=True)
    return rc


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    return parser.parse_args(argv)


def main() -> int:
    parse_args(sys.argv[1:])
    return coverage_gate()


if __name__ == "__main__":
    sys.exit(main())
