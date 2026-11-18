#!/usr/bin/env python3
"""The adacovex task runner as pure Python.

Every recipe that used to live inline in the Makefile is a function here, so
the same logic can be called from two thin front ends: the `justfile` (the
primary developer runner) and the `Makefile` (a compatibility shim that
delegates each target to this script).

    python3 tools/tasks.py <task> [args]
    python3 tools/tasks.py --list

Environment:
  VERSION=x.y.z   passed to bump-version / release
  DRY_RUN=1       release: everything except commit/tag/push
  CHECK=1         description / requirements: verify only, without writing

Exit code is the last subprocess's, or 0.
"""

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
PY: str = sys.executable

#  The generated specs, excluded from gnatformat.  gnatformat has no
#  exclusion flag, so `fmt` passes an explicit source list instead of -P.
#  Formatting a generated spec is destructive: gnatformat and the generator
#  disagree on layout, so a formatted spec fails the generator's byte
#  comparison, is rewritten, and is mangled again on the next fmt.
GENERATED_SPECS: List[str] = [
    "adacovex_version_info.ads",
    "adacovex-dashboard_template.ads",
    "adacovex-docs_template.ads",
    "adacovex-tldr_template.ads",
]

#  Fixture projects are Ada sources the root GPR never compiles.  Each one
#  carries its own project file and belongs to a different build (the
#  ecosystem fixtures exist to give the SBOM parser a real manifest).  Rooted
#  at these prefixes, gnatformat would format a file the project cannot see
#  and print the "not visible to the provided project" warning, so `fmt`
#  leaves them alone.  New fixture roots belong here rather than in an
#  ever-growing per-file list.
FIXTURE_ROOTS: List[str] = [
    "src/tests/fixtures/",
    "src/tests/projects/",
]


#  A parallel gate captures its child output into a thread-local buffer so
#  task_check can print the gates in their declared order after the phase
#  finishes.  A serial gate streams as before.
_PARALLEL_CAPTURE = threading.local()


def run(cmd: List[str], env: Dict[str, str] = None) -> int:
    """Run a command from the repo root, streaming or capturing its output."""
    if getattr(_PARALLEL_CAPTURE, "active", False):
        proc = subprocess.run(cmd, cwd=str(ROOT), env=env,
                              capture_output=True, text=True)
        if proc.stdout:
            _PARALLEL_CAPTURE.chunks.append(proc.stdout)
        if proc.stderr:
            _PARALLEL_CAPTURE.chunks.append(proc.stderr)
        return proc.returncode
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


def py(*args: str) -> int:
    """Run a Python script with the current interpreter."""
    return run([PY, *args])


def adacovex(*args: str) -> int:
    """Run the built binary (bin/adacovex, or bin/adacovex.exe on Windows)."""
    exe = ROOT / "bin" / "adacovex"
    if os.name == "nt" and (ROOT / "bin" / "adacovex.exe").exists():
        exe = ROOT / "bin" / "adacovex.exe"
    return run([str(exe), *args])


#  One build, one docs bundle, and one proof run feed every gate in a single
#  `check` run.  Each flag records a product an earlier gate already made, so
#  a later gate reuses it instead of rebuilding, re-bundling, or re-proving
#  it.  `tools/build.py` regenerates the bundled offline manual among its
#  pre-build steps, so a successful build also satisfies the offline-manual
#  gate.
_BUILD_DONE = False
_BOOK_DONE = False
_PROVE_DONE = False


def task_build() -> int:
    """Build once per process; later gates reuse the built tree."""
    global _BUILD_DONE, _BOOK_DONE
    if _BUILD_DONE or os.environ.get("ADACOVEX_ASSUME_BUILT") == "1":
        return 0
    rc = py("tools/build.py")
    _BUILD_DONE = rc == 0
    if _BUILD_DONE:
        _BOOK_DONE = True
    return rc


def task_man() -> int:
    rc = task_build()
    return rc if rc != 0 else adacovex("man")


def task_test() -> int:
    rc = task_build()
    if rc != 0:
        return rc
    exe = ROOT / "bin" / "test_runner"
    if os.name == "nt" and (ROOT / "bin" / "test_runner.exe").exists():
        exe = ROOT / "bin" / "test_runner.exe"
    rc = run([str(exe)])
    #  GNAT's Text_IO terminates lines with CRLF on Windows, but the report
    #  is a tracked LF-only artifact (.gitattributes eol=lf) and the ASCII
    #  gate rejects carriage returns: normalise both copies to LF here, so
    #  `test` leaves the tree in the state the gates expect on every host.
    for rel in ("test_result.md", "docs/test_result.md"):
        p = ROOT / rel
        try:
            data = p.read_bytes()
        except OSError:
            continue
        if b"\r\n" in data:
            p.write_bytes(data.replace(b"\r\n", b"\n"))
    return rc


def task_prove() -> int:
    """Prove once per process; a second gate reads the first run's output."""
    global _PROVE_DONE
    rc = task_build()
    if rc != 0:
        return rc
    if _PROVE_DONE:
        print("=== SPARK proof: already run in this `check` ===")
        return 0
    rc = py("tools/run.py", "prove")
    _PROVE_DONE = rc == 0
    return rc


