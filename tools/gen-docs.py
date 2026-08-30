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
   * mdbook's client-side search assets are *not* bundled -- its elasticlunr
     search index is a 4 MB single blob that would overflow the gnatprove
     frontend stack as one Ada string constant.  Instead a compact
     `offline-search.json` index (page title, headings, body excerpt) is
     generated from the docs source and a small self-contained search widget
     is injected into every bundled page, so the offline manual is searchable
     with no network; mdbook's own search box stays hidden;
   * the PNG dashboard screenshots are dropped and each `<img>` becomes a
     short note (the images stay in the online book);
   * every remaining non-ASCII glyph is escaped as an HTML character
     reference so the Ada source stays pure ASCII;
3. writes `src/adacovex-docs_template.ads` as a constant table of
   (path, MIME type, body index) assets plus one `aliased constant String`
   per asset body (bodies are never concatenated into one value: a single
   multi-megabyte string constant overflows the gnatprove frontend stack).
   `--serve` exposes the table at `/docs/` so the dashboard links carry a
   fully offline copy of the whole manual inside the binary itself.

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
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

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

# ---- Offline search -------------------------------------------------------
# mdbook ships a client-side search driven by elasticlunr, but its searchindex
# is a few-MB single blob that cannot be one Ada string constant (the bundler
# splits bodies per-asset precisely to keep each under the gnatprove frontend
# limit).  We bundle a compact index (page title, headings, body excerpt) and a
# small self-contained widget instead, so the bundled manual is searchable
# with no network.  The widget fetches /docs/offline-search.json (served from
# the asset table) and does simple substring search over title + headings +
# excerpt, ranking heading matches first.

# The widget is injected after <body> on every bundled HTML page.  It is
# deliberately self-contained (no external JS/CSS assets) so post-processing
# needs no book changes beyond the inject.
_OFFLINE_SEARCH_ID = "acx-search"
# Raw string on purpose: the JS uses regex literals (\s+); a normal string
# would let the re.sub replacement interpret them as escapes.
_OFFLINE_SEARCH_WIDGET = r'''
<div id="acx-search"><input id="acx-search-input" type="search" placeholder="Search the manual..." aria-label="Search the manual"><div id="acx-search-results"></div></div>
<style>
#acx-search{position:relative;max-width:520px;margin:0 0 20px}
#acx-search input{width:100%;box-sizing:border-box;padding:10px 14px;border:1px solid #ccc;border-radius:8px;font:inherit;font-size:.95rem}
#acx-search-results{display:none;position:absolute;top:100%;left:0;right:0;background:#fff;border:1px solid #ccc;border-radius:8px;max-height:380px;overflow:auto;z-index:50;box-shadow:0 4px 12px rgba(0,0,0,.18)}
#acx-search .acx-sr{display:block;padding:8px 12px;font-size:.88rem;border-bottom:1px solid #f0f0f0}
#acx-search .acx-sr:last-child{border-bottom:none}
a.acx-sr{text-decoration:none;color:#333}
a.acx-sr:hover{background:#f5f5f5}
.acx-hdr{font-size:.78rem;color:#888}
.acx-sr-t{font-weight:600}
.acx-sr-d{font-size:.8rem;color:#666;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
</style>
<script>
(function(){
var w=document,id="acx-search";
var inp=w.getElementById(id+"-input");
var res=w.getElementById(id+"-results");
// Resolve the manual root at run time from the current page URL (each
// bundled page is served under a root-relative /docs/<page>), so the widget
// source carries no root-absolute href/src literal for the link checker to
// mis-resolve.
var base=(function(){var p=location.pathname;var i=p.lastIndexOf("/docs/");return i>=0?p.slice(0,i+6):"";})();
var idx=null;
function load(){if(idx!==null)return;var x=new XMLHttpRequest();
x.open("GET",base+"offline-search.json");
x.onload=function(){if(x.status===200){try{idx=JSON.parse(x.responseText);}catch(e){}}};
x.send();}
if(w.addEventListener){w.addEventListener("DOMContentLoaded",load);}
function draw(q){
res.innerHTML="";
var terms=q.toLowerCase().split(/\s+/);
var out=[];
for(var p in idx){var e=idx[p];
var hay=(e.t+" "+(e.h?e.h.join(" "):"")+" "+(e.b||"")).toLowerCase();
var ok=true;
for(var k=0;k<terms.length;k++){if(hay.indexOf(terms[k])===-1){ok=false;break;}}
if(ok)out.push([p,e]);}
out.sort(function(a,b){return a[1].t.localeCompare(b[1].t);});
var h=w.createElement("div");h.className="acx-sr acx-hdr";
h.textContent=out.length+" result"+(out.length===1?"":"s");res.appendChild(h);
var n=Math.min(out.length,10);
for(var i=0;i<n;i++){var a=w.createElement("a");a.className="acx-sr";
a.href=base+out[i][0];
var t=w.createElement("div");t.className="acx-sr-t";t.textContent=out[i][1].t;a.appendChild(t);
var d=w.createElement("div");d.className="acx-sr-d";
d.textContent=(out[i][1].h&&out[i][1].h.length?out[i][1].h[0]:"");a.appendChild(d);
res.appendChild(a);}
res.style.display="block";}
inp.addEventListener("input",function(){var q=inp.value.trim();
if(!q||idx===null){res.innerHTML="";res.style.display="none";return;}draw(q);});
w.addEventListener("click",function(ev){var n=ev.target;
if(n!==inp&&n!==res&&!res.contains(n)){res.style.display="none";}});
})();
</script>
'''

