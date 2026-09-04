# adacovex 1.43.0

Date: _2026-09-04_

Version bumped 1.42.0 -> 1.43.0.

## Changes

### C1: A warm prove hit restores gnatprove.out

The proof result cache stored only a success marker, so a warm hit on a
tree whose `obj/gnatprove/` had been wiped short-circuited the prover and
then assessed nothing: the pipeline found no `gnatprove.out`, reported
Stone with 0 VCs, and the run failed. The cache now also stores the
summary content under a `proveout:`-namespaced key derived from the input
hash, and a warm hit writes it back to
`<target>/obj/gnatprove/gnatprove.out` before the assessment starts. The
restored run reports the exact proof state the producing run reported
(Platinum / 876 VCs on the self-audit). A missing, oversized, or
unreadable summary blob degrades silently to the old behaviour -- never a
corrupt summary.

### C2: The warm-run walkers stop enumerating build-product trees

The strace profile of a warm run showed ~21k `newfstatat` calls, and
~13.3k of them (~53%) hit `docs/_build` -- the gitignored Sphinx build
tree of the bundled offline manual -- because fourteen distinct walkers
(the tools-key source-tree hash, the vendored discovery walk, the
graph-key language probe and vendored hash, the GPR collection walk, and
more) re-enumerated it on every run. The walkers that own a per-site skip
decision now skip `_build`: the tools scan and graph-key walks, the
scanner walk, the GPR collection walk, the vendored-component walk, the
`Vendored_Hash` tree hash, and the prove-input walk. `Skip_Walk_Dir`
itself deliberately does not change: `node_modules` stays out of it so
the generic vendored discovery still finds package manifests there, and
the `Vendored_Hash` tree hash now honours the shared skip set so `.venv`
and `alire` are never enumerated by it either. Warm syscalls drop to
~12k (-41%), warm wall time from ~40 ms to ~35 ms, and warm system time
from ~16 ms to ~10 ms. Cold wall drops from ~91 ms to ~86 ms.

### C3: The manifest-pinned gnatprove deployment says what it is doing

The first deployment of a manifest-pinned gnatprove downloads a ~130 MB
bundle through `alr -n get` and can take a minute on a slow link. It now
prints a progress line up front (`deploy: gnatprove <v> not in
~/.adacovex/toolchain -- downloading via alr (one-time, may take a
minute)...`) instead of sitting silent for the duration -- a silent
minute read as a hang. The deployment remains one-time per version:
every later run reuses the deployed crate under `~/.adacovex/toolchain/`
with no download, and two projects pinning different versions keep both
toolchains side by side.

### C4: make perf-bench prints the tables it measures

`perf stat` writes its counter table to stderr, which the old
capture-and-print-stdout shape discarded -- the perf sections printed
adacovex output but no counters. The `strace ... 2>&1 | tail -20` pipe
interleaved the workload's stdout with the summary table and cut the
header rows. Both tables now print in full (perf's from its stderr, the
full strace table including the header and total rows), a missing `perf`
or `strace` fails loudly with install guidance instead of silently
printing nothing, and the summary notes that strace serialises the
workload's threads so syscall counts -- not wall times -- are the signal.
The literal-`%%` typo in the summary text is gone.

## Fixes

(None this cycle. The cache-restore walk regression risk is covered by
the existing SBOM fixtures pinning `node_modules` discovery.)

## Test Suite

The native suite stays at 1222 tests across 17 categories, all passing.
The existing Result-cache and SBOM categories pin the restored-summary
and vendored-discovery behaviour this release touches (a `node_modules`
skip-set regression was caught by the SBOM fixtures during development
and fixed before it shipped).

## Proof Results

Platinum, 0 unproved, 0 justified, 876 VCs (876 proved) under gnatprove
16.1.0 across 56 analysed units -- unchanged from 1.42.0: this release
touches cache layout, walk skip sets, and reporting, not proof-affecting
code. Measured at the binary level (hyperfine, 12 logical cores, 10
proof jobs): prove warm ~40 ms, prove cold ~39.4 s (solver-dominated,
unchanged), pipeline warm ~35 ms, pipeline cold ~86 ms, warm-run
syscalls ~12k. The performance guide's comparison table now tracks the
last four trees and documents the `--level=1` cold-cost note (~68 s at
`-j0` on this machine at the same 876 VCs: level 1 re-tries each check
with stronger solver configurations, so lower levels are not strictly
faster).

## Traceability

- No new HLRs. The release changes performance internals, cache
  behaviour, and documentation only; the existing tags below cover it.
- `HLR-ARCH` -- C1 the cached-proof restore and C3 the deployment
  progress line (the on-disk result cache and the toolchain resolution
  are build/architecture infrastructure).
- `HLR-SCAN` / `HLR-MANIFEST` -- C2 the completed walk skip sets.
- `HLR-PROVE` -- the installation guide's resolution-tier documentation
  and the prove.ads contract refresh.
- `HLR-ARCH` -- the perf documentation refresh and this changelog
  (documentation currency is an architecture requirement).