def fmt_sources() -> List[str]:
    """Every source file gnatformat formats.

    Generated specs and standalone fixture projects are excluded: neither
    belongs to the root project, so formatting either one is destructive or
    prints a "not visible to the provided project" warning.
    """
    paths: List[str] = []
    for p in sorted(ROOT.glob("src/**/*.ads")) + sorted(ROOT.glob("src/**/*.adb")):
        rel = p.relative_to(ROOT).as_posix()
        if p.name in GENERATED_SPECS:
            continue
        if any(rel.startswith(root) for root in FIXTURE_ROOTS):
            continue
        paths.append(rel)
    return paths


def _digest(path: Path) -> bytes:
    """Content digest of a source, used to tell a real edit from a rewrite."""
    return hashlib.sha256(path.read_bytes()).digest()


def _fmt_stamp(sources: List[Path]) -> str:
    """Digest of the formatting inputs: every source and the dev manifest.

    The manifest carries the gnatformat pin, so a tool change invalidates the
    stamp even when the sources are unchanged.
    """
    digest = hashlib.sha256()
    for path in sources:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(_digest(path))
    manifest = ROOT / "alire-dev.toml"
    if manifest.exists():
        digest.update(manifest.read_bytes())
    return digest.hexdigest()


def task_fmt() -> int:
    #  gnatformat rewrites every file it visits, even when the layout is
    #  already correct, which bumps the mtime and makes gprbuild rebuild the
    #  whole tree.  Snapshot each source's content and timestamps first, then
    #  restore the timestamps of the files whose bytes did not change.  A
    #  warm `just check` therefore gets a no-op build, while a real format
    #  edit still reaches gnatprove and the API docs in the same run.
    sources = [ROOT / rel for rel in fmt_sources()]
    before = {}
    for path in sources:
        try:
            stat = path.stat()
            before[path] = (stat.st_mtime_ns, stat.st_atime_ns,
                            _digest(path))
        except OSError:
            continue
    stamp_path = ROOT / "obj" / "adacovex-fmt.stamp"
    stamp = _fmt_stamp(sources)
    if stamp_path.is_file():
        try:
            if stamp_path.read_text(encoding="utf-8").strip() == stamp:
                print("=== fmt: sources unchanged since the last "
                      "formatted pass ===")
                rc = py("tools/gen-version.py")
                return rc if rc != 0 else py("tools/gen-dashboard.py")
        except OSError:
            pass
    sources_arg = " ".join(fmt_sources())
    #  A warm tree is already formatted: `--check` proves it without writing
    #  a byte, so the common case never touches a source mtime.  Only a
    #  genuine formatting change pays for the rewrite pass.
    check_rc = py("tools/dev-cmd.py",
                  f"alr exec -- gnatformat -U --check {sources_arg}")
    if check_rc == 0:
        stamp_path.parent.mkdir(exist_ok=True)
        stamp_path.write_text(stamp + "\n", encoding="utf-8", newline="\n")
        rc = py("tools/gen-version.py")
        return rc if rc != 0 else py("tools/gen-dashboard.py")
    cmd = "alr exec -- gnatformat -U " + sources_arg
    rc = py("tools/dev-cmd.py", cmd)
    if rc != 0:
        return rc
    for path, (mtime, atime, digest) in before.items():
        try:
            if _digest(path) == digest:
                os.utime(path, ns=(atime, mtime))
        except OSError:
            continue
    stamp_path.parent.mkdir(exist_ok=True)
    stamp_path.write_text(_fmt_stamp(sources) + "\n", encoding="utf-8",
                          newline="\n")
    rc = py("tools/gen-version.py")
    return rc if rc != 0 else py("tools/gen-dashboard.py")


def _doc_stamp() -> str:
    """Digest of every input gnatdoc reads (sources and the converter).

    The manifest carries the gnatdoc/toolchain pin, so a tool change
    invalidates the stamp even when no source changed.
    """
    digest = hashlib.sha256()
    #  The generated bundle specs are data-only string constants.  A docs or
    #  dashboard edit rewrites their bodies but never their package
    #  interface, so they must not invalidate the gnatdoc stamp.
    generated = set(GENERATED_SPECS)
    files: List[Path] = sorted(
        p for p in (ROOT / "src").rglob("*")
        if p.suffix in (".ads", ".adb") and p.is_file()
        and p.name not in generated
    )
    for extra in (ROOT / "tools" / "rst2md.py", ROOT / "adacovex.gpr",
                  ROOT / "alire-dev.toml"):
        if extra.is_file():
            files.append(extra)
    for path in files:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(_digest(path))
    return digest.hexdigest()