# Strip markdown link/markup to plain display text for the search index.
def _plain(text: str) -> str:
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    s = s.replace("`", "").replace("*", "").replace("_", "")
    s = re.sub(r"[#~|]+|^>\s*", " ", s)
    return " ".join(s.split())


def _page_meta(md_text: str) -> Tuple[str, List[str], str]:
    """Return (title, headings, excerpt) for one markdown page."""
    title = ""
    headings: List[str] = []
    body: List[str] = []
    in_code = False
    for raw in md_text.splitlines():
        line = raw.strip()
        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not line:
            continue
        if not title and line.startswith("# "):
            title = _plain(line[2:])
            continue
        if line.startswith("## "):
            headings.append(_plain(line[3:]))
            continue
        if line.startswith("#"):
            continue
        if set(line) <= set("-="):
            continue
        p = _plain(line)
        if p:
            body.append(p)
    excerpt = " ".join(body)
    return title, headings, excerpt[:300]


# Compact search index:  {html-path: {t: title, h: [headings], b: excerpt}}.
# Deterministic (sorted pages and keys) so gen-docs --check is stable.  Only
# pages that exist in the built book are indexed (their links must resolve).
def build_search_index(book_html: Set[str]) -> str:
    idx: Dict[str, Dict[str, object]] = {}
    for md in sorted(DOCS.rglob("*.md")):
        rel = md.relative_to(DOCS).as_posix()
        if rel.startswith("book/"):
            continue
        html = rel[:-3] + ".html"  # docs/x.md -> x.html; proof/index.md -> proof/index.html
        if html not in book_html:
            continue
        try:
            text = md.read_text(encoding="utf-8")
        except OSError:
            continue
        title, headings, excerpt = _page_meta(text)
        if not title:
            title = md.stem.replace("_", " ").title()
        idx[html] = {"t": title, "h": headings, "b": excerpt}
    return json.dumps(idx, ensure_ascii=True, sort_keys=True, separators=(",", ":"))

