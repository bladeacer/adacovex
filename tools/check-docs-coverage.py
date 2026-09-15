#!/usr/bin/env python3
"""Check the user documentation covers the CLI and the server surface.

AGENTS.md makes the CLI-reference and dashboard coverage a manual audit to
repeat whenever the option set or the route set changes.  This script turns
that audit into a feature gate, exactly like `tools/check-action-parity.py`
does for the action inputs:

- every CLI flag in `Known_Flags` is documented in one of the
  `docs/usage/cli-reference*.md` pages (as `--flag` or as a bare subcommand);
- every path the server dispatches on (the `Route` function in
  src/server/adacovex-server-http.ads) appears in the
  `docs/usage/dashboard.md` endpoint table;
- every hand-written page under `docs/usage/` and `docs/contributing/`
  is reachable from a `{toctree}` in `docs/index.md` (a page that no toctree
  names is a page the sidebar never shows).

Sources of truth:

- CLI flags: the `Known_Flags` constant in src/core/adacovex-config.adb
  (the same list the "did you mean" suggestion and the action-parity gate
  read);
- server routes: the string literals in the `Route` function in
  src/server/adacovex-server-http.ads;
- documentation: docs/usage/cli-reference*.md, docs/usage/dashboard.md, and
  the `{toctree}` entries in docs/index.md.

Usage:
  python3 tools/check-docs-coverage.py   # check; exit 1 on any gap
  python3 tools/check-docs-coverage.py --sources  # print the parsed sets
"""

import argparse
import re
import sys
from pathlib import Path
from typing import List, Set

ROOT: Path = Path(__file__).resolve().parent.parent

# Subcommands and bare words that `Known_Flags` carries but that a page may
# document without a leading `--`.  A flag is covered when either spelling
# appears, so this set only documents the intent.
_SUBCOMMANDS: Set[str] = {
    "serve",
    "status",
    "completion",
    "man",
    "check",
    "complexity",
    "export",
    "metrics",
    "help",
    "version",
}


def cli_flags() -> Set[str]:
    """The CLI flag names from Known_Flags in adacovex-config.adb."""
    path: Path = ROOT / "src" / "core" / "adacovex-config.adb"
    text: str = path.read_text(encoding="utf-8")
    m = re.search(r"Known_Flags : constant String :=\s*(.*?);", text, re.S)
    if m is None:
        raise SystemExit(f"  ERROR: Known_Flags not found in {path}")
    block: str = "".join(re.findall(r'"([^"]*)"', m.group(1)))
    return set(block.split())


def route_paths() -> Set[str]:
    """The literal request paths the server's Route function dispatches on.

    A trailing slash is normalised away (`/docs/` and `/docs` reach the same
    handler), so the documentation may list the canonical form once.
    """
    path: Path = ROOT / "src" / "server" / "adacovex-server-http.ads"
    text: str = path.read_text(encoding="utf-8")
    m = re.search(r"function Route \(Path : String\).*?Global => null;",
                  text, re.S)
    if m is None:
        raise SystemExit(f"  ERROR: Route function not found in {path}")
    return {p.rstrip("/") or "/"
            for p in re.findall(r'"(/[^"]*)"', m.group(0))}


def cli_reference_text() -> str:
    """Every docs/usage/cli-reference*.md page, concatenated."""
    pages = sorted((ROOT / "docs" / "usage").glob("cli-reference*.md"))
    if not pages:
        raise SystemExit("  ERROR: no docs/usage/cli-reference*.md pages")
    return "\n".join(p.read_text(encoding="utf-8") for p in pages)


def dashboard_text() -> str:
    """The docs/usage/dashboard.md endpoint table page."""
    path: Path = ROOT / "docs" / "usage" / "dashboard.md"
    if not path.is_file():
        raise SystemExit(f"  ERROR: {path} not found")
    return path.read_text(encoding="utf-8")