def task_doc() -> int:
    #  Create the staging directory from Python: the command below runs
    #  through the platform shell, and `mkdir -p` would make cmd.exe create
    #  a literal `-p` directory on Windows.
    (ROOT / "obj").mkdir(exist_ok=True)
    stamp_path = ROOT / "obj" / "adacovex-doc.stamp"
    stamp = _doc_stamp()
    if (ROOT / "docs" / "api-docs" / "index.md").is_file() \
            and stamp_path.is_file():
        try:
            if stamp_path.read_text(encoding="utf-8").strip() == stamp:
                print("=== API docs: sources unchanged since the last "
                      "gnatdoc pass ===")
                return 0
        except OSError:
            pass
    cmd = (
        "alr exec -- gnatdoc -P adacovex.gpr --backend=rst "
        "--generate private --output-dir=obj/gnatdoc-rst && "
        f'"{PY}" tools/rst2md.py obj/gnatdoc-rst docs/api-docs '
        "--prune-test-pages"
    )
    rc = py("tools/dev-cmd.py", cmd)
    if rc != 0:
        return rc
    #  The pages rst2md prunes by name only, dropped after the conversion
    #  the same way the old `rm -f` did.
    for pattern in ("test_*.md", "adacovex-test_support.md"):
        for page in (ROOT / "docs" / "api-docs").glob(pattern):
            page.unlink()
    stamp_path.write_text(stamp + "\n", encoding="utf-8", newline="\n")
    return 0


def task_book() -> int:
    """Bundle the offline manual once; the build already did it."""
    global _BOOK_DONE
    if _BOOK_DONE:
        print("=== Offline manual: already bundled by the build ===")
        return 0
    rc = py("tools/gen-docs.py")
    _BOOK_DONE = rc == 0
    return rc


def task_run_self() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/run.py", "self")


def task_run_ada_crdt() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/run.py", "ada-crdt")


def task_sbom() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/run.py", "sbom")


def task_compliance() -> int:
    rc = task_build()
    if rc != 0:
        return rc
    epoch = subprocess.run(
        ["git", "show", "-s", "--format=%ct", "HEAD"],
        cwd=str(ROOT), capture_output=True, text=True,
    ).stdout.strip()
    env = dict(os.environ)
    if epoch:
        env["SOURCE_DATE_EPOCH"] = epoch
    exe = ROOT / "bin" / "adacovex"
    if os.name == "nt" and (ROOT / "bin" / "adacovex.exe").exists():
        exe = ROOT / "bin" / "adacovex.exe"
    rc = run(
        [str(exe), "-t=.", "--dal=C",
         "--emit-markdown=docs/compliance", "--no-svg", "--no-sbom"],
        env=env,
    )
    if rc != 0:
        return rc
    #  Ada.Text_IO writes CRLF on Windows; the committed files are LF.
    for name in ("docs/compliance/VERIFICATION.md",
                 "docs/compliance/TRACE.md"):
        path = ROOT / name
        if path.is_file():
            data = path.read_bytes().replace(b"\r\n", b"\n")
            path.write_bytes(data)
    return 0


def task_bench() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/bench.py")


def task_perf_bench() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/perf-bench.py")


def task_coverage_gate() -> int:
    rc = task_build()
    return rc if rc != 0 else py("tools/coverage-gate.py")


def task_link_check() -> int:
    return py("tools/check-links.py")


def task_action_parity_check() -> int:
    return py("tools/check-action-parity.py")


def task_docs_coverage_check() -> int:
    return py("tools/check-docs-coverage.py")


def task_surface_parity_check() -> int:
    return py("tools/check-surface-parity.py")


def task_agents_tree() -> int:
    out = ROOT / "obj" / "agents-tree.out"
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as fh:
        rc = subprocess.run(
            [PY, "tools/gen-agents-tree.py"], cwd=str(ROOT), stdout=fh,
        ).returncode
    if rc != 0:
        return rc
    rc = py("tools/apply-agents-tree.py", str(out))
    try:
        out.unlink()
    except OSError:
        pass
    return rc


def task_proof_status() -> int:
    return py("tools/update-proof-status.py")


def task_test_count() -> int:
    return py("tools/update-test-count.py")


def task_diagnostics_coverage_check() -> int:
    return py("tools/check-diagnostic-coverage.py")


def task_test_layout_check() -> int:
    return py("tools/check-test-layout.py")


def task_portability_check() -> int:
    return py("tools/check-test-portability.py")


def task_docs_tree() -> int:
    return py("tools/gen-docs-tree.py")


def task_changelog_check() -> int:
    return py("tools/check-changelogs.py")


def task_complexity_check() -> int:
    rc = task_build()
    if rc != 0:
        return rc
    return adacovex("complexity", "--excludes=rst", "--skip-path=docs/api-docs")


def task_csslint_check() -> int:
    return py("tools/csslint.py", "--check")


def task_ascii_check() -> int:
    return py("tools/ascii-check.py")


def task_docs_check() -> int:
    return py("tools/check-docs.py")


def task_para_split_check() -> int:
    return py("tools/para-split.py", "--check")


def task_tldr_check() -> int:
    rc = py("tools/check-tldr.py")
    return rc if rc != 0 else py("tools/gen-tldr.py", "--check")


