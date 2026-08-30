#!/usr/bin/env python3
"""Check the bundled offline manual's links against a fresh mdBook build.

Wired as `make book-links-check` (part of `make check`):

Every link inside the bundled offline manual (the pages tools/gen-docs.py
post-processes and embeds in src/adacovex-docs_template.ads) must resolve to a
bundled asset or to a file that is deliberately not bundled.  The deliberate
exclusions are the OFFLINE_EXCLUDED_PREFIXES shared with tools/gen-docs.py
(media/, fonts/, 404.html, book.toml, .nojekyll), so the checker never flags
the files gen-docs.py intentionally drops or replaces with a note.  The print
view (print.html), the SVG favicon, and mdbook's search machinery (elasticlunr-,
mark-, searcher-, searchindex-) ARE bundled -- the print button works and
offline search resolves -- so their links must resolve like any other
asset.  External links and in-page anchors are skipped.

The check runs against a **fresh** `mdbook build` from a temp copy of docs/
(the output docs/book is a local, gitignored build product -- the committed
artifact is the generated spec, gated by `python3 tools/gen-docs.py --check`),
so a stale local docs/book can never mask a broken link.  When mdbook is not
on PATH the local docs/book is checked instead (with a note), and when neither
exists the check is skipped -- the committed spec is the fallback, exactly
like tools/gen-docs.py.

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
from typing import List, Optional, Set, Tuple

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
    (media/, fonts/, 404.html, book.toml, .nojekyll -- the files the
    post-processing drops or replaces).
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


def fresh_build(dest: Path) -> bool:
    """Build the book into dest/out from a temp copy of docs/.

    Returns False when mdbook is not on PATH or the build fails.  The copy
    excludes the local docs/book output so the build never folds a stale
    book into itself.
    """
    if shutil.which("mdbook") is None:
        return False
    src: Path = dest / "src"
    out: Path = dest / "out"
    shutil.copytree(ROOT / "docs", src, ignore=shutil.ignore_patterns("book"))
    result = subprocess.run(
        ["mdbook", "build", str(src), "--dest-dir", str(out)],
        capture_output=True, text=True)
    if result.returncode != 0:
        print(f"note: mdbook build failed: {result.stderr.strip()[-500:]}",
              file=sys.stderr)
        return False
    return True


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0])
    ap.parse_args(argv)

    # The link check runs against a fresh temp build when mdbook is present
    # (a stale local docs/book can never mask a broken link); otherwise it
    # falls back to the local build output, and when neither exists it is
    # skipped -- the committed spec is the fallback, like tools/gen-docs.py.
    with tempfile.TemporaryDirectory(prefix="adacovex-book-") as td:
        tmp: Path = Path(td)
        book_dir: Optional[Path] = None
        if fresh_build(tmp):
            book_dir = tmp / "out"
            print("  Checking links against a fresh mdbook build.")
        elif BOOK.is_dir():
            book_dir = BOOK
            print("  note: mdbook not on PATH; checking the local docs/book",
                  file=sys.stderr)
        else:
            print("note: mdbook not on PATH and no local docs/book -- "
                  "link check skipped", file=sys.stderr)
            return 0

        assets: List[Tuple[str, str, str]] = gen_docs.collect_assets(book_dir)
        errors: List[str] = check_bundle_links(assets)

    if errors:
        for e in errors:
            print(f"  ERROR: {e}", file=sys.stderr)
        print(f"  Book link check FAILED ({len(errors)} broken link(s))",
              file=sys.stderr)
        return 1
    print("  All links resolve in the bundled offline manual.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
