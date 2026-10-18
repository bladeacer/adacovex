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
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import List, Optional, Tuple

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


def build_phase_section() -> None:
    """Profile and time every cold-build phase, then restore the tree.

    The strace profiles come first (the docs one needs no Sphinx build
    directory), then the timings; the docs timings end with a `--fresh`
    rebuild, so the working tree is left with an up-to-date build directory
    and spec.
    """
    strace_profile("alr build (warm no-op)", ["alr", "build"])
    strace_profile("gen-docs (cold tree)",
                   [sys.executable, "tools/gen-docs.py"], wipe=DOCS_WIPE)
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


def bench(section: str = "all") -> int:
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
        choices=("all", "build", "pipeline", "prove"),
        help="which scenarios to run (default: all; 'build' is the "
             "cold-build phases: strace profiles, warm no-op, cold "
             "fresh-checkout build, and the two docs shapes)")
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])
    return bench(args.section)


if __name__ == "__main__":
    sys.exit(main())
