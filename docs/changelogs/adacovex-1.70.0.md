# adacovex 1.70.0

Date: _2026-11-14_

Version bumped 1.69.0 -> 1.70.0.

## Changes

### C1: The SBOM parser is measured against syft

`docs/usage/sbom-syft.md` records a component, version, and licence
comparison with [Anchore's syft](https://github.com/anchore/syft) over three
trees: adacovex itself, yams, and Ada_CRDT. syft was built from a source
checkout and run as `syft dir:<path> -o json`; adacovex ran
`sbom --format=cyclonedx-json`; one script counted both documents. On the
development tree syft reports 63 components (56 versioned, 23 licensed) and
adacovex 25 (22, 5). The page explains each difference: syft reads the
installed `.venv` closure and the `obj/` test fixtures, while adacovex reads
the declared manifests; only adacovex reports system tools; syft has no Alire
or GPR cataloger, so Ada_CRDT's crate graph is invisible to it.

The page also states the gaps worth closing under the zero-dependency rule
(workflow action usage, dev-dependency inclusion, lockfile-resolved licence)
and the gaps rejected by decision (installed environments, generated trees,
container images). syft stays a measurement reference: adacovex never calls
it, and the attribution is in `docs/THIRD_PARTY_NOTICES.md` and
`docs/CREDITS.md`.

### C2: A technical debt register

`docs/contributing/debt.md` starts the register the v1.69.0-v1.75.0 releases
need. Each entry states the defect, the condition that closes it ("done
when"), and its state: open, closed with the version that closed it, or
accepted with the reason. The page names the standing SPARK constraints --
`SPARK_Mode (Off)` at exactly `Types.Implementation` and `Complexity`, and
contracts on every new executable statement -- so a later entry cannot
propose work that breaks either one. Fourteen entries cover diagnostics,
manifest parsing, bounded strings, time, help, cache parity and identity,
colour, CI annotations, the pipeline budget, and the docstring pass.

### C3: The check pipeline is measured per gate

A full `just check` run on 2026-11-14 recorded per-gate wall time for all 31
gates on the development machine (12 logical CPUs, built tree, warm result
cache, warm gnatprove session). The warm run passed all 31 gates in 452.99 s
and replaced the single 344 s figure from 2026-11-06 with the gate table in
`docs/contributing/perf/check-pipeline.md`.

The raw stdout of both runs is kept in `obj/`. The page names the slowest
gates: the complexity walk at 131.15 s, the prove diagnostics fixtures at
72.55 s, and the tools unit tests at 69.27 s. The SPARK proof is 5.63 s on a
warm cache hit and 155.33 s on the cold pass in the same session.

### C4: Docstring pass for the changed packages

`Adacovex.Parsers.Manifest` now documents the scan scope the code enforces:
dev-facing build files only, with source files, prose, and generated build
trees excluded. The spec docstring previously listed Ada sources and Python
tools, which
`Should_Scan` had already stopped reading. The predicate that decides a
directory, `Skip_Scan_Dir`, documents the two-way build-tree rule and its
use by the cache key.

## Fixes

### H1: A generated build tree no longer registers a system tool

`adacovex sbom` over yams, a C project built with Meson, listed `cargo` and
`go` as system dependencies and tied both to the root. Neither tool is
installed by the project: its generated `build/` and `builddir/` trees record
the developer's `PATH` in Meson logs, Ninja state, and CMake configure
output, and the tool scan descended into them. The word `cargo` matched
`/home/dev/.cargo/bin` in a Meson log.

`Skip_Scan_Dir` owns the directory decision for the tool scan. A generated
tree is recognised by its conventional name (`build`, `builddir`, `target`,
`dist`, `out`, `coverage`) and by the build-system state inside it
(`build.ninja`, `meson-info`, `CMakeCache.txt`, `compile_commands.json`), so a
tree under any other name is skipped too. `Source_Tree_Hash` uses the same
predicate, so the tool-set cache key covers exactly the files the scan reads.
The tool-set key's namespace salt moved to `namespace-v5`, so a set stored by
an earlier release is never served again.

yams now reports `make` and `ninja` with no other component and no spurious
edge. `tests/e2e/cli_flags.py` pins the shape: the sibling check fails if
`cargo`, `go`, or `rustc` reappears for that project.

## Test Suite

`src/tests/adacovex_sbom_tests.adb` adds `Make_C_Project_Fixture` and five
checks. The fixture is a C project with no `Cargo.toml`, `go.mod`, or
`package.json`, and its build trees record a developer `PATH` that names
`cargo` and `go`, one under a conventional name and one under `out-linux`.
The checks assert that neither tool registers, and that `make` (from the root
Makefile) and `ninja` (from its recipe) still do. The `yams` sibling pin in
`tests/e2e/cli_flags.py` adds the forbidden-tool check, and the e2e run
passes 165 checks.

Native suite: 2180/2180 passing (29 categories).

`just prove-e2e` passes 132 checks. `just run-ada-crdt` is unchanged.

## Proof Results

The change is outside the proof surface: the manifest parser and its scan
predicate are I/O-bound units with no `SPARK_Mode => On` contracts, and no
`SPARK_Mode (Off)` pragma was added. The tree proves at the default budget
(gnatprove 16.1.0: 1057 VCs, 0 unproved, 0 justified), with no
`--steps=20000`.

## Traceability

HLR-SBOM: The system-tool scan reads only authored build files, so a
generated build tree contributes no component.

HLR-SBOM: SBOM dependency resolution is measured against syft, and every
difference is documented with its decision.

HLR-CACHE: The referenced-tool set cache covers exactly the files the scan
reads, and a rule change invalidates the stored set.

HLR-CHECK: Every quality gate records its wall time in the `just check`
summary, so the pipeline budget is measured on every run.
