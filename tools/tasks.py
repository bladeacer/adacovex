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
  CHECK=1         description: verify only, without writing

Exit code is the last subprocess's, or 0.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
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
]


def run(cmd: List[str], env: Dict[str, str] = None) -> int:
    """Run a command from the repo root, streaming its output."""
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


def task_build() -> int:
    return py("tools/build.py")


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
    rc = task_build()
    return rc if rc != 0 else py("tools/run.py", "prove")


def fmt_sources() -> List[str]:
    """Every source file gnatformat formats (generated specs excluded)."""
    paths: List[str] = []
    for p in sorted(ROOT.glob("src/**/*.ads")) + sorted(ROOT.glob("src/**/*.adb")):
        if p.name not in GENERATED_SPECS:
            paths.append(p.relative_to(ROOT).as_posix())
    return paths


def task_fmt() -> int:
    cmd = "alr exec -- gnatformat -U " + " ".join(fmt_sources())
    rc = py("tools/dev-cmd.py", cmd)
    if rc != 0:
        return rc
    rc = py("tools/gen-version.py")
    return rc if rc != 0 else py("tools/gen-dashboard.py")


def task_doc() -> int:
    #  Create the staging directory from Python: the command below runs
    #  through the platform shell, and `mkdir -p` would make cmd.exe create
    #  a literal `-p` directory on Windows.
    (ROOT / "obj").mkdir(exist_ok=True)
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
    return 0


def task_book() -> int:
    return py("tools/gen-docs.py")


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


def task_doc_links() -> int:
    return py("tools/update-doc-links.py")


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
    return py("tools/check-tldr.py")


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


def task_doc_links_check() -> int:
    return py("tools/update-doc-links.py", "--check")


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
    rc = task_build()
    return rc if rc != 0 else py("tests/e2e/cli_flags.py")


def task_e2e() -> int:
    rc = task_cli_e2e()
    if rc != 0:
        return rc
    rc = run(["pnpm", "--dir", "tests/e2e", "install"])
    if rc != 0:
        return rc
    rc = run(["pnpm", "--dir", "tests/e2e", "exec", "playwright",
              "install", "chromium"])
    return rc if rc != 0 else run(["pnpm", "--dir", "tests/e2e", "test"])


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
#  static gates run before the expensive build + proof, and the count-sync
#  checks run last, after `test`/`prove` have refreshed the metrics.
#  Each entry is (label, gate, preflight): the preflight returns a SKIP
#  reason, or None to run the gate.
CHECK_GATES: List[Tuple[str, Callable[[], int],
                         Optional[Callable[[], Optional[str]]]]] = [
    ("fmt", task_fmt, skip_without_gnatformat),
    ("ASCII", task_ascii_check, None),
    ("complexity (no god objects/functions/files)", task_complexity_check,
     skip_without_alr),
    ("CSS 4px spacing", task_csslint_check, None),
    ("SPARK_Mode Off", task_spark_off_check, None),
    ("changelog format", task_changelog_check, None),
    ("action/CLI/docs parity", task_action_parity_check, None),
    ("documentation coverage", task_docs_coverage_check, None),
    ("tools unit tests", task_tools_check, None),
    ("CLI end-to-end", task_cli_e2e, skip_without_alr),
    ("version source", task_version_source_check, None),
    ("version consistency", task_version_consistency_check, None),
    ("doc links", task_doc_links_check, None),
    ("markdown links", task_link_check, None),
    ("user documentation", task_docs_check, None),
    ("paragraph splitter", task_para_split_check, None),
    ("tldr structure", task_tldr_check, None),
    ("bundled offline manual links", task_book_links_check, None),
    ("bundled offline manual spec", task_book_spec_check, None),
    ("build", task_build, skip_without_alr),
    ("native tests", task_test, skip_without_alr),
    ("SPARK proof + badges", task_prove, skip_without_alr),
    ("API docs", task_doc, skip_without_gnatdoc),
    ("offline manual", task_book, skip_without_sphinx),
    ("SBOM", task_sbom, skip_without_alr),
    ("test counts in sync", task_test_count_check, None),
    ("proof metrics in sync", task_proof_status_check, None),
    ("description sync", task_description_check, None),
]


def check_gate_labels() -> List[str]:
    """The gate labels of the `check` recipe, in order."""
    return [label for label, _, _ in CHECK_GATES]


def task_check() -> int:
    """Run every gate and keep going past a failure, then summarise.

    A gate whose tool is missing here is SKIPped with its reason, a gate
    that runs and fails is FAILED, and the summary lists all three states.
    Only failures set the exit code, so one broken gate no longer hides
    the state of the rest of the tree.
    """
    passed: List[str] = []
    failed: List[Tuple[str, int]] = []
    skipped: List[Tuple[str, str]] = []
    for label, action, preflight in CHECK_GATES:
        print(f"=== Quality gate: {label} ===")
        reason = preflight() if preflight is not None else None
        if reason is not None:
            print(f"--- SKIP: {label}: {reason} ---")
            skipped.append((label, reason))
            continue
        rc = action()
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
    if failed:
        print(f"{len(failed)} of {len(CHECK_GATES)} gate(s) failed.")
        return failed[0][1]
    note = f" ({len(skipped)} skipped)" if skipped else ""
    print(f"All {len(passed)} gate(s) passed{note}.")
    return 0


def task_sync() -> int:
    for action in (task_agents_tree, task_proof_status, task_test_count,
                   task_doc_links, task_description):
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
    "agents-tree": task_agents_tree,
    "proof-status": task_proof_status,
    "test-count": task_test_count,
    "doc-links": task_doc_links,
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
    "bump-version": task_bump_version,
    "release": task_release,
    "publish": task_publish,
    "test-publish": task_test_publish,
    "clean": task_clean,
    "cli-e2e": task_cli_e2e,
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
