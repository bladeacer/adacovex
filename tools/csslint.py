#!/usr/bin/env python3
"""Enforce the 4px spacing rule in the dashboard CSS.

adacovex follows a spacing convention: every `margin`, `padding`, and `gap`
pixel length must be a multiple of 4px.  This keeps the dashboard rhythm
consistent and is the pure-stdlib Python equivalent of a stylelint custom
rule (the dev tooling is Python-only by convention; no npm dependency is
added for the gate).

The rule applies to the spacing longhands and shorthands only:
  margin, margin-top/right/bottom/left, padding, padding-top/right/bottom/left,
  gap, row-gap, column-gap
Pixels in any other property (border, box-shadow, max-width, position, ...)
are left untouched.

Usage:
  python3 tools/csslint.py --check          # exit 1 on any violation
  python3 tools/csslint.py --fix            # rewrite the file to conform

Wired as `make csslint-check` and run as a cheap static gate in `make build`
and `make check`.
"""

import argparse
import re
import sys
from pathlib import Path
from typing import List, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
CSS: Path = ROOT / "resources" / "css" / "dashboard.css"

# Spacing properties the 4px rule applies to (word-boundary anchored).
_SPACING_RE = re.compile(
    r"(?ix)(?<![\w-])"
    r"(margin|margin-top|margin-right|margin-bottom|margin-left|"
    r"padding|padding-top|padding-right|padding-bottom|padding-left|"
    r"gap|row-gap|column-gap)"
    r"\s*:\s*([^;}]+)"
)

# A px length token inside a spacing value: a positive integer pixel amount.
_PX_RE = re.compile(r"(?<![\w\-])(\d+)px")


def multiple_of_4(value: int) -> int:
    """Round a positive px amount up to the next multiple of 4 (>=4)."""
    if value == 0:
        return 0
    base: int = ((value + 3) // 4) * 4
    return max(base, 4)


def conform_value(value: str) -> str:
    """Rewrite spacing px tokens to 4px multiples, leaving everything else."""
    def _px(m: "re.Match[str]") -> str:
        return f"{multiple_of_4(int(m.group(1)))}px"
    return _PX_RE.sub(_px, value)


def lint(text: str) -> List[Tuple[str, str]]:
    """Return [(original_value, fixed_value)] for every violating declaration."""
    violations: List[Tuple[str, str]] = []
    for m in _SPACING_RE.finditer(text):
        value: str = m.group(2).strip()
        fixed: str = conform_value(value)
        if fixed != value:
            violations.append((value, fixed))
    return violations


def check() -> int:
    if not CSS.exists():
        print(f"  ERROR: {CSS} not found")
        return 1
    text: str = CSS.read_text(encoding="utf-8")
    bad: List[Tuple[str, str]] = lint(text)
    if not bad:
        print("  CSS 4px spacing rule: passed (margin/padding/gap are "
              "multiples of 4px)")
        return 0
    print(f"  CSS 4px spacing rule: {len(bad)} violation(s) in "
          f"{CSS.relative_to(ROOT)}:")
    for orig, fixed in bad:
        print(f"      {orig!r:42} -> {fixed!r}")
    print("  Run `python3 tools/csslint.py --fix` (or `make csslint-check "
          "--fix`) to conform.")
    return 1


def fix() -> int:
    """Rewrite only the spacing-property values (never global substring
    replaces, which would corrupt values like 32px when matching `2px`)."""
    if not CSS.exists():
        print(f"  ERROR: {CSS} not found")
        return 1
    text: str = CSS.read_text(encoding="utf-8")

    def _val(m: "re.Match[str]") -> str:
        name: str = m.group(1)
        value: str = m.group(2).strip()
        return f"{name}:{conform_value(value)}"

    new: str = _SPACING_RE.sub(_val, text)
    count: int = len(lint(text))
    if new != text:
        CSS.write_text(new, encoding="utf-8")
        print(f"  rewrote {count} spacing declaration(s) in "
              f"{CSS.relative_to(ROOT)}")
    else:
        print(f"  {CSS.relative_to(ROOT)} already conforms to the 4px rule")
    return 0


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true",
                      help="exit 1 when any spacing px is not a multiple of 4")
    mode.add_argument("--fix", action="store_true",
                      help="rewrite the CSS to conform")
    args: argparse.Namespace = ap.parse_args(argv)
    return fix() if args.fix else check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))