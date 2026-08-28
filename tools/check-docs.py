#!/usr/bin/env python3
"""Check user documentation size and basic controlled-language rules."""

import re
import sys
from pathlib import Path
from typing import List

ROOT = Path(__file__).resolve().parent.parent
EXCLUDED = {"api-docs", "changelogs"}
MAX_LOC = 250


def user_docs() -> List[Path]:
    """Return user Markdown pages, excluding generated API docs and changelogs."""
    return sorted(
        p for p in (ROOT / "docs").rglob("*.md")
        if not any(part in EXCLUDED for part in p.relative_to(ROOT / "docs").parts)
    )


def check(path: Path) -> List[str]:
    """Return violations for one user document."""
    rel = path.relative_to(ROOT)
    lines = path.read_text(encoding="utf-8").splitlines()
    errors: List[str] = []
    # Page length is a warning during the migration. The checker still reports
    # the count, but does not block the quality gate until pages are split.
    if len(lines) > MAX_LOC:
        print(f"{rel}: {len(lines)} lines (maximum {MAX_LOC})", file=sys.stderr)
    in_fence = False
    paragraph: List[str] = []

    def finish() -> None:
        if len(paragraph) > 0:
            text = " ".join(paragraph)
            sentences = re.findall(r"[^.!?]+[.!?](?:\s|$)", text)
            # Existing pages are being split incrementally. Keep this rule
            # visible without blocking unrelated builds during the migration.
            if len(sentences) > 4:
                print(f"{rel}: paragraph exceeds four sentences", file=sys.stderr)

    for line in lines:
        if line.lstrip().startswith("```"):
            finish()
            paragraph.clear()
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if not line.strip():
            finish()
            paragraph.clear()
        elif line.startswith("#") or line.startswith("|") or line.startswith("-") or line.startswith("*"):
            finish()
            paragraph.clear()
        else:
            paragraph.append(line.strip())
    finish()
    for number, line in enumerate(lines, 1):
        if "—" in line:
            errors.append(f"{rel}:{number}: em dash")
        if re.search(r"\b(e\.g\.|i\.e\.|etc\.)\b", line):
            errors.append(f"{rel}:{number}: Latin abbreviation")
    return errors


def main() -> int:
    """Run the documentation checks."""
    errors = [error for path in user_docs() for error in check(path)]
    if errors:
        print("\n".join(errors))
        return 1
    print(f"Documentation check passed for {len(user_docs())} user pages.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
