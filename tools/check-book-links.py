#!/usr/bin/env python3
"""Check the committed mdBook build output (docs/book) against the docs source.

Two checks, both wired as `make book-links-check` (part of `make check`):

1. **Drift**: a fresh `mdbook build` from a temp copy of docs/ (without the
   committed book output, so the build does not copy it into itself) must
   reproduce the committed docs/book byte for byte.  Any difference means
   docs/ changed without `make book` being re-run, so the committed site is
   stale.  When mdbook is not on PATH the rebuild is skipped with a note and
   only the bundle-link check runs -- the committed book is the fallback,
   exactly like tools/gen-docs.py.

2. **Bundle links**: every link inside the bundled offline manual (the pages
   tools/gen-docs.py post-processes and embeds in
   src/adacovex-docs_template.ads) must resolve to a bundled asset or to a
   file that is deliberately not bundled.  The deliberate exclusions are the
   OFFLINE_EXCLUDED_PREFIXES shared with tools/gen-docs.py (media/, fonts/,
   print.html, 404.html, book.toml, .nojekyll), so the checker never flags
   the files gen-docs.py intentionally drops or replaces with a note.
   mdbook's search machinery (elasticlunr-, mark-, searcher-, searchindex-)
   IS bundled -- the manual's own search works offline -- so its links
   resolve like any other asset.  External links and in-page anchors are
   skipped.

Usage:
  python3 tools/check-book-links.py
"""

import argparse
import importlib
import posixpath
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Set, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
BOOK: Path = ROOT / "docs" / "book"

# tools/gen-docs.py shares the offline asset rules with this checker (see the
# comment block there), so import them rather than duplicating the list.
gen_docs = importlib.import_module("gen-docs")

# href/src attribute values to scan inside the bundled pages.
_LINK_ATTR = re.compile(r'(?:href|src)="([^"]+)"')
# URL schemes and pseudo-targets that are not book-internal files.
_EXTERNAL = ("http://", "https://", "mailto:", "data:", "javascript:", "tel:")


def internal_targets(html: str, page_rel: str) -> List[str]:
    """Resolved book-relative targets of every internal link in one page.

    Anchors and query strings are stripped, external schemes are skipped, and
    each target is resolved against the page's directory so callers compare
    against book-rooted paths (for example `../architecture.html` from
    `api-docs/index.html` resolves to `architecture.html`).
    """
    targets: List[str] = []
    page_dir: str = posixpath.dirname(page_rel)
    for match in _LINK_ATTR.finditer(html):
        url: str = match.group(1)
        target: str = url.split("#", 1)[0].split("?", 1)[0]
        if not target or target.startswith(_EXTERNAL) or target.startswith("//"):
            continue
        combined: str = (
            posixpath.normpath(posixpath.join(page_dir, target))
            if page_dir else posixpath.normpath(target))
        if combined in ("", "."):
            continue
        targets.append(combined)
    return targets


def check_bundle_links(assets: List[Tuple[str, str, str]]) -> List[str]:
    """Broken-link messages for the bundled offline manual (empty when sound).

    assets is gen_docs.collect_assets() output: (book-relative path, MIME,
    post-processed body).  Every internal target of every HTML asset must be
    another bundled asset, or sit under a deliberately-not-bundled prefix
    (media/, fonts/, print.html, 404.html, book.toml, .nojekyll -- the files
    the post-processing drops or replaces).
    """
    paths: Set[str] = {rel for rel, _, _ in assets}
    errors: List[str] = []
    for rel, _, body in assets:
        if not rel.endswith(".html"):
            continue
        for target in internal_targets(body, rel):
            if target in paths:
                continue
            if any(target.startswith(p) for p in gen_docs.OFFLINE_EXCLUDED_PREFIXES):
                continue
            errors.append(f"{rel}: link to missing bundled asset: {target}")
    return errors


def dir_differences(fresh: Path, committed: Path) -> List[str]:
    """File-set and byte differences between two directory trees."""
    def file_set(d: Path) -> Set[str]:
        return {p.relative_to(d).as_posix() for p in d.rglob("*") if p.is_file()}

    fresh_files: Set[str] = file_set(fresh)
    committed_files: Set[str] = file_set(committed)
    diffs: List[str] = []
    for rel in sorted(fresh_files - committed_files):
        diffs.append(f"only in fresh build: {rel}")
    for rel in sorted(committed_files - fresh_files):
        diffs.append(f"only in committed docs/book: {rel}")
    for rel in sorted(fresh_files & committed_files):
        if (fresh / rel).read_bytes() != (committed / rel).read_bytes():
            diffs.append(f"content differs: {rel}")
    return diffs


def check_drift() -> Tuple[bool, List[str], str]:
    """Rebuild the book from docs/ and compare with the committed docs/book.

    Returns (ok, diffs, note).  When mdbook is not on PATH the rebuild is
    skipped: ok stays True, diffs is empty, and note explains the skip.
    """
    if shutil.which("mdbook") is None:
        return True, [], "note: mdbook not on PATH; drift check skipped (link check still ran)"
    with tempfile.TemporaryDirectory(prefix="adacovex-book-") as td:
        tmp: Path = Path(td)
        src: Path = tmp / "src"
        out: Path = tmp / "out"
        # Copy docs/ without the committed book output so the build does not
        # copy the stale book into itself.
        shutil.copytree(ROOT / "docs", src, ignore=shutil.ignore_patterns("book"))
        result = subprocess.run(
            ["mdbook", "build", str(src), "--dest-dir", str(out)],
            capture_output=True, text=True)
        if result.returncode != 0:
            return False, [f"mdbook build failed: {result.stderr.strip()[-500:]}"], ""
        return len(dir_differences(out, BOOK)) == 0, dir_differences(out, BOOK), ""


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.parse_args(argv)

    # Bundle-link check: always runs (no mdbook needed).
    assets: List[Tuple[str, str, str]] = gen_docs.collect_assets(BOOK)
    errors: List[str] = check_bundle_links(assets)
    if errors:
        for e in errors:
            print(f"  ERROR: {e}", file=sys.stderr)
        print(f"  Book link check FAILED ({len(errors)} broken link(s))",
              file=sys.stderr)
        return 1
    print("  All links resolve in the bundled offline manual.")

    # Drift check: the committed book must equal a fresh mdbook build.
    ok, diffs, note = check_drift()
    if note:
        print(f"  {note}")
    if not ok:
        for d in diffs:
            print(f"  ERROR: {d}", file=sys.stderr)
        print("  ERROR: docs/book is stale -- run `make book` and commit the rebuilt site",
              file=sys.stderr)
        return 1
    print("  docs/book is current (a fresh mdbook build reproduces it).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
