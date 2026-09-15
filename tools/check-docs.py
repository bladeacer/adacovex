#!/usr/bin/env python3
"""Check user documentation paragraphs and basic controlled-language rules.

Rules enforced here:

* no paragraph may exceed four sentences (Simplified Technical English and
  the project style guide keep sentences short and paragraphs tight);
* no em dash (\u2014) characters;
* no Latin abbreviations (e.g., i.e., etc.);
* one space after a sentence-ending `.`, `!`, or `?` (never two).  The
  hand-written docs, the changelogs, and the Ada comment text under src/ use
  single spacing; `--fix` collapses a double space after a sentence in the
  same places the gate covers, and nowhere else (Ada code is never touched).

The paragraph rule is a hard gate: exceeding four sentences in any paragraph
fails the check with exit 1.  It covers the hand-written user documentation
under docs/, the human changelogs under docs/changelogs/, and the root
README.md.  docs/api-docs is excluded because `make doc` regenerates those
pages from Ada source docstrings (the paragraph rule there belongs in the
source docstrings, not the generated output).  The single-space rule has a
wider set: it also covers AGENTS.md and CONTRIBUTING.md, whose long-form
paragraphs are outside the four-sentence cap, and the comment text of every
`src/**/*.ads` and `src/**/*.adb` file, where a docstring is prose too.  An
Ada line is only ever read from its `--` marker on, so code alignment, string
literals, and the `--  ` prefix itself are outside the rule.

The 250-line cap is a soft gate: an overrun prints a warning but does not fail
the check.  A page may opt out of the line cap with a
`no-covex-docs-loc` marker in an HTML comment near the top of the file (the
same opt-out convention the complexity checker uses).  It is meant for
reference dictionaries and historical records whose length is their content,
not prose that grew by accident.

Usage:
  python3 tools/check-docs.py          # check; exit 1 on any violation
  python3 tools/check-docs.py --fix    # collapse sentence double spaces first
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
# Opt-out marker for the line cap (see module docstring).  Matched against the
# first LOC_MARKER_SCAN lines of a file so the marker stays near the top.
LOC_MARKER = "no-covex-docs-loc"
LOC_MARKER_SCAN = 12

# A decimal point between digits is not a sentence break (e.g. 1.21.0).
_DECIMAL = re.compile(r"(?<=\d)\.(?=\d)")
# A sentence ends at a . ! ? (decimal-stripped) followed by whitespace then an
# uppercase letter (or the end of the paragraph).
_SENTENCE = re.compile(r"[^.!?]+[.!?](?=\s+[A-Z]|\s*$|$)")
_MAX_SENTENCES = 4

# Two or more spaces after a sentence-ending `.`, `!`, or `?`, followed by
# any further text: the next sentence may start with a capital, a quote, a
# bracket, a backtick, a flag, or a numeral, and all of them are the same
# violation.  A markdown hard line break (a trailing double space) has no next
# character, so it is never flagged, and a decimal point between digits is not
# a sentence end.  The `--  ` Ada comment prefix is safe because `--` is not
# sentence punctuation.
_DOUBLE_SPACE = re.compile(r"(?<=[.!?]) {2,}(?=\S)")


def doc_files() -> List[Path]:
    """Return hand-written Markdown pages: user docs + changelogs + README."""
    files = set()
    for p in (ROOT / "docs").rglob("*.md"):
        if "api-docs" in p.relative_to(ROOT / "docs").parts:
            continue
        files.add(p)
    files.add(ROOT / "README.md")
    return sorted(files)


def spacing_files() -> List[Path]:
    """Every file the single-sentence-space rule covers.

    Wider than doc_files(): the root AGENTS.md and CONTRIBUTING.md are prose
    the sentence-spacing rule applies to, but their long-form paragraphs are
    out of scope for the four-sentence cap.
    """
    files = {p for p in doc_files() if p.is_file()}
    for extra in (ROOT / "AGENTS.md", ROOT / "CONTRIBUTING.md"):
        if extra.is_file():
            files.add(extra)
    return sorted(files)


def count_sentences(text: str) -> int:
    return len(_SENTENCE.findall(_DECIMAL.sub("", text)))


def has_loc_opt_out(path: Path) -> bool:
    """Whether the file opts out of the line cap with a no-covex-docs-loc marker."""
    with path.open(encoding="utf-8") as fp:
        for _, line in zip(range(LOC_MARKER_SCAN), fp):
            if LOC_MARKER in line:
                return True
    return False


def check(path: Path) -> List[str]:
    """Return violations (hard errors) for one documentation file."""
    rel = path.relative_to(ROOT)
    lines = path.read_text(encoding="utf-8").splitlines()
    errors: List[str] = []
    if len(lines) > MAX_LOC and not has_loc_opt_out(path):
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
    errors.extend(spacing_errors(rel, lines))
    for number, line in enumerate(lines, 1):
        if "\u2014" in line:
            errors.append(f"{rel}:{number}: em dash")
        if re.search(r"\b(e\.g\.|i\.e\.|etc\.)\b", line):
            errors.append(f"{rel}:{number}: Latin abbreviation")
    return errors


def spacing_errors(rel, lines: List[str]) -> List[str]:
    """Return the single-sentence-space violations of one file.

    Fenced code blocks are skipped (the rule is about prose); inline code
    spans are left in place but never trigger it, because the `--  ` Ada
    comment prefix a span documents is not sentence punctuation.  The rule is
    exactly the one `fix` collapses, so the two always agree.
    """
    errors: List[str] = []
    in_fence = False
    for number, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if _DOUBLE_SPACE.search(line):
            errors.append(
                f"{rel}:{number}: two spaces after a sentence "
                f"(run check-docs.py --fix)")
    return errors


def collapse_sentence_spaces(text: str) -> str:
    """Collapse the sentence double spaces the gate flags.

    Fenced code blocks are skipped, and a markdown hard break (a trailing run
    of spaces) is left alone, because the rule needs a following character.
    Exactly the pattern `spacing_errors` flags, so the fixer and the gate
    always agree.
    """
    out: List[str] = []
    in_fence = False
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            out.append(line)
            continue
        if not in_fence:
            body, nl = (line[:-1], "\n") if line.endswith("\n") \
                else (line, "")
            line = _DOUBLE_SPACE.sub(" ", body) + nl
        out.append(line)
    return "".join(out)


def source_files() -> List[Path]:
    """The Ada sources whose comment text the single-space rule covers.

    The generated units (`adacovex-docs_template`, `adacovex-dashboard_template`,
    `adacovex_version_info`) are excluded, exactly as the generated api-docs
    pages are: the rule belongs in the generator's own text, which emits
    single-spaced comments already, and a hand edit here would be overwritten
    by the next `make build`.
    """
    generated = {"adacovex-docs_template", "adacovex-dashboard_template",
                 "adacovex_version_info"}
    files: List[Path] = []
    root = ROOT / "src"
    if root.is_dir():
        for suffix in ("*.ads", "*.adb"):
            files.extend(
                p for p in root.rglob(suffix)
                if p.is_file() and p.stem not in generated)
    return sorted(files)


def ada_comment_start(line: str) -> int:
    """Index of the `--` that opens the comment on an Ada source line.

    Returns -1 when the line carries no comment.  A `--` inside a string
    literal is not a comment, so the scan tracks string state (a doubled
    quote escapes one), and an unterminated literal reports no comment -- the
    compiler rejects such a line anyway.
    """
    in_string = False
    index = 0
    while index < len(line):
        char = line[index]
        if in_string:
            if char == '"':
                if index + 1 < len(line) and line[index + 1] == '"':
                    index += 2
                    continue
                in_string = False
        elif char == '"':
            in_string = True
        elif char == "-" and line.startswith("--", index):
            return index
        index += 1
    return -1


def source_spacing_errors(rel, lines: List[str]) -> List[str]:
    """Return the single-sentence-space violations in Ada comment text.

    Only the comment part of a line is read, so code alignment and string
    literals are never flagged, and the rule is exactly the one the fixer
    collapses.
    """
    errors: List[str] = []
    for number, line in enumerate(lines, 1):
        start = ada_comment_start(line)
        if start < 0:
            continue
        if _DOUBLE_SPACE.search(line[start:]):
            errors.append(
                f"{rel}:{number}: two spaces after a sentence in a comment "
                f"(run check-docs.py --fix)")
    return errors


def collapse_comment_spaces(text: str) -> str:
    """Collapse the sentence double spaces in Ada comment text only.

    The code before a `--` marker is copied byte for byte, so an alignment or
    a string literal can never be rewritten.
    """
    out: List[str] = []
    for line in text.splitlines(keepends=True):
        body, nl = (line[:-1], "\n") if line.endswith("\n") else (line, "")
        start = ada_comment_start(body)
        if start >= 0:
            body = body[:start] + _DOUBLE_SPACE.sub(" ", body[start:])
        out.append(body + nl)
    return "".join(out)


def fix() -> int:
    """Collapse every sentence double space in the rule's files.

    Only the spacing rule is rewritten here; the paragraph splitter lives in
    tools/para-split.py, so the two fixers stay in step with their gates.
    """
    changed = 0
    jobs = [(path, collapse_sentence_spaces) for path in spacing_files()]
    jobs.extend((path, collapse_comment_spaces) for path in source_files())
    for path, collapse in jobs:
        text = path.read_text(encoding="utf-8")
        new_text = collapse(text)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            print(f"  collapsed sentence double spaces in "
                  f"{path.relative_to(ROOT)}")
            changed += 1
    if changed == 0:
        print("  no sentence double spaces found (no change)")
    else:
        print(f"  normalised {changed} file(s)")
    return 0


def main(argv: List[str]) -> int:
    """Run the documentation checks (or the --fix normaliser)."""
    if "--fix" in argv:
        return fix()
    files = doc_files()
    errors = [error for path in files for error in check(path)]
    for path in spacing_files():
        if path in files:
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        errors.extend(spacing_errors(path.relative_to(ROOT), lines))
    sources = source_files()
    for path in sources:
        lines = path.read_text(encoding="utf-8").splitlines()
        errors.extend(source_spacing_errors(path.relative_to(ROOT), lines))
    if errors:
        print("\n".join(errors))
        return 1
    print(f"Documentation check passed for {len(files)} hand-written pages "
          f"and {len(sources)} Ada sources.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
