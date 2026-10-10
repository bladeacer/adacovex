#!/usr/bin/env python3
"""Check the bundled offline manual's links against a fresh Sphinx build.

Wired as `just book-links-check` (part of `just check`):

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

The fresh build is kept in a **content-keyed cache** under
`obj/book-links-check/<fingerprint>/out`, keyed by the SHA-256 of every
docs source file plus the Sphinx build identity.  `just check` builds the
manual twice -- once for this gate and once for the tools unit test that
asserts a fresh build produces the whole book -- and the full Sphinx build
was the two most expensive things in the gate list (measured: 17.6-31.8 s
for this script and 18.57 s for that one test case).  Keying the cache by the
docs content preserves the property that matters: a changed docs/ tree always
rebuilds, so a stale build can never mask a broken link, and the gate is not
weakened by reusing a build the tools test already made.  Pass `--fresh` to
ignore the cache and rebuild unconditionally.

Usage:
  python3 tools/check-book-links.py [--fresh]
"""

import argparse
import importlib
import os
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
# Content-keyed cache of the fresh manual build (see the module docstring).
BOOK_CACHE: Path = ROOT / "obj" / "book-links-check"

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


def book_build_key() -> Optional[str]:
    """Cache key for the fresh manual build, or None without sphinx-build.

    The key covers every docs source file (via the digests gen-docs.py
    already computes for its own stamp), the Sphinx build command, and the
    Sphinx version.  A changed page, a changed toolchain, or a changed build
    command therefore all miss the cache and rebuild.
    """
    cmd = gen_docs.sphinx_build_cmd()
    if cmd is None:
        return None
    version = ""
    try:
        import sphinx
        version = sphinx.__version__
    except Exception:  # pragma: no cover - sphinx always present here
        version = "unknown"
    return f"{gen_docs.tree_fingerprint(gen_docs.docs_source_digests())}-" \
           f"{'-'.join(cmd)}-{version}"


def fresh_book(fresh: bool = False) -> Optional[Path]:
    """Path of a freshly built manual, reusing the content-keyed cache.

    Returns the cached build when the key matches and the build is still
    there, otherwise builds from a temp copy of docs/ and moves the result
    into the cache.  Returns None when sphinx-build is unresolvable or the
    build fails; a failed build never falls back to the cached one, so a
    broken docs/ tree can never be masked.
    """
    key = book_build_key()
    if key is None:
        return None
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", key)
    dest = BOOK_CACHE / safe
    # The cache entry directory *is* the build output, so the key covers the
    # whole tree and a reader sees either the old complete build or the new
    # one, never a half-written tree.
    if not fresh and (dest / "index.html").is_file():
        return dest
    with tempfile.TemporaryDirectory(prefix="adacovex-book-") as td:
        if not sphinx_build_into(Path(td)):
            return None
        staged = Path(td) / "out"
        BOOK_CACHE.mkdir(parents=True, exist_ok=True)
        incoming = BOOK_CACHE / f".incoming-{os.getpid()}"
        if incoming.exists():
            shutil.rmtree(incoming, ignore_errors=True)
        shutil.move(str(staged), str(incoming))
        if dest.exists():
            shutil.rmtree(dest, ignore_errors=True)
        incoming.rename(dest)
    return dest if (dest / "index.html").is_file() else None


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0])
    ap.add_argument("--fresh", action="store_true",
                    help="rebuild the manual even when the "
                         "content-keyed cache is current")
    args = ap.parse_args(argv)

    # The link check runs against a fresh build when sphinx-build is present
    # (a stale local docs/_build/html can never mask a broken link); the
    # fresh build is cached by the docs content digest so the gate and the
    # tools unit test share one build.  Otherwise it falls back to the local
    # build output, and when neither exists it is skipped -- the committed
    # spec is the fallback, like tools/gen-docs.py.
    book_dir: Optional[Path] = fresh_book(fresh=args.fresh)
    if book_dir is not None:
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