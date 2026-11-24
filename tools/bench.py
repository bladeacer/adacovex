#!/usr/bin/env python3
"""Benchmark the assessment pipeline + prove subcommand + build phases + binary size.

The old `make bench` recipe interleaved hyperfine invocations, a bash
`time` fallback loop, and a strip/size report in one long shell block
whose quoting (`$$bench_cache`, `--export-markdown` position, trap cleanup)
was easy to break.  This script owns the same flow:

  python3 tools/bench.py [all|build|pipeline|prove]

- Build warm timing: `alr build` on an already-built tree (the workspace
  sync + gprbuild no-op a developer pays after every source edit).
- Cold build timing: `tools/build.py --release` against a fresh copy of the
  tree with no `obj/`, no `bin/` and no `docs/_build/` -- the shape a first
  build on a freshly cloned checkout sees (generators, the workspace sync,
  and the full compile + link), 3 runs, each preceded by a wipe.  The copy
  keeps the working tree's build state untouched, so the scenario cannot
  flip the working tree's build profile or drop its gnatprove session.
- Docs timing: `gen-docs.py` on a tree with no Sphinx build directory (the
  cold-tree skip: the committed spec's `Source_Fingerprint` already records
  these sources, so Sphinx does not run) and `gen-docs.py --fresh` (the
  full Sphinx rebuild a docs edit pays), 3 runs each.
- Pipeline cold timing: hyperfine with 10 runs over a freshly emptied
  result cache (when hyperfine is installed), else 5 Python-measured runs.
- Pipeline warm timing: one warm-up run to populate the caches, then
  hyperfine with 2 warm-ups + 15 runs (or 5 Python-measured runs).
- Prove cold timing: `prove --no-cache` against a freshly emptied result
  cache AND a wiped gnatprove session store (obj/gnatprove/), hyperfine
  with 3 runs.  This is the truly cold shape: every repetition pays a
  from-scratch solver run, as a first CI invocation on a bare runner
  would.  It is expensive by construction; see docs/contributing/perf/prove-timing.md
  for the cheaper adacovex-side-only cold shape.
- Prove warm timing: `prove` with the result cache populated, hyperfine
  with 2 warm-ups + 15 runs.  This is the true proof-performance number:
  the short-circuit path a developer hits on an unchanged tree.
- Prove cold-clone timing: `prove` against a fresh copy of the target
  tree with no result cache, no gnatprove session, and no gnatprove.out
  (2 runs).  This is the shape a first run on a freshly cloned checkout
  sees: nothing is populated, and the proof summary the assessment
  grades does not even exist yet.  A copy of the working tree is used
  instead of a real `git clone` so the scenario also runs on a tree with
  no git history and cannot pick up build state; the measured work is
  the same.
- Build phase breakdown: each pre-build step (version spec, CSS gate,
  dashboard template, bundled manual, tldr page) timed on its own, then
  the parallel bundle exactly as tools/build.py runs it.  The step list is
  read from tools/build.py, so the bench cannot measure a phase the build
  does not run.  Hyperfine exports JSON and the script prints the sum of
  the step means beside the bundle mean, which is the overlap the build
  buys.
- Binary size: a /tmp copy of bin/adacovex is stripped and both sizes are
  reported via tools/bench-size.py, so the build output is never modified.

Sample sizes match the old recipe (hyperfine 10 cold + 15 warm, fallback
5 + 5) so the reported means stay comparable with past runs.  The build
phase samples are small (5 warm, 3 cold, 3 docs) because a cold compile is
about half a minute.  The
hyperfine markdown exports still land in /tmp (adacovex-bench-cold.md /
adacovex-bench-warm.md / adacovex-bench-build-*.md /
adacovex-bench-docs-*.md / adacovex-bench-prove-*.md) as before.

The `build` section also prints an strace syscall summary for the two cheap
phases (the no-op build and the cold-tree docs run), so the profile behind
each figure is reproducible with the same command.

Exit code 0 on success; 1 when the binary is missing, strip fails, or
bench-size.py reports a problem.
"""

import argparse
import importlib.util
import json
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent
SECONDARY: Path = ROOT.parent / "Ada_CRDT"

COLD_RUNS: int = 10
WARM_RUNS: int = 15
PROVE_COLD_RUNS: int = 3
PROVE_WARM_RUNS: int = 15
PROVE_CLONE_RUNS: int = 2
FALLBACK_RUNS: int = 5
BUILD_WARM_RUNS: int = 5
BUILD_COLD_RUNS: int = 3
DOCS_RUNS: int = 3
BUILD_PHASE_RUNS: int = 10

#  The syscalls the strace profile of a build phase reports: the stat/open
#  traffic that dominates a warm no-op build and the exec/read/write of a
#  real one.
STRACE_ROWS: Tuple[str, ...] = ("newfstatat", "openat", "read", "write",
                                "execve", "wait4", "total")


