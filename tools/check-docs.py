#!/usr/bin/env python3
"""Check user documentation paragraphs and basic controlled-language rules.

Rules enforced here:

* no paragraph may exceed four sentences (Simplified Technical English and
  the project style guide keep sentences short and paragraphs tight);
* no em dash (\u2014) characters;
* no Latin abbreviations (e.g., i.e., etc.).

The paragraph rule is a hard gate: exceeding four sentences in any paragraph
fails the check with exit 1.  It covers the hand-written user documentation
under docs/, the human changelogs under docs/changelogs/, and the root
README.md.  docs/api-docs is excluded because `make doc` regenerates those
pages from Ada source docstrings (the paragraph rule there belongs in the
source docstrings, not the generated output).
"""

import re
import sys
from pathlib import Path
from typing import List, Tuple

ROOT = Path(__file__).resolve().parent.parent
# Generated pages (rebuilt from Ada docstrings by `make doc`) are not edited
# by hand; the paragraph rule applies to their source docstrings instead.
EXCLUDED = {"api-docs"}
MAX_LOC = 250

# A decimal point between digits is not a sentence break (e.g. 1.21.0).
_DECIMAL = re.compile(r"(?<=\d)\.(?=\d)")
# A sentence ends at a . ! ? (decimal-stripped) followed by whitespace then an
# uppercase letter (or the end of the paragraph).
_SENTENCE = re.compile(r"[^.!?]+[.!?](?=\s+[A-Z]|\s*$|$)")
_MAX_SENTENCES = 4


def doc_files() -> List[Path]:
    """Return hand-written Markdown pages: user docs + changelogs + README."""
    files = set()
    for p in (ROOT / "docs").rglob("*.md"):
        if "api-docs" in p.relative_to(ROOT / "docs").parts:
            continue
        files.add(p)
    files.add(ROOT / "README.md")
    return sorted(files)


def count_sentences(text: str) -> int:
    return len(_SENTENCE.findall(_DECIMAL.sub("", text)))


def check(path: Path) -> List[str]:
    """Return violations (hard errors) for one documentation file."""
    rel = path.relative_to(ROOT)
    lines = path.read_text(encoding="utf-8").splitlines()
    errors: List[str] = []
    if len(lines) > MAX_LOC:
        print(f"{rel}: {len(lines)} lines (maximum {MAX_LOC})", file=sys.stderr)
    in_fence = False
    paragraph: List[str] = []
    start: int = 1

    def finish() -> None:
        if len(paragraph) > 0:
            count = count_sentences(" ".join(paragraph))
            if count > _MAX_SENTENCES:
                errors.append(
                    f"{rel}: paragraph has {count} sentences "
                    f"(maximum {_MAX_SENTENCES}) starting at line {start}")
            paragraph.clear()

    for number, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            finish()
            in_fence = not in_fence
        elif in_fence:
            continue
        elif not line.strip():
            finish()
        elif line[0] in "#|-*" or re.match(r"^\s*\d+[.)]\s", line):
            # Headings, bullet lists, tables, and numbered lists are structural,
            # not prose paragraphs; they never count toward the sentence cap.
            finish()
        else:
            if not paragraph:
                start = number
            paragraph.append(line.strip())
    finish()
    for number, line in enumerate(lines, 1):
        if "\u2014" in line:
            errors.append(f"{rel}:{number}: em dash")
        if re.search(r"\b(e\.g\.|i\.e\.|etc\.)\b", line):
            errors.append(f"{rel}:{number}: Latin abbreviation")
    return errors


def main() -> int:
    """Run the documentation checks."""
    files = doc_files()
    errors = [error for path in files for error in check(path)]
    if errors:
        print("\n".join(errors))
        return 1
    print(f"Documentation check passed for {len(files)} hand-written pages.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
