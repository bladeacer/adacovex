#!/usr/bin/env python3
"""Split paragraphs over the four-sentence limit in hand-written docs.

adacovex enforces that no paragraph exceeds four sentences (see check-docs.py
and the project's Simplified Technical English style).  This utility inserts a
blank line between sentence groups so no paragraph carries more than four
completed sentences.  It never rewrites a sentence: it inserts blank lines
only, and it keeps the existing line wrapping at every line except the two
that a break falls between.

It edits only the hand-written Markdown: docs/ (excluding generated
docs/api-docs) and the root README.md.

The sentence rule is the one check-docs.py applies, so `--check` fails exactly
when the gate fails.  A break is never placed inside an inline construct -- a
code span, a link or image, or an autolink -- so an identifier such as
`Adacovex.Target_Profiles` and a badge such as `![tests](tests.svg)` stay
intact.  When a group of four sentences lies wholly inside one such construct,
the paragraph is left as it is and reported, because a break there would
corrupt the Markdown.

Usage:
  python3 tools/para-split.py --fix          # bring files into compliance
  python3 tools/para-split.py --check        # exit 1 when any paragraph is over

Exit code 0 on success (or when no change is needed).
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Iterator, List, NamedTuple, Tuple, Union

ROOT: Path = Path(__file__).resolve().parent.parent
_MAX = 4

# Inline Markdown constructs a break must never cut through: code spans,
# the label of a link or image, the destination of a link or image, and an
# autolink or inline HTML tag.
_PROTECTED = (
    re.compile(r"`[^`]*`"),
    re.compile(r"!?\[[^\]]*\]"),
    re.compile(r"\]\([^)]*\)"),
    re.compile(r"<[^>\s]+>"),
)


class _Block(NamedTuple):
    """One prose paragraph: its first line number and its lines."""
    start: int
    lines: List[str]


def _sentence_ends(text: str) -> List[int]:
    """Indices (exclusive) where sentences end in `text`.

    This is the rule tools/check-docs.py applies, so the two tools always
    agree on a count.  A break is a `.`, `!`, or `?` followed by whitespace
    and a capital letter, or one that ends the paragraph.  A `.` between two
    digits is a decimal point, not a break.  The rule keeps version numbers
    (1.21.0), identifiers (Ada.Text_IO), and badge syntax (![badge](...), and
    links with a `?query`) out of the count.
    """
    ends: List[int] = []
    n: int = len(text)
    j: int = 0
    while j < n:
        while j < n and text[j] not in ".!?":
            j += 1
        if j >= n:
            break
        if (text[j] == "."
                and j > 0 and text[j - 1].isdigit()
                and j + 1 < n and text[j + 1].isdigit()):
            j += 1                      # a decimal point between digits
            continue
        k: int = j + 1
        # A terminator ends the paragraph, or precedes whitespace and a
        # capital letter.  A terminator with no space after it (as in
        # Ada.Text_IO) ends nothing.
        if k >= n:
            ends.append(j + 1)
        elif text[k].isspace():
            while k < n and text[k].isspace():
                k += 1
            if k >= n or text[k].isupper():
                ends.append(j + 1)
        j += 1
    return ends


def _count_sentences(text: str) -> int:
    """The number of sentences in `text` (the check-docs.py rule)."""
    return len(_sentence_ends(text))


def _protected_ranges(text: str) -> List[Tuple[int, int]]:
    """The half-open [start, end) ranges of the inline constructs in `text`."""
    ranges: List[Tuple[int, int]] = []
    for pattern in _PROTECTED:
        ranges.extend(m.span() for m in pattern.finditer(text))
    return ranges


def _inside(position: int, ranges: List[Tuple[int, int]]) -> bool:
    """Whether a break at `position` would fall inside a protected range."""
    return any(start < position < end for start, end in ranges)


def _split_positions(ends: List[int], ranges: List[Tuple[int, int]]) -> List[int]:
    """The break positions (index just past a sentence end) for `ends`.

    Each group holds four sentences when a safe break allows.  The search
    walks back from the fourth sentence to an earlier safe end, then falls
    back to the start of the construct that holds it.  It returns an empty
    list when no safe break exists -- a paragraph whose first four sentences
    all lie inside one code span is reported, never cut.
    """
    cuts: List[int] = []
    index: int = 0
    total: int = len(ends)
    last: int = 0
    while total - index > _MAX:
        candidate: int = ends[min(index + _MAX - 1, total - 2)]
        cut: int = 0
        chosen: int = min(index + _MAX - 1, total - 2)
        while chosen >= index:
            if not _inside(ends[chosen], ranges):
                cut = ends[chosen]
                break
            chosen -= 1
        if cut <= last:
            # No end of the first four sentences is safe: break before the
            # construct that holds the fourth one.
            for start, end in ranges:
                if start < candidate < end:
                    if start > last and start < ends[-1]:
                        cut = start
                    break
        if cut <= last:
            return []
        cuts.append(cut)
        last = cut
        while index < total and ends[index] <= cut:
            index += 1
    return cuts


def _segment_lines(block: List[str], stripped: List[str], starts: List[int],
                   begin: int, end: int) -> List[str]:
    """The lines of `block` that cover [begin, end) of the joined text.

    `end` is None for the last segment.  A line that the segment covers whole
    is kept exactly as it was; only the lines a cut falls between are rebuilt,
    so the file keeps its wrapping.
    """
    texts: List[str] = []
    for i, text in enumerate(stripped):
        line_start: int = starts[i]
        if end is not None and line_start >= end:
            break
        line_end: int = line_start + len(text)
        first: int = max(begin - line_start, 0)
        last: int = (len(text) if end is None or end >= line_end
                     else end - line_start)
        if last <= first:
            continue
        if first == 0 and last == len(text):
            texts.append(block[i])
            continue
        piece: str = text[first:last].strip()
        if piece:
            texts.append(piece)
    return texts


def _split_block(block: List[str]) -> List[str]:
    """Insert blank lines inside one prose block, four sentences at a time.

    Returns the block unchanged when every candidate break lies inside an
    inline construct, and says so on standard error.
    """
    stripped: List[str] = [line.strip() for line in block]
    joined: str = " ".join(stripped)
    ends: List[int] = _sentence_ends(joined)
    if len(ends) <= _MAX:
        return list(block)
    starts: List[int] = []
    offset: int = 0
    for text in stripped:
        starts.append(offset)
        offset += len(text) + 1
    cuts: List[int] = _split_positions(ends, _protected_ranges(joined))
    if not cuts:
        print(f"  warning: a paragraph of {len(ends)} sentences has no break "
              f"outside an inline code span; split it by hand",
              file=sys.stderr)
        return list(block)
    out: List[str] = []
    begin: int = 0
    for cut in cuts:
        out.extend(_segment_lines(block, stripped, starts, begin, cut))
        out.append("")
        begin = cut
    out.extend(_segment_lines(block, stripped, starts, begin, None))
    return out


def _is_prose(line: str) -> bool:
    """Whether a line belongs to a prose paragraph (the check-docs.py rule)."""
    if not line.strip():
        return False
    if line[0] in "#|-*":
        return False
    if re.match(r"^\s*\d+[.)]\s", line):
        return False
    return True


def _walk(lines: List[str]) -> Iterator[Union[str, _Block]]:
    """Yield each structural line as a str and each prose paragraph as a
    `_Block`.  The segmentation matches tools/check-docs.py, so both tools
    count the same paragraphs.
    """
    in_fence: bool = False
    block: List[str] = []
    start: int = 1
    for number, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            if block:
                yield _Block(start, block)
                block = []
            yield line
            in_fence = not in_fence
            continue
        if in_fence:
            yield line
            continue
        if _is_prose(line):
            if not block:
                start = number
            block.append(line)
        else:
            if block:
                yield _Block(start, block)
                block = []
            yield line
    if block:
        yield _Block(start, block)


def _collapse_blanks(lines: List[str]) -> List[str]:
    """Drop a blank line that another blank line already follows."""
    out: List[str] = []
    prev_blank: bool = False
    for line in lines:
        if line == "":
            if not prev_blank:
                out.append(line)
            prev_blank = True
        else:
            out.append(line)
            prev_blank = False
    return out


def _split_lines(lines: List[str]) -> List[str]:
    """The file's lines with a blank line between sentence groups.

    A paragraph of four sentences or fewer keeps its lines untouched.
    """
    items: List[Union[str, _Block]] = list(_walk(lines))
    out: List[str] = []
    for i, item in enumerate(items):
        if isinstance(item, str):
            out.append(item)
            continue
        if _count_sentences(" ".join(x.strip() for x in item.lines)) <= _MAX:
            out.extend(item.lines)
            continue
        out.extend(_split_block(item.lines))
        if i + 1 < len(items):
            out.append("")
    return _collapse_blanks(out)


def _doc_files() -> List[Path]:
    files: set = set()
    for p in (ROOT / "docs").rglob("*.md"):
        if "api-docs" in p.relative_to(ROOT / "docs").parts:
            continue
        files.add(p)
    files.add(ROOT / "README.md")
    return sorted(files)


def _over_limit(path: Path) -> List[str]:
    """Report every paragraph of `path` that holds more than four sentences."""
    lines: List[str] = path.read_text(encoding="utf-8").splitlines()
    rel = path.relative_to(ROOT)
    messages: List[str] = []
    for item in _walk(lines):
        if isinstance(item, str):
            continue
        count: int = _count_sentences(" ".join(x.strip() for x in item.lines))
        if count <= _MAX:
            continue
        if len(_split_block(item.lines)) == len(item.lines):
            messages.append(
                f"  {rel}:{item.start}: paragraph of {count} sentences sits "
                f"inside an inline construct; split it by hand")
        else:
            messages.append(
                f"  {rel}:{item.start}: paragraph of {count} sentences "
                f"(run para-split.py --fix)")
    return messages


def check() -> int:
    messages: List[str] = [m for path in _doc_files() for m in _over_limit(path)]
    if messages:
        print("\n".join(messages))
        files: int = len({m.split(":")[0] for m in messages})
        print(f"  {files} file(s) have paragraphs over four sentences")
        return 1
    print("  Paragraph 4-sentence rule: passed (no paragraph > 4 sentences)")
    return 0


def fix() -> int:
    changed = 0
    for path in _doc_files():
        lines = path.read_text(encoding="utf-8").splitlines()
        out = _split_lines(lines)
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
