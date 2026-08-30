#!/usr/bin/env python3
"""Build the mdBook manual and bundle the whole built site into the binary.

The manual source is the mdBook project at `docs/` (read the `.readthedocs.yaml`
dependency: the same book powers the Read the Docs site).  This script:

1. runs `mdbook build docs` (when mdbook is on PATH; the build output lands
   in `docs/book/`, a local, gitignored build product -- the committed
   artifact is the generated spec below), then
2. collects the built site into an offline asset set -- every HTML page, the
   stylesheets, the local scripts (theme, toc, clipboard, highlight.js), and
   mdbook's client-side search machinery (elasticlunr, searcher, mark, and the
   search index) -- and post-processes each page so the offline manual works
   with no network:

   * the font stylesheet and woff2 files are dropped (system fonts are used);
   * the binary favicon is dropped (the SVG favicon is kept);
   * the PNG dashboard screenshots are dropped and each `<img>` becomes a
     short note (the images stay in the online book);
   * every remaining non-ASCII glyph is escaped as an HTML character
     reference so the Ada source stays pure ASCII;

   mdbook's own search stays fully functional in the bundle: the search
   assets are bundled and the search box is left visible.  The search index
   is a multi-MB single line, far past the ~1 MB per-constant limit of the
   gnatprove frontend, so it is split into fixed-size chunks, each its own
   Ada constant, and the server streams the chunks back as one response when
   the page requests the index.  The index's content-hashed filename
   (`searchindex-<hash>.js`) is normalised to a stable `searchindex.js` --
   the asset and every page's reference -- so a docs edit no longer renames
   the file and each build just overwrites the same entry.  The single-page
   print view (`print.html`), which mdBook's print button opens and which
   triggers `window.print()` on load, is bundled too (and chunked like the
   search index) so the offline and online manuals behave identically.
   Only the PNG favicon and the PNG dashboard screenshots are dropped (their
   links/icons are stripped from every page, and the SVG favicon is kept);
3. writes `src/adacovex-docs_template.ads` as a constant table of
   (path, MIME type, body index) assets plus one `aliased constant String`
   per asset body (bodies are never concatenated into one value: a single
   multi-megabyte string constant overflows the gnatprove frontend stack).
   `--serve` exposes the table at `/docs/` so the dashboard links carry a
   fully offline copy of the whole manual inside the binary itself.

The generated spec is committed so the tree builds without running mdbook
(the project has no mdbook/Markdown runtime dependency).  `docs/book/` itself
is a local build output (gitignored: mdBook content-hashes its assets, so a
committed build would churn `searchindex-<hash>.js` and every page reference
on each docs edit); the spec is the only committed artifact.  `make book` /
`make build` regenerate it (byte-identical when the docs are unchanged) and
`--check` fails when it drifts -- exactly the same pattern
tools/gen-dashboard.py uses.

Usage:
  python3 tools/gen-docs.py [--check] [--out=PATH]

--check    Verify the generated spec matches the current resources; exit 1 on
           mismatch (used by CI so the committed file never goes stale).
--out      Output Ada spec path (default: src/adacovex-docs_template.ads).

Exit code 0 on success, 1 on a missing tool/build or a --check mismatch.  When
mdbook is not on PATH the previously committed spec is left in place and a note
is printed -- the spec is authored to build without it.
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
DOCS: Path = ROOT / "docs"
BOOK: Path = DOCS / "book"          # mdbook default dest dir (committed)
OUT: Path = ROOT / "src" / "adacovex-docs_template.ads"

# ---------------------------------------------------------------------------
# Offline asset rules.  Shared with tools/check-book-links.py (imported), so
# the link checker knows which built-site files are deliberately not bundled.
# ---------------------------------------------------------------------------

# Path prefixes (relative to the book root) that are never bundled: binary
# fonts and the PNG screenshots.  mdbook's search machinery (elasticlunr-,
# searcher-, mark-, searchindex-) IS bundled so the manual's own search
# works offline, and the print view (print.html) is bundled so the print
# button works exactly as it does online.  The SVG favicon is bundled (the
# pages link it); only the PNG favicon is dropped (its <link> is stripped
# from every page below).  The 404 page and the dry book.toml/.nojekyll
# side-car files are not served pages.
OFFLINE_EXCLUDED_PREFIXES: Tuple[str, ...] = (
    "fonts/",
    "media/",
    "404.html",
    "book.toml",
    ".nojekyll",
)

# The font stylesheet link (the woff2 files are not bundled).  Matches the
# `fonts/...` href with any leading path_to_root (`../`) prefix, because a
# subpage links ``../fonts/fonts-...css`` while the index page links
# `fonts/fonts-...css` -- the fonts must be dropped on every page or the
# unbundled asset 404s when the offline manual navigates to a subpage.
_DROP_FONT_LINK = re.compile(
    r'<link[^>]*rel="stylesheet"[^>]*href="[^"]*fonts/[^"]+"[^>]*>')
# The binary favicon link (the SVG favicon link is kept).  The prefixed
# `favicon-` exclusion above was removed precisely so the SVG icon stays in
# the bundle; only the PNG shortcut-icon <link> is stripped, and stray PNG
# favicon assets (not referenced once that link is gone) are skipped below.
_DROP_PNG_ICON = re.compile(
    r'<link[^>]*rel="shortcut icon"[^>]*href="[^"]*favicon-[^"]+\.png"[^>]*>')
# The PNG dashboard screenshots: replaced by a short note.
_IMG_MEDIA = re.compile(r'<img[^>]*src="media/[^"]+"[^>]*>')

_MIME: Dict[str, str] = {
    ".html": "text/html",
    ".css": "text/css",
    ".js": "application/javascript",
    ".svg": "image/svg+xml",
}

# Max size of one emitted Ada string constant.  The gnatprove frontend blows
# its stack on a single constant over ~1 MB (whatever its structure), so every
# asset body -- and every chunk of the multi-MB search index -- stays well
# under it.
MAX_CONSTANT: int = 400_000


def sh(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)


def mdbook_build() -> bool:
    """Run `mdbook build docs` (output lands in docs/book).  True on success."""
    if shutil.which("mdbook") is None:
        print("note: mdbook not on PATH; keeping the existing spec")
        return False
    result = sh(["mdbook", "build", str(DOCS)])
    if result.returncode != 0:
        print(f"note: mdbook build failed ({result.returncode}); "
              f"keeping the existing spec", file=sys.stderr)
        return False
    return True


def postprocess_page(html: str) -> str:
    """Make one built page fully offline: drop fonts/binary favicon and
    replace the PNG screenshots with notes.  mdbook's search scripts and
    search box are kept, so search works offline.  Non-ASCII glyphs are
    emitted as raw UTF-8 bytes by the Ada generator."""
    html = _DROP_FONT_LINK.sub("", html)
    html = _DROP_PNG_ICON.sub("", html)

    def img_repl(match: "re.Match[str]") -> str:
        alt_m = re.search(r'alt="([^"]*)"', match.group(0))
        alt = alt_m.group(1) if alt_m else "screenshot"
        return f'<em>{alt} -- see the online manual for the image.</em>'

    html = _IMG_MEDIA.sub(img_repl, html)
    return html


def collect_assets(book: Path) -> List[Tuple[str, str, str]]:
    """Return [(path, mime, body), ...] for every bundled asset of the book.

    The PNG favicon is deliberately dropped (its <link> is stripped from
    every page by postprocess_page); the SVG favicon is kept.  Every HTML
    page -- including print.html, the single-page print view -- is
    post-processed so the offline manual behaves like the online one (the
    print button must work, so print.html is bundled, not skipped).  The
    content-hashed search index (`searchindex-<hash>.js`) is normalised to a
    stable `searchindex.js` so a build no longer churns the asset name and
    every page's reference on each docs change.
    """
    assets: List[Tuple[str, str, str]] = []
    for path in sorted(book.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(book).as_posix()
        if any(rel.startswith(p) for p in OFFLINE_EXCLUDED_PREFIXES):
            continue
        # The PNG favicon is not referenced once its <link> is stripped from
        # every page; the SVG icon stays.  The filename is content-hashed by
        # mdBook (`favicon-<hash>.png` vs `favicon-<hash>.svg`).
        if rel.startswith("favicon-") and rel.endswith(".png"):
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

    # Normalise the content-hashed search index (`searchindex-<hash>.js`) to
    # a stable name so the bundle and every page reference do not change hash
    # on each docs edit.  Rename the asset and rewrite every reference in the
    # browser-facing bodies (searcher.js default, path_to_searchindex_js
    # assignments in each page).
    hashed_index = next(
        (rel for rel, _, _ in assets if re.match(r"^searchindex-[0-9a-f]+\.js$", rel)),
        None)
    if hashed_index:
        normalised: List[Tuple[str, str, str]] = []
        for rel, mime, body in assets:
            if rel == hashed_index:
                rel = "searchindex.js"
            normalised.append(
                (rel, mime, body.replace(hashed_index, "searchindex.js")))
        assets = normalised

    if not assets:
        raise RuntimeError("no assets collected from the book build")
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
    return lines


def _split_body(body: str) -> List[str]:
    """Split one asset body into MAX_CONSTANT-size chunks (at least one)."""
    return ([body[i:i + MAX_CONSTANT]
             for i in range(0, len(body), MAX_CONSTANT)]
            or [""])


def generate(out: Path) -> None:
    """Build the book (or keep the existing spec when mdbook is missing)
    and write the Ada spec."""
    if not mdbook_build() and not BOOK.is_dir():
        raise RuntimeError("mdbook not on PATH and no docs/book present")

    assets = collect_assets(BOOK)

    # Any asset over MAX_CONSTANT (the multi-MB mdBook search index, and the
    # ~1 MB single-page print view) becomes several smaller constants; every
    # other asset is one constant.  plan = [(rel, mime, [chunk, ...]), ...].
    plan: List[Tuple[str, str, List[str]]] = []
    for rel, mime, body in assets:
        if len(body) > MAX_CONSTANT:
            plan.append((rel, mime, _split_body(body)))
        else:
            plan.append((rel, mime, [body]))
    body_count: int = sum(len(chunks) for _, _, chunks in plan)
    chunked_at: List[Tuple[int, int]] = [  # (table index, chunk count)
        (i + 1, len(chunks))
        for i, (_, _, chunks) in enumerate(plan) if len(chunks) > 1
    ]

    header = (
        "--  Generated by tools/gen-docs.py from the mdBook manual (docs/):\n"
        "--  the whole built site (pages, stylesheets, scripts, badges, search)\n"
        "--  as an offline asset blob + lookup table.  --serve exposes it at\n"
        "--  /docs/.  Do not edit by hand; edit docs/ and run make book.\n"
    )
    lines: List[str] = header.splitlines()
    lines.append("package Adacovex.Docs_Template is")
    lines.append("")
    lines.append("   --  One entry of the lookup table.  The path and MIME type")
    lines.append("   --  are fixed-size (space-padded) strings; Idx selects the")
    lines.append("   --  first body of the asset via Asset_Bodies.  Fixed-size")
    lines.append("   --  components keep the aggregate a plain static constant")
    lines.append("   --  (a discriminated-record array is dynamically elaborated")
    lines.append("   --  by GNAT and blows the heap).")
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
    lines.append("      end record;")
    lines.append("")
    lines.append("   type Asset_Table is array (Positive range <>) of Asset_Ref;")
    lines.append("")
    lines.append("   --  Every asset body (or search-index chunk) as its own")
    lines.append("   --  static constant.  One constant per body keeps each")
    lines.append("   --  string small: a single multi-megabyte blob constant")
    lines.append("   --  overflows the gnatprove frontend stack (Storage_Error)")
    lines.append("   --  whatever its structure, so the bodies are never")
    lines.append("   --  concatenated into one value.")
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
    lines.append("   --  one body except the oversized ones (the search index and")
    lines.append("   --  the single-page print view), which are chunked so each")
    lines.append("   --  constant stays under the gnatprove limit.")
    if chunked_at:
        overrides = ", ".join(f"{k} => {n}" for k, n in chunked_at)
        lines.append("   Chunk_Count : constant array (Asset_Index) of Natural :=")
        lines.append(f"     ({overrides}, others => 1);")
    else:
        lines.append("   Chunk_Count : constant array (Asset_Index) of Natural :=")
        lines.append("     (others => 1);")
    lines.append("")
    lines.append("   --  The whole offline manual, keyed by book-relative path")
    lines.append('   --  (for example "index.html" or "css/general-e96d0476.css").')
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
        lines.append(f"         Idx   => {cum + 1}){end_ref}")
        cum += len(chunks)
    lines.append("")
    lines.append("   --  The first body of a table asset (its only body for")
    lines.append("   --  every asset except the chunked search index).")
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
    print(f"{out.name} regenerated ({len(plan)} assets, {body_count} bodies, "
          f"{total} bytes).")


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
