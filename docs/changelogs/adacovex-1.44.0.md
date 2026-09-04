# adacovex 1.44.0

Date: _2026-09-04_

Version bumped 1.43.0 -> 1.44.0.

## Changes

### C1: Persistent stat-stamp store (cross-process dirty tracking)

The 1.28.0 stamp map dies with the process, so every adacovex invocation
re-opened and re-hashed every unchanged file: sources for scan keys,
manifests, lockfiles, and whole vendored trees for graph keys. 1.44.0
adds a persistent stat-stamp store at `~/.adacovex/stamps/`
(machine-local, outside the result cache, so `--cache-dir` redirection
and cache wipes never cost a re-hash). A record holds the file's size,
mtime, record time, and SHA-256 digest, keyed by the digest of the path;
a lookup is one open plus four short reads and validates exactly two
stats (size + mtime) against the stored pair. Two safety rules keep a
stale digest from ever being served for edited content: the size AND
mtime must both match, and a file modified during the second the record
was written is never recorded (git's racy-clean rule). Records expire
after 30 days.

Measured on the self-audit tree: warm-run syscalls drop from ~12k to
~2k (`newfstatat` ~26.8k -> ~2k), pipeline warm from ~35 ms to ~23 ms,
and pipeline cold from ~86 ms to ~60 ms -- a wiped result cache on a
stamped machine now re-serialises instead of re-hashing. New
`Persistent_Stamp_Hits` / `Persistent_Stamp_Misses` counters and a
`Reset_Process_Stamps` diagnostic (also useful to long-lived `--serve`
processes) make the fast path testable.

### C2: The stamp store is size-gated by measurement

Consulting the store for small files is a net loss: a lookup costs two
stats plus one open/read/close, while re-hashing a 10 KB source costs
the same open plus a cheap SHA-256 over a tiny payload -- measured on
the self-audit tree, stamping the 38 `.ads` sources made warm runs
slower, not faster. Files below 16 KiB are therefore never recorded and
never looked up; the store earns its keep on the payloads where
re-hashing dominates (vendored manifests, lockfiles, generated assets).
This cost model is the same one language servers apply when deciding
whether dirty-tracking pays for a given document.

### C3: Incremental-processing design credited to the studied projects

The design was informed by studying two reference projects for their
incremental-processing techniques -- the
[Ada Language Server](https://github.com/AdaCore/ada_language_server)
(persistent indexed file sets, cross-session dirty tracking) and
[tree-sitter](https://github.com/tree-sitter/tree-sitter) (reusable
single-buffer parse input) -- and the stamp validation follows the shape
of git's index dirty tracking, racy-clean guard included. Neither
project is linked into adacovex. The performance-engineering tools the
work relies on (perf, strace, hyperfine) are now credited with upstream
links in the Third-Party Notices and Credits pages.

## Fixes

### F1: Test-count and stamp-regression hardening

The 1.43.0 documentation edits left the perf guide's optimisation
history without the 1.44.0 entry; the comparison table now tracks the
last five trees. A stamp-store miss counter dropped during development
was restored and pinned by tests (a silent fast-path regression is
visible as `Persistent_Stamp_Hits = 0` with a non-empty store, the same
failure shape as the 1.28 name-length bug).

## Test Suite

The native suite grows from 1222 to 1228 tests across 17 categories, all
passing. Result-cache tests 22+ pin the new store: first hash of a
16 KiB+ file is a store miss, an unchanged file is served from the store
after `Reset_Process_Stamps`, a size change forces a re-hash with a
changed digest, and a sub-gate file never creates a stamp record.

## Proof Results

Platinum, 0 unproved, 0 justified, 876 VCs (876 proved) under gnatprove
16.1.0 across 56 analysed units -- unchanged: this release touches the
cache layer (I/O only, no proof-affecting contracts). Measured at the
binary level (hyperfine, 12 logical cores, 10 proof jobs): prove warm
~44 ms, prove cold ~36.4 s at 876 VCs (solver-dominated; the
adacovex-side share shrank again), pipeline warm ~23 ms, pipeline cold
~60 ms, warm-run syscalls ~2k. The perf guide's comparison table now
tracks 1.40.0 through 1.44.0.

## Traceability

- No new HLRs. The release changes cache internals, tests, and
  documentation only; the existing tags below cover it.
- `HLR-ARCH` -- C1/C2 the persistent stamp store and its size gate (the
  on-disk result cache and its machine-local satellite stores are
  build/architecture infrastructure), F1 the test-count sync, and the
  perf/credits/notices documentation refresh.
- `HLR-CACHE` -- C1 the stamp store's TTL, eviction-independent layout,
  and `Reset_Process_Stamps` contract.
- `HLR-SCAN` / `HLR-MANIFEST` -- C1 the store serves the scan and graph
  key hashing paths that those parsers drive.
