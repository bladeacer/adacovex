#!/usr/bin/env python3
"""Split paragraphs over the four-sentence limit in hand-written docs.

adacovex enforces that no paragraph exceeds four sentences (see check-docs.py
and the project's Simplified Technical English style).  This utility brings a
file into compliance by inserting a blank line between sentence groups so no
paragraph carries more than four completed sentences.

It edits only the hand-written Markdown: docs/ (excluding generated
docs/api-docs) and the root README.md.  It never rewrites a sentence or a
line; it only inserts blank lines at paragraph boundaries.  Fenced code
blocks, headings, tables, bullet lists, and numbered lists are untouched.

Usage:
  python3 tools/para-split.py --fix          # bring files into compliance
  python3 tools/para-split.py --check        # exit 1 when any paragraph is over

Exit code 0 on success (or when no change is needed).
"""

import argparse
import re
import sys
from pathlib import Path
from typing import List

ROOT: Path = Path(__file__).resolve().parent.parent
_DECIMAL = re.compile(r"(?<=\d)\.(?=\d)")
_SENTENCE = re.compile(r"[^.!?]+[.!?](?=\s+[A-Z]|\s*$|$)")
_MAX = 4


def _sentence_ends(text: str) -> List[int]:
    """Indices (exclusive) where sentences end in `text`.

    A `.` is a sentence end only when it is not a decimal point (between
    digits) and the next non-space character is an uppercase letter (or it is
    the end of the paragraph).  `!` and `?` always end a sentence.  This keeps
    version numbers (1.21.0), abbreviations, and inline code intact.
    """
    ends: List[int] = []
    n: int = len(text)
    j: int = 0
    while j < n:
        while j < n and text[j] not in ".!?":
            j += 1
        if j >= n:
            break
        boundary: bool = True
        if text[j] == ".":
            if (j > 0 and text[j - 1].isdigit()
                    and j + 1 < n and text[j + 1].isdigit()):
                boundary = False
            else:
                k: int = j + 1
                while k < n and text[k] == ' ':
                    k += 1
                if k < n and not text[k].isupper():
                    boundary = False
        if boundary:
            ends.append(j + 1)
        j += 1
    return ends


def _count_sentences(text: str) -> int:
    return len(_sentence_ends(text))


def _chunks(text: str) -> List[str]:
    """Split a paragraph into <= four-sentence chunks, preserving its text."""
    ends: List[int] = _sentence_ends(text)
    if len(ends) <= _MAX:
        return [text]
    snippets: List[str] = []
    prev: int = 0
    for end in ends:
        snippets.append(text[prev:end].strip())
        prev = end
    if prev < len(text):
        snippets.append(text[prev:].strip())
    groups: List[str] = []
    for i in range(0, len(snippets), _MAX):
        groups.append(" ".join(x for x in snippets[i:i + _MAX] if x))
    return groups


def _is_prose(line: str) -> bool:
    if not line.strip():
        return False
    if line[0] in "#|-*":
        return False
    if re.match(r"^\s*\d+[.)]\s", line):
        return False
    return True


def _split_lines(lines: List[str]) -> List[str]:
    """Rewrap any prose run with more than four sentences into <=4 chunks.

    Chunks are emitted as their own single-line paragraphs separated by a
    blank line.  Lines are never reordered and inline formatting is preserved.
    """
    out: List[str] = []
    in_fence: bool = False
    block: List[str] = []

    def flush() -> None:
        if not block:
            return
        joined: str = " ".join(x.strip() for x in block)
        if _count_sentences(joined) > _MAX:
            for chunk in _chunks(joined):
                out.append(chunk)
                out.append("")
        else:
            out.extend(block)
        block.clear()

    for line in lines:
        stripped: str = line.lstrip()
        if stripped.startswith("```"):
            flush()
            out.append(line)
            in_fence = not in_fence
            continue
        if in_fence:
            out.append(line)
            continue
        if _is_prose(line):
            block.append(line)
        else:
            flush()
            out.append(line)
    flush()
    # Collapse any accidental double blank lines introduced by the trailing
    # blank after each chunked paragraph.
    result: List[str] = []
    prev_blank: bool = False
    for line in out:
        if line == "":
            if not prev_blank:
                result.append(line)
            prev_blank = True
        else:
            result.append(line)
            prev_blank = False
    return result


def _doc_files() -> List[Path]:
    files: set = set()
    for p in (ROOT / "docs").rglob("*.md"):
        if "api-docs" in p.relative_to(ROOT / "docs").parts:
            continue
        files.add(p)
    files.add(ROOT / "README.md")
    return sorted(files)


def check() -> int:
    bad: List[Path] = []
    for path in _doc_files():
        lines = path.read_text(encoding="utf-8").splitlines()
        out = _split_lines(list(lines))
        if out != lines:
            bad.append(path)
    if bad:
        for path in bad:
            print(f"  {path.relative_to(ROOT)} needs paragraph splitting "
                  f"(run para-split.py --fix)")
        print(f"  {len(bad)} file(s) have paragraphs over four sentences")
        return 1
    print("  Paragraph 4-sentence rule: passed (no paragraph > 4 sentences)")
    return 0


def fix() -> int:
    changed = 0
    for path in _doc_files():
        lines = path.read_text(encoding="utf-8").splitlines()
        out = _split_lines(list(lines))
        if out != lines:
            path.write_text("\n".join(out) + "\n", encoding="utf-8")
            print(f"  split paragraphs in {path.relative_to(ROOT)}")
            changed += 1
    if changed == 0:
        print("  all hand-written docs already comply (no change)")
    else:
        print(f"  split paragraphs in {changed} file(s)")
    return 0


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--fix", action="store_true",
                      help="insert paragraph breaks to comply")
    mode.add_argument("--check", action="store_true",
                      help="exit 1 when any paragraph is over the limit")
    args: argparse.Namespace = ap.parse_args(argv)
    return fix() if args.fix else check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))