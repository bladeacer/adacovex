#!/usr/bin/env python3
"""Shared helpers, constants, and process plumbing for the CLI e2e checks."""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.e2e_support import (  # noqa: E402  (path set above)
    BIN, ROOT, Results, free_port, run_binary as run,
)

GIT_ENV: Dict[str, str] = {
    "GIT_AUTHOR_NAME": "adacovex e2e",
    "GIT_AUTHOR_EMAIL": "e2e@adacovex.invalid",
    "GIT_COMMITTER_NAME": "adacovex e2e",
    "GIT_COMMITTER_EMAIL": "e2e@adacovex.invalid",
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_SYSTEM": os.devnull,
}

HELP_FRAMES: Tuple[Tuple[str, str], ...] = (
    ("prove", "adacovex prove [options]"),
    ("serve", "adacovex [--serve] [serve options]"),
    ("sbom", "adacovex sbom [options]"),
    ("target", "adacovex [options]"),
)

HELP_TOPICS: Tuple[Tuple[str, str], ...] = (
    ("workers", "--serve-workers"),
    ("svg-path", "--emit-svg"),
    ("md-path", "--emit-markdown"),
    ("emit-md", "--emit-markdown"),
    ("no-md", "--emit-markdown"),
    ("diff", "--compare-base"),
    ("base", "--compare-base"),
    ("delta", "--coverage-delta"),
    ("spark", "--require-"),
    ("docstrs", "--require-"),
    ("tests", "--require-"),
    ("strict", "--skip-dir"),
    ("cache-expiry", "--cache-expiry=DAYS"),
    ("cache-clear", "--cache-clear"),
)

ALIAS_NAMES: Tuple[str, ...] = (
    "workers", "svg-path", "md-path", "emit-md", "no-md", "strict",
    "diff", "base", "delta", "spark", "docstrs", "tests",
)

TIER_TOKENS: Tuple[Tuple[str, str, Optional[str]], ...] = (
    ("dal-c", "DO-178C", "DAL-C"),
    ("asil-b", "ISO 26262", "ASIL B"),
    ("class-c", "IEC 62304", "Class C"),
    ("asil-qm", "ISO 26262", None),
)

SBOM_SCOPES: Tuple[str, ...] = (
    "base", "dev", "transitive", "vendored", "test", "system",
)

SBOM_SIBLINGS: Tuple[Tuple[str, Tuple[str, ...]], ...] = (
    #  Cargo workspace with a Python binding crate.
    ("polars", ("pkg:cargo/", "pkg:pypi/", "pkg:github/")),
    #  npm workspace whose lockfile pins the development toolchain.
    ("playwright", ("pkg:npm/", "pkg:github/")),
    #  CMake C/C++ tree with vendored 3rdparty sources and no manifest.
    ("opencv", ("pkg:github/",)),
    #  pnpm workspace with a vendored node_modules tree.
    ("lccst", ("pkg:npm/", "pkg:github/")),
    #  Python project built with meson.
    ("numpy", ("pkg:pypi/", "pkg:github/")),
    #  C library built with meson and no package manifest.
    ("yams", ("pkg:github/",)),
)

SBOM_FORBIDDEN_TOOLS: Dict[str, Tuple[str, ...]] = {
    "yams": ("cargo", "go", "rustc"),
}

def target_line(text: str) -> Optional[str]:
    """The `target:` line of a `status` report, or None."""
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("target:"):
            return line
    return None

def write_project(path: Path, packages: int) -> None:
    """Scaffold a minimal Ada project with `packages` packages and a .gpr."""
    src = path / "src"
    src.mkdir(parents=True, exist_ok=True)
    (path / "demo.gpr").write_text(
        'project Demo is\n'
        '   for Source_Dirs use ("src");\n'
        '   for Object_Dir use "obj";\n'
        'end Demo;\n',
        encoding="utf-8",
    )
    for i in range(1, packages + 1):
        name = f"P{i:02d}"
        (src / f"p{i:02d}.ads").write_text(
            f"package {name} is\n   procedure Go;\nend {name};\n",
            encoding="utf-8",
        )
        (src / f"p{i:02d}.adb").write_text(
            f"package body {name} is\n   procedure Go is\n   begin\n"
            f"      null;\n   end Go;\nend {name};\n",
            encoding="utf-8",
        )

