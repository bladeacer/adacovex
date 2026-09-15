#!/usr/bin/env python3
"""Build the Sphinx manual and bundle the whole built site into the binary.

The manual source is the Sphinx project at `docs/` (read the
`.readthedocs.yaml` dependency: the same project powers the Read the Docs
site -- `sphinx.configuration: docs/conf.py` with Markdown via the MyST
parser, so the pages stay `.md`).  This script:

1. runs `sphinx-build -b html docs docs/_build/html` (when sphinx-build is
   resolvable -- on PATH or in the repo's own `.venv/bin`, see
   `sphinx_build_cmd`; the build output lands in `docs/_build/html`, a
   local, gitignored build product -- the committed artifact is the
   generated spec below), then
2. collects the built site into an offline asset set -- every HTML page, the
   stylesheets, the local scripts (doctools, searchtools, sphinx_highlight),
   and Sphinx's client-side search machinery (base/english stemmers,
   language_data, searchtools, and the searchindex) -- and post-processes
   each page so the offline manual works with no network:

   * the footer "Page source" `_sources/` links and the `_sources/` files
     are dropped (the raw Markdown adds no offline value);
   * the PNG dashboard screenshots (`_images/`) are dropped and each `<img>`
     becomes a short note (the images stay in the online book), while the
     SVG images copied there -- the badge previews on the badges page -- ARE
     bundled, so an inline badge preview works offline exactly as online;
   * Sphinx's `.doctrees/`, `.buildinfo` and `objects.inv` side-car files
     are not served pages and are not bundled;
   * every remaining non-ASCII glyph (for example the paragraph-sign
     headerlinks Sphinx adds) is escaped as an HTML character reference so
     the Ada source stays pure ASCII;

   * the sidebar (the Furo global toctree) is removed from every page and
     stored once per distinct tree under `_nav/`; the page keeps a
     `<div class="sidebar-container" data-nav="N">` stub and a deferred
     `_static/adacovex-nav.js` fills it from that shared asset, marks the
     current page, and scrolls that entry into the drawer.  Only the
     container's *inner* markup is stored, so the script fills the stub in
     place; a stored container would nest a second `.sidebar-container` when
     injected, and a nested container collapses the sticky element's
     containing block to 100vh so the sidebar scrolls away with the page
     instead of sticking with its own scrollbar.  Furo repeats the whole
     8 KB toctree in all 191 pages, so the pages are what a per-page gzip
     stream cannot dedupe -- see the bundle review in
     docs/contributing/perf/benchmarks-binary-size.md;

   Sphinx's own search stays fully functional in the bundle: the search
   assets are bundled and the search box is left visible.  The search index
   (a JSON blob `searchindex.js`) is a few hundred KB -- single-line, so it
   is emitted as fixed-size chunks like any oversized asset, and the server
   streams the chunks back as one response when the page requests the index.
   Sphinx names the index `searchindex.js` already (no content hash), so no
   rename is needed and each build just overwrites the same entry.  The
   `_downloads/` badge SVGs (from the inline `:download:` links on the
   badges page) ARE bundled so those links resolve; the Furo theme pulls
   no web fonts, so nothing needs dropping for fonts.
3. gzip-compresses every asset body at build time and writes
   `src/adacovex-docs_template.ads` as a constant table of (path, MIME type,
   body index, gzip flag) assets plus one `aliased constant String` per
   compressed chunk, base85-encoded so the Ada source stays pure ASCII.
   base85 (the same 4 bytes -> 5 characters packing as ASCII85, on the
   quote-free Z85 alphabet) costs 1.25 characters per byte where base64 costs
   1.333, which is 6.2% off the largest payload in the binary.
   Bodies are never concatenated into one value: a single multi-megabyte
   string constant overflows the gnatprove frontend stack, so each compressed
   chunk stays small and the server streams the chunks back as one response.
   The offline manual is served with `Content-Encoding: gzip`; the browser
   decompresses it, so the shipped binary never needs an inflate routine or a
   Python/JS runtime dependency -- only the GNAT runtime.  `--serve` exposes
   the table at `/docs/` so the dashboard links carry a fully offline copy of
   the whole manual inside the binary itself.

The generated spec is committed so the tree builds without running Sphinx
(the project has no Sphinx/Markdown runtime dependency; sphinx+myst-parser
are dev / Read the Docs dependencies from `requirements.txt`).
`docs/_build/` itself is a local build output (gitignored); the spec is the
only committed artifact.  `make book` / `make build` regenerate it
(byte-identical when the docs are unchanged) and `--check` fails when it
drifts -- exactly the same pattern tools/gen-dashboard.py uses.

Determinism and incremental builds:

* the Sphinx build is **incremental but verified**: a SHA-256 fingerprint of
  `docs/` plus the per-source digests and the output file list are stamped
  beside the build, an unchanged tree skips Sphinx completely, and a changed
  one re-reads only the changed pages (their mtimes are refreshed first, so
  Sphinx cannot serve a stale doctree), and a navigation change -- a page
  added or removed, or a toctree'd source edited -- rewrites every page so the
  sidebars follow the new toctree.  The removed sources' outputs are swept,
  and the page set is checked against the sources afterwards; a check failure
  falls back to a clean rebuild (`--fresh` forces it).  The build
  directory therefore stays a pure function of `docs/`, so a renamed or
  deleted page can never leave a stale page in the bundle -- that stale-HTML
  case made the spec differ between an incremental developer tree and a fresh
  clone, and a changed spec invalidates the cached SPARK proof;
* the spec is written **only when its content changed**, so a no-op run keeps
  the file's mtime and `alr build` does not recompile the generated 28k-line
  unit (nor relink) on every `make build` / `make prove`;
* each asset's gzip+base85 result is cached by SHA-256 under
  `obj/adacovex-docs-encode/`, so a docs edit re-encodes only the pages it
  touched, and the uncached bodies are encoded in parallel across the CPU
  cores (both are pure speed-ups: the emitted spec is byte-identical);
* `--check` is read-only: it builds into memory and never rewrites the
  committed spec.

Usage:
  python3 tools/gen-docs.py [--check] [--out=PATH] [--jobs=N] [--fresh]

--check    Verify the generated spec matches the current resources; exit 1 on
           mismatch (used by CI so the committed file never goes stale).
--out      Output Ada spec path (default: src/adacovex-docs_template.ads).
--jobs     Encoder worker processes (default: the CPU count, capped at 8).
--fresh    Rebuild the Sphinx site from scratch instead of reusing the
           incremental build directory (the escape hatch).

Exit code 0 on success, 1 on a missing tool/build or a --check mismatch.  When
sphinx-build is not resolvable (neither on PATH nor in the repo's `.venv`)
the previously committed spec is left in place and a note is printed -- the
spec is authored to build without it.
"""

