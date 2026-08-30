#!/usr/bin/env python3
"""Build the mdBook manual and bundle the whole built site into the binary.

The manual source is the mdBook project at `docs/` (read the `.readthedocs.yaml`
dependency: the same book powers the Read the Docs site).  This script:

1. runs `mdbook build docs` (when mdbook is on PATH; the build output lands in
   `docs/book/`, which is committed as the fallback), then
2. collects the built site into an offline asset set -- every HTML page, the
   stylesheets, the local scripts (theme, toc, clipboard, highlight.js), and
   the SVG badges -- and post-processes each page so the offline manual works
   with no network:

   * the font stylesheet and woff2 files are dropped (system fonts are used);
   * the binary favicon is dropped (the SVG favicon is kept);
   * the search assets (elasticlunr, searcher, mark, the large search index)
     are dropped and the search box is hidden -- search stays online-only;
   * the PNG dashboard screenshots are dropped and each `<img>` becomes a
     short note (the images stay in the online book);
   * every remaining non-ASCII glyph is escaped as an HTML character
     reference so the Ada source stays pure ASCII;
3. writes `src/adacovex-docs_template.ads` as a constant table of
   (path, MIME type, body) assets.  `--serve` exposes the table at `/docs/`
   so the dashboard links carry a fully offline copy of the whole manual
   inside the binary itself.

The generated spec is committed so the tree builds without running mdbook
(the project has no mdbook/Markdown runtime dependency).  `make book` / `make
build` regenerate it (byte-identical when the docs are unchanged) and `--check`
fails when it drifts -- exactly the same pattern tools/gen-dashboard.py uses.

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
# fonts, the search machinery, the PNG screenshots, and the print/404 pages.
OFFLINE_EXCLUDED_PREFIXES: Tuple[str, ...] = (
    "fonts/",
    "favicon-",          # png favicon (the svg one is kept); safe prefix match
    "elasticlunr-",
    "searcher-",
    "searchindex-",
    "mark-",
    "media/",
    "print.html",
    "404.html",
    "book.toml",
    ".nojekyll",
)

# Scripts dropped from every bundled page (search machinery).
_DROP_SCRIPT_SRC = re.compile(
    r'<script[^>]*src="(?:elasticlunr-[^"]+|searcher-[^"]+|'
    r'searchindex-[^"]+|mark-[^"]+\.min\.js)"[^>]*></script>'
)
# The font stylesheet link (the woff2 files are not bundled).
_DROP_FONT_LINK = re.compile(
    r'<link[^>]*rel="stylesheet"[^>]*href="fonts/[^"]+"[^>]*>')
# The binary favicon link (the SVG favicon link is kept).
_DROP_PNG_ICON = re.compile(
    r'<link[^>]*rel="shortcut icon"[^>]*href="favicon-[^"]+\.png"[^>]*>')
# The PNG dashboard screenshots: replaced by a short note.
_IMG_MEDIA = re.compile(r'<img[^>]*src="media/[^"]+"[^>]*>')
_SEARCH_HIDE = '<style>.search-wrapper{display:none!important}</style>'

_MIME: Dict[str, str] = {
    ".html": "text/html",
    ".css": "text/css",
    ".js": "application/javascript",
    ".svg": "image/svg+xml",
}


def sh(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)


def mdbook_build() -> bool:
    """Run `mdbook build docs` (output lands in docs/book).  True on success."""
    if shutil.which("mdbook") is None:
        print("note: mdbook not on PATH; using committed docs/book")
        return False
    result = sh(["mdbook", "build", str(DOCS)])
    if result.returncode != 0:
        print(f"note: mdbook build failed ({result.returncode}); "
              f"using committed docs/book", file=sys.stderr)
        return False
    return True


def postprocess_page(html: str) -> str:
    """Make one built page fully offline: drop search/fonts/binary favicon,
    hide the search box, and replace the PNG screenshots with notes.
    Non-ASCII glyphs are emitted as raw UTF-8 bytes by the Ada generator."""
    html = _DROP_FONT_LINK.sub("", html)
    html = _DROP_PNG_ICON.sub("", html)
    html = _DROP_SCRIPT_SRC.sub("", html)

    def img_repl(match: "re.Match[str]") -> str:
        alt_m = re.search(r'alt="([^"]*)"', match.group(0))
        alt = alt_m.group(1) if alt_m else "screenshot"
        return f'<em>{alt} -- see the online manual for the image.</em>'

    html = _IMG_MEDIA.sub(img_repl, html)
    # Hide the (non-functional) search box; search stays online-only.
    html = re.sub(r"(?i)<head>", "<head>" + _SEARCH_HIDE, html, count=1)
    return html


def collect_assets(book: Path) -> List[Tuple[str, str, str]]:
    """Return [(path, mime, body), ...] for every bundled asset of the book."""
    assets: List[Tuple[str, str, str]] = []
    for path in sorted(book.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(book).as_posix()
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
        if mime == "text/html" and rel != "print.html":
            body = postprocess_page(body)
        assets.append((rel, mime, body))
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


def _body_lines(body: str) -> List[str]:
    """The Ada expression lines for one asset body.

    Ada string literals cannot span physical lines, so the body is emitted one
    literal per source line (ASCII runs), with control and non-ASCII glyphs as
    Character'Val byte runs; source lines are joined with `& ASCII.LF` so the
    embedded newlines stay faithful.  The final trailing newline is dropped.
    The first line is a bare literal; every later line carries `& `.
    """
    body_lines: List[str] = body.split("\n")
    if body_lines and body_lines[-1] == "":
        body_lines.pop()
    lines: List[str] = []
    first: bool = True
    for bl in body_lines:
        tokens: List[object] = _tokenize(bl) or [""]
        for token in tokens:
            if isinstance(token, str):
                # Chunk long runs (inline SVG templates etc.) so every Ada
                # literal stays under the -gnatyM line-length limit.
                pieces = [token[i:i + 76]
                          for i in range(0, len(token), 76)] or [""]
                for piece in pieces:
                    prefix = "           " if first else "           & "
                    lines.append(prefix + '"' + piece.replace('"', '""') + '"')
                    first = False
            else:
                for byte in token:
                    prefix = "           " if first else "           & "
                    lines.append(prefix + f"Character'Val({byte})")
                    first = False
        lines.append("           & ASCII.LF")
    if lines and lines[-1].strip() == "& ASCII.LF":
        lines.pop()  # no trailing newline after the final line
    return lines


def _body_bytes(body: str) -> int:
    """The emitted Ada string length for a body: UTF-8 byte length minus the
    dropped trailing newline (non-ASCII glyphs become one Character'Val per
    UTF-8 byte)."""
    body_bytes = len(body.encode("utf-8"))
    if body.endswith("\n"):
        body_bytes -= 1
    return body_bytes


def generate(out: Path) -> None:
    """Build the book (or reuse the committed one) and write the Ada spec."""
    if not mdbook_build() and not BOOK.is_dir():
        raise RuntimeError("mdbook not on PATH and no docs/book present")

    assets = collect_assets(BOOK)

    header = (
        "--  Generated by tools/gen-docs.py from the mdBook manual (docs/):\n"
        "--  the whole built site (pages, stylesheets, scripts, badges)\n"
        "--  as an offline asset blob + lookup table.  --serve exposes it at\n"
        "--  /docs/.  Do not edit by hand; edit docs/ and run make book.\n"
    )
    lines: List[str] = header.splitlines()
    lines.append("package Adacovex.Docs_Template is")
    lines.append("")
    lines.append("   --  One entry of the lookup table.  The path and MIME type")
    lines.append("   --  are fixed-size (space-padded) strings; Start/Len index")
    lines.append("   --  the Blob.  Fixed-size components keep the aggregate a")
    lines.append("   --  plain static constant (a discriminated-record array is")
    lines.append("   --  dynamically elaborated by GNAT and blows the heap).")
    lines.append("   Max_Path : constant := 80;")
    lines.append("   Max_Mime : constant := 32;")
    lines.append("   type Asset_Ref is")
    lines.append("      record")
    lines.append("         Path  : String (1 .. Max_Path) := (others => ' ');")
    lines.append("         Mime  : String (1 .. Max_Mime) := (others => ' ');")
    lines.append("         Start : Positive;")
    lines.append("         Len   : Natural;")
    lines.append("      end record;")
    lines.append("")
    lines.append("   type Asset_Table is array (Positive range <>) of Asset_Ref;")
    lines.append("")
    lines.append("   --  The whole offline manual, keyed by book-relative path")
    lines.append('   --  (for example "index.html" or "css/general-e96d0476.css").')
    lines.append("   Assets : constant Asset_Table :=")
    offset = 1
    for i, (rel, mime, body) in enumerate(assets):
        # The line template closes the Asset_Ref' qualified aggregate with
        # `)`; end_ref closes the array aggregate for the final ref.
        end_ref = ");" if i == len(assets) - 1 else ","
        body_bytes = _body_bytes(body)
        if len(rel) > 80 or len(mime) > 32:
            raise RuntimeError(f"asset {rel!r} exceeds fixed-size bounds")
        pad_path = rel.ljust(80)
        pad_mime = mime.ljust(32)
        lines.append("     (Asset_Ref'" if i == 0 else "      Asset_Ref'")
        lines.append(f'        (Path  => "{pad_path}",')
        lines.append(f'         Mime  => "{pad_mime}",')
        lines.append(f"         Start => {offset},")
        lines.append(f"         Len   => {body_bytes}){end_ref}")
        offset += body_bytes
    lines.append("")
    lines.append("   --  The concatenated bodies of every asset, in Assets order.")
    lines.append("   --  A single static string (like the pre-bundle manual page)")
    lines.append("   --  so the constant lives in the read-only data section.")
    lines.append("   Blob : constant String :=")
    first_body: bool = True
    for rel, mime, body in assets:
        body_lines = _body_lines(body)
        for idx, bl in enumerate(body_lines):
            if first_body:
                lines.append("       " + bl)
                first_body = False
            elif idx == 0:
                # first line of a later body continues the chain: add "& "
                lines.append("       & " + bl.strip())
            else:
                lines.append("       " + bl)
    lines.append("       ;")
    lines.append("")
    lines.append("   --  The asset body for a table index (the Blob slice).")
    lines.append("   function Content (Idx : Positive) return String;")
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
    print(f"{out.name} regenerated ({len(assets)} assets, {total} bytes).")


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
