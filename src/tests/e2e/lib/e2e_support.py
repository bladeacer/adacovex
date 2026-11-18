#!/usr/bin/env python3
"""Shared helpers for the adacovex end-to-end suites.

Both Python suites run the real binary from the repository root.  They need
the same three things: the root, the built binary, and a result recorder that
keeps a skip apart from a pass and a failure.  This module owns them once so
the two suites cannot disagree about what a skip means.

Usage from a suite under `src/tests/e2e/<category>/`:

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from lib.e2e_support import BIN, ROOT, Results, free_port

No third-party package and no browser is involved.
"""

import os
import socket
import subprocess
from pathlib import Path
from typing import Dict, List, Optional


def _find_root() -> Path:
    """The repository root (the directory holding the GPR and the manifest).

    The suites live four levels down (`src/tests/e2e/lib`), but the marker
    search keeps the answer correct if the layout moves again.

    @return The repository root.
    """
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "adacovex.gpr").is_file() and \
                (parent / "alire.toml").is_file():
            return parent
    return here.parents[4]


ROOT: Path = _find_root()


def binary() -> Path:
    """The built binary: `bin/adacovex`, or `bin/adacovex.exe` on Windows.

    @return Path to the runnable binary.
    """
    for name in ("adacovex.exe", "adacovex"):
        candidate = ROOT / "bin" / name
        if candidate.is_file():
            return candidate
    return ROOT / "bin" / "adacovex"


BIN: str = str(binary())


def base_env(env_extra: Optional[Dict[str, str]] = None,
             no_color: bool = False) -> Dict[str, str]:
    """Build the environment for one binary run.

    ADACOVEX_OFFLINE is forced on so no check spawns a package-registry CLI,
    which is the same hermetic-suite rule the native runner applies.

    @param env_extra  Variables to override or add.
    @param no_color  True to force plain text output.
    @return The environment to pass to the child process.
    """
    env = dict(os.environ)
    env["ADACOVEX_OFFLINE"] = "1"
    if no_color:
        env["NO_COLOR"] = "1"
    if env_extra:
        env.update(env_extra)
    return env


def run_binary(args: List[str], timeout: int = 120,
               env_extra: Optional[Dict[str, str]] = None,
               cwd: Optional[Path] = None,
               no_color: bool = False) -> subprocess.CompletedProcess:
    """Run the built binary and capture its output as text.

    @param args  Arguments after the program name.
    @param timeout  Seconds before the run is killed.
    @param env_extra  Variables to override or add.
    @param cwd  Working directory (the repository root when omitted).
    @param no_color  True to force plain text output.
    @return The completed process.
    """
    return subprocess.run(
        [BIN] + args, capture_output=True, text=True, timeout=timeout,
        cwd=str(cwd) if cwd is not None else str(ROOT),
        env=base_env(env_extra, no_color=no_color),
    )


def free_port() -> int:
    """A currently-free localhost TCP port.

    @return The port number.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


class Results:
    """Collect check outcomes and print one line per check.

    A skip is never a pass and never a failure.  It carries a reason so the
    run summary explains why the check could not run on this host.
    """

    def __init__(self) -> None:
        self.passed: int = 0
        self.failed: int = 0
        self.skipped: int = 0

    def check(self, ok: bool, label: str) -> None:
        """Record one check.

        @param ok  True when the check passed.
        @param label  Human-readable description.
        """
        if ok:
            self.passed += 1
            print(f"  PASS: {label}")
        else:
            self.failed += 1
            print(f"  FAIL: {label}")

    def skip(self, label: str, reason: str) -> None:
        """Record one check that cannot run here.

        @param label  Human-readable description.
        @param reason  Why the check cannot run on this host.
        """
        self.skipped += 1
        print(f"  SKIP: {label}: {reason}")

    def report(self, suite: str) -> int:
        """Print the totals and return the process exit code.

        @param suite  Suite name used in the summary banner.
        @return 0 when nothing failed, 1 otherwise.
        """
        total = self.passed + self.failed
        print(f"\n  Passed: {self.passed}  Failed: {self.failed}  "
              f"Skipped: {self.skipped}  ({total} checks)")
        if self.failed:
            print(f"=== {suite} FAILED ===")
            return 1
        if self.skipped:
            print(f"=== ALL {suite} CHECKS PASSED "
                  f"({self.skipped} skipped) ===")
        else:
            print(f"=== ALL {suite} CHECKS PASSED ===")
        return 0
