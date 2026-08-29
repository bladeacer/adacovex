#!/usr/bin/env python3
"""Generate src/adacovex-dashboard_template.ads from the modular dashboard
resources under resources/ (an index.html shell plus one file per concern):
presentation (css/dashboard.css) and behaviour: the vendored graphre.js /
nomnoml.js / flexsearch.js plus the authored js/ modules (theme, tabs,
deps, details, nomnoml diagram, search).

The --serve dashboard used to be written out line by line from Ada string
literals, mixing HTML/CSS/JS with rendering logic.  The static page shell
(doctype, CSS, header with the theme dropdown + Save settings button, footer
with the embed hint, and the theme script) now lives in
resources/dashboard.html, and this script bundles it -- and the sibling
resources/ modules it references via __STYLE_*__ / __JS_*__ placeholders --
into the binary at build time as a single String constant.  The CSS and
author JS are minified here (comments stripped, whitespace collapsed); the
vendored files are already minified and are inlined byte-for-byte.

Two placeholders are substituted at run time by
Adacovex.Renderers.HTML.Render_Dashboard:

  __CARDS__   replaced with the dynamic card markup (badges, source
              overview, SPARK proof, tests, compliance, HLR traceability).
  __THEME__   replaced with the initial dashboard theme
              (system / light / dark), used by the theme script via the
              <html data-initial-theme> attribute.

The generated file is committed so the tree builds without running this
script, and `make build` regenerates it (byte-identical when nothing
changed) so the served page never drifts from the template.

The authored CSS/JS live under resources/css/ and resources/js/ (one file
per concern); the skeleton inlines each module at its own placeholder so
style and behaviour stay separate and the cascade order is explicit:
base CSS first, then the vendored libraries, then the authored modules in
dependency order (theme, tabs, deps, details, nomnoml, search).

Ada string literals cannot span lines, so each template line is emitted as
its own quoted segment joined with ` & ASCII.LF & `.  Embedded double quotes
are doubled per Ada syntax.  The template must stay pure ASCII (enforced by
`make ascii-check`).

Usage:
  python3 tools/gen-dashboard.py [--check] [--template=PATH] [--out=PATH]

--check       Verify the generated file matches the template; exit 1 on
              mismatch (used by CI to fail loudly when the committed file
              drifted from resources/).
--template    Skeleton source path (default: resources/dashboard.html).
--out         Output Ada spec path (default: src/adacovex-dashboard_template.ads).

Exit code 0 on success, 1 on a missing resource or a --check mismatch.
"""

import argparse
import sys
from pathlib import Path
from typing import Dict, List

ROOT: Path = Path(__file__).resolve().parent.parent

# Placeholder -> module file, in insertion order.  The skeleton contains
# exactly one occurrence of each placeholder.  $T is resolved relative to
# the skeleton's directory so --template=DIR/dashboard.html works on any
# checkout.
MODULES: Dict[str, str] = {
    "__STYLE_CUSTOM__": "css/dashboard.css",    # author CSS (minified at build)
    "__JS_GRAPhRE__": "graphre.js",             # vendored (already minified)
    "__JS_NOMMONL__": "nomnoml.js",             # vendored (already minified)
    "__JS_FLEXSEARCH__": "flexsearch.js",       # vendored (already minified)
    "__JS_THEME__": "js/theme.js",              # author JS (minified at build)
    "__JS_TABS__": "js/tabs.js",                # author JS (minified at build)
    "__JS_DEPS__": "js/deps.js",                # author JS (minified at build)
    "__JS_DETAILS__": "js/details.js",          # author JS (minified at build)
    "__JS_NOMMONL_APP__": "js/nomnoml.js",      # author JS (minified at build)
    "__JS_SEARCH__": "js/search.js",            # author JS (minified at build)
    "__JS_YACE__": "js/yace.js",                # vendored (not minified: tokenizer regexes stay byte-faithful)
    "__JS_API__": "js/api.js",                  # author JS (minified at build)
}


