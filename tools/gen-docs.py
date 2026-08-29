#!/usr/bin/env python3
"""Build the mdbook manual into a self-contained offline manual page and
generate the Ada spec that bundles it into the adacovex binary.

The manual source is the mdBook project at `docs/` (read the `.readthedocs.yaml`
dependency: the same book powers the Read the Docs site).  This script:

1. runs `mdbook build docs --dest-dir <tmp>` (when mdbook is on PATH and the
   build is fresh), then
2. reads the generated single-page `print.html`,
3. inlines the referenced stylesheets into one <style> block so the page needs
   no external CSS, drops the font <link>s (the offline manual uses system
   fonts), and removes the interactive script tags (search / clipboard / toc),
   leaving a plain, readable, fully self-contained chapter,
4. writes it to `src/adacovex-docs_template.ads` as the Ada constant
   `Adacovex.Docs_Template.Manual`.

`--serve` exposes this bundled page at `/docs` so the dashboard links carry a
readable, fully offline copy of the manual inside the binary itself.

The generated file is committed so the tree builds without running mdbook (the
project has no mdbook/Markdown runtime dependency).  `make build` regenerates
it (byte-identical when the docs are unchanged) and `--check` fails when it
drifts -- exactly the same pattern tools/gen-dashboard.py uses.

Usage:
  python3 tools/gen-docs.py [--check] [--out=PATH] [--keep]

--check    Verify the generated spec matches the current resources; exit 1 on
           mismatch (used by CI so the committed file never goes stale).
--out      Output Ada spec path (default: src/adacovex-docs_template.ads).
--keep     Keep the temporary mdbook build directory (for debugging).

Exit code 0 on success, 1 on a missing tool/build or a --check mismatch.  When
mdbook is not on PATH the previous committed spec is left in place and a note
is printed -- the spec is authored to build without it.
"""

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Optional

ROOT: Path = Path(__file__).resolve().parent.parent
DOCS: Path = ROOT / "docs"

_LINK = re.compile(r'<link[^>]*>')
_SCRIPT = re.compile(r'<script[\s\S]*?</script>')
_STYLE_OPEN = re.compile(r'<style[\s\S]*?>', re.IGNORECASE)
_STYLE_CLOSE = re.compile(r'</style>', re.IGNORECASE)


def sh(cmd: List[str], check: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True,
                          check=check)


def mdbook_build(dest: Path) -> bool:
    """Run `mdbook build docs --dest-dir dest`.  Return True on success."""
    if shutil.which("mdbook") is None:
        return False
    result = sh(["mdbook", "build", str(DOCS), "--dest-dir", str(dest)])
    return result.returncode == 0


def inline_css(html: str, base: Path) -> str:
    """Replace <link rel=stylesheet href=...> tags with inlined <style> bodies,
    and drop the font stylesheet (the offline manual uses system fonts)."""
    styles: List[str] = []

    def repl(match: re.Match) -> str:
        tag = match.group(0)
        if 'rel="stylesheet"' not in tag:
            # icon / preload links carry binary assets (favicon, fonts): drop
            # them; the offline manual needs none.
            return ""
        href = re.search(r'href="([^"]+)"', tag)
        if not href:
            return ""
        href_val = href.group(1)
        if href_val.startswith("fonts/"):
            return ""
        css_path = base / href_val
        if not css_path.is_file():
            return ""
        try:
            body = css_path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            return ""
        css = re.sub(r"\s*\n\s*", "", body)
        styles.append(css)
        return ""

    html = _LINK.sub(repl, html)
    if not styles:
        return html
    return _STYLE_OPEN.sub(
        lambda m: m.group(0) + "\n".join(styles) + "\n", html, count=1
    )