def load_avg() -> str:
    """The 1-minute load average, as recorded beside every figure.

    The scenarios run in sequence and each one loads the box, so a scenario
    measured late inherits the load the earlier ones left behind. Printing the
    reading in front of each scenario is what lets a reader tell a real
    difference from a sequence artefact -- see the paired-comparison note in
    docs/contributing/perf/prove-timing.md. Best effort: a machine without
    /proc/loadavg reports "unknown" rather than failing the bench.
    """
    try:
        return Path("/proc/loadavg").read_text().split()[0]
    except (OSError, IndexError):
        return "unknown"


def announce(label: str) -> None:
    """Print a scenario banner carrying the load it is measured under."""
    print(f"=== {label} (load {load_avg()}) ===")


def binary_path() -> Path:
    binary = ROOT / "bin" / "adacovex"
    if not binary.is_file():
        print(f"error: {binary} not found; run `just build` first", file=sys.stderr)
        sys.exit(1)
    return binary


def hyperfine_available() -> bool:
    return shutil.which("hyperfine") is not None


def run_cold_hyperfine(cache: str, target_args: List[str] = None,
                       label: str = "Pipeline cold (fresh result cache)") -> None:
    announce(label)
    cmd = [
        "hyperfine", "--runs", str(COLD_RUNS),
        "--prepare", f"rm -rf {cache}",
        "./bin/adacovex " + " ".join(target_args or []) + f" --cache-dir={cache}",
        "--export-markdown", "/tmp/adacovex-bench-cold.md",
    ]
    subprocess.run(cmd, cwd=str(ROOT), check=True)


