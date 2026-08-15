# AGENTS.md -- adacovex

## Project

**adacovex** -- zero-dependency Ada/SPARK CLI tool for coverage, proof analysis,
test-result parsing, DO-178C DAL compliance assessment, and interactive dashboards.

- **Repo**: https://github.com/bladeacer/adacovex
- **Language**: Ada 2012 / SPARK 2014 (GNAT, Alire)
- **Zero library dependency**: uses only the GNAT runtime. gnatprove is *not* a
  declared dependency -- the `prove` subcommand resolves it at run time
  (per-project manifest, `$PATH`, `~/.adacovex/toolchain/`, or download) and
  lives only in the dev manifest for local make targets.
- **SPARK target**: Platinum. See [SPARK levels](docs/api-docs/adacovex-spark-levels.md).

## Dogfood target

adacovex audits the Ada_CRDT library at `../Ada_CRDT` (`make run-ada-crdt`) and
its own source (`make run-self`, default target: cwd). `--target=PATH` points at
any Ada/SPARK project.

Self-assessment (`make run-self`) must always show:
- 100% docstring coverage (strict mode on by default, cannot be disabled)
- Platinum SPARK level (343 VCs under gnatprove 16.1.0, 0 unproved; see
  `docs/proof/16.1.0-ledger.md`)
- 372/372 native tests passing
- DAL-C Achieved

## Architecture

<!-- agents-tree:begin -->
```
src/
|-- adacovex.ads                              -- Version constant
|-- adacovex_main.adb                         -- CLI entry point (builds as bin/adacovex; covex alias)
|-- compliance/
|   |-- adacovex-compliance.ads               -- Parent package for DO-178C compliance assessment
|   `-- adacovex-compliance-dal.ads/.adb      -- DAL level assessment logic (DAL-A..E criteria)
|-- core/
|   |-- adacovex-cache.ads/.adb               -- On-disk result cache (content-hashed per-file, oldest-first eviction, size policy)
|   |-- adacovex-config.ads/.adb              -- CLI argument parser (prove mode, --no-sbom, --sbom-format)
|   |-- adacovex-core.ads                     -- Parent package for core data types and configuration
|   |-- adacovex-cpus.ads/.adb                -- Host CPU/CI detection + GNATprove parallelism resolution
|   |-- adacovex-diff.ads/.adb                -- Differential assessment (--compare-base / --coverage-delta)
|   |-- adacovex-prove.ads/.adb               -- GNATprove runner for the `prove` subcommand (alire-first toolchain resolution)
|   `-- adacovex-types.ads/.adb               -- All domain types + conversion functions
|-- ir/
|   |-- adacovex-ir_bounds.ads/.adb           -- Bounds-verification fixture (synthesized lowered types, gnatprove-proved)
|   |-- adacovex-ir_synthesiser.ads/.adb      -- Future-use IR synthesiser (foreign type-name lowering to bounded Ada)
|   `-- adacovex-target_profiles.ads/.adb     -- Bounded IR scalar types (IR_Int8..IR_Int64 / IR_UInt8..IR_UInt64) + host/target config
|-- parsers/
|   |-- adacovex-parsers.ads/.adb             -- Parent package for all input-file parsers
|   |-- adacovex-parsers-do178c.ads/.adb      -- HLR/LLR markdown parser + source tag matcher
|   |-- adacovex-parsers-gnatprove.ads/.adb   -- GNATprove .out parser
|   |-- adacovex-parsers-manifest.ads/.adb    -- Alire manifest / alire.lock / .gpr dep graph
|   |-- adacovex-parsers-source.ads/.adb      -- Ada source scanner (procs/funcs/docstrings/HLR)
|   `-- adacovex-parsers-tests.ads/.adb       -- AUnit test-result parser
|-- renderers/
|   |-- adacovex-renderers.ads                -- Parent package for all output renderers
|   |-- adacovex-renderers-ansi.ads/.adb      -- Terminal ANSI report (NO_COLOR aware)
|   |-- adacovex-renderers-html.ads/.adb      -- Web dashboard + JSON API
|   |-- adacovex-renderers-markdown.ads/.adb  -- VERIFICATION.md + TRACE.md
|   |-- adacovex-renderers-sbom.ads/.adb      -- CycloneDX 1.5 / SPDX 2.3 / Markdown SBOM generator
|   `-- adacovex-renderers-svg.ads/.adb       -- SVG badges (spark/tests/do178c/docs)
|-- server/
|   |-- adacovex-server.ads                   -- Parent package for the HTTP server subsystem
|   |-- adacovex-server-http.ads/.adb         -- HTTP/1.1 server (4-worker task pool)
|   `-- adacovex-server-router.ads            -- Parent package for HTTP request routing (future expansion)
`-- tests/
    |-- adacovex-test_support.ads/.adb        -- Native test Runner type
    |-- adacovex_config_tests.ads/.adb        -- CLI config tests (32)
    |-- adacovex_dal_tests.ads/.adb           -- DAL compliance tests (7)
    |-- adacovex_ir_tests.ads/.adb            -- IR synthesis tests (27)
    |-- adacovex_prove_tests.ads/.adb         -- GNATprove parser tests (64)
    |-- adacovex_renderer_svg_tests.ads/.adb  -- SVG renderer tests (30)
    |-- adacovex_sbom_tests.ads/.adb          -- SBOM / manifest graph tests (60)
    |-- adacovex_scanner_tests.ads/.adb       -- Source scanner tests (83)
    |-- adacovex_testparser_tests.ads/.adb    -- Test-result parser tests (43)
    |-- adacovex_types_tests.ads/.adb         -- Type conversion tests (26)
    `-- test_runner.adb                       -- Test suite entry point (372 tests)
```
<!-- agents-tree:end -->