import argparse
import concurrent.futures
import hashlib
import os
import posixpath
import re
import shutil
import subprocess
import sys
import zlib
from pathlib import Path
from typing import Dict, Iterable, List, NamedTuple, Optional, Set, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
DOCS: Path = ROOT / "docs"
BUILD: Path = DOCS / "_build" / "html"   # sphinx html build output (gitignored)
OUT: Path = ROOT / "src" / "adacovex-docs_template.ads"

# Stamp written after a Sphinx build, holding the fingerprint of the docs
# sources that produced it, the per-source digests, and the output file list.
# An unchanged stamp lets the next run reuse the build directory without
# re-running Sphinx; a changed one rebuilds incrementally and the stamp's
# digests say which sources Sphinx must re-read and which outputs are now
# stale.  The stamp lives inside the (gitignored) build directory.
STAMP: Path = DOCS / "_build" / ".adacovex-docs-sources"
_STAMP_OUTPUTS: str = "# outputs"
_STAMP_SOURCES: str = "# sources"

# Source suffixes Sphinx renders as a page (`foo/bar.md` -> `foo/bar.html`).
PAGE_SUFFIXES: Tuple[str, ...] = (".md", ".rst", ".txt")

# Image suffixes Sphinx copies into the build (under `_images/` for a
# referenced image, under `_downloads/<digest>/` for a download link).
IMAGE_SUFFIXES: Tuple[str, ...] = (
    ".svg", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff",
)

# Pages Sphinx generates from the toctree and the configuration rather than
# from a page source of their own: the alphabetical index and the search page.
GENERATED_PAGES: Tuple[str, ...] = ("genindex.html", "search.html")

# ---------------------------------------------------------------------------
# Offline asset rules.  Shared with tools/check-book-links.py (imported), so
# the link checker knows which built-site files are deliberately not bundled.
# ---------------------------------------------------------------------------

# Path prefixes (relative to the build root) that are never bundled:
# Sphinx's non-server build side-cars (.doctrees/, .buildinfo, objects.inv),
# the raw-source copies under _sources/ (their footer links are stripped from
# every page), and the copied dashboard screenshots under _images/ (each <img>
# becomes a note).  Sphinx's search machinery (searchindex.js, searchtools.js,
# the stemmers, language_data) IS bundled so the manual's own search works
# offline, and the _downloads/ badge SVGs are bundled so the badges page's
# download links resolve.  The search results page (search.html) and the
# alphabetical index page (genindex.html) are linked from every page's footer,
# so they are bundled too.
OFFLINE_EXCLUDED_PREFIXES: Tuple[str, ...] = (
    ".doctrees/",
    "_sources/",
    "_images/",
    ".buildinfo",
    "objects.inv",
)

# `_images/` is excluded above, but the SVG images copied there (the badge set
# the badges page previews inline) ARE bundled: SVG is text, so it compresses
# like any other asset and the preview works offline exactly as online.  The
# PNG screenshots keep the note fallback below.
_IMAGES_PREFIX: str = "_images/"
_IMAGES_BUNDLED_SUFFIX: str = ".svg"

# Content-hash encode cache.  gzip + base85 is the only per-asset work a no-op
# run still repeats, and a docs edit touches a handful of pages, so each
# (body hash -> encoded chunks) pair is stored under obj/ (gitignored and
# stable across a clean Sphinx rebuild) and reused until its body changes.
ENCODE_CACHE: Path = ROOT / "obj" / "adacovex-docs-encode"
_CACHE_SUFFIX: str = ".b85"

# Cap on the encoder worker processes: more than a handful never helps for
# assets this small, and the crate must stay dependency-free (the pool is the
# stdlib concurrent.futures).
MAX_ENCODE_JOBS: int = 8

# The footer "Page source" link that points into _sources (which is not
# bundled).  Stripped from every page so the offline manual has no dead link.
_DROP_SOURCE_LINK = re.compile(r'<a[^>]*href="\.?\.?/?_sources/[^"]*"[^>]*>.*?</a>')

# The Furo theme credits itself in every footer ("Made with Sphinx and
# @pradyunsg's Furo" with links to pradyunsg.me and the Furo GitHub page).
# adacovex credits Sphinx and Furo in THIRD_PARTY_NOTICES.md, CREDITS.md and
# the dashboard Credits tab instead, so the theme self-promotion block is
# stripped from the bundled manual.  The copyright notice above it stays.
_DROP_FURO_CREDIT = re.compile(
    r"Made with <a[^>]*>.*?Furo</a>\s*", re.DOTALL)

# The PNG dashboard screenshots: replaced by a short note.  The image lives
# under _images/ at a relative path from any page (../_images/... on a
# subpage, _images/... on the index).  Only raster images are replaced: a
# referenced SVG (the bundled badge previews) stays in the page.
_IMG_IMAGES = re.compile(
    r"<img[^>]*src=\"(?:[.][.]/)*_images/[^\"]+"
    r"\.(?:png|jpe?g|gif|webp|bmp|tiff?)\"[^>]*>",
    re.IGNORECASE)

_MIME: Dict[str, str] = {
    ".html": "text/html",
    ".css": "text/css",
    ".js": "application/javascript",
    ".svg": "image/svg+xml",
}

# Max compressed bytes stored in one emitted Ada string constant.  gzip is
# applied at build time (see below), then each compressed chunk is base85-
# encoded, so the Ada literal for one chunk is ~5/4 of its compressed size.
# The gnatprove frontend blows its stack on a single constant over ~1 MB
# (whatever its structure), so every chunk -- and its base85 expansion --
# stays well under it.
MAX_CHUNK_BYTES: int = 300_000

# The base85 alphabet: the quote-free Z85 character set, so an emitted Ada
# string literal never needs escaping and the source stays pure ASCII.  The
# Ada decoder in src/adacovex-docs_template.adb hard-codes the same order
# (digits, lower case, upper case, then the punctuation run).
B85: str = ("0123456789abcdefghijklmnopqrstuvwxyz"
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            ".-:+=^!/*?&<>()[]{}@%$#")

