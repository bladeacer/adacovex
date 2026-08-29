#!/usr/bin/env python3
"""Build the project (adacovex + test_runner, covex alias).

The old `make build` recipe chained six steps in one shell line: regenerate
the version Ada spec, regenerate the dashboard template, run `alr build`
with the log diverted to a temp file, filter the benign ld 2.44 SFrame
message out of the log, drop the temp file, and symlink `bin/covex` to
`bin/adacovex` when the build succeeded.  That chain is easy to break with
a stray quoting or `set -e` change, so this script owns it:

  python3 tools/build.py

Steps, in order:

1. `python3 tools/gen-version.py`  -- regenerate src/adacovex_version_info.ads
   from alire-dev.toml (or ADACOVEX_VERSION); byte-identical when unchanged.
2. `python3 tools/gen-dashboard.py` -- regenerate
   src/adacovex-dashboard_template.ads from resources/.
3. `python3 tools/gen-docs.py` -- regenerate
   src/adacovex-docs_template.ads (the bundled offline manual) from the
   mdBook docs source; byte-identical when the docs are unchanged.
4. `alr build` with stdout+stderr captured, the log filtered by
   tools/filter-sframe.py (the benign SFrame notice), and the filtered
   output printed to stdout.
5. On success only, symlink `bin/covex` -> `bin/adacovex` (the Alire
   crate alias), so both names resolve to the freshly built binary.

Exit code is alr's (0 on success).  A failure in any earlier step aborts
the build like the old `&&`-chained recipe did.  gen-docs.py never fails
when mdbook is missing (it keeps the committed spec), so the build still
works on a machine without the docs toolchain.
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


def build() -> int:
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

    print("=== alr build ===")
    result = run_capture(["alr", "build"])
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
        covex.symlink_to("adacovex")
        print("linked bin/covex -> bin/adacovex")
    else:
        if filtered.stderr:
            sys.stderr.write(filtered.stderr)
    return result.returncode


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    return parser.parse_args(argv)


def main() -> int:
    parse_args(sys.argv[1:])
    return build()


if __name__ == "__main__":
    sys.exit(main())