def task_tldr_lint() -> int:
    if shutil.which("tldr-lint") is None:
        print("tldr-lint not installed; skipping "
              "(docs/tldr/adacovex.md is still covered by `just tldr-check`)")
        return 0
    return run(["tldr-lint", "docs/tldr/adacovex.md"])


def task_book_links_check() -> int:
    return py("tools/check-book-links.py")


def task_docs_serve() -> int:
    return run([PY, "-m", "http.server", "8000", "--directory", "docs"])


def task_book_serve() -> int:
    rc = task_book()
    return rc if rc != 0 else run(
        [PY, "-m", "http.server", "8000", "--directory", "docs/_build/html"]
    )


def task_tools_check() -> int:
    return py("tools/tests.py")


def task_spark_off_check() -> int:
    return py("tools/spark-off-check.py")


def task_version_consistency_check() -> int:
    return py("tools/check-version-consistency.py")


def task_version_source_check() -> int:
    return py("tools/gen-version.py", "--check")


def task_docs_tree_check() -> int:
    return py("tools/gen-docs-tree.py", "--check")


def task_book_spec_check() -> int:
    return py("tools/gen-docs.py", "--check")


def task_test_count_check() -> int:
    return py("tools/update-test-count.py", "--check")


def task_proof_status_check() -> int:
    return py("tools/update-proof-status.py", "--check")


def task_description_check() -> int:
    return py("tools/update-description.py", "--check")


def task_description() -> int:
    if os.environ.get("CHECK") == "1":
        return task_description_check()
    return py("tools/update-description.py")


def task_requirements_check() -> int:
    return py("tools/update-requirements.py", "--check")


def task_requirements() -> int:
    if os.environ.get("CHECK") == "1":
        return task_requirements_check()
    return py("tools/update-requirements.py")


def task_bump_version() -> int:
    return py("tools/bump-version.py", os.environ.get("VERSION", ""))


def task_release() -> int:
    args = ["tools/release.py", f"--version={os.environ.get('VERSION', '')}"]
    if os.environ.get("DRY_RUN"):
        args.append("--dry-run")
    return py(*args)


def task_publish() -> int:
    status = subprocess.run(
        ["git", "status", "--porcelain"], cwd=str(ROOT),
        capture_output=True, text=True,
    ).stdout.strip()
    if status:
        print("Error: working tree is not clean. Commit or stash changes first.")
        return 1
    return run(["alr", "publish"])


def task_test_publish() -> int:
    version = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0"], cwd=str(ROOT),
        capture_output=True, text=True,
    ).stdout.strip()
    if not version:
        version = subprocess.run(
            [PY, "tools/versions.py", "current"], cwd=str(ROOT),
            capture_output=True, text=True,
        ).stdout.strip()
    print("=== test-publish dry-run ===")
    print(f"Version:  {version}")
    print("Action:   alr publish (auto-detects GitHub, test deps excluded)")
    print("Requires: GitHub PAT in GITHUB_TOKEN env var or gh auth token")
    print("Docs:     "
          "https://github.com/alire-project/alire/blob/master/doc/publishing.md")
    print("=== end dry-run ===")
    return 0


def task_clean() -> int:
    subprocess.run(["alr", "clean"], cwd=str(ROOT),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for d in ("bin", "obj", "docs/badges", "docs/api"):
        shutil.rmtree(ROOT / d, ignore_errors=True)
    return 0


def task_cli_e2e() -> int:
    """Run the CLI checks as four independent shards in parallel."""
    rc = task_build()
    if rc != 0:
        return rc
    from concurrent.futures import ThreadPoolExecutor

    shards = 4
    script = ROOT / "src" / "tests" / "e2e" / "cli" / "cli_flags.py"
    env = dict(os.environ)
    env["ADACOVEX_ASSUME_BUILT"] = "1"

    def run_shard(index: int) -> Tuple[int, str]:
        proc = subprocess.run(
            [PY, str(script), "--shard", f"{index}/{shards}"],
            cwd=str(ROOT), env=env, capture_output=True, text=True)
        return proc.returncode, (proc.stdout or "") + (proc.stderr or "")

    with ThreadPoolExecutor(max_workers=shards) as pool:
        outputs = list(pool.map(run_shard, range(shards)))
    first_rc = 0
    passed = failed = 0
    for code, output in outputs:
        print(output.rstrip())
        for match in re.finditer(r"Passed: (\d+)  Failed: (\d+)", output):
            passed += int(match.group(1))
            failed += int(match.group(2))
        if code != 0 and first_rc == 0:
            first_rc = code
    if first_rc == 0:
        print(f"=== ALL CLI E2E CHECKS PASSED ({passed} checks, "
              f"{shards} shards) ===")
    return first_rc


def task_prove_e2e() -> int:
    """Run the output-mode checks and every fixture case in parallel.

    Each case owns its own temporary project, so the cases do not share
    state.  The modes run once on the index case; the cases run with
    `--skip-modes` so the mode checks are not repeated nine times.
    """
    reason = skip_without_gnatprove()
    if reason is not None:
        print(f"--- SKIP: prove diagnostics end-to-end: {reason} ---")
        return 0
    rc = task_build()
    if rc != 0:
        return rc
    script = ROOT / "src" / "tests" / "e2e" / "prove" / "prove_diagnostics.py"
    fixture_root = ROOT / "src" / "tests" / "projects" / "contract-errors"
    cases = sorted(child.name for child in fixture_root.iterdir()
                   if child.is_dir())
    jobs: List[Tuple[str, List[str]]] = [
        ("modes", [str(script), "--modes-only"]),
    ] + [(name, [str(script), "--case", name, "--skip-modes"])
         for name in cases]
    results: Dict[str, Tuple[int, str]] = {}
    from concurrent.futures import ThreadPoolExecutor
    #  Each job is a `-j 1` prove run.  The default cap keeps this gate from
    #  monopolising the machine while the other parallel check gates run; a
    #  standalone `just prove-e2e` can raise it with the environment variable.
    try:
        cap = int(os.environ.get("ADACOVEX_PROVE_E2E_WORKERS", "6"))
    except ValueError:
        cap = 6
    workers = max(2, min(len(jobs), os.cpu_count() or 4, cap))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(subprocess.run, [PY, *args], cwd=str(ROOT),
                        capture_output=True, text=True): key
            for key, args in jobs
        }
        for future, key in futures.items():
            proc = future.result()
            results[key] = (proc.returncode,
                            (proc.stdout or "") + (proc.stderr or ""))
    first_rc = 0
    for key, _ in jobs:
        code, output = results[key]
        if output.strip():
            print(output.rstrip())
        if code != 0 and first_rc == 0:
            first_rc = code
    if first_rc == 0:
        print(f"=== ALL PROVE DIAGNOSTICS CHECKS PASSED "
              f"({len(cases)} cases + modes) ===")
    return first_rc