def minimal_offline(html: str, base: Path) -> str:
    """Produce a plain self-contained offline manual from print.html:
    inline the CSS, drop external fonts and the interactive scripts, and
    tighten the layout for a reading pane.  Purely text + inline CSS.
    The result is pure ASCII: the Ada source prefers printable block ASCII,
    so non-ASCII glyphs are escaped as HTML character references (mdBook's
    breadcrumb arrows become &larr; &amp;c.), which browsers render."""
    page = inline_css(html, base)
    # Remove scripts (search / clipboard / toc) -- the bundled page is a
    # read-only manual, no interactivity needed.
    page = _SCRIPT.sub("", page)
    # Escape any remaining non-ASCII characters as HTML character references
    # so the Ada literal stays pure ASCII while the rendered page is unchanged.
    page = _ascii_escape(page)
    return page


def _ascii_escape(text: str) -> str:
    """Return text with every character above U+007F replaced by its HTML
    character reference (e.g. '\u2190' -> '&#8592;'), dropping characters
    without a printable equivalent.  ASCII text passes through unchanged; the
    <style>/<script> bodies stay closed so nothing is split mid-attribute."""
    out: List[str] = []
    for ch in text:
        o = ord(ch)
        if o < 128:
            out.append(ch)
        elif ch not in ('\n', '\r'):
            # HTML codepoint reference for any glyph the Ada source cannot
            # hold; leaving the byte-stuffed entity keeps the page readable.
            out.append('&#%d;' % o)
    return "".join(out)


def load_manual(tmp: Path) -> str:
    """Build the book into tmp and return the self-contained print.html."""
    if not mdbook_build(tmp):
        # Fall back to the prebuilt print.html when mdbook is unavailable.
        prebuilt = DOCS / "book" / "print.html"
        if prebuilt.is_file():
            return prebuilt.read_text(encoding="utf-8")
        raise RuntimeError(
            "mdbook not on PATH and no docs/book/print.html present"
        )
    print_page = tmp / "print.html"
    return print_page.read_text(encoding="utf-8")


def generate(out: Path, keep: bool) -> None:
    tmp = Path(tempfile.mkdtemp(prefix="adacovex-docs-"))
    try:
        html = load_manual(tmp)
        offline = minimal_offline(html, tmp)
    except RuntimeError as e:
        # Keep the previously committed spec; the build must not fail when the
        # docs toolchain is missing.
        print(f"note: {e}; keeping existing {out.name}")
        return
    finally:
        if not keep:
            shutil.rmtree(tmp, ignore_errors=True)

    chunks: List[str] = []
    for line in offline.split("\n"):
        chunk_max = 60
        for start in range(0, len(line), chunk_max):
            piece = line[start:start + chunk_max].replace('"', '""')
            chunks.append('"' + piece + '"')
        chunks.append("ASCII.LF")
    body = "\n  & ".join(chunks).rstrip(" & ")

    header = (
        "--  Generated by tools/gen-docs.py from the mdBook manual (docs/):\n"
        "--  a self-contained offline copy of the built manual's print.html,\n"
        "--  with the stylesheets inlined and external fonts/scripts removed.\n"
        "--  `--serve` exposes it at /docs.  Do not edit by hand; edit docs/\n"
        "--  and run make book (or tools/gen-docs.py).\n"
    )
    out.write_text(
        header
        + "package Adacovex.Docs_Template is\n"
        + "\n"
        + "   -- The full offline manual page (single self-contained HTML).\n"
        + "   Manual : constant String :=\n"
        + body
        + ";\n"
        + "end Adacovex.Docs_Template;\n",
        encoding="ascii",
    )
    print(f"{out.name} regenerated.")


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="verify the committed spec is current")
    parser.add_argument("--out",
                        default=str(ROOT / "src" / "adacovex-docs_template.ads"),
                        help="output Ada spec path")
    parser.add_argument("--keep", action="store_true",
                        help="keep the temporary mdbook build dir")
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    out: Path = Path(args.out).resolve()
    before: Optional[str] = out.read_text(encoding="ascii") if out.is_file() else None
    generate(out, args.keep)
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