#!/usr/bin/env python3
"""Version helpers for the Makefile and other dev scripts.

The old Makefile recipes parsed versions with `sed -n 's/^version = ...'`,
compared them with GNU-only `sort -V`, and rewrote manifests with GNU-only
`sed -i`.  This script exposes the same operations in pure Python so they
work identically on Linux, WSL, and macOS:

  python3 tools/versions.py current [--file=FILE]
      Print the `version = "x.y.z"` line of a toml manifest (default
      alire.toml).  Exit 1 when the file has no version line.

  python3 tools/versions.py sort [--reverse]
      Read version tokens from stdin (one per line, each line may carry a
      path prefix, e.g. `docs/changelogs/adacovex-1.2.3.md`), print them
      in numeric version order (ascending unless --reverse).

  python3 tools/versions.py min
      Print the smallest version found on stdin.

  python3 tools/versions.py max
      Print the largest version found on stdin.

  python3 tools/versions.py set-version FILE VERSION
      Rewrite every `version = "..."` line at column 0 of FILE to the new
      VERSION (same semantics as the old `sed -i 's/^version = .../'`).
      Exit 1 when the file is missing or carries no version line.

  python3 tools/versions.py between MIN MAX
      Filter stdin lines (paths with embedded x.y.z tokens) to the ones
      whose version is strictly greater than MIN and no greater than MAX
      (either bound may be empty to mean unbounded), printed newest first.
      This replaces the shell's `sort -V` filtering in the release target.

All sort-style commands accept lines with or without a `v` prefix and
ignore lines that contain no x.y.z token.
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

VERSION_RE: str = r"\d+\.\d+\.\d+"


def find_version(text: str) -> Optional[str]:
    """Return the first x.y.z triple in text, or None."""
    match = re.search(VERSION_RE, text)
    return match.group(0) if match else None


def version_key(version: str) -> Tuple[int, ...]:
    """Numeric sort key for an x.y.z version string."""
    return tuple(int(part) for part in version.split("."))


def sort_lines(lines: Iterable[str]) -> List[str]:
    """Return the input lines containing a version, in numeric order."""
    with_version: List[Tuple[Tuple[int, ...], str]] = []
    for line in lines:
        version = find_version(line)
        if version is not None:
            with_version.append((version_key(version), line.strip()))
    with_version.sort(key=lambda item: item[0])
    return [line for _, line in with_version]


def read_manifest_version(path: Path) -> Optional[str]:
    """Return the version of a toml manifest, or None."""
    if not path.is_file():
        return None
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        if re.match(r'^version = "', line):
            match = re.search(r'"([^"]+)"', line)
            if match:
                return match.group(1)
    return None


def set_manifest_version(path: Path, version: str) -> bool:
    """Rewrite every `version = "..."` line at column 0; False when absent."""
    if not path.is_file():
        print(f"error: {path} does not exist", file=sys.stderr)
        return False
    text = path.read_text(encoding="utf-8")
    new_text, count = re.subn(
        r'^version = "[^"]*"', f'version = "{version}"', text, flags=re.MULTILINE
    )
    if count == 0:
        print(f"error: no version line in {path}", file=sys.stderr)
        return False
    path.write_text(new_text, encoding="utf-8")
    return True


def read_stdin() -> List[str]:
    return [line for line in sys.stdin]


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)

    p_current = sub.add_parser("current", help="print the manifest version")
    p_current.add_argument("--file", default="alire.toml",
                           help="manifest path (default: alire.toml)")

    for name in ("sort", "min", "max"):
        p = sub.add_parser(name, help=f"version-{name.replace('sort', 'aware sort')}")
        p.add_argument("--reverse", action="store_true",
                       help="descending order (sort only)")

    p_set = sub.add_parser("set-version",
                           help="rewrite the version line of a manifest")
    p_set.add_argument("file")
    p_set.add_argument("version")

    p_between = sub.add_parser("between",
                               help="filter stdin lines by version bounds")
    p_between.add_argument("min", help="exclusive lower bound (or empty)")
    p_between.add_argument("max", help="inclusive upper bound (or empty)")
    p_between.add_argument("--exclude", default="",
                           help="drop lines whose version equals this one")
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])
    if args.command == "current":
        path = Path(args.file)
        version = read_manifest_version(path)
        if version is None:
            print(f"error: no version line in {path}", file=sys.stderr)
            return 1
        print(version)
        return 0

    if args.command == "set-version":
        return 0 if set_manifest_version(Path(args.file), args.version) else 1

    if args.command == "between":
        lo = version_key(args.min) if args.min else None
        hi = version_key(args.max) if args.max else None
        excluded = version_key(args.exclude) if args.exclude else None
        kept: List[Tuple[Tuple[int, ...], str]] = []
        for line in read_stdin():
            version = find_version(line)
            if version is None:
                continue
            key = version_key(version)
            if excluded is not None and key == excluded:
                continue
            if lo is not None and key <= lo:
                continue
            if hi is not None and key > hi:
                continue
            kept.append((key, line.strip()))
        kept.sort(key=lambda item: item[0], reverse=True)
        for _, line in kept:
            print(line)
        return 0

    lines = read_stdin()
    ordered = sorted(
        (line for line in (find_version(l) for l in lines) if line is not None),
        key=version_key,
        reverse=args.reverse,
    )
    if not ordered:
        return 1
    if args.command == "min":
        print(ordered[0])
    elif args.command == "max":
        print(ordered[-1])
    else:
        for version in ordered:
            print(version)
    return 0


if __name__ == "__main__":
    sys.exit(main())