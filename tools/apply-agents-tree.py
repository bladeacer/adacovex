#!/usr/bin/env python3
"""Splice the generated architecture tree into AGENTS.md.

Reads the tree text from argv[1], locates the markers
`<!-- agents-tree:begin -->` / `<!-- agents-tree:end -->` in AGENTS.md, and
replaces the fenced block between them.  Used by the Makefile `agents-tree`
target.

Usage: python3 tools/apply-agents-tree.py /tmp/agents-tree.out
"""

import sys
from typing import List, Tuple

TREE_MARKERS: Tuple[str, str] = (
    "<!-- agents-tree:begin -->",
    "<!-- agents-tree:end -->",
)


def main(argv: List[str]) -> int:
    if len(argv) < 2:
        print("usage: apply-agents-tree.py <tree-file>", file=sys.stderr)
        return 1
    with open(argv[1], encoding="utf-8") as fh:
        tree = fh.read().rstrip()
    with open("AGENTS.md", encoding="utf-8") as fh:
        text = fh.read()
    start = text.index(TREE_MARKERS[0])
    end = text.index(TREE_MARKERS[1]) + len(TREE_MARKERS[1])
    block = TREE_MARKERS[0] + "\n```\n" + tree + "\n```\n" + TREE_MARKERS[1]
    with open("AGENTS.md", "w", encoding="utf-8") as fh:
        fh.write(text[:start] + block + text[end:])
    print("AGENTS.md architecture tree regenerated.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