def run_warm_hyperfine(cache: str, target_args: List[str] = None,
                       label: str = "Pipeline warm (populated caches)") -> None:
    # One warm-up run populates the result + probe caches.
    subprocess.run(
        [str(ROOT / "bin" / "adacovex")] + (target_args or [])
        + [f"--cache-dir={cache}"],
        cwd=str(ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    announce(label)
    cmd = [
        "hyperfine", "--warmup", "2", "--runs", str(WARM_RUNS),
        "./bin/adacovex " + " ".join(target_args or []) + f" --cache-dir={cache}",
        "--export-markdown", "/tmp/adacovex-bench-warm.md",
    ]
    subprocess.run(cmd, cwd=str(ROOT), check=True)


def make_build_clone() -> Path:
    """Copy the tree for a cold build: no obj/, no bin/, no docs/_build/.

    A fresh checkout carries neither compiled units nor the Sphinx build
    directory, so the scenario measures the first `just build` a new machine
    runs -- generators, workspace sync, full compile and link.  The working
    tree keeps its own build state (and its gnatprove session) untouched, so
    the scenario cannot flip the working tree's build profile.
    """
    clone = Path(tempfile.mkdtemp(prefix="adacovex-bench-build-")) / ROOT.name
    shutil.copytree(
        str(ROOT), str(clone),
        ignore=shutil.ignore_patterns("obj", "bin", ".git", ".adacovex",
                                      "_build"),
    )
    return clone


BUILD_CLONE_WIPE: str = "obj bin docs/_build"
DOCS_WIPE: str = "docs/_build obj/adacovex-docs-encode"


def strace_profile(label: str, argv: List[str], prepare: str = "",
                   wipe: str = "") -> None:
    """Print the strace -c syscall summary of one build-phase command.

    `wipe` names paths removed before the traced run (the cold shapes),
    `prepare` any other shell setup.  Only the rows in STRACE_ROWS are
    printed: the stat/open traffic that dominates a warm no-op build and the
    exec/read/write of real work.  strace serialises the workload, so the
    table is for syscall counts, never for wall time.
    """
    if shutil.which("strace") is None:
        print(f"== strace not found; skipping the {label} profile ==")
        return
    if wipe:
        for rel in wipe.split():
            shutil.rmtree(ROOT / rel, ignore_errors=True)
    announce(f"strace profile: {label}")
    log = Path(tempfile.gettempdir()) / "adacovex-bench-strace.txt"
    result = subprocess.run(["strace", "-f", "-c", "-o", str(log)] + argv,
                            cwd=str(ROOT), capture_output=True, text=True)
    if result.returncode != 0:
        print(f"note: strace {label} exited {result.returncode}")
    try:
        rows = log.read_text(errors="replace").splitlines()[1:]
    except OSError:
        return
    print(f"{'calls':>10}  syscall")
    for row in rows:
        parts = row.split()
        if len(parts) < 5 or parts[-1] not in STRACE_ROWS + ("totals",):
            continue
        #  strace drops the errors column when a syscall made none, so the
        #  calls count is the second or third field from the end.
        calls = parts[-3] if len(parts) >= 6 else parts[-2]
        name = "total" if parts[-1] == "totals" else parts[-1]
        print(f"{calls:>10}  {name}")


def run_build_warm() -> None:
    """`alr build` on an already-built tree (sync + gprbuild no-op)."""
    if hyperfine_available():
        announce("Build warm (alr build, no-op)")
        cmd = [
            "hyperfine", "--warmup", "1", "--runs", str(BUILD_WARM_RUNS),
            "alr build",
            "--export-markdown", "/tmp/adacovex-bench-build-warm.md",
        ]
        subprocess.run(cmd, cwd=str(ROOT), check=True)
        return
    print(f"== hyperfine not found; using bash time "
          f"(build warm, load {load_avg()}) ==")
    for i in range(1, FALLBACK_RUNS + 1):
        start = time.perf_counter()
        subprocess.run(["alr", "build"], cwd=str(ROOT),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"build warm run {i}: {time.perf_counter() - start:.3f} s")


def run_cold_build() -> None:
    """A full `just build --release` against a fresh copy of the tree."""
    clone = make_build_clone()
    try:
        if hyperfine_available():
            announce("Cold build (fresh checkout: generators + workspace "
                     "sync + compile, release profile)")
            cmd = [
                "hyperfine", "--runs", str(BUILD_COLD_RUNS),
                "--prepare",
                "rm -rf " + " ".join(f"{clone}/{p}"
                                     for p in BUILD_CLONE_WIPE.split()),
                "python3 tools/build.py --release",
                "--export-markdown", "/tmp/adacovex-bench-build-cold.md",
            ]
            subprocess.run(cmd, cwd=str(clone), check=True)
            return
        print(f"== hyperfine not found; using bash time "
              f"(cold build, load {load_avg()}) ==")
        for i in range(1, BUILD_COLD_RUNS + 1):
            for rel in BUILD_CLONE_WIPE.split():
                shutil.rmtree(clone / rel, ignore_errors=True)
            start = time.perf_counter()
            subprocess.run([sys.executable, "tools/build.py", "--release"],
                           cwd=str(clone), stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
            print(f"cold build run {i}: {time.perf_counter() - start:.3f} s")
    finally:
        shutil.rmtree(clone.parent, ignore_errors=True)


def run_docs_phases() -> None:
    """The two docs shapes: the cold-tree skip and the full Sphinx build."""
    encode_cache = ROOT / "obj" / "adacovex-docs-encode"
    if hyperfine_available():
        announce("Docs regen, cold tree (no Sphinx build directory; the "
                 "committed spec's fingerprint already records these sources)")
        cmd = [
            "hyperfine", "--runs", str(DOCS_RUNS),
            "--prepare", f"rm -rf {ROOT / 'docs' / '_build'} {encode_cache}",
            "python3 tools/gen-docs.py",
            "--export-markdown", "/tmp/adacovex-bench-docs-cold.md",
        ]
        subprocess.run(cmd, cwd=str(ROOT), check=True)
        announce("Docs regen, full Sphinx rebuild (--fresh)")
        cmd = [
            "hyperfine", "--runs", str(DOCS_RUNS),
            "--prepare", f"rm -rf {encode_cache}",
            "python3 tools/gen-docs.py --fresh",
            "--export-markdown", "/tmp/adacovex-bench-docs-fresh.md",
        ]
        subprocess.run(cmd, cwd=str(ROOT), check=True)
        return
    print(f"== hyperfine not found; using bash time "
          f"(docs phases, load {load_avg()}) ==")
    for label, args in (("docs cold tree", []), ("docs --fresh", ["--fresh"])):
        for i in range(1, DOCS_RUNS + 1):
            shutil.rmtree(ROOT / "docs" / "_build", ignore_errors=True)
            shutil.rmtree(encode_cache, ignore_errors=True)
            start = time.perf_counter()
            subprocess.run([sys.executable, "tools/gen-docs.py"] + args,
                           cwd=str(ROOT), stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
            print(f"{label} run {i}: {time.perf_counter() - start:.3f} s")


def pre_build_steps() -> Sequence[Tuple[str, List[str]]]:
    """The pre-build steps tools/build.py runs, read from that module.

    Keeping one source of truth means a step added to the build is measured
    by `just bench` the first time the build runs it, and a step removed
    from the build cannot linger in a stale benchmark table.
    """
    spec = importlib.util.spec_from_file_location(
        "adacovex_build", ROOT / "tools" / "build.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module.PRE_BUILD_STEPS


def hyperfine_json(commands: List[str], runs: int,
                   warmup: int = 1) -> Optional[List[dict]]:
    """Run hyperfine over several commands and return its per-command JSON.

    Returns None when hyperfine is missing or the export cannot be read, so
    the caller can fall back to a plain timing loop.
    """
    export = Path(tempfile.gettempdir()) / "adacovex-bench-phases.json"
    export.unlink(missing_ok=True)
    result = subprocess.run(
        ["hyperfine", "--warmup", str(warmup), "--runs", str(runs)]
        + commands + ["--export-json", str(export)],
        cwd=str(ROOT),
    )
    if result.returncode != 0:
        return None
    try:
        return json.loads(export.read_text())["results"]
    except (OSError, ValueError, KeyError):
        return None


def row_seconds(row: dict, field: str) -> float:
    """Read a hyperfine result's wall-clock mean or deviation, in seconds.

    Hyperfine 2.x nests the statistics under `summary.time_wall_clock`
    while older exports put `mean`/`stddev` at the top level; accept both.
    """
    if field in row:
        return float(row[field])
    return float(row["summary"]["time_wall_clock"][field])


def run_build_phase_breakdown() -> None:
    """Time every pre-build step on its own, then the parallel bundle.

    The steps are independent, and tools/build.py runs them concurrently,
    so the bundle's wall time is the slowest step plus startup, not the
    sum.  Printing both makes that overlap visible and gives the cold
    build's generator cost a per-step attribution.
    """
    steps = pre_build_steps()
    if hyperfine_available():
        announce("Build phase breakdown (each pre-build step alone)")
        results = hyperfine_json(
            [shlex.join(cmd) for _, cmd in steps], BUILD_PHASE_RUNS)
        if results is not None:
            print(f"{'mean':>10}  {'sigma':>8}  step")
            total = 0.0
            for (label, _), row in zip(steps, results):
                mean = row_seconds(row, "mean") * 1000.0
                total += mean
                print(f"{mean:9.1f}ms "
                      f"{row_seconds(row, 'stddev') * 1000:7.1f}ms  {label}")
            print(f"{total:9.1f}ms {'':8}  sum of the steps (serial)")
            announce("Pre-build bundle (parallel, as tools/build.py runs it)")
            bundle = hyperfine_json(
                [f"{shlex.quote(sys.executable)} tools/build.py --steps-only"],
                BUILD_PHASE_RUNS)
            if bundle is not None and bundle:
                mean = row_seconds(bundle[0], "mean") * 1000.0
                print(f"{mean:9.1f}ms "
                      f"{row_seconds(bundle[0], 'stddev') * 1000:7.1f}ms  "
                      "bundle (parallel)")
                if mean > 0:
                    print(f"{'':>10}  {'':>8}  overlap saves "
                          f"{total - mean:.1f} ms ({100.0 * (total - mean) / total:.0f}% of the serial sum)")
        return
    print(f"== hyperfine not found; using bash time "
          f"(build phases, load {load_avg()}) ==")
    for label, cmd in steps:
        start = time.perf_counter()
        subprocess.run(cmd, cwd=str(ROOT), stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        print(f"{label}: {time.perf_counter() - start:.3f} s")
    start = time.perf_counter()
    subprocess.run([sys.executable, "tools/build.py", "--steps-only"],
                   cwd=str(ROOT), stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)
    print(f"bundle (parallel): {time.perf_counter() - start:.3f} s")


def build_phase_section() -> None:
    """Profile and time every cold-build phase, then restore the tree.

    The strace profiles come first (the docs one needs no Sphinx build
    directory), then the per-step breakdown, then the timings; the docs
    timings end with a `--fresh` rebuild, so the working tree is left with
    an up-to-date build directory and spec.
    """
    strace_profile("alr build (warm no-op)", ["alr", "build"])
    strace_profile("gen-docs (cold tree)",
                   [sys.executable, "tools/gen-docs.py"], wipe=DOCS_WIPE)
    run_build_phase_breakdown()
    run_build_warm()
    run_cold_build()
    run_docs_phases()


def ensure_proof_output(target: Path = ROOT) -> None:
    """Make sure <target>/obj/gnatprove/gnatprove.out exists.

    The pipeline scenarios grade the proof summary; without one the run
    grades Stone, DAL goes Unmet, and the binary exits 1 -- which hyperfine
    reports as a benchmark failure.  Generate the summary once (a full
    prove --no-cache) when it is missing so the pipeline scenarios measure
    the pipeline, not the absence of a proof.
    """
    out = target / "obj" / "gnatprove" / "gnatprove.out"
    if out.is_file():
        return
    print(f"== proof summary missing for {target.name}; one prove --no-cache ==")
    subprocess.run(
        [str(ROOT / "bin" / "adacovex"), "prove", "--no-cache",
         f"--target={target}"],
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
    announce("Prove cold (--no-cache, result cache + gnatprove session wiped)")
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
    announce("Prove warm (populated prove cache)")
    cmd = [
        "hyperfine", "--warmup", "2", "--runs", str(PROVE_WARM_RUNS),
        f"./bin/adacovex prove --cache-dir={cache}",
        "--export-markdown", "/tmp/adacovex-bench-prove-warm.md",
    ]
    subprocess.run(cmd, cwd=str(ROOT), check=True)


def make_clone(target: Path) -> Optional[Path]:
    """Copy the target tree to /tmp without its build or VCS state.

    The cold-clone scenario needs a tree that carries no cached proof work:
    no obj/ (gnatprove session), no bin/ (build output), no .git, and no
    committed .adacovex result-cache state.  Everything else (sources,
    manifests, docs) is copied, because those are exactly what a fresh
    checkout would carry.
    """
    clone = Path(tempfile.mkdtemp(prefix="adacovex-bench-clone-")) / target.name
    shutil.copytree(
        str(target), str(clone),
        ignore=shutil.ignore_patterns("obj", "bin", ".git", ".adacovex"),
    )
    return clone


def run_prove_clone_hyperfine(cache: str, target: Path = ROOT) -> None:
    # Cold clone: a fresh copy of the tree with no result cache, no
    # gnatprove session, and no gnatprove.out.  Every repetition recopies
    # the clone and wipes the result cache, so each run pays the full
    # first-run cost: pipeline + session-less solver run + summary parse.
    clone = make_clone(target)
    try:
        announce("Prove cold clone (fresh tree: no cache, no session, "
                 "no summary)")
        cmd = [
            "hyperfine", "--runs", str(PROVE_CLONE_RUNS),
            "--prepare",
            f"rm -rf {cache} {clone}/obj {clone}/bin {clone}/.adacovex",
            f"./bin/adacovex prove --cache-dir={cache} --target={clone}",
            "--export-markdown", "/tmp/adacovex-bench-prove-clone.md",
        ]
        subprocess.run(cmd, cwd=str(ROOT), check=True)
    finally:
        shutil.rmtree(clone.parent, ignore_errors=True)


def time_runs(cache: str, label: str, count: int, reset: bool,
              extra_args: List[str] = None) -> None:
    """Fallback timing loop using perf_counter (no hyperfine installed)."""
    print(f"== hyperfine not found; using bash time "
          f"({label}, load {load_avg()}) ==")
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


def time_prove_clone(cache: str, target: Path) -> None:
    """Fallback timing loop for the cold-clone prove shape."""
    clone = make_clone(target)
    try:
        print(f"== hyperfine not found; using bash time "
              f"(prove cold clone, load {load_avg()}) ==")
        binary = str(ROOT / "bin" / "adacovex")
        for i in range(1, PROVE_CLONE_RUNS + 1):
            shutil.rmtree(cache, ignore_errors=True)
            shutil.rmtree(clone / "obj", ignore_errors=True)
            shutil.rmtree(clone / "bin", ignore_errors=True)
            shutil.rmtree(clone / ".adacovex", ignore_errors=True)
            start = time.perf_counter()
            subprocess.run(
                [binary, "prove", f"--cache-dir={cache}",
                 f"--target={clone}"],
                cwd=str(ROOT),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            elapsed = time.perf_counter() - start
            print(f"prove cold clone run {i}: {elapsed:.3f} s")
    finally:
        shutil.rmtree(clone.parent, ignore_errors=True)


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


#  ``just perf-report`` samples: small, because the report runs at every
#  version bump and the cold shapes are expensive by construction.
REPORT_RUNS: dict = {
    "pipeline cold": 5,
    "pipeline warm": 10,
    "prove warm": 5,
    "build warm": 3,
    "docs cold tree": 2,
    "docs fresh": 2,
}


def measure(label: str, command: str, runs: int, warmup: int = 1,
            prepare: str = "", cwd: Path = ROOT,
            env: Optional[dict] = None) -> dict:
    """Time one command and return a report row.

    The measurement primitive behind `just perf-report`: hyperfine when it is
    installed (its JSON export owns the mean and the deviation), otherwise a
    plain wall-clock loop.  A host without hyperfine still produces a
    complete row, marked with the tool that measured it, so the report never
    silently drops a metric.
    """
    row: dict = {
        "label": label,
        "command": command,
        "runs": runs,
        "warmup": warmup,
        "mean_s": None,
        "stddev_s": None,
        "tool": "hyperfine",
    }
    export = Path(tempfile.gettempdir()) / "adacovex-perf-report.json"
    if hyperfine_available():
        export.unlink(missing_ok=True)
        cmd = ["hyperfine", "--warmup", str(warmup), "--runs", str(runs)]
        if prepare:
            cmd += ["--prepare", prepare]
        cmd += [command, "--export-json", str(export)]
        result = subprocess.run(cmd, cwd=str(cwd), env=env)
        if result.returncode == 0:
            try:
                entry = json.loads(export.read_text())["results"][0]
                row["mean_s"] = row_seconds(entry, "mean")
                row["stddev_s"] = row_seconds(entry, "stddev")
                return row
            except (OSError, ValueError, KeyError):
                pass
    row["tool"] = "time"
    samples: List[float] = []
    for _ in range(runs):
        if prepare:
            subprocess.run(prepare, shell=True, cwd=str(cwd), env=env,
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
        started = time.perf_counter()
        subprocess.run(command, shell=True, cwd=str(cwd), env=env,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        samples.append(time.perf_counter() - started)
    mean = sum(samples) / len(samples)
    variance = sum((s - mean) ** 2 for s in samples) / len(samples)
    row["mean_s"] = mean
    row["stddev_s"] = variance ** 0.5
    return row


def _first_line(argv: List[str]) -> str:
    """The first line of a tool's version banner, or "unknown"."""
    try:
        result = subprocess.run(argv, capture_output=True, text=True,
                                timeout=10)
    except (OSError, subprocess.SubprocessError):
        return "unknown"
    line = (result.stdout or result.stderr or "").splitlines()
    return line[0].strip() if line else "unknown"


def _cpu_model() -> str:
    """The CPU model, read from /proc/cpuinfo where the host provides it."""
    try:
        for line in Path("/proc/cpuinfo").read_text(errors="replace").splitlines():
            if line.lower().startswith(("model name", "hardware", "cpu model")):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "unknown"


def _filesystem() -> str:
    """The filesystem type under the repository root."""
    try:
        result = subprocess.run(["findmnt", "-no", "FSTYPE", "-T", str(ROOT)],
                                capture_output=True, text=True, timeout=10)
        kind = result.stdout.strip()
        if result.returncode == 0 and kind:
            return kind
    except (OSError, subprocess.SubprocessError):
        pass
    return "unknown"


def _build_profile() -> str:
    """The Alire build profile the current workspace was built with."""
    settings = ROOT / "alire" / "settings.toml"
    try:
        for line in settings.read_text(errors="replace").splitlines():
            if line.startswith("last_build_profile"):
                return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "unknown"


def host_profile() -> dict:
    """The machine a report was measured on.

    A figure without this context is not comparable with another figure, so
    every generated page carries the profile beside its table.
    """
    return {
        "cpu": _cpu_model(),
        "cores": os.cpu_count() or 0,
        "kernel": platform.release(),
        "platform": f"{platform.system()} {platform.machine()}",
        "filesystem": _filesystem(),
        "compiler": _first_line(["gnatmake", "--version"]),
        "gnatprove": _first_line(["gnatprove", "--version"]),
        "build_profile": _build_profile(),
        "hyperfine": _first_line(["hyperfine", "--version"]),
        "strace": _first_line(["strace", "--version"]),
        "load_average": load_avg(),
    }


def cache_readings(extra_args: Sequence[str] = ()) -> dict:
    """Run the pipeline once and report its cache hit, miss, and evicted counts.

    The warm-up run of the timing scenarios already pays this work; this run
    keeps one captured copy its own so the numbers cannot be mixed with a
    hyperfine sample.
    """
    cache = tempfile.mkdtemp(prefix="adacovex-perf-cache-")
    try:
        run = [str(ROOT / "bin" / "adacovex")] + list(extra_args) \
            + [f"--cache-dir={cache}"]
        subprocess.run(run, cwd=str(ROOT), stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        result = subprocess.run(run, cwd=str(ROOT), capture_output=True,
                                text=True)
        match = re.search(r"(\d+) hit\(s\), (\d+) miss\(es\), "
                          r"(\d+) evicted", result.stdout)
        if match:
            return {"hits": int(match.group(1)),
                    "misses": int(match.group(2)),
                    "evicted": int(match.group(3))}
        return {"hits": 0, "misses": 0, "evicted": 0,
                "note": "no cache line in the pipeline output"}
    finally:
        shutil.rmtree(cache, ignore_errors=True)


def syscall_readings(extra_args: Sequence[str] = ()) -> List[dict]:
    """The strace -c counts of one pipeline run, for the report table.

    strace serialises the workload, so these are syscall counts, never wall
    time.  A host without strace reports an empty list and the report page
    says why instead of inventing a figure.
    """
    if shutil.which("strace") is None:
        return []
    cache = tempfile.mkdtemp(prefix="adacovex-perf-strace-")
    log = Path(tempfile.gettempdir()) / "adacovex-perf-strace.txt"
    try:
        run = [str(ROOT / "bin" / "adacovex")] + list(extra_args) \
            + [f"--cache-dir={cache}"]
        subprocess.run(run, cwd=str(ROOT), stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        subprocess.run(["strace", "-f", "-c", "-o", str(log)] + run,
                       cwd=str(ROOT), stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        try:
            rows = log.read_text(errors="replace").splitlines()[1:]
        except OSError:
            return []
        readings: List[dict] = []
        for row in rows:
            parts = row.split()
            if len(parts) < 5 or parts[-1] not in STRACE_ROWS + ("totals",):
                continue
            calls = parts[-3] if len(parts) >= 6 else parts[-2]
            readings.append({
                "syscall": "total" if parts[-1] == "totals" else parts[-1],
                "calls": int(calls) if calls.isdigit() else 0,
            })
        return readings
    finally:
        shutil.rmtree(cache, ignore_errors=True)


def binary_readings() -> dict:
    """The raw and stripped size of bin/adacovex, in bytes."""
    raw = ROOT / "bin" / "adacovex"
    stripped = Path(tempfile.gettempdir()) / "adacovex-perf-strip"
    try:
        shutil.copy2(raw, stripped)
        if subprocess.run(["strip", str(stripped)]).returncode != 0:
            return {"raw": raw.stat().st_size, "stripped": None}
        return {"raw": raw.stat().st_size, "stripped": stripped.stat().st_size}
    finally:
        stripped.unlink(missing_ok=True)


def docs_readings() -> dict:
    """The committed bundle's size, page count, and fingerprint.

    Read from the generated spec, never from a Sphinx build directory, so the
    figure describes the artifact the binary carries.
    """
    spec = ROOT / "src" / "adacovex-docs_template.ads"
    readings: dict = {"spec_bytes": 0, "assets": 0, "bodies": 0,
                      "fingerprint": "unknown"}
    try:
        readings["spec_bytes"] = spec.stat().st_size
        text = spec.read_text(errors="replace")
        for key, pattern in (
                ("assets", r"Asset_Count\s*:\s*constant\s*:=\s*(\d+)"),
                ("bodies", r"Body_Count\s*:\s*constant\s*:=\s*(\d+)")):
            match = re.search(pattern, text)
            readings[key] = int(match.group(1)) if match else 0
        match = re.search(
            r'Source_Fingerprint\s*:\s*constant\s+String\s*:=\s*"([0-9a-f]+)"',
            text)
        if match:
            readings["fingerprint"] = match.group(1)
    except OSError:
        pass
    return readings


def collect_report(release: bool = False, version: str = "") -> dict:
    """Measure every metric family `just perf-report` publishes.

    One call owns the scenario list, so the report and `just bench` cannot
    drift into two recipes.  The cold shapes wipe only their own temporary
    cache; the working tree's cache, session store, and spec are untouched.

    `release` measures the release profile: the warm build row runs `alr
    build --release`, which is a no-op on a tree tools/release.py already
    built, so the measurement cannot relink the release binary as a
    development one.  `version` names the release the report describes when
    the manifest has not been bumped yet.
    """
    binary_path()
    ensure_proof_output()
    cache = tempfile.mkdtemp(prefix="adacovex-perf-report-")
    prove_cache = tempfile.mkdtemp(prefix="adacovex-perf-report-prove-")
    scenarios: List[dict] = []
    try:
        pipeline = f"./bin/adacovex --cache-dir={cache}"
        scenarios.append(measure(
            "pipeline cold", pipeline, REPORT_RUNS["pipeline cold"],
            warmup=0, prepare=f"rm -rf {cache}"))
        scenarios.append(measure(
            "pipeline warm", pipeline, REPORT_RUNS["pipeline warm"],
            warmup=2))
        scenarios.append(measure(
            "prove warm", f"./bin/adacovex prove --cache-dir={prove_cache}",
            REPORT_RUNS["prove warm"], warmup=1))
        build_command = "alr build --release" if release else "alr build"
        scenarios.append(measure(
            "build warm", build_command, REPORT_RUNS["build warm"],
            warmup=1))
        #  Settle the committed spec first: the cold-tree row is the
        #  fingerprint-hit shape, so a spec that is stale against the sources
        #  would measure one full Sphinx build instead.  The untimed run is
        #  also the correctness precondition the row claims.
        subprocess.run([sys.executable, "tools/gen-docs.py"], cwd=str(ROOT),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        scenarios.append(measure(
            "docs cold tree", f"{shlex.quote(sys.executable)} tools/gen-docs.py",
            REPORT_RUNS["docs cold tree"], warmup=0,
            prepare="rm -rf docs/_build obj/adacovex-docs-encode"))
        scenarios.append(measure(
            "docs fresh",
            f"{shlex.quote(sys.executable)} tools/gen-docs.py --fresh",
            REPORT_RUNS["docs fresh"], warmup=0,
            prepare="rm -rf obj/adacovex-docs-encode"))
    finally:
        shutil.rmtree(cache, ignore_errors=True)
        shutil.rmtree(prove_cache, ignore_errors=True)

    counts = _native_test_counts()

    return {
        "version": version or _project_version(),
        "host": host_profile(),
        "scenarios": scenarios,
        "cache": cache_readings(),
        "syscalls": syscall_readings(),
        "binary": binary_readings(),
        "docs": docs_readings(),
        "tests": counts,
    }


def _native_test_counts() -> dict:
    """The native suite counts from test_result.md, via the sync tool.

    The parser lives in tools/update-test-count.py, whose hyphenated name
    needs an explicit import; a missing or unreadable result file reports
    zeros rather than failing the whole report.
    """
    try:
        spec = importlib.util.spec_from_file_location(
            "adacovex_test_count", ROOT / "tools" / "update-test-count.py")
        if spec is None or spec.loader is None:
            return {"passed": 0, "failed": 0}
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _, passed, failed = module.parse_result(ROOT / "test_result.md")
        return {"passed": passed, "failed": failed}
    except (OSError, SystemExit, ValueError, AttributeError):
        return {"passed": 0, "failed": 0}


def _project_version() -> str:
    """The version the report describes, read from the dev manifest."""
    try:
        for line in (ROOT / "alire-dev.toml").read_text(errors="replace").splitlines():
            if line.startswith("version"):
                return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "unknown"


def bench(section: str = "all") -> int:
    if section == "report":
        print(json.dumps(collect_report(), indent=2))
        return 0
    binary_path()  # fail fast when the binary is missing
    if section in ("all", "build"):
        build_phase_section()
        if section == "build":
            print()
            return report_binary_size()
    cache = tempfile.mkdtemp(prefix="adacovex-bench-")
    prove_cache = tempfile.mkdtemp(prefix="adacovex-bench-prove-")
    try:
        if section in ("all", "pipeline"):
            ensure_proof_output()
            if hyperfine_available():
                run_cold_hyperfine(cache)
                run_warm_hyperfine(cache)
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
        if section in ("all", "prove"):
            if hyperfine_available():
                run_prove_cold_hyperfine(prove_cache)
                run_prove_warm_hyperfine(prove_cache)
                run_prove_clone_hyperfine(prove_cache)
            else:
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
                time_prove_clone(prove_cache, ROOT)
        # Secondary target: the Ada_CRDT dogfood tree exercises a second
        # codebase shape (different file mix, vendored layout, manifest set)
        # so a regression tied to one project's structure cannot hide behind
        # self-assessment numbers.  Pipeline shapes only -- the prove shapes
        # are already covered against the primary tree.
        if section == "all":
            if SECONDARY.is_dir():
                sec_cache = tempfile.mkdtemp(prefix="adacovex-bench-crdt-")
                try:
                    ensure_proof_output(SECONDARY)
                    sec_args = [f"--target={SECONDARY}"]
                    if hyperfine_available():
                        run_cold_hyperfine(sec_cache, sec_args,
                                           f"Pipeline cold, secondary target {SECONDARY.name}")
                        run_warm_hyperfine(sec_cache, sec_args,
                                           f"Pipeline warm, secondary target {SECONDARY.name}")
                    else:
                        time_runs(sec_cache, f"cold ({SECONDARY.name})",
                                  FALLBACK_RUNS, reset=True, extra_args=sec_args)
                        subprocess.run(
                            [str(ROOT / "bin" / "adacovex")] + sec_args
                            + [f"--cache-dir={sec_cache}"],
                            cwd=str(ROOT),
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                        time_runs(sec_cache, f"warm ({SECONDARY.name})",
                                  FALLBACK_RUNS, reset=False, extra_args=sec_args)
                finally:
                    shutil.rmtree(sec_cache, ignore_errors=True)
            else:
                print(f"== secondary target {SECONDARY} not present; skipped ==")
            print()
            return report_binary_size()
        print()
        return 0
    finally:
        shutil.rmtree(cache, ignore_errors=True)
        shutil.rmtree(prove_cache, ignore_errors=True)


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "section", nargs="?", default="all",
        choices=("all", "build", "pipeline", "prove", "report"),
        help="which scenarios to run (default: all; 'build' is the "
             "cold-build phases: strace profiles, warm no-op, cold "
             "fresh-checkout build, and the two docs shapes; 'report' "
             "prints the perf-report measurement set as JSON)")
    return parser.parse_args(argv)


def main() -> int:
    #  The scenario banners and the phase table are ours; hyperfine writes
    #  straight to the inherited descriptor. Line buffering keeps the two in
    #  order when the run is redirected to a file, where block buffering
    #  would flush our lines after every benchmark table.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
    args = parse_args(sys.argv[1:])
    return bench(args.section)


if __name__ == "__main__":
    sys.exit(main())
