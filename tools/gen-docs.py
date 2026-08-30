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
     becomes a short note (the images stay in the online book);
   * Sphinx's `.doctrees/`, `.buildinfo` and `objects.inv` side-car files
     are not served pages and are not bundled;
   * every remaining non-ASCII glyph (for example the paragraph-sign
     headerlinks Sphinx adds) is escaped as an HTML character reference so
     the Ada source stays pure ASCII;

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
   compressed chunk, base64-encoded so the Ada source stays pure ASCII.
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

Usage:
  python3 tools/gen-docs.py [--check] [--out=PATH]

--check    Verify the generated spec matches the current resources; exit 1 on
           mismatch (used by CI so the committed file never goes stale).
--out      Output Ada spec path (default: src/adacovex-docs_template.ads).

Exit code 0 on success, 1 on a missing tool/build or a --check mismatch.  When
sphinx-build is not resolvable (neither on PATH nor in the repo's `.venv`)
the previously committed spec is left in place and a note is printed -- the
spec is authored to build without it.
"""

import argparse
import base64
import re
import shutil
import subprocess
import sys
import zlib
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
DOCS: Path = ROOT / "docs"
BUILD: Path = DOCS / "_build" / "html"   # sphinx html build output (gitignored)
OUT: Path = ROOT / "src" / "adacovex-docs_template.ads"

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
# subpage, _images/... on the index).
_IMG_IMAGES = re.compile(r"<img[^>]*src=\"(?:\\.\\./)*_images/[^\"]+\"[^>]*>")

_MIME: Dict[str, str] = {
    ".html": "text/html",
    ".css": "text/css",
    ".js": "application/javascript",
    ".svg": "image/svg+xml",
}

# Max compressed bytes stored in one emitted Ada string constant.  gzip is
# applied at build time (see below), then each compressed chunk is base64-
# encoded, so the Ada literal for one chunk is ~4/3 of its compressed size.
# The gnatprove frontend blows its stack on a single constant over ~1 MB
# (whatever its structure), so every chunk -- and its base64 expansion --
# stays well under it.
MAX_CHUNK_BYTES: int = 300_000


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


def sphinx_build() -> bool:
    """Run `sphinx-build -b html docs docs/_build/html`.  True on success."""
    cmd = sphinx_build_cmd()
    if cmd is None:
        print("note: sphinx-build not on PATH; keeping the existing spec")
        return False
    result = sh(cmd + [str(DOCS), str(BUILD)])
    if result.returncode != 0:
        print(f"note: sphinx-build failed ({result.returncode}); "
              f"keeping the existing spec", file=sys.stderr)
        return False
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
    for path in sorted(build.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(build).as_posix()
        if any(rel.startswith(p) for p in OFFLINE_EXCLUDED_PREFIXES):
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
        assets.append((rel, mime, body))

    if not assets:
        raise RuntimeError("no assets collected from the sphinx build")
    return assets


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


def _b64_chunks(body: str) -> List[str]:
    """The base64 Ada bodies for one asset: gzip the text, split the compressed
    bytes into MAX_CHUNK_BYTES-sized chunks, and base64-encode each chunk.
    Returns at least one chunk (an empty asset gzips to a non-empty header).
    """
    gz = _gzip(body.encode("utf-8"))
    return [
        base64.b64encode(gz[i:i + MAX_CHUNK_BYTES]).decode("ascii")
        for i in range(0, len(gz), MAX_CHUNK_BYTES)
    ]


def generate(out: Path) -> None:
    """Build the manual (or keep the existing spec when sphinx-build is
    missing) and write the Ada spec."""
    if not sphinx_build() and not BUILD.is_dir():
        raise RuntimeError("sphinx-build not on PATH and no docs/_build/html")

    assets = collect_assets(BUILD)

    # Every asset body is gzip-compressed and base64-encoded into one or more
    # chunks; each chunk becomes its own `Asset_NNN` constant.  Sphinx pages
    # reuse the same stylesheets and scripts, so gzip collapses that
    # redundancy -- the generated spec is ~1/7th the size of the old
    # verbatim-per-line encoding -- and the server sends the compressed bytes
    # with `Content-Encoding: gzip` for browsers to inflate.
    # plan = [(rel, mime, [base64 chunk, ...]), ...].
    plan: List[Tuple[str, str, List[str]]] = [
        (rel, mime, _b64_chunks(body)) for rel, mime, body in assets
    ]
    body_count: int = sum(len(chunks) for _, _, chunks in plan)
    chunked_at: List[Tuple[int, int]] = [  # (table index, chunk count)
        (i + 1, len(chunks))
        for i, (_, _, chunks) in enumerate(plan) if len(chunks) > 1
    ]

    header = (
        "--  Generated by tools/gen-docs.py from the Sphinx manual (docs/):\n"
        "--  the whole built site (pages, stylesheets, scripts, badges, search)\n"
        "--  as a gzip-compressed, base64-encoded offline asset blob + lookup\n"
        "--  table.  --serve exposes it at /docs/ with Content-Encoding: gzip\n"
        "--  (the browser inflates it).  Do not edit by hand; edit docs/ and\n"
        "--  run make book.\n"
    )
    lines: List[str] = header.splitlines()
    lines.append("package Adacovex.Docs_Template is")
    lines.append("")
    lines.append("   --  One entry of the lookup table.  The path and MIME type")
    lines.append("   --  are fixed-size (space-padded) strings; Idx selects the")
    lines.append("   --  first body of the asset via Asset_Bodies; Gzip says the")
    lines.append("   --  body holds base64 gzip bytes served with Content-Encoding:")
    lines.append("   --  gzip.  Fixed-size components keep the aggregate a plain")
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
    lines.append("   --  static constant of base64 text.  One constant per body")
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
    lines.append("   --  How many bodies a table asset spans.  Every asset spans")
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
    lines.append("   --  otherwise the body verbatim.  The server streams one chunk")
    lines.append("   --  at a time, so no worker ever materialises a multi-megabyte")
    lines.append("   --  body.")
    lines.append("   function Body_Bytes (B : Body_Index; Is_Gzip : Boolean)")
    lines.append("     return String;")
    lines.append("")
    lines.append("   --  The decoded first body of a table asset (its only body for")
    lines.append("   --  every asset unless a compressed chunk split it).")
    lines.append("   function Content (Idx : Asset_Index) return String;")
    lines.append("")
    lines.append("   --  Find the asset for a request subpath.  Normalises:")
    lines.append('   --  "" and "/" map to index.html, a trailing slash appends')
    lines.append("   --  index.html, and an extensionless leaf tries leaf.html")
    lines.append("   --  then leaf/index.html.  Returns 0 when absent.")
    lines.append("")
    lines.append("   function Find (Subpath : String) return Natural;")
    lines.append("")
    lines.append("end Adacovex.Docs_Template;")
    out.write_text("\n".join(lines) + "\n", encoding="ascii")
    total = sum(len(b) for _, _, b in assets)
    gz_total = sum(len(c) for _, _, chunks in plan for c in chunks)
    print(f"{out.name} regenerated ({len(plan)} assets, {body_count} bodies, "
          f"{gz_total} compressed bytes, {total} original bytes).")


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="verify the committed spec is current")
    parser.add_argument("--out", default=str(OUT), help="output Ada spec path")
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    out: Path = Path(args.out).resolve()
    before: Optional[str] = out.read_text(encoding="ascii") if out.is_file() else None
    try:
        generate(out)
    except RuntimeError as e:
        # Keep the previously committed spec; the build must not fail when the
        # docs toolchain is missing.
        print(f"note: {e}; keeping existing {out.name}")
        return 0
    if not args.check:
        return 0
    after: str = out.read_text(encoding="ascii")
    if before is not None and before == after:
        print(f"{out.name} is up to date.")
        return 0
    print(f"error: {out.name} is stale -- run tools/gen-docs.py (or make book)",
          file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))