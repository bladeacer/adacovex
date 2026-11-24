#!/usr/bin/env python3
"""Unit tests for the tools/*.py dev scripts.

Runs under the stdlib `unittest` only (no third-party packages), matching
the tools' zero-dependency rule:

  python3 tools/tests.py
  python3 -m unittest discover -s tools -p tests.py   (same thing)

The tests exercise the pure logic of the orchestration scripts --
ascii-check, coverage-gate, dev-cmd, release, run and versions -- against
temporary directories / throwaway git repositories.  Filesystem-heavy
subprocess orchestration (build.py, bench.py) is exercised by `just check`
itself rather than duplicated here.

Exit code 0 when every test passes.
"""

import importlib
import json
import os
import re
import shutil
import subprocess
import sys
import contextlib
import io
import tarfile
import tempfile
import unittest
from unittest import mock
from pathlib import Path
from typing import List, Optional, Tuple

TOOLS: Path = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

# Hyphenated module names need importlib; the rest import directly.
ascii_check = importlib.import_module("ascii-check")
coverage_gate = importlib.import_module("coverage-gate")
dev_cmd = importlib.import_module("dev-cmd")
gen_docs = importlib.import_module("gen-docs")
import release
import live_files
import run
import tasks
from taskkit import build as task_build_module
from taskkit import common as task_common
import versions
import csslint
para_split = importlib.import_module("para-split")
rst2md = importlib.import_module("rst2md")
check_book_links = importlib.import_module("check-book-links")
check_docs = importlib.import_module("check-docs")
check_docs_coverage = importlib.import_module("check-docs-coverage")
check_surface_parity = importlib.import_module("check-surface-parity")
check_version = importlib.import_module("check-version-consistency")
diagnostic_coverage = importlib.import_module("check-diagnostic-coverage")
update_proof_status = importlib.import_module("update-proof-status")
perf_report = importlib.import_module("perf-report")
bench = importlib.import_module("bench")
update_test_count = importlib.import_module("update-test-count")
test_layout = importlib.import_module("check-test-layout")
test_portability = importlib.import_module("check-test-portability")
gen_docs_tree = importlib.import_module("gen-docs-tree")
spark_off = importlib.import_module("spark-off-check")
update_reqs = importlib.import_module("update-requirements")

# Every git command a test runs goes through `git()` below, which forces a
# throwaway identity and blanks the global/system config.  Two guarantees
# follow, both load-bearing in a repo that also cuts releases:
#
#   1. A commit can never be attributed to the developer's own git user.  The
#      AUTHOR/COMMITTER variables override any user.name/user.email, and
#      GIT_CONFIG_GLOBAL/SYSTEM point at the null device so no global hook,
#      signing, or template can leak in.  `os.devnull` (not the hardcoded
#      "/dev/null") keeps this working on Windows, where the e2e harness
#      already used the portable spelling.
#   2. No test pushes.  The release-tag tests assert push ORDER against a
#      fake `sh` (see ReleaseTagTests), so `git push` is never executed for
#      real; nothing else in the suite names a remote at all.
GIT_ENV: dict = {
    "GIT_AUTHOR_NAME": "adacovex test",
    "GIT_AUTHOR_EMAIL": "test@adacovex.invalid",
    "GIT_COMMITTER_NAME": "adacovex test",
    "GIT_COMMITTER_EMAIL": "test@adacovex.invalid",
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_SYSTEM": os.devnull,
    # Never let a test reach a real remote, even if a stray push slipped
    # through: git will refuse a protocol not listed here.
    "GIT_PROTOCOL_FROM_USER": "0",
}


def git(repo: Path, *args: str) -> subprocess.CompletedProcess:
    """Run a git command inside a throwaway repository."""
    env = dict(os.environ)
    env.update(GIT_ENV)
    return subprocess.run(
        ["git"] + list(args), cwd=str(repo), env=env,
        capture_output=True, text=True,
    )


def make_git_repo(repo: Path, tags: list) -> Path:
    """Initialise a throwaway git repository AT repo, one commit + tags.

    The identity is also written into the repository-local config, so the
    commit is attributed to the test user even on a git that ignores the
    AUTHOR/COMMITTER variables.  The repo carries no remote, so it cannot
    push.
    """
    repo.mkdir(parents=True, exist_ok=True)
    (repo / "f.txt").write_text("hello\n", encoding="utf-8")
    git(repo, "init", "-q", "-b", "main")
    git(repo, "config", "user.name", "adacovex test")
    git(repo, "config", "user.email", "test@adacovex.invalid")
    git(repo, "add", "f.txt")
    git(repo, "commit", "-q", "-m", "initial")
    for tag in tags:
        git(repo, "tag", tag)
    return repo


def write_manifest(path: Path, version: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'name = "covex"\nversion = "{version}"\n',
                    encoding="utf-8")


def write_fake_binary(binary: Path, line: str, rc: int = 0) -> None:
    """Write a runnable stub at `binary` that prints `line` and exits `rc`.

    Windows cannot execute a POSIX shebang script, and both version gates
    probe a `.cmd` launcher next to the plain binary name, so the stub is a
    `.cmd` there -- the same shape a Windows consumer run uses.
    """
    binary.parent.mkdir(parents=True, exist_ok=True)
    if os.name == "nt":
        stub = binary.with_name(binary.name + ".cmd")
        stub.write_text(
            "@echo off\r\n"
            f"echo {line}\r\n"
            f"exit /b {rc}\r\n",
            encoding="utf-8",
        )
        return
    binary.write_text(f"#!/bin/sh\necho '{line}'\nexit {rc}\n",
                      encoding="utf-8")
    binary.chmod(0o755)


# The two dashboard/tldr generators are loaded here so every test module
# shares one import and one module identity.
gen_dashboard = importlib.import_module("gen-dashboard")
gen_tldr = importlib.import_module("gen-tldr")
