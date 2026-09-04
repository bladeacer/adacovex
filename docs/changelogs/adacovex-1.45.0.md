# adacovex 1.45.0

Date: _2026-09-04_

Version bumped 1.44.0 -> 1.45.0.

## Changes

### C1: Single-file persistent stamp index (git-index shape)

The 1.44.0 stamp store spent ~2 syscalls per stamp lookup (open + read,
plus a 3-stat validation burst in the worst case). The store is now one
packed index file in the shape of git's index: a fixed-size header, then
fixed-width records of the path hash, size, mtime, record time, name, and
digest, written whole on flush (a 24-record throttle amortises the
rewrite; a process exit without a flush simply re-hashes next time). A
warm lookup loads the index once at first miss and then answers from
memory -- measured on the self-audit tree, the whole stamp subsystem
costs ~2 syscalls per run. The size gate (16 KiB) and the safety rules
(size AND mtime, racy-clean guard, 30-day TTL) are unchanged.

### C2: Shared directory-snapshot memo extended to every walker

The 1.44.0 per-process snapshot memo served hits only when a walker
spelled a directory the same way (`"."` vs `"src"` vs the absolute path),
so several walkers still re-enumerated the same trees. 1.45.0 resolves
every memo key to its absolute image (the process working directory is
read once and cached) and grows the slot table from 64 to 256 entries
(the self tree enumerates ~120 distinct directories).
`Collect_GPR_Files` joins the shared-snapshot walkers. Measured warm
memo hits rise from 43 to 107 on the self audit.

### C3: `_build` excluded from every shared walk

The strace profile showed the vendored-discovery walk enumerating the
Sphinx build tree (`docs/_build`, ~750 stats per run) because the shared
`Skip_Walk_Dir` did not exclude it. A build-product tree can never carry
a vendored package (no ecosystem manifest is authored there), so `_build`
(the shared convention for Sphinx, Meson, Dune, and GNAT build outputs)
joined the shared skip set.

### C4: Smarter system-tool table + run-time flag inference

The curated system-tool table now groups its 63 entries by category
(build drivers, language implementations and package managers, VCS,
documentation, CI/container, performance engineering) and stores only the
name and category. The version-probe flag is gone: the probe infers it at
run time by trying `--version`, then `-v`, then the `version` subcommand
and taking the first flag that yields a version token, so a
subcommand-only tool (go, fossil, git-lfs) needs no special-cased column
and a misconfigured entry cannot exist. The tools-cache fingerprint folds
names and categories (not per-tool flags) and the probe fallback chain
stays folded in, so a table edit self-invalidates the cache.
hyperfine, perf, and strace are detected (performance-engineering
category) alongside the existing sets.

### C5: Ada_CRDT as the secondary bench target

`tools/bench.py` measures the pipeline cold/warm shapes against
`../Ada_CRDT` (the dogfood tree) in addition to the self-audit tree, so a
regression tied to one project's file mix, vendored layout, or manifest
set cannot hide behind self-assessment numbers. The scenario is skipped
with a note when the tree is absent.

### C6: Benchmark machine documented

`docs/contributing/perf.md` now records the dev machine behind every
figure (CPU, cache hierarchy, memory, storage, toolchain) -- the specs
that plausibly affect a CLI benchmark. The GPU specs are deliberately
omitted: adacovex is CPU/I/O-bound and no code path touches a GPU.

## Fixes

### F1: Cached system-tool versions track the installed binary

A cached probe answer was keyed only on the tool name and a 7-day TTL, so
after upgrading a tool (jj is the reported case) the SBOM kept serving the
old version for up to a week. Both cache layers now carry the identity of
the binary the version was probed from -- the PATH-resolved executable
path plus its size and mtime, SHA-256-folded into a digest:

- the per-machine probe store writes the fingerprint image next to the
  version and serves the answer only while the live binary's fingerprint
  matches (`Get_Probe`/`Put_Probe` gained a `Fingerprint` parameter; a
  pre-1.45.0 one-line file is treated as a miss);
- the tools-set blob stores each probe's binary digest
  (`name=version@digest`); a cache hit re-validates every restored probe
  against the live binary and re-probes exactly the tools whose digest
  changed, refreshing both layers.

Verified with a PATH shim whose `--version` output changes between runs:
run 1 probes the shim, run 2 (upgraded shim, fully warm caches) re-probes
the new version, run 3 serves it from cache (49 ms), run 4 (real binary
restored) re-probes the real version. A version in the SBOM always
describes the binary installed now.

### F2: Version_flag unit removed

The per-tool stored flag made a misconfigured entry possible and
duplicated knowledge the probe fallback chain already owns; with flags
inferred at run time (C4) the unit had no purpose left. The tool-entry
documentation in `docs/usage/sbom.md` describes the inference instead.

### F3: perf-bench cache-hygiene warning fix

`tools/perf-bench.py` no longer imports `shutil` without use and its
warnings no longer fire; the cache-directory cleanup uses explicit
`--prepare` hooks in the hyperfine commands it drives.

## Test Suite

The native suite grows from 1228 to 1229 tests across 17 categories, all
passing. Result-cache test 11 pins the probe fingerprint contract: a
round trip serves the stored version, and a different fingerprint
(upgraded/replaced binary) is a miss.

## Proof Results

Platinum, 0 unproved, 0 justified, 876 VCs (876 proved) under gnatprove
16.1.0 across 57 analysed units -- the new memo and fingerprint helpers
carry provable contracts and add no justifications. Measured at the
binary level (hyperfine, 12 logical cores, 10 proof jobs): prove warm
~46 ms, prove cold ~36.8 s at 876 VCs (solver floor), pipeline warm
~41 ms, pipeline cold ~84 ms, warm-run syscalls ~6k. The perf guide's
comparison table now tracks 1.40.0 through 1.45.0, and its warm-wall
notes explain the 1.44.0 -> 1.45.0 movement (correct-version validation
plus wider memo coverage, not an I/O regression).

## Traceability

- No new HLRs. The release changes cache internals, the tool table, the
  bench harness, tests, and documentation; the existing tags below cover
  it.
- `HLR-ARCH` -- C1 the packed stamp index (cache infrastructure), C2/C3
  the shared-snapshot walkers and skip-set completion, C5 the bench
  harness, C6/F1-F3 and the perf/credits/notices documentation refresh.
- `HLR-CACHE` -- C1 the index flush contract and TTL, F1 the
  fingerprint-keyed probe store (a cached answer is valid only for the
  binary it describes).
- `HLR-SBOM` -- C4 the categorised tool table and run-time flag
  inference, F1 the correct-version guarantee for system-tool versions.