def task_e2e() -> int:
    rc = task_cli_e2e()
    if rc != 0:
        return rc
    if shutil.which("pnpm") is None:
        print("--- SKIP: dashboard e2e: pnpm is not on PATH "
              "(see docs/contributing/developer-guide.md) ---")
        return 0
    dashboard = "src/tests/e2e/dashboard"
    rc = run(["pnpm", "--dir", dashboard, "install"])
    if rc != 0:
        return rc
    rc = run(["pnpm", "--dir", dashboard, "exec", "playwright",
              "install", "chromium"])
    if rc != 0:
        # A browser download can fail on an offline host or a locked-down CI
        # runner.  That says nothing about the tree, so it is a skip, not a
        # failed gate.
        print("--- SKIP: dashboard e2e: the Chromium download failed ---")
        return 0
    return run(["pnpm", "--dir", dashboard, "test"])


#  ------------------------------------------------------------------
#  Gate preflights.  A gate whose tool is missing on this host is SKIPped
#  with the reason instead of failing: a missing tool says nothing about
#  the tree, while a failing gate does.  Each returns None when the gate
#  can run, or the reason to skip it.
#  ------------------------------------------------------------------


def skip_without_alr() -> Optional[str]:
    """SKIP reason for the gates that drive the Alire toolchain."""
    return None if shutil.which("alr") else "alr is not on PATH"


def _skip_missing_dev_tool(tool: str) -> Optional[str]:
    """SKIP reason for a gate that needs a dev-manifest binary.

    gnatformat is a binary crate of `alire-dev.toml`, so it is on PATH only
    through the manifest swap `tools/dev-cmd.py` performs; probing a bare
    `alr exec` would skip the gate on every host.  The probe therefore runs
    exactly where the gate runs.  alr's own "Executable not found" is the
    only missing-tool signal: any other exit code means the binary ran (a
    tool that rejects `--version` still proves it exists).
    """
    if shutil.which("alr") is None:
        return "alr is not on PATH"
    try:
        probe = subprocess.run(
            [sys.executable, "tools/dev-cmd.py",
             f"alr exec -- {tool} --version"],
            cwd=str(ROOT), capture_output=True, text=True, timeout=600,
        )
    except subprocess.TimeoutExpired:
        return f"the {tool} probe timed out"
    except OSError:
        return f"the {tool} probe could not run"
    output = (probe.stdout or "") + (probe.stderr or "")
    if probe.returncode == 0 or "Executable not found" not in output:
        return None
    return f"{tool} is not available in the dev toolchain"


def skip_without_gnatprove() -> Optional[str]:
    """SKIP reason for the prove diagnostics e2e gate: it needs a prover."""
    return _skip_missing_dev_tool("gnatprove")


def skip_without_gnatformat() -> Optional[str]:
    """SKIP reason for `fmt`: gnatformat ships in the dev toolchain."""
    return _skip_missing_dev_tool("gnatformat")


