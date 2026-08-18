#!/usr/bin/env python3
"""Check every markdown link in the repo resolves.

Scans all `.md` files under the repository root and verifies that:

- relative links point at files that exist (resolved against the containing
  file's directory);
- links carrying an `#anchor` point at a real GitHub-style heading slug in
  the target markdown file (lowercased, punctuation stripped, spaces
  hyphenated);
- external links (http/https/mailto) are not verified.

Fenced code blocks are stripped before link extraction so code samples that
happen to contain `[x](y)`-looking text are not treated as links.

Usage:
  python3 tools/check-links.py            # check the whole repo; exit 1 on breaks
  python3 tools/check-links.py --dry-run  # print the scanned files, no checks
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

# Directories whose contents are never scanned (build output, Alire state,
# vendored index copies).
SKIP_DIRS: Tuple[str, ...] = (
    ".git",
    "obj",
    "alire",
    "index",
    "config",
    "docs/badges",
)

LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


def slugify(heading: str) -> str:
    """GitHub-faithful anchor slug for a markdown heading.

    Mirrors github/html-pipeline's TableOfContentsFilter: lowercase, drop
    everything that is not a word character (letters, digits, underscore),
    hyphen, or space, then replace *each* space with a hyphen (consecutive
    spaces yield consecutive hyphens, e.g. `a  b` -> `a--b`).
    """
    s: str = heading.strip().lower()
    s = re.sub(r"^#{1,6}\s+", "", s)          # drop leading markdown markers
    s = re.sub(r"[^\w\- ]", "", s)            # remove punctuation
    s = s.strip()                               # drop space left by markers
    s = s.replace(" ", "-")                    # each space -> hyphen
    return s


def headings_slugs(path: Path) -> List[str]:
    """Return the GitHub anchor slugs of all headings in a markdown file.

    Duplicate headings get GitHub's `-1`, `-2`, ... suffixes (the first
    occurrence keeps the bare slug).
    """
    slugs: List[str] = []
    seen: Dict[str, int] = {}
    try:
        text: str = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return slugs
    for line in text.splitlines():
        m = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if m:
            slug: str = slugify(m.group(1))
            n: int = seen.get(slug, 0)
            seen[slug] = n + 1
            slugs.append(slug if n == 0 else f"{slug}-{n}")
    return slugs


def strip_code_fences(text: str) -> str:
    """Blank out fenced code blocks so their contents are not link-checked."""
    lines: List[str] = text.splitlines()
    out: List[str] = []
    in_fence: bool = False
    for line in lines:
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            out.append("")
        elif in_fence:
            out.append("")
        else:
            out.append(line)
    return "\n".join(out)


def md_files() -> List[Path]:
    """All markdown files to check, in a stable order."""
    files: List[Path] = []
    for path in sorted(ROOT.rglob("*.md")):
        rel: Path = path.relative_to(ROOT)
        if any(rel.is_relative_to(skip) for skip in SKIP_DIRS):
            continue
        files.append(path)
    return files


def check_file(path: Path, slug_cache: Dict[Path, List[str]],
               errors: List[str]) -> None:
    """Verify every link target in one markdown file."""
    try:
        raw: str = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        errors.append(f"{path}: unreadable: {exc}")
        return

    text: str = strip_code_fences(raw)
    rel: Path = path.relative_to(ROOT)
    for line_no, line in enumerate(text.splitlines(), start=1):
        for target in LINK_RE.findall(line):
            target = target.strip()
            if not target or target.startswith("#"):
                continue
            if target.startswith(("http://", "https://", "mailto:", "ftp://")):
                continue
            if " " in target:  # unescaped spaces are not valid link targets
                errors.append(f"{rel}:{line_no}: link target contains a "
                              f"space: {target!r}")
                continue
            file_part, _, anchor = target.partition("#")
            if file_part == "":
                continue
            resolved: Path = (path.parent / file_part).resolve()
            if not resolved.exists():
                errors.append(f"{rel}:{line_no}: broken link: {target!r} "
                              f"(no such file {resolved})")
                continue
            if anchor and resolved.suffix == ".md":
                if resolved not in slug_cache:
                    slug_cache[resolved] = headings_slugs(resolved)
                if anchor not in slug_cache[resolved]:
                    errors.append(f"{rel}:{line_no}: broken anchor "
                                  f"{anchor!r} in {resolved.relative_to(ROOT)}")


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true",
                    help="list the scanned files without checking")
    args: argparse.Namespace = ap.parse_args(argv)

    files: List[Path] = md_files()
    if args.dry_run:
        for f in files:
            print(f.relative_to(ROOT))
        return 0

    errors: List[str] = []
    slug_cache: Dict[Path, List[str]] = {}
    for f in files:
        check_file(f, slug_cache, errors)

    if errors:
        for e in errors:
            print(f"  ERROR: {e}")
        print(f"  Link check FAILED ({len(errors)} problem(s))")
        return 1
    print(f"  All links resolve across {len(files)} markdown files.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
