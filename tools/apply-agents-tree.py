#!/usr/bin/env python3
"""Splice the generated architecture tree into AGENTS.md.

Reads the tree text from argv[1], locates the markers
`<!-- agents-tree:begin -->` / `<!-- agents-tree:end -->` in AGENTS.md, and
replaces the fenced block between them.  Used by the Makefile `agents-tree`
target.

Usage: python3 tools/apply-agents-tree.py /tmp/agents-tree.out
"""

import sys


def main():
    if len(sys.argv) < 2:
        print("usage: apply-agents-tree.py <tree-file>", file=sys.stderr)
        return 1
    with open(sys.argv[1], encoding="utf-8") as fh:
        tree = fh.read().rstrip()
    markers = ("<!-- agents-tree:begin -->", "<!-- agents-tree:end -->")
    with open("AGENTS.md", encoding="utf-8") as fh:
        text = fh.read()
    start = text.index(markers[0])
    end = text.index(markers[1]) + len(markers[1])
    block = markers[0] + "\n```\n" + tree + "\n```\n" + markers[1]
    with open("AGENTS.md", "w", encoding="utf-8") as fh:
        fh.write(text[:start] + block + text[end:])
    print("AGENTS.md architecture tree regenerated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
