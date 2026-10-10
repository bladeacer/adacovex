#!/usr/bin/env python3
"""Validate adacovex changelog format.

Enforces the canonical changelog format (see CONTRIBUTING.md "Changelog
format").  Every `docs/changelogs/adacovex-X.Y.Z.md` must follow:

    # adacovex X.Y.Z

    Date: _YYYY-MM-DD_

    Version bumped A.B.C -> X.Y.Z.

    ## Changes          (optional; at least one of Changes/Fixes required)
    ### C1: <Title>
    ### C2: <Title>

    ## Fixes            (optional)
    ### H1: <Title>

    ## Test Suite       (mandatory)
    ## Proof Results    (mandatory)
    ## Traceability     (mandatory, last)

Exits 0 when every changelog is compliant, 1 otherwise.
"""

import argparse
import re
import sys
from pathlib import Path
from typing import List, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
CHANGELOG_DIR: Path = ROOT / "docs" / "changelogs"

HEADER_RE = re.compile(r"^# adacovex (\d+\.\d+\.\d+)$")
DATE_RE = re.compile(r"^Date: _(\d{4}-\d{2}-\d{2})_$")
VERSION_LINE_RE = re.compile(
    r"^Version bumped (\d+\.\d+\.\d+) -> (\d+\.\d+\.\d+)\.$")
SECTION_RE = re.compile(r"^## (.+)$")
SUBSECTION_RE = re.compile(r"^### ([CH])(\d+): (.+)$")

# Canonical top-level section order.  Changes/Fixes are optional (at least one
# must be present); everything from Test Suite onward is mandatory and must
# appear in this order at the end of the file.
CANONICAL_SECTIONS = [
    "Changes",
    "Fixes",
    "Test Suite",
    "Proof Results",
    "Traceability",
]

MANDATORY_TAIL = ["Test Suite", "Proof Results", "Traceability"]


def collect_changelogs() -> List[Path]:
    """Return the adacovex-X.Y.Z.md files to check."""
    files: List[Path] = []
    for path in sorted(CHANGELOG_DIR.iterdir()):
        if not path.name.startswith("adacovex-") or not path.name.endswith(".md"):
            continue
        stem = path.name[len("adacovex-"):-len(".md")]
        if re.match(r"^\d+\.\d+\.\d+$", stem):
            files.append(path)
    return files


