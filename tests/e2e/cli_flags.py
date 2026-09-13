#!/usr/bin/env python3
"""End-to-end CLI tests for the adacovex shorthands, aliases, and tier tokens.

The Playwright suite (tests/dashboard.spec.ts) covers the served dashboard.
This script covers the command line itself: it runs the real `bin/adacovex`
binary and checks the shorthands, the long aliases, the `--standard` tier
tokens, the `--require-*` gates, the `complexity` subcommand (`--excludes` /
`--skip-path` and the pass/fail gate), and the VCS differential modes
(`--compare-base` / `--coverage-delta` and every alias) end to end -- exit
codes, the parsed effect, and the shorthand server flags.

It needs no browser and no third-party package, so it runs anywhere the
binary is built:

  make build          # once
  python3 tests/e2e/cli_flags.py

Exit code 0 when every check passes, 1 otherwise.
"""

import json
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parents[2]
BIN: str = str(ROOT / "bin" / "adacovex")

# Alias / shorthand topic -> a string that must appear in `help TOPIC`.
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
)

# Every long alias spelling that shell completion must advertise.
ALIAS_NAMES: Tuple[str, ...] = (
    "workers", "svg-path", "md-path", "emit-md", "no-md", "strict",
    "diff", "base", "delta", "spark", "docstrs", "tests",
)

# `--standard` tier token -> (standard label, level label) in the SBOM.
# The level is None for the no-safety-effect tier (QM == DAL-E): the SBOM
# deliberately omits the adacovex:level row there (see Level_Property).
TIER_TOKENS: Tuple[Tuple[str, str, Optional[str]], ...] = (
    ("dal-c", "DO-178C", "DAL-C"),
    ("asil-b", "ISO 26262", "ASIL B"),
    ("class-c", "IEC 62304", "Class C"),
    ("asil-qm", "ISO 26262", None),
)


class Results:
    """Collects check outcomes and prints one line per check."""

    def __init__(self) -> None:
        self.passed: int = 0
        self.failed: int = 0

    def check(self, ok: bool, label: str) -> None:
        if ok:
            self.passed += 1
            print(f"  PASS: {label}")
        else:
            self.failed += 1
            print(f"  FAIL: {label}")

    def report(self) -> int:
        total = self.passed + self.failed
        print(f"\n  Passed: {self.passed}  Failed: {self.failed}  "
              f"({total} checks)")
        if self.failed:
            print("=== CLI E2E FAILED ===")
            return 1
        print("=== ALL CLI E2E CHECKS PASSED ===")
        return 0


def run(args: List[str], timeout: int = 120) -> subprocess.CompletedProcess:
    """Run the binary with args and capture stdout/stderr as text."""
    return subprocess.run(
        [BIN] + args, capture_output=True, text=True, timeout=timeout,
        cwd=str(ROOT),
    )


