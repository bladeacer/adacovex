"""Cheap gates, sync targets, and local maintenance tasks."""

import os
import shutil
import subprocess

from .build import task_book, task_build
from .common import PY, ROOT, adacovex, py, run


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

def task_clean() -> int:
    subprocess.run(["alr", "clean"], cwd=str(ROOT),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for d in ("bin", "obj", "docs/badges", "docs/api"):
        shutil.rmtree(ROOT / d, ignore_errors=True)
    return 0
