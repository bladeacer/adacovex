# adacovex 1.24.0

Date: _2026-08-24_

Version bumped 1.23.0 -> 1.24.0.

## Changes

### C1: Complexity module docstrings and SPARK mode alignment

The `Adacovex.Complexity` package now carries a package-level docstring and
`@brief` tags on every public subprogram, and all body subprograms have
docstrings.  The package-level `pragma SPARK_Mode (Off)` remains necessary
because it instantiates the non-formal `Ada.Containers.Vectors`; the exception
is now documented consistently across AGENTS.md, the Makefile, and the
proof-status ledger.

### C2: Complexity gate CI provisions Alire before build

The `complexity-gate` jobs in `ci.yml` and `pr-check.yml` now run
`alire-project/setup-alire` before `make complexity-check`, so the gate no
longer fails with `/bin/sh: alr: not found` on a fresh runner.

### C3: Temp directory and shell abstraction for non-Linux platforms

Hardcoded `/tmp/` paths in `adacovex-cpus`, `adacovex-vcs`, `adacovex-prove`,
`adacovex-renderers-man`, and `adacovex-parsers-manifest` are replaced by
`Adacovex.CPUs.Get_Temp_Directory`, which honours `TMPDIR` / `TEMP` / `TMP`
environment variables and falls back to `/tmp`.  The shell executable is
similarly abstracted through `Adacovex.CPUs.Get_Shell_Command`.

### C4: GNAT v16.1.0 toolchain rollout

The composite action default, CI workflow pins, and documentation now all
target `gnat_native=16.1.0` (previous default was `15.2.1`).  The action
input default, `ci.yml`, `pr-check.yml`, `release.yml`, `docs/ci-cd.md`, and
`docs/architecture.md` are updated so consumers do not inherit a stale
toolchain pin.

### C5: Documentation tier separation clarified

`AGENTS.md` now explicitly defines the two documentation tiers: `docs/` (user
documentation: install, CLI, dashboard, SBOM, VCS, standards, CI/CD, proving,
architecture, changelogs, HLR/LLR, performance) for end users and safety
engineers; and `docs/api-docs/` (generated gnatdoc reference, docstring spec,
test format, SPARK/DAL/ASIL/class levels) for contributors and auditors.

### C6: HLR index completeness

`HLR-COMPLEXITY` is added to both `docs/HLR.md` and `docs/compliance/HLR.md`,
closing the gap between the tag used in source docstrings and the published
HLR index.

## Fixes

### H1: Complexity-check target no longer drifts from native implementation

The Makefile target description and help text now correctly state that
`make complexity-check` invokes the native Ada checker (`./bin/adacovex
complexity`), removing the stale `tools/check-complexity.py` reference.

### H2: Stale Python-checker references purged from docs

`docs/ci-cd.md`, `AGENTS.md`, `.github/workflows/ci.yml`, and
`docs/changelogs/adacovex-1.24.0.md` no longer mention the removed
`tools/check-complexity.py`; the complexity gate is now uniformly described
as the native Ada implementation.

## Test Suite

900 tests passing across 14 categories.

## Proof Results

Platinum, 720/720 VCs proved under gnatprove 16.1.0.  0 unproved, 0 justified.

## Traceability

No new HLRs.  Coverage:

   - `HLR-COMPLEXITY` -- C1 docstrings and SPARK exception documentation for
     the complexity checker; C6 added to HLR indexes;
   - `HLR-DOC` -- C1 package-level and body docstrings for the complexity
     module; C5 documentation tier separation;
   - `HLR-CI` -- C2 Alire provisioning in the complexity-gate workflow; C4
     GNAT v16.1.0 rollout in CI and action;
   - `HLR-CPU` -- C3 portable temp-directory and shell abstractions.

See `docs/cli-reference.md`, `docs/ci-cd.md`, `docs/architecture.md`.
