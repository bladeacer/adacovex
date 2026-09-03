# adacovex 1.42.0

Date: _2026-09-03_

Version bumped 1.41.0 -> 1.42.0.

## Changes

### C1: The result-cache read/write path moves whole blobs in one call

`Cache.Store` copied every cached blob byte-by-byte through a
`Stream_Element` conversion loop on write, and `Cache.Load` paid an
`Exists` stat plus a `Size` stat before re-running the same per-byte loop
on read. Both directions now build one `Stream_Element_Array` and issue a
single `Write`/`Read`: the allocator copies once and the kernel transfers
once per blob. `Load` also no longer stats the file before opening it --
the `Open` call already reports a missing file, so the extra syscall is
gone from every cache hit. The per-file hash fast path keeps a
size-stamped digest map, so a file hashed once in a run is never opened
again by a second walk over the same tree.

### C2: The per-run directory walks carry the full skip set

The strace profile of a warm run showed ~218k `newfstatat` calls in
1.41.0. Three directory walks were the source, and all three missed the
`.venv`/`node_modules`/installer-tree skip set the SBOM walk already had:

- the `.gpr` collection walk, which runs on *every* graph build before the
  cached-graph lookup, so its cost was paid warm and cold;
- the vendored-component discovery walk;
- the prove-input hash walk, which re-hashed every `.ads`/`.adb` under
  paths that can never hold proof units.

Completing the skip sets drops the warm syscall count to ~15k (14.8x) and
the warm wall time from ~104 ms to ~41 ms. The walk that locates a
target's `.gpr` files still descends into `tests/` and `docs/`: real
projects keep harness project files there, and the fixture in the SBOM
test category pins that behaviour.

### C3: Ecosystem metadata moves out of the result cache

The perf profile of a fully cold run showed 66% of CPU inside `node` and
17% inside `python`: the SBOM's ecosystem-metadata resolution spawns
registry tools (`npm view`, `pip index`, `cargo search`, ...) to fill the
licence/website fields, and those spawns lived under the result cache.
Wiping the cache -- or pointing `--cache-dir` at a fresh directory, as CI
does -- re-spawned all of them (~4 s of interpreter boots). The metadata
now lives in `~/.adacovex/meta/`, beside the version-probe store: it is
machine-level state with the same TTL model, so a cold result cache is no
longer a cold registry. `Cache_Schema` moved to s7 for the layout change.

### C4: `make bench` samples the prove subcommand, cold and warm

The benchmark script now times four hyperfine scenarios: the assessment
pipeline cold and warm, and the `prove` subcommand cold (`prove --no-cache`
against a fresh cache dir) and warm. The prove scenarios are the true test
of proof performance: they measure the adacovex binary's proving path
(input-hash walk, proof parse, pipeline re-run, SBOM) rather than the
gnatprove level alone. The measured 1.42.0 figures: pipeline warm ~43 ms,
prove warm ~51 ms, prove cold ~1.3 s (with the gnatprove session store
intact), and a one-time fully cold solver run of ~42 s when
`obj/gnatprove/` is wiped too. The performance guide documents the three
shapes so the numbers are never read as the wrong thing.

### C5: Multi-pair contract synthesis ships in the IR synthesiser

`Synthesize_Bounded_Function` takes a comma-separated `P:Type` parameter
list and emits the contract-carrying bounded-function spec: pass one
lowers every well-formed pair onto its bounded IR scalar (fixed-size
records, 32 pairs, named-constant bounds), pass two emits the signature,
pass three emits the joined `and then` half-range guard chain -- one
guard per signed parameter, none for modular ones. The three-pass form
follows the design recorded in 1.41.0: one slice per `Append`, bounds
carried in the length subtypes, no chained `&` assembly. Malformed pairs,
foreign type names, embedded spaces, and over-long lists degrade to an
empty string, never a truncated spec. The IR design doc now records the
implemented form instead of the deferred one.

## Fixes

### H1: The prove-input walk stats every entry once

The prove-input hash walk called `Kind (N)` -- a stat by path -- for each
directory entry after `Get_Next_Entry` had already returned the kind in
the entry record. The walk now reads `Kind (E)` and issues one stat per
entry fewer across the whole tree.

### H2: Cache stamp lookups never probe past an empty slot

The stamp-map fast path from 1.41.0 counted a probe-chain walk past an
empty slot as a hit candidate; the lookup now stops at the first empty
slot, matching the insertion probe order exactly.

## Test Suite

The native suite grows to 1222 tests across 17 categories: the IR
synthesis category grows from 33 to 42 tests, covering the multi-pair
three-pass form -- signature layout, guard-chain join, unsigned-only
lists (no contract), mixed signed lists, over-long-list degradation,
empty-pair and space rejection, and the nullary form. The Result-cache
category keeps the stamp-map and block-I/O behaviour pinned. All 1222
tests pass.

## Proof Results

Platinum, 0 unproved, 0 justified, 876 VCs (876 proved) under gnatprove
16.1.0 across 56 analysed units. The multi-pair slice adds 85 VCs over
the 1.41.0 lean slice; the bounded length subtypes keep the loop VCs
tractable, so the general form proved without justifications or
`SPARK_Mode (Off)` additions. Measured at the binary level (`make bench`,
hyperfine): prove warm ~51 ms (from ~2.5 s at 1.41.0), prove cold
(`prove --no-cache`, gnatprove session intact) ~1.3 s, and a one-time fully
cold solver run of ~42 s when `obj/gnatprove/` is wiped too. A warm
assessment run is ~43 ms (from ~104 ms in 1.41.0).

## Traceability

- No new HLRs. The release changes performance internals, the IR
  synthesiser, and documentation only; the existing tags below cover it.
- `HLR-ARCH` -- C1 the block-copy cache I/O, C3 the machine-level
  metadata store, C4 the prove-scenario benchmarks, and the H2
  stamp-lookup fix (the on-disk result cache is build/architecture
  infrastructure).
- `HLR-IR` -- C5 the multi-pair three-pass synthesis and the IR design
  doc update.
- `HLR-SCAN` / `HLR-MANIFEST` -- C2 the completed walk skip sets.
- `HLR-ARCH` -- the perf and IR documentation refresh and this changelog
  (documentation currency is an architecture requirement).