def skip_without_gnatdoc() -> Optional[str]:
    """SKIP reason for the API docs gate.

    A deployed binary is not enough: the gnatdoc 26.0.0 Windows build
    starts and then crashes on an access violation for any project, so the
    probe also documents a one-package probe project through the same
    manifest swap the gate uses.  A tool that cannot document one package
    cannot document the tree, and that says nothing about the tree itself.
    """
    if shutil.which("alr") is None:
        return "alr is not on PATH"
    probe_dir = Path(tempfile.mkdtemp(prefix="adacovex-gnatdoc-probe-"))
    try:
        src = probe_dir / "src"
        src.mkdir()
        (src / "adacovex_gnatdoc_probe.ads").write_text(
            "package Adacovex_Gnatdoc_Probe is\n"
            "   --  Probe docstring.\n"
            "   function Answer return Integer;\n"
            "end Adacovex_Gnatdoc_Probe;\n",
            encoding="utf-8", newline="\n")
        (probe_dir / "adacovex_gnatdoc_probe.gpr").write_text(
            "project Adacovex_Gnatdoc_Probe is\n"
            '   for Source_Dirs use ("src");\n'
            '   for Object_Dir use "obj";\n'
            "end Adacovex_Gnatdoc_Probe;\n",
            encoding="utf-8", newline="\n")
        (probe_dir / "obj").mkdir()
        try:
            probe = subprocess.run(
                [sys.executable, "tools/dev-cmd.py",
                 "alr exec -- gnatdoc"
                 f" -P {probe_dir / 'adacovex_gnatdoc_probe.gpr'}"
                 " --backend=rst --generate private"
                 f" --output-dir {probe_dir / 'rst'}"],
                cwd=str(ROOT), capture_output=True, text=True, timeout=600,
            )
        except subprocess.TimeoutExpired:
            return "gnatdoc timed out on a one-package probe project"
        except OSError:
            return "the gnatdoc probe could not run"
        output = (probe.stdout or "") + (probe.stderr or "")
        if "Executable not found" in output:
            return "gnatdoc is not available in the dev toolchain"
        if probe.returncode != 0:
            return "gnatdoc cannot generate docs on this host"
        return None
    finally:
        shutil.rmtree(probe_dir, ignore_errors=True)


def skip_without_sphinx() -> Optional[str]:
    """SKIP reason for the offline manual: rebuilding it needs Sphinx."""
    try:
        import sphinx  # noqa: F401  (presence probe only)
    except ImportError:
        return "sphinx is not installed (see requirements.txt)"
    return None


#  The `check` recipe order.  `fmt` is first: gnatprove and the API docs both
#  read the sources, so every later gate must see formatted code.  The cheap
#  static gates run before the build, the build comes before every gate that
#  needs the binary (so the compile is attributed to one row instead of the
#  first gate that happened to need it), and the count-sync checks run last,
#  after `test`/`prove` have refreshed the metrics.  Build, docs bundle, and
#  proof are each produced once: the memos above make a later gate a reuse.
#  Each entry is (label, gate, preflight): the preflight returns a SKIP
#  reason, or None to run the gate.
CHECK_GATES: List[Tuple[str, Callable[[], int],
                         Optional[Callable[[], Optional[str]]]]] = [
    ("fmt", task_fmt, skip_without_gnatformat),
    ("ASCII", task_ascii_check, None),
    ("CSS 4px spacing", task_csslint_check, None),
    ("SPARK_Mode Off", task_spark_off_check, None),
    ("changelog format", task_changelog_check, None),
    ("action/CLI/docs parity", task_action_parity_check, None),
    ("documentation coverage", task_docs_coverage_check, None),
    ("test layout", task_test_layout_check, None),
    ("test portability", task_portability_check, None),
    ("diagnostics coverage", task_diagnostics_coverage_check, None),
    ("CLI surface parity", task_surface_parity_check, None),
    ("tools unit tests", task_tools_check, None),
    ("version source", task_version_source_check, None),
    ("version consistency", task_version_consistency_check, None),
    ("docs tree", task_docs_tree_check, None),
    ("markdown links", task_link_check, None),
    ("user documentation", task_docs_check, None),
    ("paragraph splitter", task_para_split_check, None),
    ("tldr structure", task_tldr_check, None),
    ("bundled offline manual links", task_book_links_check, None),
    ("bundled offline manual spec", task_book_spec_check, None),
    ("build", task_build, skip_without_alr),
    ("complexity (no god objects/functions/files)", task_complexity_check,
     skip_without_alr),
    ("CLI end-to-end", task_cli_e2e, skip_without_alr),
    ("native tests", task_test, skip_without_alr),
    ("SPARK proof + badges", task_prove, skip_without_alr),
    ("prove diagnostics end-to-end", task_prove_e2e, skip_without_gnatprove),
    ("API docs", task_doc, skip_without_gnatdoc),
    ("offline manual", task_book, skip_without_sphinx),
    ("SBOM", task_sbom, skip_without_alr),
    ("test counts in sync", task_test_count_check, None),
    ("proof metrics in sync", task_proof_status_check, None),
    ("description sync", task_description_check, None),
    ("requirements sync", task_requirements_check, None),
]


