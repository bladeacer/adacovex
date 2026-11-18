"""CLI, prove-diagnostics, and dashboard end-to-end suites."""

import os
import re
import shutil
import subprocess
from typing import Dict, List, Tuple

from .build import task_build
from .common import PY, ROOT, run, skip_without_gnatprove


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
