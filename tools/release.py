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

1. Build the release binary: `ADACOVEX_VERSION` forces the tag version into
   src/adacovex_version_info.ads, then `tools/build.py --release` runs the
   same regeneration steps as a dev build (version spec, CSS gate,
   dashboard, bundled manual) and `alr build --release`.
2. Verify the built binary reports the release version.
3. Prove: `adacovex prove --target=. <self-assess-args> --emit-svg=docs/badges/`
4. Validate: self-assessment with the same acceptance gates.
5. Coverage gate: `--coverage-delta` against the previous release tag.
6. List the changelogs covered by this release.
7. Bundle dist/ + the two tarballs (binary + action).
8. Attest the tarballs with `gh attest` when gh + GITHUB_TOKEN are present.
9. Bump the index + release manifests, sync descriptions, tag and push.

The build runs first on purpose.  Every later step shells out to
`bin/adacovex`, so proving before building proves the *previous* release's
binary: its banner reports the old version, its result cache is the old
version's namespace, and any artifact it writes (sbom.json, docs/badges/*.svg)
records that old version while the manifests already carry the new one.  The
committed 1.54.0 tree held exactly that pair (SBOM tool version 1.53.0
against component version 1.54.0).  `verify_binary_version` turns any
residual drift into a hard abort instead of a wrong artifact.

`--dry-run` runs steps 1-8 and the manifest bumps, but prints (and skips)
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


def binary_path() -> Path:
    """The built binary, in the runnable form this host uses.

    On POSIX that is `bin/adacovex`; on Windows the build emits
    `bin/adacovex.exe`, and a test or CI launcher may be a `bin/adacovex.cmd`
    next to the plain name.  The names are probed in that order, so the real
    binary always wins over a launcher.
    """
    exe = ROOT / "bin" / "adacovex"
    if os.name == "nt":
        for name in ("adacovex.exe", "adacovex.cmd", "adacovex.bat"):
            alt = ROOT / "bin" / name
            if alt.is_file():
                return alt
    return exe

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
    cmd = [str(binary_path())] + args
    if emit_svg:
        cmd.append("--emit-svg=docs/badges/")
    result = sh(cmd, env=env, check=False)
    if result.returncode != 0:
        print(f"  stdout: {result.stdout.strip()}", file=sys.stderr)
        print(f"  stderr: {result.stderr.strip()}", file=sys.stderr)
    return result.returncode


def build_release_binary(version: str) -> int:
    """Build the release binary with the tag version forced into the spec.

    Delegates to tools/build.py --release so the release runs the same
    regeneration steps as a dev build (version spec, CSS gate, dashboard
    template, bundled offline manual) and only the `alr` profile differs.
    """
    env = dict(os.environ)
    env["ADACOVEX_VERSION"] = version
    return sh([sys.executable, "tools/build.py", "--release"],
              env=env).returncode


def verify_binary_version(version: str) -> bool:
    """Fail when bin/adacovex does not report the release version.

    A release that bundles one version and proves another is the exact
    failure this guard exists for, so the check is cheap and unconditional:
    run `--version` and compare the token the banner prints.
    """
    try:
        result = sh([str(binary_path()), "--version"],
                    check=False, capture_output=True, text=True)
    except OSError as exc:
        print(f"ERROR: cannot run {binary_path()}: {exc}", file=sys.stderr)
        return False
    if result.returncode != 0:
        print(f"ERROR: {binary_path().name} --version failed (rc={result.returncode})",
              file=sys.stderr)
        return False
    reported = result.stdout.strip().split()[-1].lstrip("v")
    if reported != version:
        print(f"ERROR: bin/adacovex reports v{reported} but the release is "
              f"v{version}; the binary is stale. Rebuild with "
              f"'just build' and retry.", file=sys.stderr)
        return False
    print(f"  bin/adacovex reports v{reported}: matches the release version.")
    return True


def bundle(version: str) -> None:
    """Create dist/ and the release + action tarballs."""
    dist = ROOT / "dist"
    shutil.rmtree(dist, ignore_errors=True)
    dist.mkdir()
    shutil.copy2(binary_path(), dist / "adacovex")
    try:
        (dist / "covex").symlink_to("adacovex")
    except OSError:
        #  Windows refuses a symlink without elevation; copy the alias
        #  instead, exactly as tools/build.py does for bin/covex.
        shutil.copy2(dist / "adacovex", dist / "covex")
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


