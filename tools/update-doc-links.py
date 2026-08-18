#!/usr/bin/env python3
"""Regenerate the Documentation block at the end of AGENTS.md.

Reads tools/doc-links.map -- one "relative-path<TAB>title" pair per line,
matching the agents-tree.map/agents-tree tooling -- and rewrites the fenced
bulleted list between the `<!-- doc-links:begin -->` /
`<!-- doc-links:end -->` markers in AGENTS.md.  Any referenced file that does
not exist is flagged (exit 1) so the map stays in sync with the docs.

Usage:
  python3 tools/update-doc-links.py [--dry-run] [--check]

--dry-run  Print the would-be block without editing AGENTS.md.
--check    Verify AGENTS.md already carries the current block; exit 1 on
           drift (used by the quality gate) without editing.

Exit code 0 when every map entry resolves and AGENTS.md was updated (or, with
--dry-run/--check, would be / already is), 1 when a referenced file is
missing, the markers are absent, or --check found drift.
"""

import argparse
import sys
from pathlib import Path
from typing import List, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
MAP: Path = ROOT / "tools" / "doc-links.map"
AGENTS: Path = ROOT / "AGENTS.md"

BEGIN_MARKER: str = "<!-- doc-links:begin -->"
END_MARKER: str = "<!-- doc-links:end -->"


def load_links() -> List[Tuple[str, str]]:
    """Return (relative_path, title) pairs from the map file."""
    links: List[Tuple[str, str]] = []
    for raw in MAP.read_text(encoding="utf-8").splitlines():
        line: str = raw.strip()
        if not line or line.startswith("#"):
            continue
        rel_path, _, title = line.partition("\t")
        links.append((rel_path.strip(), title.strip()))
    return links


def render_block(links: List[Tuple[str, str]]) -> str:
    lines: List[str] = [BEGIN_MARKER]
    for rel_path, title in links:
        lines.append(f"- [{title}]({rel_path})")
    lines.append(END_MARKER)
    return "\n".join(lines)


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true",
                    help="print the would-be block without editing AGENTS.md")
    ap.add_argument("--check", action="store_true",
                    help="verify AGENTS.md already matches; exit 1 on drift")
    args: argparse.Namespace = ap.parse_args(argv)

    links: List[Tuple[str, str]] = load_links()
    missing: List[str] = []
    for rel_path, _ in links:
        if not (ROOT / rel_path).exists():
            missing.append(rel_path)
    if missing:
        for rel_path in missing:
            print(f"  MISSING DOC: {rel_path} (fix tools/doc-links.map)",
                  file=sys.stderr)
        return 1

    block: str = render_block(links)
    text: str = AGENTS.read_text(encoding="utf-8")
    if BEGIN_MARKER not in text or END_MARKER not in text:
        print("error: AGENTS.md is missing the doc-links markers "
              f"{BEGIN_MARKER!r} / {END_MARKER!r}", file=sys.stderr)
        return 1

    start: int = text.index(BEGIN_MARKER)
    end: int = text.index(END_MARKER) + len(END_MARKER)
    current: str = text[start:end]
    if args.dry_run:
        print(block)
        return 0
    if args.check:
        if current == block:
            print("ok: AGENTS.md Documentation block is current")
            return 0
        print("error: AGENTS.md Documentation block is out of date "
              "(run `make doc-links`)", file=sys.stderr)
        return 1
    if current != block:
        AGENTS.write_text(text[:start] + block + text[end:], encoding="utf-8")
    print("AGENTS.md Documentation block regenerated.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))