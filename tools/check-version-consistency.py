#!/usr/bin/env python3
"""Fail when the tree, the built binary, and the SBOM disagree on the version.

The version is copied into four places, and each is derived from a
different source, so they can drift apart silently:

  alire.toml / alire-dev.toml   the source of truth (make bump-version)
  src/adacovex_version_info.ads the generated Ada constant the binary
                                 compiles (tools/gen-version.py)
  bin/adacovex --version        the version actually linked into the
                                 executable
  sbom.json metadata.tools[]    the version the tool recorded when it wrote
                                 the SBOM (the SBOM root component version
                                 is read from the manifest instead, so the
                                 two can disagree inside one file)

That drift is not cosmetic.  `make release` used to prove the tree *before*
it built the release binary, so the proof pass, its result-cache namespace,
and every artifact it wrote (sbom.json, docs/badges/*.svg) came from the
previous release's binary.  The committed 1.54.0 tree carried the result:
sbom.json named tool version 1.53.0 against component version 1.54.0.
tools/release.py now builds first and calls
`release.verify_binary_version`; this gate is the tree-wide backstop, so a
stale binary, an un-regenerated version spec, or a mismatched manifest
fails `make check` instead of shipping.

Usage:
  python3 tools/check-version-consistency.py

Each check that needs a build product is skipped when that product is
absent, so the gate is meaningful in a fresh checkout before `make build`.

Exit code 0 when every available version source agrees, 1 on any mismatch.
"""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

# The two manifests `make bump-version` rewrites together.
MANIFESTS: Tuple[Path, ...] = (ROOT / "alire.toml", ROOT / "alire-dev.toml")

# The generated Ada spec the binary compiles the version from.
VERSION_SPEC: Path = ROOT / "src" / "adacovex_version_info.ads"

# The binary the release ships, and the SBOM the release commits.
BINARY: Path = ROOT / "bin" / "adacovex"
SBOM: Path = ROOT / "sbom.json"

MANIFEST_RE: str = r'^version\s*=\s*"([^"]+)"'
SPEC_RE: str = r'Version\s*:\s*constant\s+String\s*:=\s*"([^"]+)"'
SBOM_TOOL_RE: str = r'"name"\s*:\s*"adacovex"\s*,\s*"version"\s*:\s*"([^"]+)"'
SBOM_ROOT_RE: str = r'"purl"\s*:\s*"pkg:alire/covex@([^"]+)"'


def manifest_version(path: Path) -> Optional[str]:
    """Return the first `version = "x.y.z"` value in a TOML manifest."""
    if not path.is_file():
        return None
    for line in path.read_text(errors="replace").splitlines():
        match = re.match(MANIFEST_RE, line.strip())
        if match:
            return match.group(1)
    return None


def spec_version(path: Optional[Path] = None) -> Optional[str]:
    """Return the version constant from the generated Ada spec."""
    path = VERSION_SPEC if path is None else path
    if not path.is_file():
        return None
    match = re.search(SPEC_RE, path.read_text(errors="replace"))
    return match.group(1) if match else None


def binary_version(path: Optional[Path] = None) -> Optional[str]:
    """Return the version `bin/adacovex --version` reports, or None."""
    path = BINARY if path is None else path
    if not path.is_file():
        return None
    result = subprocess.run([str(path), "--version"],
                            capture_output=True, text=True)
    if result.returncode != 0:
        return None
    tokens = result.stdout.strip().split()
    return tokens[-1].lstrip("v") if tokens else None


def sbom_versions(path: Optional[Path] = None) -> Tuple[Optional[str], Optional[str]]:
    """Return (tool version, root component version) from a committed SBOM."""
    path = SBOM if path is None else path
    if not path.is_file():
        return None, None
    text = path.read_text(errors="replace")
    tool = re.search(SBOM_TOOL_RE, text)
    root = re.search(SBOM_ROOT_RE, text)
    return (tool.group(1) if tool else None,
            root.group(1) if root else None)


def check(expected: str) -> List[str]:
    """Return one message per mismatch against the alire.toml version."""
    problems: List[str] = []
    for manifest in MANIFESTS:
        found = manifest_version(manifest)
        label = manifest.relative_to(ROOT)
        if found is None:
            problems.append(f"{label}: no version line found")
        elif found != expected:
            problems.append(
                f"{label}: version = {found}, but alire.toml says {expected}")
    found = spec_version()
    if found is None:
        problems.append(f"{VERSION_SPEC.relative_to(ROOT)}: no Version constant")
    elif found != expected:
        problems.append(
            f"{VERSION_SPEC.relative_to(ROOT)}: Version = {found}, expected "
            f"{expected} (run 'python3 tools/gen-version.py')")
    found = binary_version()
    if found is not None and found != expected:
        problems.append(
            f"bin/adacovex: reports v{found}, expected v{expected} (the binary "
            f"is stale; run 'make build')")
    tool, root = sbom_versions()
    if tool is not None and tool != expected:
        problems.append(
            f"sbom.json: tool version {tool} does not match the release "
            f"version {expected} (regenerate with 'make sbom')")
    if root is not None and tool is not None and root != tool:
        problems.append(
            f"sbom.json: tool version {tool} disagrees with the root "
            f"component version {root} in the same file")
    return problems


def main() -> int:
    expected = manifest_version(ROOT / "alire.toml")
    if expected is None:
        print("error: alire.toml has no version line", file=sys.stderr)
        return 1
    problems = check(expected)
    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 1
    built = binary_version()
    print(f"ok: every version source agrees on v{expected}"
          + ("" if built is not None else " (bin/adacovex not built yet)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