def write_documented_project(path: Path, packages: int) -> None:
    """Scaffold a project whose subprograms all carry a docstring."""
    src = path / "src"
    src.mkdir(parents=True, exist_ok=True)
    (path / "demo.gpr").write_text(
        'project Demo is\n'
        '   for Source_Dirs use ("src");\n'
        '   for Object_Dir use "obj";\n'
        'end Demo;\n',
        encoding="utf-8",
    )
    for i in range(1, packages + 1):
        name = f"P{i:02d}"
        (src / f"p{i:02d}.ads").write_text(
            f"package {name} is\n"
            f"   --  Run the {name} step.\n"
            f"   procedure Go;\n"
            f"end {name};\n",
            encoding="utf-8",
        )
        (src / f"p{i:02d}.adb").write_text(
            f"package body {name} is\n"
            f"   --  Run the {name} step.\n"
            f"   procedure Go is\n   begin\n      null;\n   end Go;\n"
            f"end {name};\n",
            encoding="utf-8",
        )

def git_init_commit(path: Path) -> bool:
    """Init a git repo at path and commit the tree; False when git is absent.

    The repository is created with GIT_ENV (an empty global and system config),
    so the developer's own git settings can never break the fixture.  The
    identity is also written into the repository-local config, so the commit
    is attributed to the test user even on a git that ignores the
    AUTHOR/COMMITTER variables.  The fixture carries no remote and no test in
    this harness runs `git push`.
    """
    if shutil.which("git") is None:
        return False
    env: Dict[str, str] = dict(os.environ)
    env.update(GIT_ENV)

    def git(*args: str) -> None:
        subprocess.run(["git", *args], cwd=path, env=env, check=True,
                       capture_output=True)

    git("init", "-q", "-b", "main")
    git("config", "user.name", "adacovex e2e")
    git("config", "user.email", "e2e@adacovex.invalid")
    git("add", "-A")
    git("commit", "-qm", "init")
    return True

def sbom_table(target: Path, out: Path) -> Optional[List[Dict[str, str]]]:
    """Run `sbom` on target and return its component table as row dicts.

    Each row maps the lower-case column name to its cell text. The metadata
    table above the component table is skipped. Returns None when no report
    was written.
    """
    proc = run(["sbom", "-t", str(target), "--format=md",
                f"--out={out}", "--no-cache"], timeout=300)
    if proc.returncode not in (0, 1) or not out.is_file():
        return None
    header: Optional[List[str]] = None
    rows: List[Dict[str, str]] = []
    for line in out.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip().strip("`")
                 for cell in line.strip().strip("|").split("|")]
        lowered = [cell.lower() for cell in cells]
        if "component" in lowered and "scope" in lowered:
            header = lowered
            continue
        if header is None:
            continue
        if all(set(cell) <= {"-", ":"} for cell in cells):
            continue
        if len(cells) == len(header):
            rows.append(dict(zip(header, cells)))
    return rows

def sbom_components(out: Path, target: Path) -> Optional[List[Tuple[str, str]]]:
    """Run `sbom` on target and return its (component, scope) rows.

    `system` rows are kept: they depend on what the host has on PATH.
    Returns None when no report was written.
    """
    table = sbom_table(target, out)
    if table is None:
        return None
    return [(row.get("component", ""), row.get("scope", ""))
            for row in table if row.get("scope") in SBOM_SCOPES]

def write_fixture(root: Path, files: Dict[str, str]) -> None:
    """Write a fixture tree: relative path -> file content."""
    for rel, content in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

def serve_get(port: int, args: List[str], path: str = "/") -> Optional[str]:
    """Start the binary with args, GET path from the dashboard, stop it.

    Returns the response body, or None when the server never answers.  The
    process is always terminated, whatever the outcome.
    """
    proc = subprocess.Popen(
        [BIN] + args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        cwd=str(ROOT),
    )
    body: Optional[str] = None
    url = f"http://127.0.0.1:{port}{path}"
    try:
        for _ in range(60):
            if proc.poll() is not None:
                break
            try:
                with urllib.request.urlopen(url, timeout=2) as resp:
                    body = resp.read().decode("utf-8", "replace")
                break
            except (urllib.error.URLError, OSError, ValueError):
                time.sleep(0.2)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=10)
    return body

def serve_get_retry(build_args: Callable[[int], List[str]],
                    path: str = "/",
                    attempts: int = 4) -> Tuple[Optional[str], int]:
    """Try to serve and GET, re-picking the port when the bind lost a race.

    The shards run concurrently, so another shard can take the port between
    `free_port` and the child's bind.  A retry gives the check a real verdict
    instead of a false failure.
    """
    for _ in range(attempts):
        port = free_port()
        body = serve_get(port, build_args(port), path)
        if body is not None:
            return body, port
    return None, 0
