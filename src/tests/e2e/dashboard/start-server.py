#!/usr/bin/env python3
"""Start the adacovex dashboard server for the Playwright e2e suite."""
import os
import subprocess
import sys
from pathlib import Path


def repo_root() -> Path:
    """The repository root, found by its GPR marker.

    @return The directory holding adacovex.gpr.
    """
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "adacovex.gpr").is_file():
            return parent
    return here.parents[4]


def main() -> int:
    """Run `--serve` until interrupted.

    @return The server's exit code.
    """
    root = repo_root()
    adacovex = root / "bin" / "adacovex"
    if os.name == "nt":
        adacovex = root / "bin" / "adacovex.exe"

    # Build if needed.
    if not adacovex.exists():
        print("Building adacovex...", file=sys.stderr)
        subprocess.run([sys.executable, "tools/build.py"], cwd=root, check=True)

    # Start server.
    cmd = [str(adacovex), "--serve", "--port=8080"]
    print(f"Starting: {' '.join(cmd)}", file=sys.stderr)
    proc = subprocess.Popen(cmd, cwd=root)
    try:
        proc.wait()
    except KeyboardInterrupt:
        proc.terminate()
        proc.wait()
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