## .adacovex patch directory

Strict mode (default) scans ALL directories except the always-excluded ones, so
vendored code counts against docstring coverage. A patch file at
`<target>/.adacovex/patches/<relative-path>` (a valid Ada `.ads` with docstrings
for the subprograms to document) overlays docstring info onto the matching
original without modifying it. Only active in strict mode.

Full format, rules, and examples:
[docs/architecture.md](docs/architecture.md#patch-system).

## CLI reference

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
```

Full flag reference, detailed behavior, CI threshold gates (`--require-*`),
exit codes, and the `sbom` subcommand: [docs/cli-reference.md](docs/cli-reference.md).

## Pipeline

Execution order: parse CLI -> scan -> patch -> doc metrics -> proof parse ->
test parse -> DAL assess -> render -> SVG/Markdown/SBOM -> serve -> exit code.
Step details: [docs/architecture.md](docs/architecture.md#pipeline-execution-order).

## Key constraints

- Ada 2012 / SPARK 2014
- **Package/subprogram collections**: `Ada.Containers.Vectors` (heap,
  `Natural'Last` ~ 2.1B). No `Max_Packages` / `Max_Subprogs` limits. HLR tags,
  test metrics, and DAL failures are also unbounded vectors.
- **Fixed-size string buffers** (`Max_Path`, `Max_Line`, etc.) remain bounded.
  Overlong lines and paths fail loudly (never truncated): the file is skipped,
  `Skipped_Ct` increments, and DAL becomes `Unmet`. See the overflow contract
  in [docs/architecture.md](docs/architecture.md).
- No library dependencies beyond the GNAT runtime (`Ada.Containers` is part of
  the standard Ada runtime). gnatprove is resolved at run time by the `prove`
  subcommand.

## Makefile targets

| Target | Description |
|--------|-------------|
| `build` | `alr build` (adacovex + test_runner, covex alias) |
| `test` | Build + run the 372-test native suite |
| `prove` | `./bin/adacovex prove --target=. --no-svg` |
| `doc` / `api-docs` | Generate API docs (gnatdoc + rst2md) |
| `fmt` | Format Ada sources (gnatformat) |
| `run-self` | Run against adacovex itself (default target: cwd) |
| `run-ada-crdt` | Run against `../Ada_CRDT` (strict mode) |
| `coverage-gate` | Docstring-coverage gate between the latest two release tags |
| `bump-version` | Bump version across manifests + changelog (`VERSION=x.y.z`) |
| `agents-tree` | Regenerate the `src/` architecture tree above |
| `release` | Build, prove, validate, run coverage gate vs last release, bundle + tag & push |
| `ascii-check` | Verify all source files are pure ASCII |
| `clean` | Remove bin/ obj/ docs/badges/ |
| `help` | Print available targets |

## Workflows

GitHub Actions (composite `./action.yml` + `ci.yml` / `pr-check.yml` /
`release.yml`), action inputs/outputs, result caching, and release bundling:
[docs/ci-cd.md](docs/ci-cd.md).

Installation methods, target-project requirements, and running against another
project: [README.md](README.md#installing-adacovex).

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 372/372 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | Platinum (343 VCs, 0 unproved under gnatprove 16.1.0) |
| Ada_CRDT regression | `make run-ada-crdt` | Stable against CRDT library (strict mode) |

## Changelog format

Releases get a `docs/changelogs/adacovex-<version>.md` file using `### C#:` /
`### H#:` numbered subsections under `## Changes` / `## Fixes`, plus
`## Test Suite`, `## Proof Results`, and `## Traceability`. Full format and
rules: [docs/contributing.md](docs/contributing.md#changelog-format).

## Unit tests

Native zero-dependency suite (`src/tests/`, 372 tests across 9 categories).
Per-category counts and framework details:
[docs/contributing.md](docs/contributing.md#unit-tests).

## Documentation

- [CLI reference](docs/cli-reference.md)
- [CI/CD](docs/ci-cd.md)
- [Contributing](docs/contributing.md)
- [Docstring spec](docs/api-docs/adacovex-docstring-spec.md)
- [DAL levels](docs/api-docs/adacovex-dal-levels.md)
- [Architecture](docs/architecture.md)