def minify_css(source: str) -> str:
    """Minify authored CSS: strip comments and collapse whitespace outside
    string literals.  Conservative -- never touches the contents of quoted
    strings (so url()/content: values are safe)."""
    out: List[str] = []
    i: int = 0
    n: int = len(source)
    in_str: str = ""
    while i < n:
        c: str = source[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(source[i + 1])
                i += 2
                continue
            if c == in_str:
                in_str = ""
            i += 1
            continue
        if source.startswith("/*", i):
            end: int = source.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        if c in "\"'":
            in_str = c
            out.append(c)
            i += 1
            continue
        if c.isspace():
            # collapse a run of whitespace to a single space
            if out and not out[-1].isspace():
                out.append(" ")
            while i < n and source[i].isspace():
                i += 1
            continue
        out.append(c)
        i += 1
    text: str = "".join(out)
    # drop a space before/after the structural punctuation CSS ignores it at
    text = text.replace(" {", "{").replace("{ ", "{")
    text = text.replace(" }", "}").replace("} ", "}")
    text = text.replace(" :", ":").replace(": ", ":")
    text = text.replace(" ;", ";").replace("; ", ";")
    text = text.replace(" ,", ",").replace(", ", ",")
    text = text.replace(" >", ">").replace("> ", ">")
    text = text.replace(" ~", "~").replace("~ ", "~")
    text = text.replace(" +", "+").replace("+ ", "+")
    text = text.replace("( ", "(").replace(" )", ")")
    return text.strip()


def _js_regex_context(prev_sig: str, prev_word: str) -> bool:
    """Decide whether a '/' opens a regular-expression literal (rather than a
    division) from the previous significant token.  A regex opens when the
    prior token leaves an expression position (an operator/punctuator) or
    follows a regex-expecting keyword such as 'return' or 'typeof'.  This keeps
    '//' or '/*' text that appears *inside* a regex literal (for example
    /^https?:\\/\\//i) from being mistaken for a comment."""
    if prev_sig == "":
        return True
    if prev_sig in "([{,;:=!&|?<>+-*/%^~":
        return True
    if prev_word in (
        "return",
        "typeof",
        "case",
        "do",
        "else",
        "in",
        "of",
        "instanceof",
        "new",
        "void",
        "delete",
        "throw",
        "await",
        "yield",
    ):
        return True
    return False


def minify_js(source: str) -> str:
    """Minify authored JS: strip // and /* */ comments and leading
    indentation while preserving newlines (ASI-safe).  String contents are
    left untouched.  So are regular-expression literals: a '/' that opens a
    regex (not a division) is copied verbatim to its closing unescaped '/'
    (outside a character class), with its flags, so '//' or '/*' text inside a
    regex is never treated as a comment."""
    lines: List[str] = []
    i: int = 0
    n: int = len(source)
    in_line_comment: bool = False
    in_block_comment: bool = False
    in_str: str = ""
    buf: List[str] = []
    prev_sig: str = ""          # last significant (non-space) char emitted
    prev_word: str = ""         # last identifier-like token emitted

    def flush_line() -> None:
        nonlocal buf, in_line_comment
        text: str = "".join(buf).rstrip()
        if text:
            lines.append(text)
        buf = []
        in_line_comment = False

    while i < n:
        c: str = source[i]
        if in_block_comment:
            if source.startswith("*/", i):
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue
        if in_line_comment:
            if c == "\n":
                flush_line()
            i += 1
            continue
        if in_str:
            buf.append(c)
            if c == "\\" and i + 1 < n:
                buf.append(source[i + 1])
                i += 2
                continue
            if c == in_str:
                in_str = ""
                prev_sig = c
                prev_word = ""
            i += 1
            continue
        if c == "\n":
            flush_line()
            i += 1
            continue
        if c in "\"'":
            in_str = c
            buf.append(c)
            prev_sig = c
            prev_word = ""
            i += 1
            continue
        if c == "/":
            if source.startswith("/*", i):
                in_block_comment = True
                i += 2
                continue
            if source.startswith("//", i):
                in_line_comment = True
                i += 2
                continue
            if _js_regex_context(prev_sig, prev_word):
                # Scan the regex literal to its closing unescaped '/' (outside a
                # character class) and copy it verbatim, flags included, so an
                # embedded '//' or '/*' is preserved.
                buf.append("/")
                j: int = i + 1
                in_class: bool = False
                while j < n:
                    d: str = source[j]
                    buf.append(d)
                    if d == "\\":
                        if j + 1 < n:
                            buf.append(source[j + 1])
                            j += 2
                            continue
                    elif d == "[":
                        in_class = True
                    elif d == "]":
                        in_class = False
                    elif d == "/" and not in_class:
                        j += 1
                        while j < n and source[j].isalpha():
                            buf.append(source[j])
                            j += 1
                        break
                    elif d == "\n":
                        break
                    j += 1
                prev_sig = "/"
                prev_word = ""
                i = j
                continue
            # Division: emit the slash as ordinary code.
            buf.append(c)
            prev_sig = c
            prev_word = ""
            i += 1
            continue
        if c.isspace():
            # collapse horizontal whitespace to a single space
            if buf and not buf[-1].isspace():
                buf.append(" ")
            while i < n and source[i] in " \t":
                i += 1
            continue
        buf.append(c)
        prev_sig = c
        if c.isascii() and c.isalnum() or c == "_" or c == "$":
            prev_word = prev_word + c
        else:
            prev_word = ""
        i += 1
    flush_line()
    return "\n".join(lines).strip()


def assemble(template: Path) -> str:
    """Inline the resource modules into the skeleton, minifying the authored
    CSS/JS; return the final page text (pure ASCII)."""
    page: str = template.read_text(encoding="ascii")
    base: Path = template.parent
    minify: Dict[str, bool] = {
        "__STYLE_CUSTOM__": True,
        "__JS_GRAPhRE__": False,
        "__JS_NOMMONL__": False,
        "__JS_FLEXSEARCH__": False,
        "__JS_THEME__": True,
        "__JS_TABS__": True,
        "__JS_DEPS__": True,
        "__JS_DETAILS__": True,
        "__JS_NOMMONL_APP__": True,
        "__JS_SEARCH__": True,
        "__JS_YACE__": False,
        "__JS_API__": True,
    }
    for placeholder, mod in MODULES.items():
        path: Path = base / mod
        if not path.is_file():
            raise FileNotFoundError(f"required module missing: {path}")
        body: str = path.read_text(encoding="ascii")
        if minify[placeholder]:
            body = (
                minify_css(body) if placeholder == "__STYLE_CUSTOM__" else minify_js(body)
            )
        if placeholder not in page:
            raise ValueError(f"placeholder {placeholder} not found in skeleton")
        page = page.replace(placeholder, body, 1)
    return page


def generate(out: Path, template: Path) -> None:
    """Write the Ada package spec embedding the assembled page."""
    page: str = assemble(template)
    # Ada string literals cannot span lines, and GNAT truncates over-long
    # source lines (the style gate is -gnatyM120), so each page line is
    # emitted as short quoted chunks joined with ` & `.
    chunks: List[str] = []
    for i, line in enumerate(page.split("\n")):
        chunk_max: int = 60
        for start in range(0, len(line), chunk_max):
            piece: str = line[start : start + chunk_max].replace('"', '""')
            chunks.append('"' + piece + '"')
        if i < page.count("\n"):
            chunks.append("ASCII.LF")
    body: str = "\n  & ".join(chunks)

    header: str = (
        "--  Generated by tools/gen-dashboard.py from resources/dashboard.html\n"
        "--  plus the resources/ modules it inlines (css/dashboard.css,"
        " js/theme.js, js/tabs.js,\n"
        "--  js/deps.js, js/details.js, js/nomnoml.js, js/search.js,"
        " graphre.js, nomnoml.js,\n"
        "--  flexsearch.js) --\n"
        "--  a single bundled dashboard page shell for --serve: the static\n"
        "--  HTML/CSS/JS (dynamic metric cards are injected at the __CARDS__\n"
        "--  placeholder by Adacovex.Renderers.HTML.Render_Dashboard, which\n"
        "--  also fills the __THEME__ placeholder with the initial dashboard\n"
        "--  theme).  Do not edit by hand; edit resources/ and run make build.\n"
    )
    out.write_text(
        header
        + "package Adacovex.Dashboard_Template is\n"
        + "\n"
        + "   -- The full dashboard page shell.  __CARDS__ marks where the\n"
        + "   -- dynamic card markup is injected; __THEME__ is replaced with\n"
        + "   -- the initial theme (system / light / dark).\n"
        + "   Template : constant String :=\n"
        + body
        + ";\n"
        + "end Adacovex.Dashboard_Template;\n",
        encoding="ascii",
    )


def build_page(template: Path) -> str:
    """Build the fully-inlined page (used by --check to detect drift without
    writing the Ada wrapper)."""
    return assemble(template)


def parse_args(argv: List[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Bundle resources/ into an Ada string constant."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed generated file matches the resources",
    )
    parser.add_argument(
        "--template",
        default=str(ROOT / "resources" / "dashboard.html"),
        help="skeleton source path (default: resources/dashboard.html)",
    )
    parser.add_argument(
        "--out",
        default=str(ROOT / "src" / "adacovex-dashboard_template.ads"),
        help="output Ada spec path (default: src/adacovex-dashboard_template.ads)",
    )
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    """Run the generator; return the process exit code."""
    args = parse_args(argv)
    template: Path = Path(args.template).resolve()
    out: Path = Path(args.out).resolve()
    if not template.is_file():
        print(f"error: template not found: {template}", file=sys.stderr)
        return 1
    if not args.check:
        generate(out, template)
        print(f"{out.name} regenerated.")
        return 0
    before: str = out.read_text(encoding="ascii") if out.is_file() else ""
    generate(out, template)
    after: str = out.read_text(encoding="ascii")
    if before != after:
        print(
            f"error: {out.name} is stale -- run tools/gen-dashboard.py (or "
            "make build) and commit the regenerated file.",
            file=sys.stderr,
        )
        return 1
    print(f"{out.name} is up to date.")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
