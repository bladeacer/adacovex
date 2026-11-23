"""The `check` gate registry, phases, and runner."""

import os
import subprocess
from typing import Callable, Dict, List, Optional, Tuple

from .build import (task_book, task_build, task_doc, task_fmt, task_prove,
                    task_sbom, task_test)
from .common import (_PARALLEL_CAPTURE, PY, ROOT,
                     skip_without_alr, skip_without_gnatformat,
                     skip_without_gnatdoc, skip_without_gnatprove,
                     skip_without_sphinx)
from .e2e import task_cli_e2e, task_prove_e2e
from .gates import (task_action_parity_check, task_ascii_check,
                    task_book_links_check, task_book_spec_check,
                    task_changelog_check, task_complexity_check,
                    task_csslint_check, task_description,
                    task_diagnostics_coverage_check, task_docs_check,
                    task_docs_coverage_check, task_docs_tree,
                    task_link_check, task_para_split_check,
                    task_portability_check, task_proof_status,
                    task_requirements, task_requirements_check,
                    task_spark_off_check, task_surface_parity_check,
                    task_test_count, task_test_layout_check,
                    task_tldr_check, task_tools_check,
                    task_version_consistency_check, task_version_source_check)


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
    #  Regenerating, not verifying: `just check` refreshes the dynamic
    #  content of AGENTS.md (the documentation tree) rather than failing a
    #  change that moved a page.
    ("docs tree", task_docs_tree, None),
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
    #  The sync gates regenerate the dynamic content the run just produced:
    #  test counts and the AGENTS.md source tree, the proof metrics and
    #  badges, the crate description copies, and requirements.txt.  They run
    #  last because they read what the tests, the proof, and the build wrote.
    #  A stale generated file is refreshed here instead of failing the run;
    #  `just <gate> CHECK=1` (and the CI workflow) verifies without writing.
    ("test counts in sync", task_test_count, None),
    ("proof metrics in sync", task_proof_status, None),
    ("description sync", task_description, None),
    ("requirements sync", task_requirements, None),
]


#  The check runner keeps three short serial phases around one parallel
#  phase.  `fmt` and `build` must be first and alone (they rewrite sources
#  and artefacts), and the docs-tree regeneration follows them so every
#  later gate reads the current AGENTS.md; the manual, API-docs, SBOM, proof,
#  and tools gates run serially next, so every read-only gate sees a stable
#  tree; the sync gates run last, after the tests and proof have refreshed
#  their inputs, and they regenerate rather than verify.
CHECK_SERIAL_HEAD: List[str] = ["fmt", "build", "docs tree"]
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