#  The check runner keeps three short serial phases around one parallel
#  phase.  `fmt` and `build` must be first and alone (they rewrite sources
#  and artefacts); the manual, API-docs, SBOM, proof, and tools gates run
#  serially next, so every read-only gate sees a stable tree; the count-sync
#  gates run last, after the tests and proof have refreshed their inputs.
CHECK_SERIAL_HEAD: List[str] = ["fmt", "build"]
CHECK_SERIAL_MID: List[str] = [
    "bundled offline manual links",
    "bundled offline manual spec",
    "SPARK proof + badges",
    "API docs",
    "SBOM",
    #  The tools suite compares `git status` around each `--check` run, so it
    #  must not overlap a gate that legitimately touches build state
    #  (alire.lock, sbom.json), or the comparison sees another gate's write.
    "tools unit tests",
]
CHECK_SERIAL_TAIL: List[str] = [
    "test counts in sync",
    "proof metrics in sync",
    "description sync",
    "requirements sync",
]

#  A gate in this map runs in its own process during the parallel phase, so
#  its own print output is captured without interleaving.  Every other
#  parallel gate runs in a thread with `run` capturing its children.
CHECK_PARALLEL_PROCESS: Dict[str, str] = {
    "CLI end-to-end": "cli-e2e",
    "native tests": "test",
    "prove diagnostics end-to-end": "prove-e2e",
    "offline manual": "book",
    "complexity (no god objects/functions/files)": "complexity-check",
}


def check_gate_labels() -> List[str]:
    """The gate labels of the `check` recipe, in order."""
    return [label for label, _, _ in CHECK_GATES]


def _run_gate_serial(label: str, action: Callable[[], int]) -> int:
    print(f"=== Quality gate: {label} ===")
    return action()


def _run_gate_parallel(label: str,
                        action: Callable[[], int]) -> Tuple[int, str]:
    command = CHECK_PARALLEL_PROCESS.get(label)
    if command is not None:
        env = dict(os.environ)
        env["ADACOVEX_ASSUME_BUILT"] = "1"
        proc = subprocess.run([PY, "tools/tasks.py", command],
                              cwd=str(ROOT), env=env,
                              capture_output=True, text=True)
        output = (proc.stdout or "") + (proc.stderr or "")
        return proc.returncode, output
    _PARALLEL_CAPTURE.active = True
    _PARALLEL_CAPTURE.chunks = []
    try:
        rc = action()
    finally:
        _PARALLEL_CAPTURE.active = False
        output = "".join(_PARALLEL_CAPTURE.chunks)
    return rc, output


def task_check() -> int:
    """Run every gate and keep going past a failure, then summarise.

    A gate whose tool is missing here is SKIPped with its reason, a gate
    that runs and fails is FAILED, and the summary lists all three states.
    Only failures set the exit code, so one broken gate no longer hides
    the state of the rest of the tree.  The independent gates run in one
    parallel phase (one worker per core, capped); the serial phases keep
    the writers apart and stay in the declared order.
    """
    from concurrent.futures import ThreadPoolExecutor
    from time import perf_counter

    passed: List[str] = []
    failed: List[Tuple[str, int]] = []
    skipped: List[Tuple[str, str]] = []
    timings: List[Tuple[str, float, int]] = []
    gate_by_label = {label: (action, preflight)
                    for label, action, preflight in CHECK_GATES}

    def run_one(label: str) -> Tuple[str, Optional[int], str, float,
                                       Optional[str]]:
        action, preflight = gate_by_label[label]
        reason = preflight() if preflight is not None else None
        if reason is not None:
            return label, None, "", 0.0, reason
        started = perf_counter()
        rc, output = _run_gate_parallel(label, action)
        return label, rc, output, perf_counter() - started, None

    parallel = [label for label, _, _ in CHECK_GATES
                if label not in CHECK_SERIAL_HEAD
                and label not in CHECK_SERIAL_MID
                and label not in CHECK_SERIAL_TAIL]

    for label in CHECK_SERIAL_HEAD:
        action, preflight = gate_by_label[label]
        reason = preflight() if preflight is not None else None
        if reason is not None:
            print(f"--- SKIP: {label}: {reason} ---")
            skipped.append((label, reason))
            continue
        started = perf_counter()
        rc = _run_gate_serial(label, action)
        timings.append((label, perf_counter() - started, rc))
        if rc == 0:
            passed.append(label)
        else:
            print(f"--- FAIL: {label} (exit {rc}) ---")
            failed.append((label, rc))

    for label in CHECK_SERIAL_MID:
        action, preflight = gate_by_label[label]
        reason = preflight() if preflight is not None else None
        if reason is not None:
            print(f"--- SKIP: {label}: {reason} ---")
            skipped.append((label, reason))
            continue
        started = perf_counter()
        rc = _run_gate_serial(label, action)
        timings.append((label, perf_counter() - started, rc))
        if rc == 0:
            passed.append(label)
        else:
            print(f"--- FAIL: {label} (exit {rc}) ---")
            failed.append((label, rc))

    workers = max(2, min(len(parallel), os.cpu_count() or 4, 8))
    if parallel:
        print(f"=== Parallel phase: {len(parallel)} gates, {workers} workers "
              "===")
        with ThreadPoolExecutor(max_workers=workers) as pool:
            parallel_results = list(pool.map(run_one, parallel))
        #  Print in the declared gate order, not in completion order, so the
        #  log is deterministic even though the gates overlapped.
        for label, rc, output, seconds, reason in parallel_results:
            if reason is not None:
                print(f"--- SKIP: {label}: {reason} ---")
                skipped.append((label, reason))
                continue
            if rc is None:
                continue
            timings.append((label, seconds, rc))
            print(f"=== Quality gate: {label} ===")
            if output.strip():
                print(output.rstrip())
            if rc == 0:
                passed.append(label)
            else:
                print(f"--- FAIL: {label} (exit {rc}) ---")
                failed.append((label, rc))

    for label in CHECK_SERIAL_TAIL:
        action, preflight = gate_by_label[label]
        reason = preflight() if preflight is not None else None
        if reason is not None:
            print(f"--- SKIP: {label}: {reason} ---")
            skipped.append((label, reason))
            continue
        started = perf_counter()
        rc = _run_gate_serial(label, action)
        timings.append((label, perf_counter() - started, rc))
        if rc == 0:
            passed.append(label)
        else:
            print(f"--- FAIL: {label} (exit {rc}) ---")
            failed.append((label, rc))
    print("")
    print("=== Quality gate summary ===")
    for label in passed:
        print(f"  PASS  {label}")
    for label, reason in skipped:
        print(f"  SKIP  {label}: {reason}")
    for label, rc in failed:
        print(f"  FAIL  {label} (exit {rc})")
    print("")
    print("=== Gate timings (seconds, slowest first) ===")
    for label, seconds, gate_rc in sorted(
            timings, key=lambda entry: entry[1], reverse=True):
        suffix = "  (FAIL)" if gate_rc else ""
        print(f"  {seconds:7.2f}  {label}{suffix}")
    print(f"  {sum(entry[1] for entry in timings):7.2f}  sum of gate times "
          "(parallel phases overlap)")
    print("")
    if failed:
        print(f"{len(failed)} of {len(CHECK_GATES)} gate(s) failed.")
        return failed[0][1]
    note = f" ({len(skipped)} skipped)" if skipped else ""
    print(f"All {len(passed)} gate(s) passed{note}.")
    return 0