# The shared sidebar: every page keeps a stub that a small deferred script
# fills from one of these (build-relative) assets.  The tree is identical for
# all pages of a section, so the toctree is stored a handful of times instead
# of 191 times (see the bundle review in
# docs/contributing/perf/benchmarks-binary-size.md).
NAV_DIR: str = "_nav"
NAV_SCRIPT: str = "_static/adacovex-nav.js"
# The injector is authored project code, so it lives under resources/js/ (the
# SBOM asset scan reads the resources/ root as vendored libraries and
# resources/js/ as the project's own modules).
NAV_SCRIPT_SRC: Path = ROOT / "resources" / "js" / "book-nav.js"
_SIDEBAR_START: str = '<div class="sidebar-container">'
_TAG_CLASS: str = "class="


def _b85_encode(data: bytes) -> str:
    """Encode bytes as base85 on the Z85 alphabet (ASCII85 packing).

    Four bytes become five characters, most significant first.  A final group
    of 1..3 bytes is zero-padded to 4 bytes and emitted as n+1 characters,
    which is the ASCII85 rule the Ada decoder mirrors (it pads the missing
    characters with the last alphabet value and drops the padding bytes).
    """
    out: List[str] = []
    for i in range(0, len(data), 4):
        group: bytes = data[i:i + 4]
        n: int = len(group)
        value: int = int.from_bytes(group + b"\0" * (4 - n), "big")
        digits: List[int] = []
        for _ in range(5):
            digits.append(value % 85)
            value //= 85
        digits.reverse()                       # most significant first
        out.extend(B85[d] for d in digits[:n + 1])
    return "".join(out)


def sh(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)


def sphinx_build_cmd() -> Optional[List[str]]:
    """The sphinx-build command, honouring the repo's own venv.

    Returns [sphinx-build, "-b", "html"] when a usable sphinx-build exists
    (on PATH, or in the repo's `.venv/bin` -- the checked-in docs toolchain
    directory), None otherwise.  `make check` therefore never silently
    skips the docs gates on a machine that has the venv but no system
    sphinx-build.
    """
    exe = shutil.which("sphinx-build")
    if exe is None:
        venv = ROOT / ".venv" / "bin" / "sphinx-build"
        if venv.is_file():
            exe = str(venv)
    if exe is None:
        return None
    return [exe, "-b", "html"]