def local_tag_sha(tag: str) -> Optional[str]:
    """The commit a local `tag` peels to, or None when there is no such tag.

    An annotated tag has two identities: the tag object, and the commit it
    peels to.  Only the peeled commit is comparable with what a remote
    reports, so `rev-parse tag^{}` is what every comparison here uses.
    """
    result = sh(["git", "rev-parse", "--verify", "--quiet", f"{tag}^{{}}"],
                check=False, capture_output=True, text=True)
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def remote_tag_sha(tag: str) -> Optional[str]:
    """The commit origin's `tag` peels to, or None when origin has no such
    tag.

    A failed query is never reported as "no such tag".  The old replace path
    drove its decision from the *local* tag, so a remote tag this clone had
    never seen was invisible: the delete it attempted was skipped, and the
    following push was then refused because origin already had the tag.  That
    is the failure a release must not be able to reach, so an unreachable
    origin stops the run instead.
    """
    # The pattern must carry the trailing `*`.  ls-remote filters on the exact
    # ref, so naming `refs/tags/v1.58.0` returns the annotated tag OBJECT and
    # omits the `^{}` line that carries the commit -- comparing that object
    # against a commit SHA reports a false mismatch on a push that landed
    # perfectly.  The wildcard brings both lines back; an absent tag yields no
    # lines and a zero exit, which is how "no such tag" is spelled here.
    result = sh(["git", "ls-remote", "--tags", "origin", f"refs/tags/{tag}*"],
                check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(
            f"error: cannot ask origin whether {tag} exists, so the tag "
            f"state is unknown and the release would be a guess:\n"
            f"{result.stderr.strip()}")
    peeled = None
    direct = None
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        sha, ref = parts
        if ref == f"refs/tags/{tag}^{{}}":
            peeled = sha
        elif ref == f"refs/tags/{tag}":
            direct = sha
    # The peeled line wins: it is the commit, so it compares with a local tag.
    return peeled or direct


def push(spec: str, what: str) -> None:
    """Push one refspec, reporting a refusal in words instead of a traceback."""
    result = sh(["git", "push", "origin", spec], check=False,
                capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(
            f"error: failed to push {what} ({spec}).\n"
            f"{result.stderr.strip()}\n"
            f"If origin refused the tag, check Settings > Rules > Protected "
            f"tags: a protected tag cannot be created or replaced by a push, "
            f"so the rule has to be lifted before a release can land.")


def git_tag_ops(version: str, dry_run: bool) -> None:
    """Commit, tag and push the release.

    Idempotent by design.  A tag that origin already carries is replaced
    rather than fought with, because a re-run after a late failure is the
    normal case: the commit and tag step is the last one, so a failure
    anywhere before it leaves the previous attempt's tag behind.
    """
    tag = f"v{version}"
    # Read-only preflight. Both paths need it, and a dry run that cannot
    # report the tag state is not much of a rehearsal.
    local_sha = local_tag_sha(tag)
    remote_sha = remote_tag_sha(tag)
    if dry_run:
        print(f"  [dry-run] would commit 'chore: Release {version}', "
              f"tag {tag}, and push HEAD + {tag}")
        print(f"  [dry-run] local {tag}: {local_sha or 'no such tag'}")
        print(f"  [dry-run] origin {tag}: {remote_sha or 'no such tag'}")
        if local_sha or remote_sha:
            print(f"  [dry-run] would replace the existing {tag} first")
        return
    if local_sha or remote_sha:
        print(f"  Replacing existing tag {tag} "
              f"(local {local_sha or 'none'}, origin {remote_sha or 'none'})")
        if local_sha:
            sh(["git", "tag", "-d", tag], capture_output=True, text=True)
        if remote_sha:
            # Not best-effort: a silent failure here is what let the old code
            # push a tag origin already had.
            push(f":refs/tags/{tag}", f"the deletion of {tag}")
    sh(["git", "add", "-A"])
    sh(["git", "commit", "-m", f"chore: Release {version}"], check=False)
    sh(["git", "tag", "-a", tag, "-m", f"Release {version}"])
    commit = sh(["git", "rev-parse", "HEAD"], capture_output=True, text=True).stdout
    print(f"Tagged {tag} at {commit.strip()}")
    push("HEAD", "the release commit")
    push(tag, f"the tag {tag}")
    # Verify rather than trust: a push that reports success but lands nothing
    # is exactly the failure a release cannot discover later.
    landed = remote_tag_sha(tag)
    if landed is None or landed != commit.strip():
        raise SystemExit(
            f"error: origin does not carry {tag} at {commit.strip()} "
            f"after a successful push (it reports {landed or 'no such tag'}).")
    print(f"Pushed commit and {tag}, and verified {tag} on origin")


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

    print(f"=== Building release binary (covex v{version}) ===")
    if build_release_binary(version) != 0:
        print("ERROR: release build failed; aborting release", file=sys.stderr)
        return 1

    print("=== Verifying the release binary version ===")
    if not verify_binary_version(version):
        return 1

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
            [str(binary_path()), "--target=.",
             f"--coverage-delta={previous}"],
            check=False,
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

    print("\nNext: run 'just publish' to submit to Alire community index.")
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
