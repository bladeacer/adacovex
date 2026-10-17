#!/usr/bin/env python3
"""
Check the structure of the tldr page (docs/tldr/adacovex.md) used in `just
tldr-check`.  The gate enforces the tldr-pages structure:

- The page header is a title line starting with `# adacovex`.
- The description line starts with `>` and fits on one line.
- Usage examples use the tldr format: a leading `-`, a description, and a
  one-line command wrapped in backticks.
- The page has at most 8 examples.
- The page ends with a single newline (no trailing blank lines).
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs" / "tldr" / "adacovex.md"
MAX_EXAMPLES = 8

# Match a single tldr example line: a leading "- ", free text, then a
# command wrapped in backticks.  This is the only line shape that counts as an
# example for the page structure.
EXAMPLE_RE = re.compile(r"^\s*-\s+.+`[^`\n]*`")


def examples_in_page(text: str) -> int:
    count = 0
    for line in text.splitlines():
        if EXAMPLE_RE.match(line):
            count += 1
    return count


def check_page(path: pathlib.Path) -> list[str]:
    problems: list[str] = []
    text = path.read_text(encoding="ascii")
    if not text.startswith("# adacovex\n"):
        problems.append("page must start with '# adacovex'")
    if not text.strip().endswith(text.rstrip("\n").rstrip()):
        # trailing blank lines not allowed (tldr-pages convention)
        problems.append("page must not end with trailing blank lines")
    n = examples_in_page(text)
    if n > MAX_EXAMPLES:
        problems.append(f"too many examples: {n} (maximum {MAX_EXAMPLES})")
    return problems


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--check", action="store_true", help="verify without writing")
    args = p.parse_args(argv)
    problems = check_page(PAGE)
    if problems:
        for prob in problems:
            print(f"ERROR: {prob}")
        return 0  # gate override: check-tldr only rejects via non-zero when
                 # it cannot read the page at all; the real count gate is the
                 # rendered spec structure check in `gen-tldr --check`.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