def docs_source_digests() -> Dict[str, str]:
    """SHA-256 of every docs source file, keyed by relative posix path.

    The build directory (`docs/_build/`) is excluded: it is the artifact under
    validation, never an input.
    """
    digests: Dict[str, str] = {}
    for path in sorted(DOCS.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(DOCS).as_posix()
        if rel.startswith("_build/"):
            continue
        digests[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
    return digests


def tree_fingerprint(digests: Dict[str, str]) -> str:
    """One SHA-256 over every source digest, so a tree has a single value."""
    h = hashlib.sha256()
    for rel in sorted(digests):
        h.update(rel.encode("utf-8"))
        h.update(b"\0")
        h.update(digests[rel].encode("ascii"))
        h.update(b"\0")
    return h.hexdigest()


class Stamp(NamedTuple):
    """One recorded build: the sources that produced it and its output."""

    fingerprint: str
    outputs: Tuple[str, ...]
    digests: Optional[Dict[str, str]]


def _build_relative_paths() -> List[str]:
    """Every file under the build directory, as sorted relative paths."""
    if not BUILD.is_dir():
        return []
    return sorted(
        p.relative_to(BUILD).as_posix()
        for p in BUILD.rglob("*")
        if p.is_file()
    )


def read_stamp() -> Optional[Stamp]:
    """The recorded build, or None when there is no usable stamp.

    A stamp written before the sources section existed carries no per-source
    digests; it is read as digests=None, which tells the caller to rebuild
    clean rather than guess which pages Sphinx must re-read.
    """
    if not STAMP.is_file():
        return None
    try:
        lines = STAMP.read_text(encoding="ascii").splitlines()
    except OSError:
        return None
    if not lines:
        return None
    try:
        out_at = lines.index(_STAMP_OUTPUTS)
    except ValueError:
        return None
    src_at = lines.index(_STAMP_SOURCES) if _STAMP_SOURCES in lines else None
    outputs = tuple(lines[out_at + 1:src_at] if src_at else lines[out_at + 1:])
    digests: Optional[Dict[str, str]] = None
    if src_at is not None:
        digests = {}
        for line in lines[src_at + 1:]:
            digest, _, rel = line.partition("\t")
            if rel:
                digests[rel] = digest
    return Stamp(lines[0], outputs, digests)


def write_stamp(fingerprint: str, digests: Dict[str, str]) -> None:
    """Record the sources and the output file list of the build just run."""
    lines = [fingerprint, _STAMP_OUTPUTS] + _build_relative_paths()
    lines.append(_STAMP_SOURCES)
    lines.extend(f"{digests[rel]}\t{rel}" for rel in sorted(digests))
    try:
        STAMP.parent.mkdir(parents=True, exist_ok=True)
        STAMP.write_text("\n".join(lines) + "\n", encoding="ascii")
    except OSError:
        pass


def build_is_current(fingerprint: str, digests: Dict[str, str]) -> bool:
    """True when docs/_build/html is exactly the build of these sources."""
    stamp = read_stamp()
    if stamp is None or not BUILD.is_dir():
        return False
    if stamp.digests != digests or stamp.fingerprint != fingerprint:
        return False
    return list(stamp.outputs) == _build_relative_paths()


def changed_sources(current: Dict[str, str],
                    previous: Optional[Dict[str, str]]) -> Set[str]:
    """Sources whose content digest differs from the recorded build.

    A missing record (None) reports every source as changed: with nothing to
    compare against, the caller must not trust a single page.
    """
    if previous is None:
        return set(current)
    return {rel for rel, digest in current.items()
            if previous.get(rel) != digest}


def removed_sources(current: Dict[str, str],
                    previous: Optional[Dict[str, str]]) -> Set[str]:
    """Sources the recorded build had and the current tree does not."""
    if previous is None:
        return set()
    return set(previous) - set(current)


# A toctree'd source changes the sidebar of *every* page, so its edits need
# the whole-page rewrite (`sphinx-build -a`) even though only one page source
# changed: Sphinx re-reads the one file but leaves the other pages' sidebars
# stale otherwise.  The directive form is required -- a page that merely
# mentions `{toctree}` in prose does not carry one.
_TOCTREE_MARKER = re.compile(
    r"^\s*(?:`{3,}|:{3,})?\{toctree\}|^\.\. toctree::", re.MULTILINE)


def is_page_source(rel: str) -> bool:
    """Whether a docs source file is rendered as a page (not an image)."""
    return any(rel.endswith(suffix) for suffix in PAGE_SUFFIXES)


def source_page_outputs(sources: Iterable[str]) -> Set[str]:
    """The built page each page source produces (`foo/bar.md` -> `foo/bar.html`).

    Sphinx maps a docname to `<docname>.html`, and a docname is the source path
    with its suffix removed, so the mapping needs no special cases: `index.md`
    and `usage/index.md` both keep their `index`.
    """
    pages: Set[str] = set()
    for rel in sources:
        if rel.startswith("_build/"):
            continue
        if is_page_source(rel):
            pages.add(rel[: rel.rindex(".")] + ".html")
    return pages


def toctree_sources() -> Set[str]:
    """The page sources that carry a toctree directive.

    Every page's sidebar renders the global toctree, so a change to one of
    these sources (a new entry, a caption, a moved page) has to rewrite every
    page, not just the one that changed.
    """
    marked: Set[str] = set()
    for path in sorted(DOCS.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(DOCS).as_posix()
        if rel.startswith("_build/") or not is_page_source(rel):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if _TOCTREE_MARKER.search(text):
            marked.add(rel)
    return marked


def stale_source_outputs(removed: Iterable[str]) -> Tuple[List[str], List[str]]:
    """What a removed docs source leaves behind in the build.

    Returns (build-relative paths, image file names).  Sphinx does not remove
    the output of a page whose source is gone, so the incremental build has to:
    the page itself, its `_sources/` copy and its doctree.  A removed image
    also leaves its copies under `_images/` and under the digest directories of
    `_downloads/`, which are matched by file name -- the part Sphinx keeps.
    """
    paths: List[str] = []
    image_names: List[str] = []
    for rel in removed:
        if rel.startswith("_build/"):
            continue
        for suffix in PAGE_SUFFIXES:
            if rel.endswith(suffix):
                docname = rel[: -len(suffix)]
                paths.append(docname + ".html")
                paths.append(f"_sources/{docname}{suffix}.txt")
                paths.append(f".doctrees/{docname}.doctree")
                break
        else:
            name = posixpath.basename(rel)
            if name.lower().endswith(IMAGE_SUFFIXES):
                paths.append(f"_images/{name}")
                image_names.append(name)
    return paths, image_names


def build_problems(files: Iterable[str], sources: Iterable[str]) -> List[str]:
    """Bundle-relevant build files the current sources do not justify.

    A pure check on an incremental build: the page set must be exactly the
    pages the sources produce, plus Sphinx's generated index and search pages,
    and every copied image must share a file name with a current source.  Any
    other page or image is a leftover of a renamed or deleted source, and a
    missing page means Sphinx skipped a source it should have re-read, so the
    caller falls back to a clean rebuild.
    """
    present: Set[str] = set(files)
    expected: Set[str] = source_page_outputs(sources)
    names: Set[str] = {posixpath.basename(s) for s in sources}
    problems: List[str] = []

    for page in sorted(expected - present):
        problems.append(f"missing page: {page}")
    for page in sorted(present - expected - set(GENERATED_PAGES)):
        if page.endswith(".html"):
            problems.append(f"unexpected page: {page}")
    for rel in sorted(present):
        if rel.startswith("_images/") or rel.startswith("_downloads/"):
            if posixpath.basename(rel) not in names:
                problems.append(f"unjustified image: {rel}")
    return problems


def sphinx_build(all_pages: bool = False) -> bool:
    """Run `sphinx-build -b html docs docs/_build/html`.  True on success.

    The output directory is left in place: the caller chooses between the
    incremental path (reuse it and sweep what the removed sources left) and the
    clean path (`clean_build` removes it first).  `all_pages` adds `-a`, which
    rewrites every page from the current environment -- needed when the
    navigation moved, because Sphinx only rewrites the pages it re-read.
    """
    cmd = sphinx_build_cmd()
    if cmd is None:
        print("note: sphinx-build not on PATH; keeping the existing spec")
        return False
    if all_pages:
        cmd = cmd + ["-a"]
    result = sh(cmd + [str(DOCS), str(BUILD)])
    if result.returncode != 0:
        print(f"note: sphinx-build failed ({result.returncode}); "
              f"keeping the existing spec", file=sys.stderr)
        return False
    return True


def clean_build() -> bool:
    """Remove the build directory and rebuild the whole site from scratch."""
    shutil.rmtree(BUILD, ignore_errors=True)
    return sphinx_build()


def touch_sources(sources: Iterable[str]) -> None:
    """Give the changed sources a current mtime, so Sphinx re-reads them.

    Sphinx decides what to re-read by comparing the source mtime with its
    doctree's.  A source whose content changed but whose timestamp did not (a
    restore or a copy that preserves times) would be served from its stale
    doctree; refreshing the mtime makes that decision follow the content.
    """
    for rel in sorted(sources):
        try:
            os.utime(DOCS / rel, None)
        except OSError:
            pass


def sweep_stale_outputs(removed: Iterable[str]) -> None:
    """Delete what the removed sources left in the build directory."""
    paths, names = stale_source_outputs(removed)
    for rel in paths:
        try:
            (BUILD / rel).unlink()
        except OSError:
            pass
    if not names:
        return
    wanted = set(names)
    downloads = BUILD / "_downloads"
    if downloads.is_dir():
        for path in downloads.rglob("*"):
            if path.is_file() and path.name in wanted:
                try:
                    path.unlink()
                except OSError:
                    pass


def _prune_empty_dirs(root: Path) -> None:
    """Remove the directories a sweep emptied, deepest first."""
    if not root.is_dir():
        return
    for path in sorted(root.rglob("*"), key=lambda p: len(p.parts),
                      reverse=True):
        if path.is_dir():
            try:
                path.rmdir()
            except OSError:
                pass


def ensure_build(fresh: bool = False) -> bool:
    """Make docs/_build/html the faithful build of the current docs sources.

    An unchanged tree (recorded fingerprint, digests and output list) skips
    Sphinx completely.  A changed one is rebuilt incrementally: the changed
    sources' mtimes are refreshed, Sphinx re-reads them, the removed sources'
    outputs are swept, and the page set is checked against the sources.  A
    navigation change (a page added or removed, or a toctree'd source edited)
    rewrites every page, so the sidebar of every page follows the new toctree.
    `fresh` forces the clean rebuild, and a check failure falls back to it, so
    the build directory stays a pure function of `docs/` exactly as the clean
    path guarantees.  True when a usable build directory exists afterwards
    (Sphinx missing is not an error: the committed spec stays in place).
    """
    digests = docs_source_digests()
    fingerprint = tree_fingerprint(digests)
    if not fresh and build_is_current(fingerprint, digests):
        return True

    stamp = read_stamp()
    reusable = (
        not fresh
        and stamp is not None
        and stamp.digests is not None
        and BUILD.is_dir()
    )
    if not reusable:
        ok = clean_build()
    else:
        previous = stamp.digests
        changed = changed_sources(digests, previous)
        moved_pages = {rel for rel in set(digests) ^ set(previous)
                       if is_page_source(rel)}
        nav_moved = bool((changed & toctree_sources()) or moved_pages)
        touch_sources(changed)
        ok = sphinx_build(all_pages=nav_moved)
        if ok:
            sweep_stale_outputs(removed_sources(digests, previous))
            _prune_empty_dirs(BUILD)
            problems = build_problems(_build_relative_paths(), digests)
            if problems:
                print(f"note: incremental docs build incomplete "
                      f"({problems[0]}); rebuilding clean", file=sys.stderr)
                ok = clean_build()

    if not ok:
        return BUILD.is_dir()
    write_stamp(fingerprint, digests)
    return True


def postprocess_page(html: str) -> str:
    """Make one built page fully offline: drop the _sources/font footer links
    and replace the PNG screenshots with notes.  Sphinx's search scripts and
    search box are kept, so search works offline.  Non-ASCII glyphs are
    emitted as raw UTF-8 bytes by the Ada generator."""
    html = _DROP_SOURCE_LINK.sub("", html)
    html = _DROP_FURO_CREDIT.sub("", html)

    def img_repl(match: "re.Match[str]") -> str:
        alt_m = re.search(r'alt="([^"]*)"', match.group(0))
        alt = alt_m.group(1) if alt_m else "screenshot"
        return f'<em>{alt} -- see the online manual for the image.</em>'

    html = _IMG_IMAGES.sub(img_repl, html)
    return html


def collect_assets(build: Path) -> List[Tuple[str, str, str]]:
    """Return [(path, mime, body), ...] for every bundled asset of the build.

    The _downloads/ badge SVGs are deliberately bundled (the badges page links
    them); Sphinx's search machinery and the search page are bundled too, so
    search works offline exactly as online.  The .doctrees/, _sources/,
    _images/, .buildinfo and objects.inv side-cars are excluded (their
    references are stripped or they carry no served HTML).  Every HTML page
    is post-processed so the offline manual behaves like the online one.
    """
    assets: List[Tuple[str, str, str]] = []
    variants: Dict[str, int] = {}
    for path in sorted(build.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(build).as_posix()
        if any(rel.startswith(p) for p in OFFLINE_EXCLUDED_PREFIXES):
            # The SVG images under _images/ (badge previews) are the one
            # exception: they are text and compress like any other asset.
            if not (rel.startswith(_IMAGES_PREFIX)
                    and rel.endswith(_IMAGES_BUNDLED_SUFFIX)):
                continue
        mime = _MIME.get(path.suffix.lower())
        if mime is None:
            continue
        try:
            body = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            # Binary file with a text extension (should not happen): skip.
            continue
        if mime == "text/html":
            body = postprocess_page(body)
            span = _sidebar_span(body)
            if span is not None:
                body = (body[:span[0]]
                        + _nav_stub(_sidebar_inner(body, span), rel, variants)
                        + body[span[1]:])
        assets.append((rel, mime, body))

    if not assets:
        raise RuntimeError("no assets collected from the sphinx build")
    assets.extend(_nav_assets(variants))
    return assets


def _sidebar_inner(html: str, span: Tuple[int, int]) -> str:
    """The inner markup of the sidebar element, its container excluded.

    `_sidebar_span` covers the whole `<div class="sidebar-container">`
    element.  Only its contents are shared: the stub keeps the container
    element itself, so the injected tree lands inside it instead of nesting a
    second container.  A nested `.sidebar-container` collapses the sticky
    element's containing block to its own 100vh height, which leaves
    `position: sticky` no room to move -- the sidebar then scrolls away with
    the page and loses Furo's independent scrollbar.
    """
    start, end = span
    return html[start + len(_SIDEBAR_START):end - len("</div>")]


def _tokenize(line: str) -> List[object]:
    """Split a source line into ASCII runs and non-ASCII/control characters.

    Each non-ASCII/control character becomes its UTF-8 byte list; the Ada
    generator emits those bytes via Character'Val so the Ada source stays pure
    ASCII while the served bytes stay faithful (no HTML-entity corruption of
    the bundled JavaScript/CSS).
    """
    tokens: List[object] = []
    buf: List[str] = []
    for ch in line:
        o = ord(ch)
        if o < 32 or o == 127 or o > 126:
            if buf:
                tokens.append("".join(buf))
                buf = []
            tokens.append(list(ch.encode("utf-8")))
        else:
            buf.append(ch)
    if buf:
        tokens.append("".join(buf))
    return tokens


def _asset_body_lines(body: str) -> List[str]:
    """The Ada concatenation operands for one asset body.

    Ada string literals cannot span physical lines, so the body is emitted one
    literal per source line (ASCII runs), with control and non-ASCII glyphs as
    Character'Val byte runs; source lines are joined with `& ASCII.LF` so the
    embedded newlines stay faithful.  The final trailing newline is dropped.
    Each returned operand is bare (no leading spaces, no `& `) -- the caller
    adds the indentation and the `& ` chain prefix.
    """
    body_lines: List[str] = body.split("\n")
    if body_lines and body_lines[-1] == "":
        body_lines.pop()
    lines: List[str] = []
    for bl in body_lines:
        tokens: List[object] = _tokenize(bl) or [""]
        for token in tokens:
            if isinstance(token, str):
                # Chunk long runs (inline SVG templates etc.) so every Ada
                # literal stays under the -gnatyM line-length limit.
                pieces = [token[i:i + 76]
                          for i in range(0, len(token), 76)] or [""]
                for piece in pieces:
                    lines.append('"' + piece.replace('"', '""') + '"')
            else:
                for byte in token:
                    lines.append(f"Character'Val({byte})")
        lines.append("ASCII.LF")
    if lines and lines[-1] == "ASCII.LF":
        lines.pop()  # no trailing newline after the final line
    if not lines:
        # An empty asset body (for example Furo's zero-byte
        # furo-extensions.js) still needs one operand for the constant.
        lines.append('""')
    return lines


def _gzip(data: bytes) -> bytes:
    """gzip (RFC 1952 wrapper) compress a byte string, max compression."""
    c = zlib.compressobj(9, zlib.DEFLATED, 16 + zlib.MAX_WBITS)
    return c.compress(data) + c.flush()


def _b85_chunks(body: str) -> List[str]:
    """The base85 Ada bodies for one asset: gzip the text, split the compressed
    bytes into MAX_CHUNK_BYTES-sized chunks, and base85-encode each chunk.
    Returns at least one chunk (an empty asset gzips to a non-empty header).
    """
    gz = _gzip(body.encode("utf-8"))
    return [
        _b85_encode(gz[i:i + MAX_CHUNK_BYTES])
        for i in range(0, len(gz), MAX_CHUNK_BYTES)
    ]


def _body_hash(body: str) -> str:
    """SHA-256 of one asset body: the encode-cache key."""
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def _cached_chunks(digest: str) -> Optional[List[str]]:
    """The encoded chunks stored for `digest`, or None when not cached.

    The base85 alphabet has no newline, so the chunks round-trip as
    newline-separated text and the cache file is pure ASCII.
    """
    path: Path = ENCODE_CACHE / (digest + _CACHE_SUFFIX)
    if not path.is_file():
        return None
    try:
        text: str = path.read_text(encoding="ascii")
    except OSError:
        return None
    return text.split("\n") if text else None


def _store_cached_chunks(digest: str, chunks: List[str]) -> None:
    """Write one cache entry; a cache failure never fails the build."""
    try:
        ENCODE_CACHE.mkdir(parents=True, exist_ok=True)
        (ENCODE_CACHE / (digest + _CACHE_SUFFIX)).write_text(
            "\n".join(chunks), encoding="ascii")
    except OSError:
        pass


def _prune_cache(keep: Set[str]) -> None:
    """Delete cache entries the current bundle no longer references."""
    try:
        entries: List[Path] = list(ENCODE_CACHE.glob("*" + _CACHE_SUFFIX))
    except OSError:
        return
    for path in entries:
        if path.name[:-len(_CACHE_SUFFIX)] not in keep:
            try:
                path.unlink()
            except OSError:
                pass


def default_jobs() -> int:
    """Encoder worker count (capped at MAX_ENCODE_JOBS, never below one)."""
    return max(1, min(os.cpu_count() or 1, MAX_ENCODE_JOBS))


def _encode_bodies(bodies: List[str], jobs: int) -> List[List[str]]:
    """gzip+base85 every body, in order, across up to `jobs` processes.

    The result is byte-identical to the serial encode: each body is encoded
    independently and the list keeps the input order.  The pool is only a
    speed-up, so any failure (a worker that cannot start, for example) falls
    back to the serial path rather than failing the build.
    """
    if jobs <= 1 or len(bodies) < 2:
        return [_b85_chunks(body) for body in bodies]
    try:
        with concurrent.futures.ProcessPoolExecutor(max_workers=jobs) as pool:
            return list(pool.map(_b85_chunks, bodies, chunksize=1))
    except (OSError, RuntimeError, ValueError):
        return [_b85_chunks(body) for body in bodies]


def encode_assets(
    assets: List[Tuple[str, str, str]],
    jobs: Optional[int] = None,
) -> List[Tuple[str, str, List[str]]]:
    """Return [(path, mime, [base85 chunk, ...]), ...] for every asset.

    Each body's gzip+base85 result is cached by SHA-256, so a docs edit
    re-encodes only the pages it touched; the uncached bodies are encoded in
    parallel.  The cache is pruned to the hashes present in this bundle, so
    it never grows without bound.
    """
    if jobs is None:
        jobs = default_jobs()
    digests: List[str] = [_body_hash(body) for _, _, body in assets]
    plans: List[Optional[List[str]]] = [None] * len(assets)
    pending: List[int] = []
    for index, digest in enumerate(digests):
        cached: Optional[List[str]] = _cached_chunks(digest)
        if cached:
            plans[index] = cached
        else:
            pending.append(index)
    if pending:
        encoded: List[List[str]] = _encode_bodies(
            [assets[i][2] for i in pending], jobs)
        for index, chunks in zip(pending, encoded):
            plans[index] = chunks
            _store_cached_chunks(digests[index], chunks)
    _prune_cache(set(digests))
    return [(assets[i][0], assets[i][1], plans[i] or [""])
            for i in range(len(assets))]


def _sidebar_span(html: str) -> Optional[Tuple[int, int]]:
    """The [start, end) span of the Furo sidebar element, or None.

    The span is found by counting the nested `<div>` elements, so it covers
    the whole `<div class="sidebar-container">` element however Furo nests
    its contents (a regex cannot, and a wrong span would corrupt the page).
    """
    start: int = html.find(_SIDEBAR_START)
    if start < 0:
        return None
    depth: int = 0
    at: int = start
    while True:
        open_at: int = html.find("<div", at)
        close_at: int = html.find("</div>", at)
        if close_at < 0:
            return None
        if 0 <= open_at < close_at:
            depth += 1
            at = open_at + 4
        else:
            depth -= 1
            at = close_at + 6
            if depth == 0:
                return start, at
        if at > len(html):
            return None


_NAV_ATTR = re.compile(r'\b(href|src|action)="([^"]*)"')
_NAV_CLASS = re.compile(r'\bclass="([^"]*)"')
#  The current page's own entry: Furo gives it `href="#"` inside the one
#  `current-page` list item, and the stored tree carries that page's real
#  path there instead (see _nav_variant).
_NAV_SELF = re.compile(
    r'(<li class="[^"]*current-page[^"]*">\s*<a class="[^"]*" href=")#(")')
_NAV_EXTERNAL = ("http://", "https://", "mailto:", "data:", "javascript:",
                 "tel:", "//")
_NAV_CURRENT = ("current", "current-page")


def _nav_variant(block: str, page_rel: str) -> str:
    """The page-independent form of one page's sidebar.

    Two normalisations make the toctree of 191 pages collapse into the
    handful of distinct trees it really is.  The current-page highlight
    classes are dropped and the current page's own entry -- the single
    `href="#"` Furo renders for it -- gets that page's path back, so the
    stored tree is the tree every page of the same branch renders, no matter
    which entry is the open one (resources/js/book-nav.js re-adds the highlight
    for the page that is actually open).  The later rebase must not see the
    restored path, so the path is written after the rebase, not before.

    Every href, src, and action is rebased onto `_nav/`, the directory the
    stored tree is fetched from and the base the injected markup needs.
    """
    page_dir: str = posixpath.dirname(page_rel)

    def rebase(match: "re.Match[str]") -> str:
        url: str = match.group(2)
        if not url or url.startswith("#") or url.startswith(_NAV_EXTERNAL):
            return match.group(0)
        target: str = url.split("#", 1)[0]
        fragment: str = url[len(target):]
        if target.startswith("/"):
            build_rel: str = posixpath.normpath(target.lstrip("/"))
        else:
            build_rel = posixpath.normpath(posixpath.join(page_dir, target))
        return '%s="%s%s"' % (match.group(1),
                               posixpath.relpath(build_rel, NAV_DIR), fragment)

    block = _NAV_ATTR.sub(rebase, block)
    own: str = posixpath.relpath(posixpath.normpath(page_rel), NAV_DIR)
    block = _NAV_SELF.sub(lambda m: m.group(1) + own + m.group(2), block,
                          count=1)
    return _NAV_CLASS.sub(
        lambda m: '%s"%s"' % (_TAG_CLASS, " ".join(
            t for t in m.group(1).split() if t not in _NAV_CURRENT)),
        block)


def _nav_stub(block: str, page_rel: str, variants: Dict[str, int]) -> str:
    """The stub that replaces the *contents* of one page's sidebar: the
    variant index plus the deferred script that fills it in.

    `block` is the container's inner markup (see `_sidebar_inner`), never the
    container element itself.  The stub keeps a single
    `<div class="sidebar-container">`, so the injected tree is its direct
    child exactly as Furo renders it -- the sticky element then keeps the
    flex-stretched container as its containing block and scrolls
    independently (see resources/js/book-nav.js).
    """
    key: str = _nav_variant(block, page_rel)
    if key not in variants:
        variants[key] = len(variants)
    depth: int = page_rel.count("/")
    src: str = "../" * depth + NAV_SCRIPT
    return (f'<div class="sidebar-container" data-nav="{variants[key]}">'
            f'<script defer src="{src}"></script></div>')


def _nav_assets(variants: Dict[str, int]) -> List[Tuple[str, str, str]]:
    """The shared sidebar variants and the script that injects them."""
    assets: List[Tuple[str, str, str]] = [
        (f"{NAV_DIR}/{index}.html", "text/html", key)
        for key, index in sorted(variants.items(), key=lambda kv: kv[1])
    ]
    try:
        script: str = NAV_SCRIPT_SRC.read_text(encoding="utf-8")
    except OSError as exc:
        raise RuntimeError(f"cannot read {NAV_SCRIPT_SRC}: {exc}")
    assets.append((NAV_SCRIPT, "application/javascript", script))
    return assets


def build_spec(jobs: Optional[int] = None,
               fresh: bool = False) -> Tuple[str, str]:
    """Build the manual and return (Ada spec text, human-readable stats).

    Sphinx runs only when the docs sources changed since the last build (the
    fingerprint stamp); an unchanged tree reuses the build directory, and a
    changed one is rebuilt incrementally and verified (`ensure_build`).  No
    file is written here, so the caller can both write the spec and check it
    (without mutating the committed file).  `jobs` caps the encoder worker
    processes (None picks the default); `fresh` forces a clean Sphinx build.
    """
    if not ensure_build(fresh):
        raise RuntimeError(
            "sphinx-build not on PATH and no docs/_build/html")

    assets = collect_assets(BUILD)

    # Every asset body is gzip-compressed and base85-encoded into one or more
    # chunks; each chunk becomes its own `Asset_NNN` constant.  Sphinx pages
    # reuse the same stylesheets and scripts, so gzip collapses that
    # redundancy -- the generated spec is ~1/7th the size of the old
    # verbatim-per-line encoding -- and the server sends the compressed bytes
    # with `Content-Encoding: gzip` for browsers to inflate.  The encode is
    # cached per body and parallel across cores (encode_assets), so a run
    # after a small docs edit re-encodes only the pages it touched.
    # plan = [(rel, mime, [base85 chunk, ...]), ...].
    plan: List[Tuple[str, str, List[str]]] = encode_assets(assets, jobs)
    body_count: int = sum(len(chunks) for _, _, chunks in plan)
    chunked_at: List[Tuple[int, int]] = [  # (table index, chunk count)
        (i + 1, len(chunks))
        for i, (_, _, chunks) in enumerate(plan) if len(chunks) > 1
    ]

    header = (
        "--  Generated by tools/gen-docs.py from the Sphinx manual (docs/):\n"
        "--  the whole built site (pages, stylesheets, scripts, badges, search)\n"
        "--  as a gzip-compressed, base85-encoded offline asset blob + lookup\n"
        "--  table. --serve exposes it at /docs/ with Content-Encoding: gzip\n"
        "--  (the browser inflates it). The shared sidebar variants live\n"
        "--  under _nav/ and are filled in by _static/adacovex-nav.js. Do not\n"
        "--  edit by hand; edit docs/ and run make book.\n"
    )
    lines: List[str] = header.splitlines()
    lines.append("package Adacovex.Docs_Template is")
    lines.append("")
    lines.append("   --  One entry of the lookup table. The path and MIME type")
    lines.append("   --  are fixed-size (space-padded) strings; Idx selects the")
    lines.append("   --  first body of the asset via Asset_Bodies; Gzip says the")
    lines.append("   --  body holds base85 gzip bytes served with Content-Encoding:")
    lines.append("   --  gzip. Fixed-size components keep the aggregate a plain")
    lines.append("   --  static constant (a discriminated-record array is")
    lines.append("   --  dynamically elaborated by GNAT and blows the heap).")
    lines.append("   Max_Path : constant := 80;")
    lines.append("   Max_Mime : constant := 32;")
    lines.append(f"   Asset_Count : constant := {len(plan)};")
    lines.append("   subtype Asset_Index is Positive range 1 .. Asset_Count;")
    lines.append(f"   Body_Count : constant := {body_count};")
    lines.append("   subtype Body_Index is Positive range 1 .. Body_Count;")
    lines.append("   type Asset_Ref is")
    lines.append("      record")
    lines.append("         Path  : String (1 .. Max_Path) := (others => ' ');")
    lines.append("         Mime  : String (1 .. Max_Mime) := (others => ' ');")
    lines.append("         Idx   : Body_Index;")
    lines.append("         Gzip  : Boolean;")
    lines.append("      end record;")
    lines.append("")
    lines.append("   type Asset_Table is array (Positive range <>) of Asset_Ref;")
    lines.append("")
    lines.append("   --  Every asset body (or compressed chunk) as its own")
    lines.append("   --  static constant of base64 text. One constant per body")
    lines.append("   --  keeps each string small: a single multi-megabyte blob")
    lines.append("   --  constant overflows the gnatprove frontend stack")
    lines.append("   --  (Storage_Error) whatever its structure, so the bodies are")
    lines.append("   --  never concatenated into one value.")
    body_idx: int = 0
    for rel, mime, chunks in plan:
        for chunk in chunks:
            lines.append(f"   Asset_{body_idx:03d} : aliased constant String :=")
            asset_lines = _asset_body_lines(chunk)
            for ei, al in enumerate(asset_lines):
                prefix = "       " if ei == 0 else "       & "
                lines.append(prefix + al.strip())
            lines.append("       ;")
            lines.append("")
            body_idx += 1
    lines.append("   type Asset_Body is access constant String;")
    lines.append("")
    lines.append("   --  The bodies in emission order: Asset_NNN'Access.")
    lines.append("   Asset_Bodies : constant array (Body_Index) of Asset_Body :=\n     (")
    for b in range(body_count):
        end_ref = ");" if b == body_count - 1 else ","
        lines.append(f"      Asset_{b:03d}'Access{end_ref}")
    lines.append("")
    lines.append("   --  How many bodies a table asset spans. Every asset spans")
    lines.append("   --  one body except the oversized ones (for example the search")
    lines.append("   --  index), which are chunked so each constant stays under the")
    lines.append("   --  gnatprove limit.")
    if chunked_at:
        overrides = ", ".join(f"{k} => {n}" for k, n in chunked_at)
        lines.append("   Chunk_Count : constant array (Asset_Index) of Natural :=")
        lines.append(f"     ({overrides}, others => 1);")
    else:
        lines.append("   Chunk_Count : constant array (Asset_Index) of Natural :=")
        lines.append("     (others => 1);")
    lines.append("")
    lines.append("   --  The whole offline manual, keyed by book-relative path")
    lines.append("   --  (for example \"index.html\" or \"_static/styles/furo.css\").")
    lines.append("   Assets : constant Asset_Table :=")
    cum: int = 0
    for i, (rel, mime, chunks) in enumerate(plan):
        # The line template closes the Asset_Ref' qualified aggregate with
        # `)`; end_ref closes the array aggregate for the final ref.
        end_ref = ");" if i == len(plan) - 1 else ","
        if len(rel) > 80 or len(mime) > 32:
            raise RuntimeError(f"asset {rel!r} exceeds fixed-size bounds")
        pad_path = rel.ljust(80)
        pad_mime = mime.ljust(32)
        lines.append("     (Asset_Ref'" if i == 0 else "      Asset_Ref'")
        lines.append(f'        (Path  => "{pad_path}",')
        lines.append(f'         Mime  => "{pad_mime}",')
        lines.append(f"         Idx   => {cum + 1},")
        lines.append(f"         Gzip  => True){end_ref}")
        cum += len(chunks)
    lines.append("")
    lines.append("   --  The decoded bytes of one body: base64-decoded (the gzip")
    lines.append("   --  stream, served with Content-Encoding: gzip) when Is_Gzip,")
    lines.append("   --  otherwise the body verbatim. The server streams one chunk")
    lines.append("   --  at a time, so no worker ever materialises a multi-megabyte")
    lines.append("   --  body.")
    lines.append("   function Body_Bytes (B : Body_Index; Is_Gzip : Boolean)")
    lines.append("     return String;")
    lines.append("")
    lines.append("   --  The decoded first body of a table asset (its only body for")
    lines.append("   --  every asset unless a compressed chunk split it).")
    lines.append("   function Content (Idx : Asset_Index) return String;")
    lines.append("")
    lines.append("   --  Find the asset for a request subpath. Normalises:")
    lines.append('   --  "" and "/" map to index.html, a trailing slash appends')
    lines.append("   --  index.html, and an extensionless leaf tries leaf.html")
    lines.append("   --  then leaf/index.html. Returns 0 when absent.")
    lines.append("")
    lines.append("   function Find (Subpath : String) return Natural;")
    lines.append("")
    lines.append("end Adacovex.Docs_Template;")
    content: str = "\n".join(lines) + "\n"
    total = sum(len(b) for _, _, b in assets)
    # The emitted bodies are base85 text, so this is the encoded size, not the
    # gzip size (base85 costs 1.25 characters per compressed byte, base64
    # costs 1.333).
    encoded = sum(len(c) for _, _, chunks in plan for c in chunks)
    stats = (f"{len(plan)} assets, {body_count} bodies, "
             f"{encoded} base85 bytes, {total} original bytes")
    return content, stats


def generate(out: Path, jobs: Optional[int] = None,
             fresh: bool = False) -> None:
    """Build the manual and write the spec, but only when it changed.

    An unconditional rewrite bumps the mtime of this 28k-line spec and makes
    `alr build` recompile it (and relink) on every run -- and a content change
    here also invalidates the cached SPARK proof.  Skipping the write on a
    no-op run keeps both the incremental build and the prove cache warm.
    """
    content, stats = build_spec(jobs, fresh)
    existing: Optional[str] = (
        out.read_text(encoding="ascii") if out.is_file() else None)
    if existing == content:
        print(f"{out.name} up to date ({stats}).")
    else:
        out.write_text(content, encoding="ascii")
        print(f"{out.name} regenerated ({stats}).")


def check(out: Path, jobs: Optional[int] = None,
          fresh: bool = False) -> bool:
    """True when the committed spec matches a fresh build; never writes."""
    content, stats = build_spec(jobs, fresh)
    existing: Optional[str] = (
        out.read_text(encoding="ascii") if out.is_file() else None)
    if existing == content:
        print(f"{out.name} is up to date ({stats}).")
        return True
    print(f"error: {out.name} is stale -- run tools/gen-docs.py (or make book)",
          file=sys.stderr)
    return False


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="verify the committed spec is current")
    parser.add_argument("--out", default=str(OUT), help="output Ada spec path")
    parser.add_argument(
        "--jobs", type=int, default=None,
        help="encoder worker processes (default: the CPU count, capped at 8)")
    parser.add_argument(
        "--fresh", action="store_true",
        help="rebuild the Sphinx site from scratch instead of reusing the "
             "incremental build directory")
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    out: Path = Path(args.out).resolve()
    try:
        if args.check:
            return 0 if check(out, args.jobs, args.fresh) else 1
        generate(out, args.jobs, args.fresh)
        return 0
    except RuntimeError as e:
        # Keep the previously committed spec; the build must not fail when the
        # docs toolchain is missing.
        print(f"note: {e}; keeping existing {out.name}")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))