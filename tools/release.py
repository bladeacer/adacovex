#!/usr/bin/env python3
"""Orchestrate a release: prove, build, validate, gate, bundle, tag, push.

The old `make release` recipe was a ~60-line shell block: version
resolution, a proof pass, a release build, a self-assessment, a coverage
gate against the previous tag, a changelog listing, artifact bundling,
attestation, manifest version bumps, and finally tag + push.  Each step
was a separate `;`-chained shell fragment with its own quoting, so a
broken step aborted mid-release with no way to resume.  This script owns
the flow:

  python3 tools/release.py [--version=x.y.z] [--self-assess-args="..."]
                           [--repo=owner/name] [--dry-run]

`--self-assess-args` overrides the acceptance-gate flags; the default is
the canonical set owned by tools/run.py (`run.py assess-args`), so a gate
change lands in one place.

Steps, in order:

1. Prove: `adacovex prove --target=. <self-assess-args> --emit-svg=docs/badges/`
2. Build the release binary (ADACOVEX_VERSION forces the tag version into
   src/adacovex_version_info.ads, then `alr build --release`).
3. Validate: self-assessment with the same acceptance gates.
4. Coverage gate: `--coverage-delta` against the previous release tag.
5. List the changelogs covered by this release.
6. Bundle dist/ + the two tarballs (binary + action).
7. Attest the tarballs with `gh attest` when gh + GITHUB_TOKEN are present.
8. Bump the index + release manifests, sync descriptions, tag and push.

`--dry-run` runs steps 1-7 and the manifest bumps, but prints (and skips)
the irreversible git commit / tag / push operations -- use it to verify a
release before it goes out.  `--repo` overrides the attestation repo
(default: the GITHUB_REPOSITORY env var or bladeacer/adacovex).
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path
from typing import List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent

TAG_RE: str = r"^v\d+\.\d+\.\d+$"
INDEX_TEMPLATE: str = "index/ad/covex/covex-0.1.0-dev.toml"
RELEASE_TEMPLATE: str = "alire/releases/covex-0.0.0.toml"


def sh(cmd: List[str], check: bool = True, **kwargs) -> subprocess.CompletedProcess:
    """Run a command at the repo root, failing loudly on a bad exit code."""
    return subprocess.run(cmd, cwd=str(ROOT), **kwargs, check=check)


def source_date_epoch() -> str:
    """Commit timestamp for reproducible SVG/HTML output (0 when no HEAD)."""
    result = sh(["git", "show", "-s", "--format=%ct", "HEAD"],
                check=False, capture_output=True, text=True)
    return result.stdout.strip() or "0"


def resolve_version(arg: str) -> str:
    """Version from --version, else the current alire.toml version."""
    if arg:
        return arg[1:] if arg.startswith("v") else arg
    result = sh([sys.executable, str(ROOT / "tools" / "versions.py"),
                 "current", "--file", "alire.toml"],
                capture_output=True, text=True)
    return result.stdout.strip()


def release_tags() -> List[str]:
    """Release tags (vX.Y.Z only), newest first."""
    result = sh(["git", "tag", "--sort=-version:refname"],
                capture_output=True, text=True)
    return [line.strip() for line in result.stdout.splitlines()
            if re.match(TAG_RE, line.strip())]


def previous_tag(version: str) -> Optional[str]:
    """Newest release tag other than v<version>, or None."""
    target = f"v{version}"
    for tag in release_tags():
        if tag != target:
            return tag
    return None


def changelogs_for(version: str, previous: Optional[str]) -> List[str]:
    """Changelog paths between previous release (or earliest) and version."""
    def between(min_v: str, paths: List[str]) -> List[str]:
        result = sh(
            [sys.executable, str(ROOT / "tools" / "versions.py"), "between",
             min_v, version, "--exclude", version],
            input="\n".join(paths), capture_output=True, text=True,
        )
        return result.stdout.splitlines()

    if previous is not None:
        prev_num = previous[1:] if previous.startswith("v") else previous
    else:
        releases = sorted(glob.glob(str(ROOT / "alire/releases/covex-*.toml")))
        listed = between("", releases)
        prev_num = listed[0] if listed else ""
    return between(prev_num, sorted(
        glob.glob(str(ROOT / "docs/changelogs/adacovex-*.md"))))


def run_assessment(args: List[str], emit_svg: bool) -> int:
    """Run adacovex prove/self-assessment with the acceptance gates."""
    env = dict(os.environ)
    env["SOURCE_DATE_EPOCH"] = source_date_epoch()
    cmd = [str(ROOT / "bin" / "adacovex")] + args
    if emit_svg:
        cmd.append("--emit-svg=docs/badges/")
    result = sh(cmd, env=env, check=False)
    if result.returncode != 0:
        print(f"  stdout: {result.stdout.strip()}", file=sys.stderr)
        print(f"  stderr: {result.stderr.strip()}", file=sys.stderr)
    return result.returncode


def bundle(version: str) -> None:
    """Create dist/ and the release + action tarballs."""
    dist = ROOT / "dist"
    shutil.rmtree(dist, ignore_errors=True)
    dist.mkdir()
    shutil.copy2(ROOT / "bin" / "adacovex", dist / "adacovex")
    (dist / "covex").symlink_to("adacovex")
    shutil.copy2(ROOT / "install.sh", dist / "install.sh")
    (dist / "install.sh").chmod(0o755)
    shutil.copy2(ROOT / "LICENSE", dist / "LICENSE")
    shutil.copy2(ROOT / "docs" / "THIRD_PARTY_NOTICES.md",
                 dist / "THIRD_PARTY_NOTICES.md")

    def tarball(name: str, source: Path, members: str) -> None:
        with tarfile.open(ROOT / name, "w:gz") as tar:
            tar.add(source, arcname=members)

    tarball(f"adacovex-v{version}.tar.gz", dist, ".")
    tarball(f"adacovex-action-v{version}.tar.gz", ROOT / "action.yml", "action.yml")
    print(f"  Bundled: adacovex-v{version}.tar.gz, "
          f"adacovex-action-v{version}.tar.gz")


def attest(version: str, repo: str) -> None:
    """Attest both tarballs with actions/attest when gh + a token exist."""
    print("=== Attesting release artifacts (actions/attest) ===")
    if shutil.which("gh") is None:
        print("  gh not installed; skipping local attestation.")
        print("  (CI attests these artifacts with OIDC on the v"
              f"{version} tag push.)")
        return
    if not os.environ.get("GITHUB_TOKEN"):
        print("  gh found but GITHUB_TOKEN is not set; skipping local attestation.")
        print("  (CI attests these artifacts with OIDC on the v"
              f"{version} tag push.)")
        return
    result = sh(
        ["gh", "attest", f"adacovex-v{version}.tar.gz",
         f"adacovex-action-v{version}.tar.gz", "--repo", repo],
        check=False,
    )
    if result.returncode == 0:
        print("  Attestations created locally.")
    else:
        print(f"  gh attest failed (rc={result.returncode}); continuing.")


def bump_manifests(version: str) -> None:
    """Create/version the index + release manifests and sync descriptions."""
    index_file = ROOT / "index" / "ad" / "covex" / f"covex-{version}.toml"
    if not index_file.is_file():
        shutil.copy2(ROOT / INDEX_TEMPLATE, index_file)
    sh([sys.executable, str(ROOT / "tools" / "versions.py"), "set-version",
        str(index_file), version], capture_output=True, text=True)

    release_file = ROOT / "alire" / "releases" / f"covex-{version}.toml"
    if not release_file.is_file():
        shutil.copy2(ROOT / RELEASE_TEMPLATE, release_file)
    sh([sys.executable, str(ROOT / "tools" / "versions.py"), "set-version",
        str(release_file), version], capture_output=True, text=True)

    sh([sys.executable, str(ROOT / "tools" / "update-description.py")],
       capture_output=True, text=True)
    print("  descriptions synced to all manifests")


def git_tag_ops(version: str, dry_run: bool) -> None:
    """Commit, tag and push the release (skipped entirely under --dry-run)."""
    tag = f"v{version}"
    if dry_run:
        print(f"  [dry-run] would commit 'chore: Release {version}', "
              f"tag {tag}, and push HEAD + {tag}")
        return
    exists = sh(["git", "rev-parse", tag], check=False,
                capture_output=True, text=True).returncode == 0
    if exists:
        sh(["git", "tag", "-d", tag], capture_output=True, text=True)
        sh(["git", "push", "origin", f":refs/tags/{tag}"],
            capture_output=True, text=True)
        print(f"  Replaced existing tag {tag}")
    sh(["git", "add", "-A"])
    sh(["git", "commit", "-m", f"chore: Release {version}"], check=False)
    sh(["git", "tag", "-a", tag, "-m", f"Release {version}"])
    commit = sh(["git", "rev-parse", "HEAD"], capture_output=True, text=True)
    print(f"Tagged {tag} at {commit.stdout.strip()}")
    sh(["git", "push", "origin", "HEAD"])
    sh(["git", "push", "origin", tag])
    print("Pushed commit and tag " + tag)


def release(version_arg: str, assess_args: str, repo: str, dry_run: bool) -> int:
    version = resolve_version(version_arg)
    if version_arg:
        # An explicit VERSION=x.y.z rewrites alire.toml up front (as the old
        # recipe did), so the release manifest carries the new version.
        sh([sys.executable, "tools/versions.py", "set-version",
            "alire.toml", version], capture_output=True, text=True)
    if assess_args:
        assess = assess_args.split()
    else:
        result = sh([sys.executable, "tools/run.py", "assess-args"],
                    capture_output=True, text=True)
        assess = result.stdout.strip().split()
    print(f"=== Releasing v{version} ===\n")

    print("=== Generating proof artifacts ===")
    proof_ok = False
    for attempt in range(1, 4):
        if run_assessment(["prove", "--target=."] + assess, emit_svg=True) == 0:
            proof_ok = True
            break
        print(f"  proof attempt {attempt}/3 failed; retrying..." if attempt < 3
              else "  proof attempt 3/3 failed", file=sys.stderr)
    if not proof_ok:
        print("ERROR: proof pass failed; aborting release", file=sys.stderr)
        return 1

    print(f"=== Building release binary (covex v{version}) ===")
    env = dict(os.environ)
    env["ADACOVEX_VERSION"] = version
    if sh([sys.executable, "tools/gen-version.py"], env=env).returncode != 0:
        return 1
    if sh(["alr", "build", "--release"], env=env).returncode != 0:
        return 1

    print("=== Validating self-assessment (DAL-C) ===")
    if run_assessment(["--target=."] + assess, emit_svg=True) != 0:
        print("ERROR: self-assessment failed; aborting release", file=sys.stderr)
        return 1

    print("=== Docstring coverage gate (last release vs current) ===")
    previous = previous_tag(version)
    if previous is None:
        print("  No previous release found; skipping coverage gate")
    else:
        print(f"  Comparing docstring coverage against {previous}")
        delta = sh(
            [str(ROOT / "bin" / "adacovex"), "--target=.",
             f"--coverage-delta={previous}"],
            env=env, check=False,
        ).returncode
        if delta != 0:
            print(f"  ERROR: docstring coverage regressed vs {previous}; "
                  "aborting release", file=sys.stderr)
            return 1

    print(f"=== Changelogs (last release to v{version}) ===")
    for changelog in changelogs_for(version, previous):
        print(f"  - {Path(changelog).name}")

    print("=== Bundling release artifacts ===")
    bundle(version)
    attest(version, repo)

    bump_manifests(version)
    git_tag_ops(version, dry_run)

    print("\nNext: run 'make publish' to submit to Alire community index.")
    return 0


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--version", default="",
                        help="version to release (default: current alire.toml)")
    parser.add_argument("--self-assess-args", default="",
                        help="acceptance-gate flags passed to prove/assess")
    parser.add_argument("--repo",
                        default=os.environ.get("GITHUB_REPOSITORY", "bladeacer/adacovex"),
                        help="repo used for attestation (default: GITHUB_REPOSITORY)")
    parser.add_argument("--dry-run", action="store_true",
                        help="run every step but skip commit/tag/push")
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])
    return release(args.version, args.self_assess_args, args.repo, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
