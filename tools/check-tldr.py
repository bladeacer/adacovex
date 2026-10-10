"""Structural check for the in-repo tldr page.

Verifies the rules that matter for docs/tldr/adacovex.md without needing
tldr-lint (which is node-based and not part of the Python toolchain):

- at most 8 examples;
- the `#` title matches the command name;
- the `>` description block is one or two lines;
- every example description starts with an imperative verb (a capital
  letter followed by a lowercase word ending in a letter, as a rough
  check that the description is a sentence, not a fragment) and the
  command line immediately follows its description line;
- no italics (`_x_`) or boldface (`**x**`) in the page.

Usage: python3 tools/check-tldr.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs" / "tldr" / "adacovex.md"


def main() -> int:
    if not PAGE.exists():
        print(f"ERROR: {PAGE} does not exist")
        return 1
    lines = PAGE.read_text(encoding="utf-8").splitlines()
    errors = []

    # Title
    if not lines or lines[0] != "# adacovex":
        errors.append("first line must be '# adacovex'")

    # Description block
    block = 0
    for line in lines[1:]:
        if line.startswith(">"):
            block += 1
        elif block and line.strip() == "":
            break
    if block == 0 or block > 2:
        errors.append(f"description block must be 1-2 lines, got {block}")

    # Examples
    examples = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("- "):
            examples += 1
            desc = line[2:].strip()
            if not desc.endswith(":"):
                errors.append(f"example description must end with ':': {desc}")
            if not re.match(r"^[A-Z][a-z]", desc):
                errors.append(f"example description should start with a verb: {desc}")
            if i + 1 >= len(lines) or not lines[i + 1].startswith("`"):
                errors.append(f"example is not followed by a command line: {desc}")
        i += 1
    if examples == 0:
        errors.append("no examples found")
    if examples > 8:
        errors.append(f"too many examples: {examples} (maximum 8)")

    # No italics/boldface
    for line in lines:
        if re.search(r"\*\*[^*]+\*\*", line):
            errors.append(f"boldface is not allowed: {line.strip()}")
        if re.search(r"(?<!\*)\*[^*]+\*(?!\*)", line):
            errors.append(f"italics are not allowed: {line.strip()}")
        if re.search(r"_[^_]+_", line):
            errors.append(f"italics are not allowed: {line.strip()}")

    for err in errors:
        print(f"ERROR: {err}")
    if errors:
        return 1
    print(f"tldr page check passed ({examples} examples)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