def check_file(path: Path) -> List[str]:
    errors: List[str] = []
    with open(path, encoding="utf-8") as fp:
        lines = fp.read().splitlines()

    # Strip trailing empty lines; require a final newline structure.
    while lines and lines[-1] == "":
        lines.pop()
    if not lines:
        return [f"{path}: empty file"]

    # Header.
    m = HEADER_RE.match(lines[0])
    if not m:
        errors.append(f"{path}:1: expected `# adacovex X.Y.Z` header, got: {lines[0]!r}")
        return errors
    version = m.group(1)
    if lines[0] != f"# adacovex {version}":
        errors.append(f"{path}:1: header must be exactly `# adacovex {version}`")

    # Date line at line 3 (line index 2), after one blank line.
    if len(lines) < 3 or lines[1] != "":
        errors.append(f"{path}: expected blank line after header")
    elif not DATE_RE.match(lines[2]):
        errors.append(f"{path}:3: expected `Date: _YYYY-MM-DD_`, got: {lines[2]!r}")

    # Version line: `Version bumped A.B.C -> X.Y.Z.` directly after the Date
    # (optionally separated by one blank line), before the first `## ` section.
    vm = None
    vline_idx = -1
    for idx in (3, 4):
        if idx < len(lines):
            vm = VERSION_LINE_RE.match(lines[idx])
            if vm:
                vline_idx = idx
                break
    if vm is None:
        errors.append(f"{path}: expected `Version bumped A.B.C -> X.Y.Z.` "
                      f"after the Date line")
    elif vm.group(2) != version:
        errors.append(f"{path}:{vline_idx + 1}: Version line target "
                      f"{lines[vline_idx]!r} does not match header version "
                      f"{version}")

    # Parse sections (top-level) and subsections.
    sections: List[Tuple[str, int]] = []      # (name, line number)
    subs: List[Tuple[str, str, int, int]] = []  # (kind C/H, number, title, line)
    for idx, line in enumerate(lines, start=1):
        m = SECTION_RE.match(line)
        if m:
            sections.append((m.group(1), idx))
        m = SUBSECTION_RE.match(line)
        if m:
            subs.append((m.group(1), m.group(2), m.group(3), idx))

    section_names = [s[0] for s in sections]

    # Mandatory tail sections present, in order, and Traceability last.
    tail_positions = [section_names.index(n) for n in MANDATORY_TAIL
                      if n in section_names]
    for n in MANDATORY_TAIL:
        if n not in section_names:
            errors.append(f"{path}: missing mandatory section `## {n}`")
    if tail_positions != sorted(tail_positions):
        errors.append(f"{path}: mandatory sections must appear in order: "
                      f"{', '.join(MANDATORY_TAIL)}")
    if section_names and section_names[-1] != "Traceability":
        errors.append(f"{path}: `## Traceability` must be the last section")

    # At least one of Changes/Fixes.
    if "Changes" not in section_names and "Fixes" not in section_names:
        errors.append(f"{path}: need at least one of `## Changes` / `## Fixes`")

    # No sections outside the canonical set (enforces a single format).
    for name, ln in sections:
        if name not in CANONICAL_SECTIONS:
            errors.append(f"{path}:{ln}: non-canonical section `## {name}` "
                          f"(allowed: {', '.join(CANONICAL_SECTIONS)})")

    # Subsections only under Changes (C#) / Fixes (H#), sequential numbering.
    if subs:
        # Determine which top-level section each subsection falls under.
        for kind, num, title, ln in subs:
            parent = None
            for name, pn in sections:
                if pn < ln:
                    parent = name
                else:
                    break
            if kind == "C" and parent != "Changes":
                errors.append(f"{path}:{ln}: `### C#:` subsection must be under "
                              f"`## Changes` (found under {parent})")
            if kind == "H" and parent != "Fixes":
                errors.append(f"{path}:{ln}: `### H#:` subsection must be under "
                              f"`## Fixes` (found under {parent})")

        for kind, label in (("C", "Changes"), ("H", "Fixes")):
            nums = [int(n) for k, n, _, _ in subs if k == kind]
            if not nums:
                continue
            if sorted(nums) != list(range(1, len(nums) + 1)):
                errors.append(f"{path}: `{label}` subsections must be numbered "
                              f"sequentially C1..C{len(nums)} / H1..H{len(nums)}, "
                              f"found: {sorted(nums)}")

    # ASCII-only.
    for idx, line in enumerate(lines, start=1):
        if any(ord(c) > 0x7E for c in line):
            errors.append(f"{path}:{idx}: non-ASCII character in line")

    # 3-space list indentation (lines starting with 3+ spaces under a subsection
    # that are list items should use exactly 3 spaces of indent for `- ` items).
    for idx, line in enumerate(lines, start=1):
        m = re.match(r"^ {4,}- ", line)
        if m:
            errors.append(f"{path}:{idx}: list item indented with 4+ spaces; "
                          f"use exactly 3 spaces")

    return errors


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.parse_args(argv)

    files = collect_changelogs()
    if not files:
        print(f"  No changelog files found in {CHANGELOG_DIR}/")
        return 1

    all_errors: List[str] = []
    for path in files:
        all_errors.extend(check_file(path))

    if all_errors:
        for e in all_errors:
            print(f"  ERROR: {e}")
        print(f"  Changelog format check FAILED ({len(all_errors)} error(s))")
        return 1

    print(f"  All {len(files)} changelogs conform to the canonical format.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
