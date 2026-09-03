#!/usr/bin/env python3
"""Benchmark the assessment pipeline + prove subcommand + binary size.

The old `make bench` recipe interleaved hyperfine invocations, a bash
`time` fallback loop, and a strip/size report in one long shell block
whose quoting (`$$bench_cache`, `--export-markdown` position, trap cleanup)
was easy to break.  This script owns the same flow:

  python3 tools/bench.py

- Pipeline cold timing: hyperfine with 10 runs over a freshly emptied
  result cache (when hyperfine is installed), else 5 Python-measured runs.
- Pipeline warm timing: one warm-up run to populate the caches, then
  hyperfine with 2 warm-ups + 15 runs (or 5 Python-measured runs).
- Prove cold timing: `prove --no-cache` against a freshly emptied result
  cache AND a wiped gnatprove session store (obj/gnatprove/), hyperfine
  with 3 runs.  This is the truly cold shape: every repetition pays a
  from-scratch solver run, as a first CI invocation on a bare runner
  would.  It is expensive by construction; see docs/contributing/perf.md
  for the cheaper adacovex-side-only cold shape.
- Prove warm timing: `prove` with the result cache populated, hyperfine
  with 2 warm-ups + 15 runs.  This is the true proof-performance number:
  the short-circuit path a developer hits on an unchanged tree.
- Binary size: a /tmp copy of bin/adacovex is stripped and both sizes are
  reported via tools/bench-size.py, so the build output is never modified.

Sample sizes match the old recipe (hyperfine 10 cold + 15 warm, fallback
5 + 5) so the reported means stay comparable with past runs.  The
hyperfine markdown exports still land in /tmp (adacovex-bench-cold.md /
adacovex-bench-warm.md / adacovex-bench-prove-*.md) as before.

Exit code 0 on success; 1 when the binary is missing, strip fails, or
bench-size.py reports a problem.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import List

ROOT: Path = Path(__file__).resolve().parent.parent

COLD_RUNS: int = 10
WARM_RUNS: int = 15
PROVE_COLD_RUNS: int = 3
PROVE_WARM_RUNS: int = 15
FALLBACK_RUNS: int = 5


def binary_path() -> Path:
    binary = ROOT / "bin" / "adacovex"
    if not binary.is_file():
        print(f"error: {binary} not found; run `make build` first", file=sys.stderr)
        sys.exit(1)
    return binary


def hyperfine_available() -> bool:
    return shutil.which("hyperfine") is not None


def run_cold_hyperfine(cache: str) -> None:
    print("=== Pipeline cold (fresh result cache) ===")
    cmd = [
        "hyperfine", "--runs", str(COLD_RUNS),
        "--prepare", f"rm -rf {cache}",
        f"./bin/adacovex --cache-dir={cache}",
        "--export-markdown", "/tmp/adacovex-bench-cold.md",
    ]
    subprocess.run(cmd, cwd=str(ROOT), check=True)


def run_warm_hyperfine(cache: str) -> None:
    # One warm-up run populates the result + probe caches.
    subprocess.run(
        [str(ROOT / "bin" / "adacovex"), f"--cache-dir={cache}"],
        cwd=str(ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    print("=== Pipeline warm (populated caches) ===")
    cmd = [
        "hyperfine", "--warmup", "2", "--runs", str(WARM_RUNS),
        f"./bin/adacovex --cache-dir={cache}",
        "--export-markdown", "/tmp/adacovex-bench-warm.md",
    ]
    subprocess.run(cmd, cwd=str(ROOT), check=True)


def ensure_proof_output() -> None:
    """Make sure <target>/obj/gnatprove/gnatprove.out exists.

    The pipeline scenarios grade the proof summary; without one the run
    grades Stone, DAL goes Unmet, and the binary exits 1 -- which hyperfine
    reports as a benchmark failure.  Generate the summary once (a full
    prove --no-cache) when it is missing so the pipeline scenarios measure
    the pipeline, not the absence of a proof.
    """
    out = ROOT / "obj" / "gnatprove" / "gnatprove.out"
    if out.is_file():
        return
    print("== proof summary missing; generating via one prove --no-cache ==")
    subprocess.run(
        [str(ROOT / "bin" / "adacovex"), "prove", "--no-cache"],
        cwd=str(ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def run_prove_cold_hyperfine(cache: str) -> None:
    # Truly cold: every repetition wipes the adacovex result cache AND the
    # gnatprove session store (obj/gnatprove/), so each run pays a full
    # from-scratch solver run -- the shape a first CI invocation on a bare
    # runner sees.  This is expensive (tens of seconds per repetition), so
    # the sample count is small.  The last repetition leaves a fresh
    # gnatprove.out behind, which the next run's ensure_proof_output picks
    # up (but a session wiped by THIS scenario does not hurt: the prove
    # subcommand regenerates everything it needs).
    print("=== Prove cold (--no-cache, result cache + gnatprove session wiped) ===")
    cmd = [
        "hyperfine", "--runs", str(PROVE_COLD_RUNS),
        "--prepare",
        f"rm -rf {cache} {ROOT}/obj/gnatprove",
        f"./bin/adacovex prove --no-cache --cache-dir={cache}",
        "--export-markdown", "/tmp/adacovex-bench-prove-cold.md",
    ]
    subprocess.run(cmd, cwd=str(ROOT), check=True)


def run_prove_warm_hyperfine(cache: str) -> None:
    # One warm-up run populates the prove result cache.
    subprocess.run(
        [str(ROOT / "bin" / "adacovex"), "prove", f"--cache-dir={cache}"],
        cwd=str(ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    print("=== Prove warm (populated prove cache) ===")
    cmd = [
        "hyperfine", "--warmup", "2", "--runs", str(PROVE_WARM_RUNS),
        f"./bin/adacovex prove --cache-dir={cache}",
        "--export-markdown", "/tmp/adacovex-bench-prove-warm.md",
    ]
    subprocess.run(cmd, cwd=str(ROOT), check=True)


def time_runs(cache: str, label: str, count: int, reset: bool,
              extra_args: List[str] = None) -> None:
    """Fallback timing loop using perf_counter (no hyperfine installed)."""
    print(f"== hyperfine not found; using bash time ({label}) ==")
    binary = str(ROOT / "bin" / "adacovex")
    args = [binary] + (extra_args or []) + [f"--cache-dir={cache}"]
    for i in range(1, count + 1):
        if reset:
            shutil.rmtree(cache, ignore_errors=True)
        start = time.perf_counter()
        subprocess.run(
            args,
            cwd=str(ROOT),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        elapsed = time.perf_counter() - start
        print(f"{label} run {i}: {elapsed:.3f} s")


def report_binary_size() -> int:
    stripped = Path(tempfile.gettempdir()) / "adacovex-strip-test"
    shutil.copy2(ROOT / "bin" / "adacovex", stripped)
    strip_rc = subprocess.run(["strip", str(stripped)]).returncode
    if strip_rc != 0:
        print(f"error: strip failed (rc={strip_rc})", file=sys.stderr)
        return 1
    print("== Binary size ==")
    rc = subprocess.run(
        [sys.executable, "tools/bench-size.py",
         str(ROOT / "bin" / "adacovex"), str(stripped)],
        cwd=str(ROOT),
    ).returncode
    stripped.unlink(missing_ok=True)
    return rc


def bench() -> int:
    binary_path()  # fail fast when the binary is missing
    cache = tempfile.mkdtemp(prefix="adacovex-bench-")
    prove_cache = tempfile.mkdtemp(prefix="adacovex-bench-prove-")
    try:
        ensure_proof_output()
        if hyperfine_available():
            run_cold_hyperfine(cache)
            run_warm_hyperfine(cache)
            run_prove_cold_hyperfine(prove_cache)
            run_prove_warm_hyperfine(prove_cache)
        else:
            time_runs(cache, "cold", FALLBACK_RUNS, reset=True)
            # Warm-up run populates the caches before the warm samples.
            subprocess.run(
                [str(ROOT / "bin" / "adacovex"), f"--cache-dir={cache}"],
                cwd=str(ROOT),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            time_runs(cache, "warm", FALLBACK_RUNS, reset=False)
            time_runs(prove_cache, "prove cold (--no-cache)",
                      FALLBACK_RUNS, reset=True, extra_args=["prove", "--no-cache"])
            # Warm-up run populates the prove result cache first.
            subprocess.run(
                [str(ROOT / "bin" / "adacovex"), "prove",
                 f"--cache-dir={prove_cache}"],
                cwd=str(ROOT),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            time_runs(prove_cache, "prove warm", FALLBACK_RUNS, reset=False)
        print()
        return report_binary_size()
    finally:
        shutil.rmtree(cache, ignore_errors=True)
        shutil.rmtree(prove_cache, ignore_errors=True)


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    return parser.parse_args(argv)


def main() -> int:
    parse_args(sys.argv[1:])
    return bench()


if __name__ == "__main__":
    sys.exit(main())