def toctree_entries() -> Set[str]:
    """The docnames named by the `{toctree}` blocks in docs/index.md.

    An entry may carry options (`:caption:`, `:maxdepth:`) and optional
    `Title <target>` syntax; the target is normalised to a docname without
    the `.md` suffix so it can be compared against page paths.
    """
    text: str = (ROOT / "docs" / "index.md").read_text(encoding="utf-8")
    entries: Set[str] = set()
    for block in re.findall(r"```\{toctree\}\n(.*?)```", text, re.S):
        for line in block.splitlines():
            line = line.strip()
            if not line or line.startswith(":"):
                continue
            m = re.search(r"<([^>]+)>", line)
            target = m.group(1) if m else line
            entries.add(target[:-3] if target.endswith(".md") else target)
    return entries


def missing_toctree_targets() -> List[str]:
    """Toctree entries in docs/index.md that name a missing document.

    Sphinx reports a dangling entry as `toc.not_readable`, and the sidebar
    silently never renders it, so a page renamed without its toctree entry
    loses its navigation home.  The check pins each entry to a real page.
    """
    return [entry for entry in sorted(toctree_entries())
            if not (ROOT / "docs" / (entry + ".md")).is_file()]


def hand_written_pages() -> List[Path]:
    """The hand-written usage/ and contributing/ pages (api-docs excluded)."""
    pages: List[Path] = []
    for sub in ("usage", "contributing"):
        pages.extend(sorted((ROOT / "docs" / sub).rglob("*.md")))
    return pages


def _flag_documented(flag: str, docs: str) -> bool:
    """Whether the CLI reference documents the flag in either spelling."""
    if re.search(r"--" + re.escape(flag) + r"\b", docs):
        return True
    return re.search(r"`" + re.escape(flag) + r"`", docs) is not None


def check() -> int:
    errors: List[str] = []
    flags: Set[str] = cli_flags()
    routes: Set[str] = route_paths()
    docs: str = cli_reference_text()
    dash: str = dashboard_text()
    toctrees: Set[str] = toctree_entries()

    # 1. Every CLI flag is documented in a cli-reference page.
    for flag in sorted(flags):
        if not _flag_documented(flag, docs):
            errors.append(
                f"CLI flag `--{flag}` is not documented in "
                f"docs/usage/cli-reference*.md. Add it (as a flag or as a "
                f"subcommand) in the same change.")

    # 2. Every dispatched server path appears in the dashboard endpoint table.
    for path in sorted(routes):
        if path not in dash:
            errors.append(
                f"server route `{path}` is not documented in "
                f"docs/usage/dashboard.md. Add its row in the same change.")

    # 3. Every toctree entry names a real page.
    for entry in missing_toctree_targets():
        errors.append(
            f"docs/index.md names `{entry}` in a `{{toctree}}`, but "
            f"docs/{entry}.md does not exist. Fix the entry in the same "
            f"change.")

    # 4. Every hand-written page is reachable from a toctree.
    for page in hand_written_pages():
        docname: str = page.relative_to(ROOT / "docs").as_posix()[:-3]
        if docname not in toctrees:
            errors.append(
                f"page docs/{docname}.md is not named by any `{{toctree}}` "
                f"in docs/index.md, so the sidebar never shows it.")

    if errors:
        for e in errors:
            print(f"  ERROR: {e}")
        print(f"  Documentation coverage check FAILED ({len(errors)} error(s))")
        return 1

    print(f"  CLI flags: {len(flags)} | server routes: {len(routes)} | "
          f"toctree pages: {len(toctrees)}")
    print("  Documentation coverage check passed.")
    return 0


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--sources",
        action="store_true",
        help="print the parsed CLI-flag / route / toctree sets",
    )
    args: argparse.Namespace = ap.parse_args(argv)
    if args.sources:
        print(f"CLI flags: {sorted(cli_flags())}")
        print(f"Server routes: {sorted(route_paths())}")
        print(f"Toctree entries: {sorted(toctree_entries())}")
        return 0
    return check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
