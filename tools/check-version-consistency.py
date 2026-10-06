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

The toolchain pin is a second dimension: `alire-dev.toml` pins gnatprove, and
every `gnat-version` in `action.yml` and the workflows must name the same
release, or a CI job proves the tree with a prover no record names.  The two
prose examples that illustrate a version-set expression must carry the live
major so a reader is not left thinking an older tool is current.  History
(the changelogs and the release/index manifests) is never
gated, because an old pin in a dated record is correct.

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


# --- gnatprove pin dimension ----------------------------------------------
# The gnatprove version is pinned in the dev manifest and selected by every
# CI job and by the composite action.  A drift is silent: a workflow picks a
# toolchain the manifest does not pin, and the proof runs against a prover no
# release record names.  This dimension gates every live pin against the
# alire-dev.toml pin, and keeps the two prose examples that illustrate a
# version-set expression from going stale.
GNATPROVE_MANIFEST: Path = ROOT / "alire-dev.toml"
GNATPROVE_RE: str = r'^gnatprove\s*=\s*"\^?([^"]+)"'
GNAT_VERSION_RE: str = r"gnat-version:\s*['\"]?(\d+\.\d+\.\d+)"
# Live pins that must all name the same gnatprove version.
GATED_GNAT_FILES: Tuple[Path, ...] = (
    ROOT / "action.yml",
    ROOT / ".github" / "workflows" / "ci.yml",
    ROOT / ".github" / "workflows" / "pr-check.yml",
    ROOT / ".github" / "workflows" / "release.yml",
)
# Prose examples that must carry the live major, so a reader is never left
# thinking an older tool is current.
GNATPROVE_EXAMPLES: Tuple[Path, ...] = (
    ROOT / "src" / "core" / "adacovex-prove.ads",
    ROOT / "docs" / "api-docs" / "adacovex-prove.md",
)
# History the gate must never flag or rewrite: an old pin in a release record
# is correct history, and a gate that flagged it would be deleted on sight.
GNATPROVE_HISTORICAL: Tuple[str, ...] = (
    "docs/changelogs/", "alire/releases/", "index/",
)


def gnatprove_pin() -> Optional[str]:
    """Return the bare gnatprove version pinned in alire-dev.toml, or None."""
    if not GNATPROVE_MANIFEST.is_file():
        return None
    match = re.search(GNATPROVE_RE,
                      GNATPROVE_MANIFEST.read_text(errors="replace"), re.M)
    return match.group(1) if match else None


def _gnat_versions(path: Path) -> List[str]:
    """Return every version a `gnat-version` key names in a YAML file.

    A workflow puts the value on the key's own line; the composite action
    puts it on a `default:` line up to three lines below the key.
    """
    versions: List[str] = []
    lines: List[str] = path.read_text(errors="replace").splitlines()
    for index, line in enumerate(lines):
        match = re.search(GNAT_VERSION_RE, line)
        if match:
            versions.append(match.group(1))
            continue
        if re.match(r"\s*gnat-version:", line):
            for following in lines[index + 1:index + 4]:
                match = re.search(r"default:\s*['\"]?(\d+\.\d+\.\d+)",
                                  following)
                if match:
                    versions.append(match.group(1))
                    break
    return versions


def check_gnatprove() -> List[str]:
    """Return one message per live gnatprove pin that disagrees."""
    problems: List[str] = []
    pin = gnatprove_pin()
    if pin is None:
        problems.append("alire-dev.toml: no gnatprove pin found")
        return problems
    for path in GATED_GNAT_FILES:
        if not path.is_file():
            continue
        rel = str(path.relative_to(ROOT))
        # A historical file can never be a live pin source; guarding the set
        # is what keeps the whitelist honest.
        if any(rel.startswith(prefix) for prefix in GNATPROVE_HISTORICAL):
            problems.append(
                f"{rel}: a historical file must never be a live gnatprove pin")
            continue
        for found in _gnat_versions(path):
            if found != pin:
                problems.append(
                    f"{rel}: gnat-version {found}, but "
                    f"alire-dev.toml pins gnatprove {pin}")
    ledger = ROOT / "docs" / "proof" / f"{pin}-ledger.md"
    if not ledger.is_file():
        problems.append(
            f"docs/proof/{pin}-ledger.md: no proof ledger for the pinned "
            f"gnatprove {pin}")
    for path in GNATPROVE_EXAMPLES:
        if not path.is_file():
            continue
        if f"^{pin}" not in path.read_text(errors="replace"):
            problems.append(
                f"{path.relative_to(ROOT)}: version-set example does not "
                f"show ^{pin} (a stale example reads as if an older tool is "
                f"current)")
    return problems


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
    problems += check_gnatprove()
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