def free_port() -> int:
    """A currently-free localhost TCP port."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


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
    """Init a git repo at path and commit the tree; False when git is absent."""
    if shutil.which("git") is None:
        return False
    ident = ["-c", "user.email=e2e@example.com", "-c", "user.name=e2e"]
    subprocess.run(["git", "init", "-q"], cwd=path, check=True,
                   capture_output=True)
    subprocess.run(["git", *ident, "add", "-A"], cwd=path, check=True,
                   capture_output=True)
    subprocess.run(["git", *ident, "commit", "-qm", "init"], cwd=path,
                   check=True, capture_output=True)
    return True


def check_version(r: Results) -> None:
    proc = run(["--version"])
    r.check(proc.returncode == 0, "--version exits 0")
    r.check(
        re.fullmatch(r"adacovex v\d+\.\d+\.\d+\s*", proc.stdout) is not None,
        "--version prints the bundled version",
    )


def check_help(r: Results) -> None:
    proc = run(["--help"])
    r.check(proc.returncode == 0, "--help exits 0")
    r.check("--target" in proc.stdout, "--help lists --target")
    for topic, needle in HELP_TOPICS:
        topic_proc = run(["help", topic])
        r.check(
            topic_proc.returncode == 0 and needle in topic_proc.stdout,
            f"help {topic} prints the {needle} section",
        )


def check_completion(r: Results) -> None:
    for shell in ("bash", "fish", "zsh", "pwsh"):
        proc = run(["completion", shell])
        missing = [name for name in ALIAS_NAMES if name not in proc.stdout]
        r.check(
            proc.returncode == 0 and not missing,
            f"completion {shell} advertises every alias"
            + (f" (missing: {', '.join(missing)})" if missing else ""),
        )


def check_rejections(r: Results) -> None:
    cases: Tuple[Tuple[List[str], str, str], ...] = (
        (["--nope"], "unknown option", "an unknown option"),
        (["zzz"], "unknown argument", "an unknown bare word"),
        (["--standard=bogus"], "--standard must be",
         "an unknown --standard value"),
        (["-l", "2"], "require the prove subcommand",
         "the -l shorthand without the prove subcommand"),
        (["--workers=6"], "requires the serve subcommand",
         "--workers without --serve"),
    )
    for args, needle, label in cases:
        proc = run(args)
        r.check(
            proc.returncode == 1 and needle in proc.stderr,
            f"rejects {label} with '{needle}'",
        )


def check_tier_tokens(r: Results, tmp: Path) -> None:
    for token, standard, level in TIER_TOKENS:
        out = tmp / f"sbom-{token}.md"
        proc = run(["sbom", "-t", str(tmp), "--format=md",
                    f"--out={out}", f"--standard={token}"])
        text = out.read_text(encoding="utf-8") if out.is_file() else ""
        has_standard = f"| adacovex:standard | {standard} |" in text
        if level is None:
            ok = proc.returncode == 0 and has_standard \
                and "| adacovex:level |" not in text
            label = (f"--standard={token} selects {standard} with no level"
                     " row (no-safety-effect tier)")
        else:
            ok = proc.returncode == 0 and has_standard \
                and f"| adacovex:level | {level} |" in text
            label = f"--standard={token} selects {standard} at {level}"
        r.check(ok, label)


def check_target_equivalence(r: Results, tmp: Path) -> None:
    short = run(["status", "-t", str(tmp)])
    long = run(["status", f"--target={tmp}"])
    r.check(
        short.returncode == 0 and long.returncode == 0,
        "status accepts -t and --target",
    )
    r.check(
        target_line(short.stdout) is not None
        and target_line(short.stdout) == target_line(long.stdout),
        "-t resolves the same target as --target",
    )


def check_markdown_output(r: Results, tmp: Path) -> None:
    # An empty target reports DAL Unmet, so the exit code is 1 by design; the
    # reports must still be written.
    plain = run(["-t", str(tmp), "--no-sbom", "--no-svg", "--emit-md",
                 "--no-cache"], timeout=300)
    docs = tmp / "docs"
    r.check(
        plain.returncode in (0, 1)
        and (docs / "VERIFICATION.md").is_file()
        and (docs / "TRACE.md").is_file(),
        "bare --emit-md writes VERIFICATION.md + TRACE.md to <target>/docs",
    )
    for name in ("VERIFICATION.md", "TRACE.md"):
        (docs / name).unlink()
    suppressed = run(["-t", str(tmp), "--no-sbom", "--no-svg", "--emit-md",
                      "--no-md", "--no-cache"], timeout=300)
    r.check(
        suppressed.returncode in (0, 1)
        and not (docs / "VERIFICATION.md").exists(),
        "--no-md overrides --emit-md",
    )


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


def check_serve_shorthands(r: Results, tmp: Path) -> None:
    port = free_port()
    body = serve_get(
        port,
        ["serve", "-t", str(tmp), "-p", str(port), "--workers=2",
         "--no-sbom", "--no-svg", "--no-md", "--no-cache"],
        "/api/metrics",
    )
    payload: Optional[dict] = None
    if body is not None:
        try:
            payload = json.loads(body)
        except ValueError:
            payload = None
    r.check(
        payload is not None
        and "spark_level" in payload
        and "standard" in payload,
        "serve -s/-p/--workers starts the dashboard and answers /api/metrics",
    )


def check_theme_and_port(r: Results, tmp: Path) -> None:
    # An unknown theme and a missing theme value fail loudly at parse time.
    bad = run(["--theme=neon"])
    r.check(
        bad.returncode == 1
        and "--theme must be light, dark, or system" in bad.stderr,
        "rejects an unknown --theme value",
    )
    missing = run(["--theme"])
    r.check(
        missing.returncode == 1
        and "--theme requires a value" in missing.stderr,
        "rejects --theme without a value",
    )

    # The CLI theme reaches the served dashboard, and the port shorthand
    # works in both the "=" and the glued form.
    for theme, form in (("dark", "-p=PORT"), ("light", "-pPORT")):
        port = free_port()
        port_arg = f"-p={port}" if form == "-p=PORT" else f"-p{port}"
        body = serve_get(
            port,
            ["serve", "-t", str(tmp), port_arg, f"--theme={theme}",
             "--workers=2", "--no-sbom", "--no-svg", "--no-md", "--no-cache"],
            "/",
        )
        r.check(
            body is not None
            and f'data-initial-theme="{theme}"' in body,
            f"serve applies --theme={theme} with the {form} port shorthand",
        )


def check_complexity(r: Results, tmp: Path) -> None:
    # A single-package project fails the gate (each file dominates the
    # codebase); a 20-package project passes (each file is ~5%).
    small = tmp / "cx-small"
    write_project(small, 1)
    (small / "notes.md").write_text("# notes\n", encoding="utf-8")
    big = tmp / "cx-big"
    write_project(big, 20)

    passing = run(["complexity", "--target", str(big)])
    r.check(
        passing.returncode == 0
        and "Complexity/LOC gate passed." in passing.stdout,
        "complexity passes a well-sized project and exits 0",
    )
    r.check(
        "Language" in passing.stdout and "files analyzed:" in passing.stdout,
        "complexity prints the tokei summary and the per-file table",
    )

    shorthand = run(["complexity", "-t", str(big)])
    r.check(
        shorthand.returncode == 0 and shorthand.stdout == passing.stdout,
        "complexity -t resolves the same target as --target",
    )

    failing = run(["complexity", "-t", str(small)])
    r.check(
        failing.returncode == 1
        and "Complexity/LOC gate FAILED" in failing.stdout,
        "complexity exits 1 and reports the gate failure",
    )

    included = run(["complexity", "-t", str(small)])
    excluded = run(["complexity", "-t", str(small), "--excludes=md"])
    r.check(
        "notes.md" in included.stdout and "notes.md" not in excluded.stdout,
        "complexity --excludes=md drops the Markdown file",
    )

    skipped = run(["complexity", "-t", str(small), "--skip-path=src"])
    r.check(
        "src/p01.adb" in included.stdout
        and "src/p01.adb" not in skipped.stdout
        and "src/p01.ads" not in skipped.stdout,
        "complexity --skip-path=src drops the files under src/",
    )


def check_differential(r: Results, tmp: Path) -> None:
    repo = tmp / "diff-repo"
    write_project(repo, 1)
    if not git_init_commit(repo):
        print("  SKIP: git not available; the differential checks need a VCS")
        return

    suppress = ["--no-sbom", "--no-svg", "--no-md", "--no-cache"]
    long_form = run(["--target", str(repo), "--compare-base=HEAD", *suppress])
    r.check(
        "Differential assessment: base <HEAD> vs current" in long_form.stdout
        and "DAL status" in long_form.stdout,
        "--compare-base=HEAD prints the differential report",
    )

    # Every alias spelling must leave the same parsed state as the canonical
    # long flag, so the reports are byte-identical.
    for label, args in (
        ("--diff", ["--diff=HEAD"]),
        ("--base", ["--base=HEAD"]),
        ("-b=", ["-b=HEAD"]),
        ("-b REF", ["-b", "HEAD"]),
    ):
        proc = run(["-t", str(repo), *args, *suppress])
        r.check(
            proc.stdout == long_form.stdout
            and proc.returncode == long_form.returncode,
            f"{label}=REF equals --compare-base=REF",
        )

    long_delta = run(["-t", str(repo), "--coverage-delta=HEAD"])
    r.check(
        long_delta.returncode == 0
        and "Coverage delta: base <HEAD> vs current" in long_delta.stdout
        and "coverage_delta:" in long_delta.stdout,
        "--coverage-delta=HEAD prints the coverage table and delta line",
    )
    for label, args in (
        ("--delta", ["--delta=HEAD"]),
        ("-d=", ["-d=HEAD"]),
        ("-d REF", ["-d", "HEAD"]),
    ):
        proc = run(["-t", str(repo), *args])
        r.check(
            proc.stdout == long_delta.stdout
            and proc.returncode == long_delta.returncode,
            f"{label}=REF equals --coverage-delta=REF",
        )

    # A target outside any repository must fail loudly, not silently.
    plain = tmp / "diff-novcs"
    plain.mkdir(parents=True, exist_ok=True)
    no_vcs = run(["-t", str(plain), "-b", "HEAD", *suppress])
    r.check(
        no_vcs.returncode == 1
        and "--compare-base requires" in no_vcs.stderr
        and "repository" in no_vcs.stderr,
        "-b REF fails loudly on a target that is not a repository",
    )


def check_differential_regression(r: Results, tmp: Path) -> None:
    repo = tmp / "diff-regression"
    write_documented_project(repo, 1)
    if not git_init_commit(repo):
        print("  SKIP: git not available; the regression checks need a VCS")
        return

    clean = run(["-t", str(repo), "--coverage-delta=HEAD"])
    r.check(
        clean.returncode == 0 and "regressed=no" in clean.stdout,
        "--coverage-delta reports no regression on an unchanged tree",
    )

    # Add an undocumented subprogram: docstring coverage drops 100% -> 50%.
    src = repo / "src"
    (src / "p01.ads").write_text(
        "package P01 is\n"
        "   --  Run the P01 step.\n"
        "   procedure Go;\n"
        "   procedure Extra;\n"
        "end P01;\n",
        encoding="utf-8",
    )
    (src / "p01.adb").write_text(
        "package body P01 is\n"
        "   --  Run the P01 step.\n"
        "   procedure Go is\n   begin\n      null;\n   end Go;\n"
        "   procedure Extra is\n   begin\n      null;\n   end Extra;\n"
        "end P01;\n",
        encoding="utf-8",
    )

    delta = run(["-t", str(repo), "--coverage-delta=HEAD"])
    r.check(
        delta.returncode == 1
        and "COVERAGE REGRESSION" in delta.stdout
        and "regressed=yes" in delta.stdout,
        "--coverage-delta flags a docstring-coverage drop and exits 1",
    )

    compare = run(["-t", str(repo), "--compare-base=HEAD",
                   "--no-sbom", "--no-svg", "--no-md", "--no-cache"])
    r.check(
        compare.returncode == 1
        and "REGRESSION DETECTED" in compare.stdout,
        "--compare-base reports REGRESSION DETECTED for a coverage drop",
    )


def check_prove(r: Results, tmp: Path) -> None:
    # A target with no .gpr file makes prove fail after argument parsing and
    # before gnatprove runs, so the flags can be exercised without a prover
    # or a network download.
    nope = tmp / "prove-target"
    nope.mkdir(parents=True, exist_ok=True)
    no_gpr = "no root .gpr project file found"

    accepted = run(["prove", "-t", str(nope), "-l", "2", "-j", "2",
                    "--timeout=60", "--steps=1000", "--memlimit=100",
                    "--quiet", "--no-loop-unrolling", "--no-inlining"])
    r.check(
        accepted.returncode == 1 and no_gpr in accepted.stderr,
        "prove parses -t/-l/-j and the full prove option set",
    )

    short = run(["prove", "-t", str(nope), "-l=2", "-j=2"])
    long_form = run(["prove", "--target", str(nope), "--level=2", "--jobs=2"])
    r.check(
        short.returncode == long_form.returncode
        and short.stderr == long_form.stderr,
        "prove -t/-l/-j shorthands equal their long forms",
    )

    rejects: Tuple[Tuple[List[str], str, str], ...] = (
        (["--level=bogus"], "--level must be an integer",
         "a non-numeric --level"),
        (["-l", "99"], "--level must be in", "an out-of-range --level"),
        (["--jobs=99999"], "--jobs must be in", "an out-of-range --jobs"),
        (["--timeout=-1"], "--timeout must be in",
         "an out-of-range --timeout"),
        (["--memlimit=0"], "--memlimit must be in",
         "an out-of-range --memlimit"),
    )
    for args, needle, label in rejects:
        proc = run(["prove", "-t", str(nope), *args])
        r.check(
            proc.returncode == 1 and needle in proc.stderr,
            f"prove rejects {label} with '{needle}'",
        )

    for args, label in (
        (["-j", "2"], "the -j shorthand"),
        (["--force"], "--force"),
        (["--steps=100"], "--steps"),
        (["-l", "1"], "the -l shorthand"),
    ):
        proc = run(args)
        r.check(
            proc.returncode == 1
            and "require the prove subcommand" in proc.stderr,
            f"rejects {label} outside the prove subcommand",
        )


def main() -> int:
    if not Path(BIN).is_file():
        print(f"error: {BIN} not found; run `make build` first",
              file=sys.stderr)
        return 1
    r = Results()
    print("=== adacovex CLI end-to-end checks ===")
    with tempfile.TemporaryDirectory(prefix="adacovex-cli-e2e-") as td:
        tmp = Path(td)
        check_version(r)
        check_help(r)
        check_completion(r)
        check_rejections(r)
        check_tier_tokens(r, tmp)
        check_target_equivalence(r, tmp)
        check_markdown_output(r, tmp)
        check_complexity(r, tmp)
        check_differential(r, tmp)
        check_differential_regression(r, tmp)
        check_prove(r, tmp)
        check_serve_shorthands(r, tmp)
        check_theme_and_port(r, tmp)
    return r.report()


if __name__ == "__main__":
    sys.exit(main())
