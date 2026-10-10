#!/usr/bin/env python3
"""Build the project (adacovex + test_runner, covex alias).

The old `make build` recipe chained six steps in one shell line: regenerate
the version Ada spec, regenerate the dashboard template, run `alr build`
with the log diverted to a temp file, filter the benign ld 2.44 SFrame
message out of the log, drop the temp file, and symlink `bin/covex` to
`bin/adacovex` when the build succeeded.  That chain is easy to break with
a stray quoting or `set -e` change, so this script owns it:

  python3 tools/build.py [--release]

Steps, in order:

1. `python3 tools/gen-version.py`  -- regenerate src/adacovex_version_info.ads
   from alire-dev.toml (or ADACOVEX_VERSION); byte-identical when unchanged.
2. `python3 tools/gen-dashboard.py` -- regenerate
   src/adacovex-dashboard_template.ads from resources/.
3. `python3 tools/gen-docs.py` -- regenerate
   src/adacovex-docs_template.ads (the bundled offline manual) from the
   Sphinx docs source (docs/conf.py + MyST); byte-identical when the docs
   are unchanged.
4. `alr build` (or `alr build --release` with `--release`) with stdout+stderr
   captured, the log filtered by tools/filter-sframe.py (the benign SFrame
   notice), and the filtered output printed to stdout.
5. On success only, symlink `bin/covex` -> `bin/adacovex` (the Alire
   crate alias), so both names resolve to the freshly built binary.

`--release` selects the release profile and is the single build entry point
for `make release`, so a release build runs exactly the same regeneration
steps (version spec, CSS gate, dashboard, bundled manual) as a dev build.  A
release build that skipped them could ship a binary whose bundled dashboard
or offline manual predates the source that produced it.

The build profile is selected from the same signal: a build is a release
build when `--release` is passed or when `ADACOVEX_VERSION` is set in the
environment (a release build stamps the version from the environment).  A
release build forwards the gprbuild external `ADACOVEX_PROFILE=release`
through to `alr build`, which selects the `Release` case of adacovex.gpr
(`-O2`, no `-g`); a development build forwards nothing and takes the
default `Development` case (`-O1`, with `-g`).  Every performance figure in
docs/contributing/perf/ is measured on the release profile.

Exit code is alr's (0 on success).  A failure in any earlier step aborts
the build like the old `&&`-chained recipe did.  gen-docs.py never fails
when sphinx-build is missing (it keeps the committed spec), so the build
still works on a machine without the docs toolchain.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List

ROOT: Path = Path(__file__).resolve().parent.parent


def run(cmd: List[str], env: dict = None) -> int:
    """Run a command, streaming its output through; return its exit code."""
    return subprocess.run(cmd, env=env, cwd=str(ROOT)).returncode


def run_capture(cmd: List[str]) -> subprocess.CompletedProcess:
    """Run a command capturing stdout+stderr (used for log filtering)."""
    return subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)


def build(release: bool = False) -> int:
    # A release build stamps the version from the environment, so an
    # ADACOVEX_VERSION in the environment selects the release profile even
    # without --release.  Both signals reach alr as --release, which Alire
    # maps to the Release external profile of adacovex.gpr.
    if not release and os.environ.get("ADACOVEX_VERSION"):
        release = True
    profile = "Release" if release else "Development"
    print(f"=== Build profile: {profile} ===")
    print("=== Regenerating version info ===")
    rc = run([sys.executable, "tools/gen-version.py"])
    if rc != 0:
        return rc
    print("=== CSS 4px spacing gate ===")
    rc = run([sys.executable, "tools/csslint.py", "--check"])
    if rc != 0:
        return rc

    print("=== Regenerating dashboard template ===")
    rc = run([sys.executable, "tools/gen-dashboard.py"])
    if rc != 0:
        return rc

    print("=== Regenerating bundled offline manual ===")
    rc = run([sys.executable, "tools/gen-docs.py"])
    if rc != 0:
        return rc

    command = ["alr", "build"] + (["--release"] if release else [])
    gpr_args: List[str] = []
    if release:
        gpr_args.append("-XADACOVEX_PROFILE=release")
    #  The Windows main-thread stack reserve lives in adacovex.gpr (package
    #  Linker, selected on the target OS), so a plain `alr build` and a
    #  consumer or Alire-index CI build carry it too -- not only this script.
    if gpr_args:
        command += ["--"] + gpr_args
    print(f"=== alr build{' --release' if release else ''} ===")
    result = run_capture(command)
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".log", delete=False
    ) as log:
        log.write(result.stdout)
        log.write(result.stderr)
        log_path = log.name
    # Filter the benign SFrame linker notice out of the log; the link still
    # succeeds, so a failing rc + a filtered log are both reported faithfully.
    filtered = subprocess.run(
        [sys.executable, "tools/filter-sframe.py", log_path],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    os.unlink(log_path)
    sys.stdout.write(filtered.stdout)
    sys.stdout.flush()

    if result.returncode == 0:
        covex = ROOT / "bin" / "covex"
        try:
            covex.unlink(missing_ok=True)
        except OSError:
            pass
        try:
            covex.symlink_to("adacovex")
            print("linked bin/covex -> bin/adacovex")
        except OSError:
            #  Windows refuses to create a symlink without elevation, and the
            #  binary is named adacovex.exe there; copy it under the covex
            #  alias instead so both names still resolve to the fresh build.
            try:
                import shutil

                src = ROOT / "bin" / "adacovex.exe"
                if not src.exists():
                    src = ROOT / "bin" / "adacovex"
                shutil.copyfile(src, ROOT / "bin" / src.name.replace(
                    "adacovex", "covex"))
                print("copied bin/covex (no symlink support on this host)")
            except OSError:
                print("note: could not create the bin/covex alias")
    else:
        if filtered.stderr:
            sys.stderr.write(filtered.stderr)
    return result.returncode


def parse_args(argv: List[str]) -> argparse.Namespace:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--release", action="store_true",
                    help="build the release profile (what `make release` uses)")
    return ap.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])
    return build(args.release)


if __name__ == "__main__":
    sys.exit(main())
