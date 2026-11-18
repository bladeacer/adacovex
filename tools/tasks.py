#!/usr/bin/env python3
"""The adacovex task runner as pure Python.

Every recipe that used to live inline in the Makefile is a function in the
`taskkit` package, so the same logic can be called from two thin front ends:
the `justfile` (the primary developer runner) and the `Makefile` (a
compatibility shim that delegates each target to this script).

    python3 tools/tasks.py <task> [args]
    python3 tools/tasks.py --list

Environment:
  VERSION=x.y.z   passed to bump-version / release
  DRY_RUN=1       release: everything except commit/tag/push
  CHECK=1         description / requirements: verify only, without writing

Exit code is the last subprocess's, or 0.
"""

import argparse
import sys
from typing import Callable, Dict, List

from taskkit.build import (fmt_sources, task_bench, task_book, task_build,
                           task_compliance, task_coverage_gate, task_doc,
                           task_fmt, task_man, task_perf_bench, task_prove,
                           task_run_ada_crdt, task_run_self, task_sbom,
                           task_test)
from taskkit.checks import (CHECK_GATES, CHECK_PARALLEL_PROCESS,
                            CHECK_SERIAL_HEAD, CHECK_SERIAL_MID,
                            CHECK_SERIAL_TAIL, check_gate_labels, task_check)
from taskkit.common import FIXTURE_ROOTS, GENERATED_SPECS, PY, ROOT
from taskkit.e2e import task_cli_e2e, task_e2e, task_prove_e2e
from taskkit.gates import (task_action_parity_check, task_agents_tree,
                           task_ascii_check, task_book_links_check,
                           task_book_serve, task_book_spec_check,
                           task_changelog_check, task_complexity_check,
                           task_csslint_check, task_description,
                           task_description_check,
                           task_diagnostics_coverage_check, task_docs_check,
                           task_docs_coverage_check, task_docs_serve,
                           task_docs_tree, task_docs_tree_check,
                           task_link_check, task_para_split_check,
                           task_portability_check, task_proof_status,
                           task_proof_status_check, task_requirements,
                           task_requirements_check, task_spark_off_check,
                           task_surface_parity_check, task_test_count,
                           task_test_count_check, task_test_layout_check,
                           task_tldr_check, task_tldr_lint, task_tools_check,
                           task_version_consistency_check,
                           task_version_source_check, task_clean)
from taskkit.release import (task_bump_version, task_publish, task_release,
                             task_sync, task_test_publish)


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
