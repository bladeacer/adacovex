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
from pathlib import Path
from typing import Callable, Dict, List, Tuple

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
    return run([str(exe)])


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
    cmd = (
        "mkdir -p obj && "
        "alr exec -- gnatdoc -P adacovex.gpr --backend=rst "
        "--generate private --output-dir=obj/gnatdoc-rst && "
        "python3 tools/rst2md.py obj/gnatdoc-rst docs/api-docs "
        "--prune-test-pages && "
        "rm -f docs/api-docs/test_*.md docs/api-docs/adacovex-test_support.md"
    )
    return py("tools/dev-cmd.py", cmd)


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
    return run(
        [str(exe), "-t=.", "--dal=C",
         "--emit-markdown=docs/compliance", "--no-svg", "--no-sbom"],
        env=env,
    )


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


#  The `check` recipe order.  `fmt` is first: gnatprove and the API docs both
#  read the sources, so every later gate must see formatted code.  The cheap
#  static gates run before the expensive build + proof, and the count-sync
#  checks run last, after `test`/`prove` have refreshed the metrics.
CHECK_GATES: List[Tuple[str, Callable[[], int]]] = [
    ("fmt", task_fmt),
    ("ASCII", task_ascii_check),
    ("complexity (no god objects/functions/files)", task_complexity_check),
    ("CSS 4px spacing", task_csslint_check),
    ("SPARK_Mode Off", task_spark_off_check),
    ("changelog format", task_changelog_check),
    ("action/CLI/docs parity", task_action_parity_check),
    ("documentation coverage", task_docs_coverage_check),
    ("tools unit tests", task_tools_check),
    ("CLI end-to-end", task_cli_e2e),
    ("version source", task_version_source_check),
    ("version consistency", task_version_consistency_check),
    ("doc links", task_doc_links_check),
    ("markdown links", task_link_check),
    ("user documentation", task_docs_check),
    ("paragraph splitter", task_para_split_check),
    ("tldr structure", task_tldr_check),
    ("bundled offline manual links", task_book_links_check),
    ("bundled offline manual spec", task_book_spec_check),
    ("build", task_build),
    ("native tests", task_test),
    ("SPARK proof + badges", task_prove),
    ("API docs", task_doc),
    ("offline manual", task_book),
    ("SBOM", task_sbom),
    ("test counts in sync", task_test_count_check),
    ("proof metrics in sync", task_proof_status_check),
    ("description sync", task_description_check),
]


def check_gate_labels() -> List[str]:
    """The gate labels of the `check` recipe, in order."""
    return [label for label, _ in CHECK_GATES]


def task_check() -> int:
    for label, action in CHECK_GATES:
        print(f"=== Quality gate: {label} ===")
        rc = action()
        if rc != 0:
            return rc
    print("")
    print("=== Quality gate passed: "
          + ", ".join(check_gate_labels()) + " ===")
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
