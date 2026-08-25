#!/usr/bin/env python3
"""Verify every source file in the repo is pure ASCII.

The old `make ascii-check` recipe used `grep -rIlP` with a `\\x20-\\x7E`
class.  `grep -P` (PCRE) is a GNU extension: it does not exist on BSD/macOS
grep, so the gate could not run on every developer machine.  This script
walks the tree in pure Python and reports any file containing a byte
outside the printable-ASCII range (plus tab), matching the old gate's
semantics exactly:

- scanned extensions: .ads .adb .md .py .toml .gpr
- excluded directories: `.git`, `alire`, `obj`, `skills`, `node_modules`,
  `playwright-report`, `test-results` (generated e2e output)
- tabs (\\t) and printable ASCII (0x20..0x7E) are allowed; anything else
  (including CRLF line endings and UTF-8 multi-byte characters) is a
  violation.

Generated e2e artefacts (`tests/e2e/playwright-report/`,
`tests/e2e/test-results/`) are gitignored but still land under the scanned
`.md` extension, so they are excluded by name the same way `node_modules`
is.

Usage:
  python3 tools/ascii-check.py   # scan the repo; exit 1 when any file fails

Exit code 0 when every scanned file is pure ASCII.
"""

import argparse
import sys
from pathlib import Path
from typing import List, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

SKIP_DIRS: Tuple[str, ...] = (
    ".git",
    "alire",
    "obj",
    "skills",
    "node_modules",
    # Generated Playwright output (gitignored, but .md so it would
    # otherwise trip the scan):
    "playwright-report",
    "test-results",
)

EXTENSIONS: Tuple[str, ...] = (".ads", ".adb", ".md", ".py", ".toml", ".gpr")


def parse_args(argv: Tuple[str, ...]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=str(ROOT),
                        help="directory to scan (default: repository root)")
    return parser.parse_args(argv)


def bad_files(root: Path) -> List[Path]:
    """Return every supported source file under root that is not pure ASCII."""
    bad: List[Path] = []
    for path in root.rglob("*"):
        if path.is_dir():
            continue
        if path.suffix not in EXTENSIONS:
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(root).parts):
            continue
        try:
            data: bytes = path.read_bytes()
        except OSError:
            continue
        for byte in data:
            # Allow tab, line feed (grep's line mode never sees it), and
            # printable ASCII.  Carriage return is rejected exactly as the
            # old `grep -P '[^\x20-\x7E\t]'` pattern rejected it, so CRLF
            # line endings still fail the gate.
            if byte not in (0x09, 0x0A) and (byte < 0x20 or byte > 0x7E):
                bad.append(path)
                break
    return bad


def main() -> int:
    args = parse_args(tuple(sys.argv[1:]))
    root = Path(args.root).resolve()
    print("=== ASCII Charset Verification ===")
    bad = bad_files(root)
    if not bad:
        print("All source files are pure ASCII.")
        return 0
    for path in sorted(bad):
        print(f"  NON-ASCII: {path.relative_to(root)}")
    print(f"{len(bad)} file(s) contain non-ASCII characters.")
    return 1


if __name__ == "__main__":
    sys.exit(main())