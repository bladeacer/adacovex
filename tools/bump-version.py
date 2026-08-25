#!/usr/bin/env python3
"""Bump the adacovex version across every manifest and scaffold the release.

Pure-Python port of the old `make bump-version` recipe, which used GNU-only
`sed -i` and GNU-grep `\\+` quantifiers and could not run on BSD/macOS.
The recipe is unchanged: validate the version, rewrite alire.toml and
alire-dev.toml, regenerate src/adacovex_version_info.ads, create or update
the alire release manifest, the index entry, and the changelog, then sync
the crate descriptions into every manifest.

Usage:
  python3 tools/bump-version.py 1.28.0

Exit code 0 on success, 1 when the version is malformed or a manifest
cannot be updated (prints the same usage hint as the Makefile target).
"""

import argparse
import datetime
import re
import subprocess
import sys
from pathlib import Path
from typing import List, Optional, Tuple

from versions import find_version, set_manifest_version, version_key

ROOT: Path = Path(__file__).resolve().parent.parent
VERSION_RE: str = r"^\d+\.\d+\.\d+$"

# Files the recipe rewrites and their template sources for first-time
# creation (template, target, description).
TEMPLATES: Tuple[Tuple[str, str, str], ...] = (
    ("alire/releases/covex-0.0.0.toml", "alire/releases/covex-{v}.toml",
     "release manifest"),
    ("index/ad/covex/covex-0.1.0-dev.toml", "index/ad/covex/covex-{v}.toml",
     "index entry"),
)


def run_dev_script(name: str) -> int:
    """Run a tools/*.py script from the repository root (inherits env)."""
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / name)],
        cwd=str(ROOT),
    )
    return result.returncode


def previous_changelog_version(current: str) -> str:
    """Return the newest changelog version below the current one, or 0.0.0."""
    versions: List[str] = []
    for path in (ROOT / "docs" / "changelogs").glob("adacovex-*.md"):
        version = find_version(path.name)
        if version is not None and version != current:
            versions.append(version)
    if not versions:
        return "0.0.0"
    return max(versions, key=version_key)


def rewrite_manifest(path: Path, version: str, label: str) -> bool:
    """Rewrite one manifest's version line and report it."""
    if not set_manifest_version(path, version):
        return False
    print(f"  {label}: version = \"{version}\"")
    return True


def scaffold_changelog(version: str) -> bool:
    """Create or update the docs/changelogs/adacovex-VERSION.md file."""
    path = ROOT / "docs" / "changelogs" / f"adacovex-{version}.md"
    if not path.is_file():
        prev = previous_changelog_version(version)
        today = datetime.date.today().isoformat()
        lines = [
            f"# adacovex {version}",
            "",
            f"Date: _{today}_",
            "",
            f"Version bumped {prev} -> {version}.",
            "",
            "## Changes",
            "",
            "### C1: <Title>",
            "",
            "## Test Suite",
            "",
            "## Proof Results",
            "",
            "## Traceability",
            "",
        ]
        path.write_text("\n".join(lines), encoding="utf-8")
        print(f"  Created: {path} (fill in the ### C1: subsection)")
    else:
        text = path.read_text(encoding="utf-8")
        new_text, count = re.subn(
            r'^version = "[^"]*"', f'version = "{version}"', text,
            flags=re.MULTILINE,
        )
        if count:
            path.write_text(new_text, encoding="utf-8")
        print(f"  Updated: {path}")
    return True


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    version: str = args.version
    if not re.match(VERSION_RE, version):
        print(f"Error: version must be in x.y.z format (got: {version})")
        return 1

    print(f"Bumping version to {version}...")
    if not rewrite_manifest(ROOT / "alire.toml", version, "alire.toml"):
        return 1
    if not rewrite_manifest(ROOT / "alire-dev.toml", version, "alire-dev.toml"):
        return 1

    if run_dev_script("gen-version.py") != 0:
        print("error: tools/gen-version.py failed", file=sys.stderr)
        return 1
    print('  src/adacovex_version_info.ads: Version = "%s" (generated)' % version)

    for template, target_pattern, label in TEMPLATES:
        target = ROOT / target_pattern.format(v=version)
        if not target.is_file():
            template_path = ROOT / template
            if not template_path.is_file():
                print(f"error: template missing: {template}", file=sys.stderr)
                return 1
            text = template_path.read_text(encoding="utf-8")
            new_text = re.sub(
                r'^version = "[^"]*"', f'version = "{version}"', text,
                flags=re.MULTILINE,
            )
            target.write_text(new_text, encoding="utf-8")
            print(f"  Created: {target}")
        else:
            if not set_manifest_version(target, version):
                return 1
            print(f"  Updated: {target}")

    if not scaffold_changelog(version):
        return 1

    if run_dev_script("update-description.py") != 0:
        print("error: tools/update-description.py failed", file=sys.stderr)
        return 1
    print("  descriptions synced to all manifests")
    print(f"Done. Version bumped to {version}.")
    print("Next: run 'make release VERSION=%s' to build, prove, validate," % version)
    print("bundle, commit, and tag the release (or 'make publish' to submit")
    print("to the Alire community index once the tag is pushed).")
    return 0


def parse_args(argv: Optional[List[str]]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("version", help="target version in x.y.z format")
    return parser.parse_args(argv)


if __name__ == "__main__":
    sys.exit(main())