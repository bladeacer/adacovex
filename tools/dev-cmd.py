#!/usr/bin/env python3
"""Run a command with the dev manifest swapped in, then restore it.

`make doc` and `make fmt` run gnatdoc / gnatformat, which are dev
dependencies present only in `alire-dev.toml`.  The old Makefile `_dev_cmd`
helper copied `alire.toml` and `alire/` aside, swapped `alire-dev.toml` in
as `alire.toml`, ran the command, and restored both -- via a shell trap so
a failing command could never leave the tree on the dev manifest.  The
trap/quoting dance is easy to break, so this script owns it:

  python3 tools/dev-cmd.py '<shell command>'

The command is run through the shell (multi-step `&&` chains are fine) with
the working directory at the repository root.  Whatever the command does,
`alire.toml` and `alire/` are restored to their original state before this
script exits -- the dev manifest never survives a failed run.

Exit code is the command's exit code.
"""

import argparse
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List

ROOT: Path = Path(__file__).resolve().parent.parent


def swap_and_run(command: str) -> int:
    """Swap the dev manifest in, run the command, restore unconditionally."""
    backup = Path(tempfile.mkdtemp(prefix="adacovex-dev-cmd-"))
    had_toml: bool = (ROOT / "alire.toml").is_file()
    had_alire: bool = (ROOT / "alire").is_dir()

    if had_toml:
        shutil.copy2(ROOT / "alire.toml", backup / "alire.toml")
    # Use copyfile (fresh mtime), not copy2: `alr exec` re-synchronizes the
    # workspace only when alire.toml is strictly newer than
    # alire/alire.lock.  copy2 would stamp alire-dev.toml's old mtime onto
    # the swapped manifest, making the lock look current and skipping the
    # sync -- so gnatdoc/gnatformat never reach the exec PATH.
    shutil.copyfile(ROOT / "alire-dev.toml", ROOT / "alire.toml")
    if had_alire:
        shutil.copytree(ROOT / "alire", backup / "alire")

    # A Ctrl-C (or make's SIGTERM to the child) must not leave the tree on
    # the dev manifest either -- the old shell trap restored on EXIT INT
    # TERM.  Turning SIGTERM into an exception lets the finally block run.
    def _sigterm(_sig, _frame):
        raise SystemExit(128 + signal.SIGTERM)

    previous = signal.signal(signal.SIGTERM, _sigterm)
    try:
        result = subprocess.run(command, shell=True, cwd=str(ROOT))
        return result.returncode
    finally:
        signal.signal(signal.SIGTERM, previous)
        # Restore exactly what was moved aside, mirroring the old shell trap:
        # alire.toml is restored when it existed, alire/ is only touched when
        # it existed (a command-created alire/ on a manifest that had none is
        # left alone, as the old recipe did).
        if had_toml:
            shutil.move(str(backup / "alire.toml"), ROOT / "alire.toml")
        if had_alire:
            shutil.rmtree(ROOT / "alire", ignore_errors=True)
            shutil.move(str(backup / "alire"), ROOT / "alire")
        shutil.rmtree(backup, ignore_errors=True)


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", help="shell command to run on the dev manifest")
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])
    return swap_and_run(args.command)


if __name__ == "__main__":
    sys.exit(main())
