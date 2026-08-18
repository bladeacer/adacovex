#!/usr/bin/env python3
"""Shared repo-file discovery for the doc-sync tools.

Both tools/update-proof-status.py and tools/update-test-count.py rewrite
anchored metric phrases (VC counts, SPARK level, test counts) across the
repo.  The file set must be derived from the tree, not maintained as a
hardcoded list, so a new doc file carrying a metric is picked up
automatically and can never go stale.  This module owns that discovery.

Rules:

  * every text file under the repo root is a candidate;
  * generated outputs are excluded: docs/api-docs/ (gnatdoc), docs/badges/
    (SVG), docs/test_result.md (make test), sbom.json, obj/, bin/,
    the Alire build state (alire.lock, alire/settings.toml,
    alire/build_hash_inputs), and the two generated Ada specs
    (src/adacovex_version_info.ads, src/adacovex-dashboard_template.ads);
  * historical records are excluded: past-release changelogs
    (docs/changelogs/adacovex-<v>.md other than the current dev changelog
    derived from the version in alire-dev.toml) and past proof ledgers
    (docs/proof/*-ledger.md other than the one for the gnatprove version
    pinned in alire-dev.toml) -- those must keep their release-time numbers;
  * the tool scripts themselves (tools/*.py) are excluded: they contain the
    anchored patterns as regex source and must never be rewritten.

The release + index manifests (alire/releases/*.toml, index/**/covex-*.toml)
carry the crate description, which embeds the same test/proof phrases, so
they ARE scanned -- keeping them in sync with the canonical
alire/long-description.txt in the same pass is exactly what prevents
`make description CHECK=1` (and therefore bump-version / release) from
re-propagating a stale count.
"""

import re
from pathlib import Path
from typing import Iterator, Optional

ROOT: Path = Path(__file__).resolve().parent.parent

# Directories that never carry live metric phrases.
GENERATED_DIRS: frozenset = frozenset({
    ".git", "obj", "bin", "dist", "docs/api-docs", "docs/badges", "tools",
})

# Individual generated/build-state files.
GENERATED_FILES: frozenset = frozenset({
    "docs/test_result.md",
    "sbom.json",
    "src/adacovex_version_info.ads",
    "src/adacovex-dashboard_template.ads",
})

# Text suffixes a metric phrase could appear in.
TEXT_SUFFIXES: frozenset = frozenset({".md", ".toml", ".yml", ".yaml", ".map", ".txt"})


def dev_version() -> Optional[str]:
    """Return the `version = "x.y.z"` from alire-dev.toml, or None."""
    path: Path = ROOT / "alire-dev.toml"
    if not path.exists():
        return None
    m: Optional[re.Match] = re.search(
        r'^version\s*=\s*"(\d+\.\d+\.\d+)"', path.read_text(errors="replace"),
        re.M,
    )
    return m.group(1) if m else None


def gnatprove_version() -> Optional[str]:
    """Return the gnatprove version pinned in alire-dev.toml, or None."""
    path: Path = ROOT / "alire-dev.toml"
    if not path.exists():
        return None
    m: Optional[re.Match] = re.search(
        r'^gnatprove\s*=\s*"\^?(\d+\.\d+\.\d+)"',
        path.read_text(errors="replace"),
        re.M,
    )
    return m.group(1) if m else None


def current_changelog() -> Path:
    """Path of the current dev changelog (derived, never hardcoded)."""
    v: Optional[str] = dev_version()
    return ROOT / "docs" / "changelogs" / (f"adacovex-{v}.md" if v else ".none")


def current_ledger() -> Path:
    """Path of the current proof ledger (derived, never hardcoded)."""
    v: Optional[str] = gnatprove_version()
    return ROOT / "docs" / "proof" / (f"{v}-ledger.md" if v else ".none")


def iter_live_files() -> Iterator[Path]:
    """Yield every repo file whose metric phrases may need syncing."""
    current: frozenset = frozenset({current_changelog(), current_ledger()})
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        rel: Path = p.relative_to(ROOT)
        parts: tuple = rel.parts
        # Generated/build/VCS dirs (prefix match on any path segment).
        if any(part in GENERATED_DIRS for part in parts):
            continue
        if rel.as_posix() in GENERATED_FILES:
            continue
        # Historical changelogs/ledgers except the current ones.
        if parts[:2] in {("docs", "changelogs"), ("docs", "proof")} \
                and p not in current:
            continue
        # Only text files that could carry metric phrases.
        if p.name != "Makefile" and p.suffix not in TEXT_SUFFIXES:
            continue
        # Skip binary files (NUL-byte sniff) and unreadable files.
        try:
            data: bytes = p.read_bytes()
        except OSError:
            continue
        if b"\x00" in data:
            continue
        yield p


def live_files() -> list:
    """All live files as a sorted list (stable order for --check output)."""
    return sorted(iter_live_files(), key=lambda p: p.relative_to(ROOT).as_posix())
