#!/usr/bin/env python3
"""Check the bundled offline manual's links against a fresh Sphinx build.

Wired as `make book-links-check` (part of `make check`):

Every link inside the bundled offline manual (the pages tools/gen-docs.py
post-processes and embeds in src/adacovex-docs_template.ads) must resolve to a
bundled asset or to a file that is deliberately not bundled.  The deliberate
exclusions are the OFFLINE_EXCLUDED_PREFIXES shared with tools/gen-docs.py
(.doctrees/, _sources/, _images/, .buildinfo, objects.inv), so the checker
never flags the files gen-docs.py intentionally drops or replaces with a note.
Sphinx's search machinery (searchindex.js, searchtools.js, the stemmers,
language_data), the search results page (search.html), the alphabetical index
(genindex.html) and the _downloads/ badge SVGs ARE bundled -- search works
offline exactly as online -- so their links must resolve like any other asset.
External links and in-page anchors are skipped.

The check runs against a **fresh** `sphinx-build` from a temp copy of docs/
(the output docs/_build/html is a local, gitignored build product -- the
committed artifact is the generated spec, gated by
`python3 tools/gen-docs.py --check`), so a stale local docs/_build/html can
never mask a broken link.  When sphinx-build is not on PATH the local
docs/_build/html is checked instead (with a note), and when neither exists the
check is skipped -- the committed spec is the fallback, exactly like
tools/gen-docs.py.

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
BUILD: Path = ROOT / "docs" / "_build" / "html"

# tools/gen-docs.py shares the offline asset rules with this checker (see the
# comment block there), so import them rather than duplicating the list.
gen_docs = importlib.import_module("gen-docs")

# href/src attribute values to scan inside the bundled pages.
_LINK_ATTR = re.compile(r'(?:href|src)="([^"]+)"')
# URL schemes and pseudo-targets that are not manual-internal files.
_EXTERNAL = ("http://", "https://", "mailto:", "data:", "javascript:", "tel:")


def internal_targets(html: str, page_rel: str) -> List[str]:
    """Resolved build-relative targets of every internal link in one page.

    Anchors and query strings are stripped, external schemes are skipped, and
    each target is resolved against the page's directory so callers compare
    against build-rooted paths (for example `../architecture.html` from
    `api-docs/index.html` resolves to `architecture.html`).  A link that is
    already build-rooted (Sphinx emits a leading `/` for the root-index
    canonical form, for example `href="/index.html"` in some themes) is
    resolved without a directory prefix.
    """
    targets: List[str] = []
    page_dir: str = posixpath.dirname(page_rel)
    for match in _LINK_ATTR.finditer(html):
        url: str = match.group(1)
        target: str = url.split("#", 1)[0].split("?", 1)[0]
        if not target or target.startswith(_EXTERNAL) or target.startswith("//"):
            continue
        if target.startswith("/"):
            combined: str = posixpath.normpath(target.lstrip("/"))
        elif page_dir:
            combined = posixpath.normpath(posixpath.join(page_dir, target))
        else:
            combined = posixpath.normpath(target)
        if combined in ("", "."):
            continue
        targets.append(combined)
    return targets


def check_bundle_links(assets: List[Tuple[str, str, str]]) -> List[str]:
    """Broken-link messages for the bundled offline manual (empty when sound).

    assets is gen_docs.collect_assets() output: (build-relative path, MIME,
    post-processed body).  Every internal target of every HTML asset must be
    another bundled asset, or sit under a deliberately-not-bundled prefix
    (.doctrees/, _sources/, _images/, .buildinfo, objects.inv -- the files
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


def sphinx_build_into(dest: Path) -> bool:
    """Build the manual into dest/out from a temp copy of docs/.

    Returns False when sphinx-build is not resolvable (PATH or the repo's
    own .venv) or the build fails.  The copy excludes the local docs/_build
    output so the build never folds a stale build into itself.
    """
    cmd = gen_docs.sphinx_build_cmd()
    if cmd is None:
        return False
    src: Path = dest / "src"
    out: Path = dest / "out"
    shutil.copytree(ROOT / "docs", src,
                    ignore=shutil.ignore_patterns("_build", "book"))
    result = subprocess.run(
        cmd + [str(src), str(out)],
        capture_output=True, text=True)
    if result.returncode != 0:
        print(f"note: sphinx-build failed: {result.stderr.strip()[-500:]}",
              file=sys.stderr)
        return False
    return True


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0])
    ap.parse_args(argv)

    # The link check runs against a fresh temp build when sphinx-build is
    # present (a stale local docs/_build/html can never mask a broken link);
    # otherwise it falls back to the local build output, and when neither
    # exists it is skipped -- the committed spec is the fallback, like
    # tools/gen-docs.py.
    with tempfile.TemporaryDirectory(prefix="adacovex-book-") as td:
        tmp: Path = Path(td)
        book_dir: Optional[Path] = None
        if sphinx_build_into(tmp):
            book_dir = tmp / "out"
            print("  Checking links against a fresh sphinx-build.")
        elif BUILD.is_dir():
            book_dir = BUILD
            print("  note: sphinx-build not on PATH; checking the local "
                  "docs/_build/html", file=sys.stderr)
        else:
            print("note: sphinx-build not on PATH and no local "
                  "docs/_build/html -- link check skipped", file=sys.stderr)
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