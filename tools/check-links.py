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
from typing import Dict, List, Optional, Tuple

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
    """GitHub-style anchor slug for a markdown heading."""
    s: str = heading.strip().lower()
    s = re.sub(r"[`*_~]", "", s)          # drop markdown emphasis / backticks
    s = re.sub(r"[^\w\s\-]", "", s)       # drop remaining punctuation
    s = re.sub(r"\s+", "-", s)            # spaces -> hyphens
    return s


def headings_slugs(path: Path) -> List[str]:
    """Return the GitHub anchor slugs of all headings in a markdown file."""
    slugs: List[str] = []
    try:
        text: str = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return slugs
    for line in text.splitlines():
        m = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if m:
            slugs.append(slugify(m.group(1)))
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
            # Generated gnatdoc pages use their own anchor scheme (e.g.
            # `type-ir_int32`), so only verify the file exists for them.
            if (anchor and resolved.suffix == ".md"
                    and "docs/api-docs/" not in resolved.as_posix()):
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
