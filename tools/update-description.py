#!/usr/bin/env python3
"""Sync the covex crate description from a single source of truth.

The Alire crate description (`description = "..."`) and long description
(a TOML triple-quoted `long-description` block) are duplicated across
alire.toml, every release manifest (alire/releases/covex-*.toml), and every
local index entry (index/ad/covex/covex-*.toml).  They drifted by hand in
the past, so this script keeps them all identical to the canonical files:

  alire/description.txt      -- the short description (one line)
  alire/long-description.txt -- the long-description body (no TOML triple
                                quote delimiters)

The canonical files are edited directly (or by `make description`), and this
script propagates them to every manifest copy.  `make bump-version` and
`make release` create new version files from the templates, which this script
also keeps in sync, so a new release always ships the current description.

Usage:
  python3 tools/update-description.py [--check] [--dry-run]

--check    Verify every manifest already matches the canonical files; exit 1
           when any copy has drifted (used by the quality gate).
--dry-run  Print what would change without editing files.

Exit code 0 on success (or, with --check, when everything is in sync), 1 when
a canonical file is missing, a manifest could not be rewritten, or --check
found drift.
"""

import argparse
import re
import sys
from pathlib import Path
from typing import List, Optional

ROOT: Path = Path(__file__).resolve().parent.parent

SHORT: Path = ROOT / "alire" / "description.txt"
LONG: Path = ROOT / "alire" / "long-description.txt"

# Files that carry the crate description, in edit order.
MANIFESTS: List[Path] = [
    ROOT / "alire.toml",
    ROOT / "alire-dev.toml",
    *sorted((ROOT / "alire" / "releases").glob("covex-*.toml")),
    *sorted((ROOT / "index" / "ad" / "covex").glob("covex-*.toml")),
]

SHORT_RE: str = r'^description\s*=\s*"[^"]*"$'
# Opening line of a TOML triple-quoted block:  long-description = """
LONG_OPEN_RE: str = r'^long-description\s*=\s*"""\s*$'
# Single-line empty block:  long-description = """"""
LONG_INLINE_RE: str = r'^long-description\s*=\s*""".*"""\s*$'
# Closing delimiter line of a TOML triple-quoted block.
CLOSE_RE: str = r'^"""\s*$'


def load_canonical() -> tuple[str, str]:
    """Return (short, long-body) from the canonical files."""
    if not SHORT.exists() or not LONG.exists():
        raise SystemExit(
            f"error: canonical description files missing "
            f"({SHORT.relative_to(ROOT)} / {LONG.relative_to(ROOT)})"
        )
    short: str = SHORT.read_text(encoding="utf-8").strip()
    body: str = LONG.read_text(encoding="utf-8").strip("\n").rstrip()
    if "\n" in short:
        raise SystemExit("error: short description must be a single line")
    return short, body


def render_long(body: str) -> str:
    """Render the TOML long-description block for a body string."""
    return 'long-description = """\n' + body + '\n"""'


def rewrite(text: str, short: str, long_block: str) -> Optional[str]:
    """Return text with description/long-description synced, or None when
    the file has no `description` line (e.g. an unrelated toml)."""
    lines: List[str] = text.splitlines()
    out: List[str] = []
    long_updated: bool = False
    desc_seen: bool = False
    i: int = 0
    while i < len(lines):
        line: str = lines[i]
        if re.match(SHORT_RE, line):
            out.append(f'description = "{short}"')
            desc_seen = True
            # Replace an existing long-description block that follows
            # directly (allowing blank lines between them).
            j: int = i + 1
            while j < len(lines) and lines[j].strip() == "":
                j += 1
            if j < len(lines) and re.match(LONG_OPEN_RE, lines[j]):
                out.append(long_block)
                long_updated = True
                i = j + 1
                # Consume the original block body up to the closing delimiter.
                while i < len(lines) and not re.match(CLOSE_RE, lines[i]):
                    i += 1
                i += 1  # skip the closing delimiter line
                continue
            i += 1
            continue
        if re.match(LONG_OPEN_RE, line):
            # Block elsewhere in the file (e.g. after auto-gpr-with): replace
            # in place and skip its body lines.
            if not long_updated:
                out.append(long_block)
                long_updated = True
            i += 1
            while i < len(lines) and not re.match(CLOSE_RE, lines[i]):
                i += 1
            i += 1  # skip the closing delimiter line
            continue
        if re.match(LONG_INLINE_RE, line):
            # Single-line (empty) block: replace in place.
            if not long_updated:
                out.append(long_block)
                long_updated = True
            i += 1
            continue
        out.append(line)
        i += 1

    if not desc_seen:
        return None

    if not long_updated:
        # No long-description anywhere: insert it right after the description
        # line (first occurrence).
        result: List[str] = []
        inserted: bool = False
        for line in out:
            result.append(line)
            if not inserted and re.match(SHORT_RE, line):
                # No blank line: matches the in-place replacement path so a
                # second run is a no-op (idempotent).
                result.append(long_block)
                inserted = True
        out = result
        long_updated = True

    return "\n".join(out) + "\n"


def main(argv: Optional[list] = None) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="verify all manifests are in sync; exit 1 on drift")
    ap.add_argument("--dry-run", action="store_true",
                    help="report changes without editing files")
    args: argparse.Namespace = ap.parse_args(argv)

    short, body = load_canonical()
    long_block: str = render_long(body)
    changed: List[Path] = []
    errors: int = 0

    for path in MANIFESTS:
        if not path.exists():
            continue
        original: str = path.read_text(encoding="utf-8")
        updated: Optional[str] = rewrite(original, short, long_block)
        if updated is None:
            continue
        if updated == original:
            continue
        changed.append(path)
        if not args.check and not args.dry_run:
            path.write_text(updated, encoding="utf-8")

    if args.check:
        if changed:
            for path in changed:
                print(f"DRIFT: {path.relative_to(ROOT)}", file=sys.stderr)
            print(
                "error: description drifted from alire/description.txt / "
                "alire/long-description.txt (run `make description`)",
                file=sys.stderr,
            )
            return 1
        print("ok: all crate descriptions match the canonical files")
        return 0

    if args.dry_run:
        for path in changed:
            print(f"would update: {path.relative_to(ROOT)}")
        print(f"{len(changed)} file(s) out of sync" if changed
              else "all crate descriptions already in sync")
        return 0

    for path in changed:
        print(f"updated: {path.relative_to(ROOT)}")
    print(f"{len(changed)} file(s) updated" if changed
          else "all crate descriptions already in sync")
    return errors


if __name__ == "__main__":
    sys.exit(main())