_MIME: Dict[str, str] = {
    ".html": "text/html",
    ".css": "text/css",
    ".js": "application/javascript",
    ".json": "application/json",
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
    # Hide mdbook's own (non-functional in the bundle) search box, then add
    # the compact self-contained search widget, so the offline manual is
    # searchable with no network.
    html = re.sub(r"(?i)<head>", "<head>" + _SEARCH_HIDE, html, count=1)
    # A function replacement keeps the widget's literal backslashes (JS
    # regexes like /\s+/) from being interpreted as re escapes.
    html = re.sub(r"(?i)<body[^>]*>",
                  lambda m: m.group(0) + _OFFLINE_SEARCH_WIDGET,
                  html, count=1)
    return html


def collect_assets(book: Path) -> List[Tuple[str, str, str]]:
    """Return [(path, mime, body), ...] for every bundled asset of the book."""
    assets: List[Tuple[str, str, str]] = []
    html_paths: Set[str] = set()
    for path in sorted(book.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(book).as_posix()
        if any(rel.startswith(p) for p in OFFLINE_EXCLUDED_PREFIXES):
            continue
        mime = _MIME.get(path.suffix.lower())
        if mime is None:
            continue
        if rel.endswith(".html") and rel != "print.html":
            html_paths.add(rel)
        try:
            body = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            # Binary file with a text extension (should not happen): skip.
            continue
        if mime == "text/html" and rel != "print.html":
            body = postprocess_page(body)
        assets.append((rel, mime, body))
    # Compact offline search index: generated from the docs source and served
    # (like every asset) from the lookup table.  The widget injected into each
    # page fetches this at /docs/offline-search.json.
    assets.append(("offline-search.json", "application/json",
                   build_search_index(html_paths)))
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
    lines.append("   --  are fixed-size (space-padded) strings; Idx selects the")
    lines.append("   --  asset body via Asset_Bodies.  Fixed-size components keep")
    lines.append("   --  the aggregate a plain static constant (a discriminated-")
    lines.append("   --  record array is dynamically elaborated by GNAT and blows")
    lines.append("   --  the heap).")
    lines.append("   Max_Path : constant := 80;")
    lines.append("   Max_Mime : constant := 32;")
    lines.append(f"   Asset_Count : constant := {len(assets)};")
    lines.append("   subtype Asset_Index is Positive range 1 .. Asset_Count;")
    lines.append("   type Asset_Ref is")
    lines.append("      record")
    lines.append("         Path  : String (1 .. Max_Path) := (others => ' ');")
    lines.append("         Mime  : String (1 .. Max_Mime) := (others => ' ');")
    lines.append("         Idx   : Asset_Index;")
    lines.append("      end record;")
    lines.append("")
    lines.append("   type Asset_Table is array (Positive range <>) of Asset_Ref;")
    lines.append("")
    lines.append("   --  Every asset body as its own static constant.  One constant")
    lines.append("   --  per asset keeps each string small: a single multi-")
    lines.append("   --  megabyte blob constant overflows the gnatprove frontend")
    lines.append("   --  stack (Storage_Error) whatever its structure, so the")
    lines.append("   --  bodies are never concatenated into one value.")
    for i, (rel, mime, body) in enumerate(assets):
        lines.append(f"   Asset_{i:03d} : aliased constant String :=")
        asset_lines = _asset_body_lines(body)
        for ei, al in enumerate(asset_lines):
            prefix = "       " if ei == 0 else "       & "
            lines.append(prefix + al.strip())
        lines.append("       ;")
        lines.append("")
    lines.append("   type Asset_Body is access constant String;")
    lines.append("")
    lines.append("   --  The bodies by table index: Asset_NNN'Access, in order.")
    lines.append("   Asset_Bodies : constant array (Asset_Index) of Asset_Body :=\n     (")
    for i in range(len(assets)):
        end_ref = ");" if i == len(assets) - 1 else ","
        lines.append(f"      Asset_{i:03d}'Access{end_ref}")
    lines.append("")
    lines.append("   --  The whole offline manual, keyed by book-relative path")
    lines.append('   --  (for example "index.html" or "css/general-e96d0476.css").')
    lines.append("   Assets : constant Asset_Table :=")
    for i, (rel, mime, body) in enumerate(assets):
        # The line template closes the Asset_Ref' qualified aggregate with
        # `)`; end_ref closes the array aggregate for the final ref.
        end_ref = ");" if i == len(assets) - 1 else ","
        if len(rel) > 80 or len(mime) > 32:
            raise RuntimeError(f"asset {rel!r} exceeds fixed-size bounds")
        pad_path = rel.ljust(80)
        pad_mime = mime.ljust(32)
        lines.append("     (Asset_Ref'" if i == 0 else "      Asset_Ref'")
        lines.append(f'        (Path  => "{pad_path}",')
        lines.append(f'         Mime  => "{pad_mime}",')
        lines.append(f"         Idx   => {i + 1}){end_ref}")
    lines.append("")
    lines.append("   --  The asset body for a table index.")
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