def task_sync() -> int:
    for action in (task_agents_tree, task_proof_status, task_test_count,
                   task_docs_tree, task_description, task_requirements):
        rc = action()
        if rc != 0:
            return rc
    print("All sync targets up to date.")
    return 0


TASKS: Dict[str, Callable[[], int]] = {
    "build": task_build,
    "man": task_man,
    "test": task_test,
    "prove": task_prove,
    "fmt": task_fmt,
    "doc": task_doc,
    "book": task_book,
    "run-self": task_run_self,
    "run-ada-crdt": task_run_ada_crdt,
    "sbom": task_sbom,
    "compliance": task_compliance,
    "bench": task_bench,
    "perf-bench": task_perf_bench,
    "coverage-gate": task_coverage_gate,
    "link-check": task_link_check,
    "action-parity-check": task_action_parity_check,
    "docs-coverage-check": task_docs_coverage_check,
    "diagnostics-coverage-check": task_diagnostics_coverage_check,
    "surface-parity-check": task_surface_parity_check,
    "agents-tree": task_agents_tree,
    "proof-status": task_proof_status,
    "test-count": task_test_count,
    "docs-tree": task_docs_tree,
    "sync": task_sync,
    "changelog-check": task_changelog_check,
    "complexity-check": task_complexity_check,
    "csslint-check": task_csslint_check,
    "ascii-check": task_ascii_check,
    "docs-check": task_docs_check,
    "para-split-check": task_para_split_check,
    "tldr-check": task_tldr_check,
    "tldr-lint": task_tldr_lint,
    "book-links-check": task_book_links_check,
    "docs-serve": task_docs_serve,
    "book-serve": task_book_serve,
    "tools-check": task_tools_check,
    "spark-off-check": task_spark_off_check,
    "version-consistency-check": task_version_consistency_check,
    "description": task_description,
    "requirements": task_requirements,
    "bump-version": task_bump_version,
    "release": task_release,
    "publish": task_publish,
    "test-publish": task_test_publish,
    "clean": task_clean,
    "test-layout-check": task_test_layout_check,
    "portability-check": task_portability_check,
    "cli-e2e": task_cli_e2e,
    "prove-e2e": task_prove_e2e,
    "e2e": task_e2e,
    "check": task_check,
}


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(description="adacovex task runner")
    ap.add_argument("task", nargs="?", help="task name (see --list)")
    ap.add_argument("--list", action="store_true", help="list task names")
    args = ap.parse_args(argv)
    if args.list or not args.task:
        for name in sorted(TASKS):
            print(name)
        return 0
    task = TASKS.get(args.task)
    if task is None:
        print(f"error: unknown task '{args.task}' (try --list)", file=sys.stderr)
        return 2
    return task()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
