#!/usr/bin/env python3
"""Sync requirements.txt from pyproject.toml (the single source of docs deps).

The docs dependencies lived only in requirements.txt, so a second declaration
would drift from it.  pyproject.toml is now the single source and
requirements.txt is derived, because .readthedocs.yaml (`python.install`) and
`pip install -r` consume it and cannot read a pyproject table.

Files:
  pyproject.toml     -- canonical: [project].dependencies (edit this)
  requirements.txt   -- derived:   rendered by this script (committed)

Usage:
  python3 tools/update-requirements.py           # regenerate requirements.txt
  python3 tools/update-requirements.py --check   # exit 1 when the two drift
  python3 tools/update-requirements.py --dry-run # show the diff, write nothing

`just requirements` runs it, `requirements sync` in `just check` runs the
--check mode, and `just sync` regenerates it with the other derived files.
Pure stdlib (tomllib is stdlib from Python 3.11).
"""

from __future__ import annotations

import argparse
import difflib
import sys
from pathlib import Path
from typing import List, Optional

ROOT: Path = Path(__file__).resolve().parent.parent
PYPROJECT: Path = ROOT / "pyproject.toml"
REQUIREMENTS: Path = ROOT / "requirements.txt"

# The rendered header.  It keeps the Read the Docs context the hand-written
# file always carried and names the generator, so a reader of requirements.txt
# learns where its lines come from.
HEADER: str = """\
# Read the Docs build dependencies for the adacovex manual.
#
# The docs live under docs/ as Markdown and are built with Sphinx using the
# Furo theme and the MyST parser so the existing .md pages compile unchanged.
# Read the Docs installs these (see .readthedocs.yaml, `python.install`) to
# run `sphinx-build` over docs/.
#
# GENERATED FILE -- the dependency list comes from pyproject.toml
# ([project].dependencies), the single source.  Edit that file and run
# `just requirements` to regenerate; the `requirements sync` gate in
# `just check` fails when the two drift.
"""


def load_dependencies(pyproject: Path) -> List[str]:
    """Read [project].dependencies from pyproject.toml, in file order.

    Every entry passes through verbatim, so extras, markers, and pins
    (`sphinx>=7`, `furo; python_version < "3.13"`) survive the round trip.
    A missing or malformed table is a loud SystemExit, never an empty render
    that would strip requirements.txt bare.
    """
    try:
        import tomllib
    except ModuleNotFoundError:  # pragma: no cover - Python < 3.11 host
        raise SystemExit(
            "error: tomllib is unavailable; update-requirements.py needs "
            "Python 3.11 or newer")
    try:
        data = tomllib.loads(pyproject.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise SystemExit(f"error: cannot read {pyproject}: {exc}")
    deps = data.get("project", {}).get("dependencies")
    if not isinstance(deps, list) or not deps:
        raise SystemExit(
            f"error: {pyproject} has no non-empty [project].dependencies "
            "list")
    for entry in deps:
        if not isinstance(entry, str) or not entry.strip():
            raise SystemExit(
                f"error: {pyproject} carries a non-string dependency entry: "
                f"{entry!r}")
    return [entry.strip() for entry in deps]


def render_requirements(deps: List[str]) -> str:
    """Render the complete requirements.txt body for these dependencies."""
    return HEADER + "\n".join(deps) + "\n"


def sync(pyproject: Path, requirements: Path,
         check_only: bool, dry_run: bool = False) -> int:
    """Write requirements.txt from pyproject (or verify it in check mode).

    Exit 0 when the file already matches (or was written), 1 on drift in
    check mode or on an unreadable source.  The file is rewritten only when
    its content changes, so a no-op run keeps its mtime.
    """
    deps = load_dependencies(pyproject)
    expected = render_requirements(deps)
    try:
        actual = requirements.read_text(encoding="utf-8")
    except OSError:
        actual = ""
    if actual == expected:
        print(f"ok: {requirements.name} matches {pyproject.name} "
              f"({len(deps)} dependencies)")
        return 0
    if check_only:
        diff = difflib.unified_diff(
            actual.splitlines(keepends=True),
            expected.splitlines(keepends=True),
            fromfile=str(requirements), tofile="pyproject.toml (rendered)",
        )
        sys.stderr.writelines(diff)
        print(
            f"error: {requirements.name} drifted from {pyproject.name} "
            "(run `just requirements`)", file=sys.stderr)
        return 1
    if dry_run:
        print(f"would write {requirements.name} ({len(deps)} dependencies)")
        return 0
    requirements.write_text(expected, encoding="utf-8")
    print(f"wrote {requirements.name} from {pyproject.name} "
          f"({len(deps)} dependencies)")
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true",
                    help="verify requirements.txt matches pyproject.toml")
    ap.add_argument("--dry-run", action="store_true",
                    help="report what would change, write nothing")
    args = ap.parse_args(argv)
    return sync(PYPROJECT, REQUIREMENTS, args.check, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())