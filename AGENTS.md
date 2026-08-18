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
- Platinum SPARK level (401 VCs under gnatprove 16.1.0, 0 unproved; see
  `docs/proof/16.1.0-ledger.md`)
- 597/597 native tests passing
- DAL-C Achieved (and, via `--standard=all`, ASIL B + Class A Achieved;
  `run-self` emits `do178c.svg` / `iso26262.svg` / `iec62304.svg` badges)

## Architecture

<!-- agents-tree:begin -->
```
src/
|-- adacovex.ads                              -- Version constant
|-- adacovex_main.adb                         -- CLI entry point (builds as bin/adacovex; covex alias)
|-- adacovex_version_info.ads                 -- Generated version constant (from alire-dev.toml / ADACOVEX_VERSION)
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
|   |-- adacovex-types.ads/.adb               -- All domain types + conversion functions
|   `-- adacovex-vcs.ads/.adb                 -- VCS abstraction (git/hg/svn/fossil/jj detection + base snapshots)
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
|   |-- adacovex-renderers-man.ads/.adb       -- Man-page renderer + installer (local man db, Linux/WSL)
|   |-- adacovex-renderers-markdown.ads/.adb  -- VERIFICATION.md + TRACE.md
|   |-- adacovex-renderers-sbom.ads/.adb      -- CycloneDX 1.5 / SPDX 2.3 / Markdown SBOM generator
|   `-- adacovex-renderers-svg.ads/.adb       -- SVG badges (spark/tests/do178c/docs)
|-- server/
|   |-- adacovex-server.ads                   -- Parent package for the HTTP server subsystem
|   |-- adacovex-server-http.ads/.adb         -- HTTP/1.1 server (4-worker task pool)
|   `-- adacovex-server-router.ads            -- Parent package for HTTP request routing (future expansion)
`-- tests/
    |-- adacovex-test_support.ads/.adb        -- Native test Runner type
    |-- adacovex_config_tests.ads/.adb        -- CLI config tests (86)
    |-- adacovex_dal_tests.ads/.adb           -- DAL compliance tests (16)
    |-- adacovex_ir_tests.ads/.adb            -- IR synthesis tests (27)
    |-- adacovex_man_tests.ads/.adb           -- Man page renderer tests (15)
    |-- adacovex_prove_tests.ads/.adb         -- GNATprove parser tests (64)
    |-- adacovex_renderer_svg_tests.ads/.adb  -- SVG renderer tests (36)
    |-- adacovex_renderer_tests.ads/.adb      -- HTML/Markdown renderer tests (17)
    |-- adacovex_sbom_tests.ads/.adb          -- SBOM / manifest graph tests (114)
    |-- adacovex_scanner_tests.ads/.adb       -- Source scanner tests (83)
    |-- adacovex_testparser_tests.ads/.adb    -- Test-result parser tests (43)
    |-- adacovex_types_tests.ads/.adb         -- Type conversion tests (67)
    |-- adacovex_vcs_tests.ads/.adb           -- VCS support tests (29)
    `-- test_runner.adb                       -- Test suite entry point (597 tests)
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
           [--standard=NAME|--dal=LEVEL|--asil=LEVEL|--class=LEVEL]
adacovex prove [--target=PATH] [prove options]
adacovex status [--target=PATH]
adacovex man [--check] [--dir=PATH]
```

Full flag reference, detailed behavior, CI threshold gates (`--require-*`),
exit codes, the `sbom` subcommand, the per-standard level flags
(`--dal`, `--asil`, `--class`), and the `--standard` flag (including
`--standard=all`): [docs/cli-reference.md](docs/cli-reference.md).

`adacovex status` reports toolchain + platform state (Alire installed,
gnatprove dependency-managed/detectable, CPU count, CI status, and which VCS
tools -- git/hg/svn/fossil/jj/mandb -- are available for the differential
modes plus the target's detected VCS) without running an assessment or
downloading anything: [docs/platforms.md](docs/platforms.md#status-subcommand).

`adacovex --version` prints the bundled version and exits. The version source
depends on the **installation method** (tools/gen-version.py resolves it and
regenerates `src/adacovex_version_info.ads`): `ADACOVEX_VERSION` (release
builds -- the shipped binary always reports the tag it was built from),
then `alire/alire-dev.toml` (source checkouts), then `alire.toml`
(dependency-managed installs: the toml associated with the covex binary for
dependency management carries the release version).

`adacovex man` installs the man page into the local man database
(`~/.local/share/man`, Linux/WSL; `--dir=PATH` overrides) and refreshes it with
`mandb` when man-db is installed. When `mandb` is missing (or fails) adacovex
prints a warning -- the page is still installed and readable via `man -l` --
and `adacovex status` reports mandb availability up front. The page embeds
the version, and `adacovex man --check` exits 0 when the installed page
matches the binary (1 when a newer version is available or none is installed)
-- so a shell prompt hook can auto-update the man page when the machine
detects a newer version.

## VCS support (Linux/WSL)

A **VCS is not required for base adacovex functionality**: scanning, proof
analysis, test parsing, compliance assessment, SBOM generation, dashboards,
and caching all work on a plain directory. A VCS is only needed for the
differential modes (`--compare-base` / `--coverage-delta`), which snapshot a
base revision -- and since adacovex audits *source code*, assuming the target
lives in a VCS is sensible.

adacovex runs on **Linux and WSL**. The differential modes (`--compare-base` /
`--coverage-delta`) snapshot a base revision without touching the working tree
across **git, Mercurial, Subversion, Fossil, and jj** (legacy codebases often
live in legacy VCS): git `worktree add`, hg `archive`, svn `export`, fossil
`open` on a copied DB, and jj via its internal git store. Detection is
marker-file based (`.git` / `.jj` / `.hg` / `.svn` / `.fslckout` / `_FOSSIL_`)
with a command-probe fallback. For VCS whose snapshot UX is poor (Subversion:
no local history, network-dependent; Fossil: niche tooling) adacovex prints a
note recommending the developers **convert the repo to git** (or a
git-compatible VCS) for the best experience. See
[docs/cli-reference.md](docs/cli-reference.md#vcs-support).

## Pipeline

Execution order: parse CLI -> scan -> patch -> doc metrics -> proof parse ->
test parse -> DAL assess -> render -> SVG/Markdown/SBOM -> serve -> exit code.
Step details: [docs/architecture.md](docs/architecture.md#pipeline-execution-order).
Early-exit modes run before the pipeline: `--help`, `--version`, `man`
(install/check the man page), `status`, differential modes, and `sbom`.

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
- **Build/dev tooling requires Python 3** (pure-stdlib `tools/*.py`: version
  generation, description sync, test/proof doc sync, changelog checks,
  doc-links, agents-tree). The adacovex binary itself has no Python
  dependency.

## Tool scripts

`tools/*.py` are pure-stdlib Python 3 (no third-party packages) and annotate
all functions/variables with `typing` (`from typing import ...`). Keep new
scripts consistent: `typing` for annotations, `argparse` for CLI, `pathlib`
for paths, and no `pip install` / external imports. Run them with
`python3 tools/<name>.py`; the sync ones are wired as `make test-count`, `make
proof-status`, and `make doc-links`.

## Makefile targets

| Target | Description |
|--------|-------------|
| `check` | Full quality gate: build + tests + SPARK proof + badges + docs + SBOM + ascii + changelog + description sync |
| `build` | Regenerate `src/adacovex_version_info.ads` from alire-dev.toml (or `ADACOVEX_VERSION`), then `alr build` (adacovex + test_runner, covex alias) |
| `man` | Install the man page into the local man database + refresh mandb (warns when mandb is missing) |
| `test` | Build + run the 597-test native suite |
| `prove` | SPARK proof (Platinum gate) + regenerates SVG badges in `docs/badges/` |
| `doc` / `api-docs` | Generate API docs (gnatdoc + rst2md) |
| `fmt` | Format Ada sources (gnatformat) |
| `sbom` | Generate the proof-aware SBOM (`sbom.json`) |
| `description` | Sync the crate description from alire/description.txt + alire/long-description.txt (`CHECK=1` verifies only) |
| `run-self` | Run against adacovex itself (default target: cwd) |
| `run-ada-crdt` | Run against `../Ada_CRDT` (strict mode) |
| `coverage-gate` | Docstring-coverage gate between the latest two release tags |
| `bump-version` | Bump version across manifests + changelog (`VERSION=x.y.z`) |
| `agents-tree` | Regenerate the `src/` architecture tree above |
| `proof-status` | Sync VC count + SPARK level from gnatprove.out |
| `test-count` | Sync test counts from docs/test_result.md |
| `doc-links` | Regenerate the AGENTS.md Documentation block from tools/doc-links.map |
| `changelog-check` | Validate all `docs/changelogs/` against the canonical format (tools/check-changelogs.py) |
| `release` | Build, prove, validate, run coverage gate vs last release, bundle + tag & push |
| `ascii-check` | Verify all source files are pure ASCII |
| `clean` | Remove bin/ obj/ docs/badges/ |
| `help` | Print available targets |

Running `alr build` / `make build` / `make test` / `make run-self` rewrites a
few generated files as a normal side effect: `alire/settings.toml` and
`alire/build_hash_inputs` (Alire build-profile state), `sbom.json` (SBOM
output), and `src/adacovex_version_info.ads` (regenerated from
`alire-dev.toml`; byte-identical when the version did not change). These are
expected and should be left as-is -- do not revert them.

## Workflows

GitHub Actions (composite `./action.yml` + `ci.yml` / `pr-check.yml` /
`release.yml`), action inputs/outputs, result caching, and release bundling:
[docs/ci-cd.md](docs/ci-cd.md).

Installation methods, target-project requirements, and running against another
project: [README.md](README.md#installing-adacovex).

### GitHub Action = base-CLI feature parity

Every CI run (the composite action and the `ci.yml` / `pr-check.yml` /
`release.yml` workflows) publishes a **Markdown summary** at the bottom of the
job page via `$GITHUB_STEP_SUMMARY`: the action appends an assessment table
(version, target, compliance, SPARK level, tests, coverage) plus an
`always()` run-summary step, and each workflow adds a `summary` job that
aggregates every job result. **Threshold failures fail loudly**: unmet
`--require-*` gates surface as `::error::` annotations, the assessment step
exits non-zero, the summary shows the unmet gates, and the workflow summary
job exits 1 when any job failed.

The composite action (`./action.yml`) mirrors the base CLI option set so CI
can drive every assessment feature the same way the binary does. The action
inputs map 1:1 onto the CLI flags (e.g. `target`/`--target`, `dal`/`--dal`,
`standard`/`--standard`, `asil`/`--asil`, `class`/`--class`, `manifest`/
`--manifest`, `relaxed`/`--relaxed`, `skip-dir`/`--skip-dir`, `no-svg`/
`--no-svg`, `no-cache`/`--no-cache`, `cache-dir`/`--cache-dir`, `cache-max`/
`--cache-max`, `verbose`/`--verbose`, `emit-markdown`/`--emit-markdown`,
`compare-base`/`--compare-base`, `coverage-delta`/`--coverage-delta`, the
`--require-*` gates, and the `prove-*` inputs onto the `prove` subcommand's
`--jobs` / `--level` / `--timeout` / `--steps` / `--memlimit` / `--force` /
`--no-loop-unrolling` / `--no-inlining` flags).

Keep them in sync: when a CLI flag is added, a matching action input (and the
docs/ci-cd.md input table) goes with it. The only assessment that is *not*
reproduced in CI is `make run-ada-crdt` (a local dogfood regression against
`../Ada_CRDT`); `ci.yml` runs `--standard=all` self-assessment, the native
tests, and the release-tag coverage gate instead.

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 597/597 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | Platinum (401 VCs, 0 unproved under gnatprove 16.1.0) |
| Ada_CRDT regression | `make run-ada-crdt` | Stable against CRDT library (strict mode) |

## Changelog format

Releases get a `docs/changelogs/adacovex-<version>.md` file using `### C#:` /
`### H#:` numbered subsections under `## Changes` / `## Fixes`, plus
`## Test Suite`, `## Proof Results`, and `## Traceability`. Full format and
rules: [CONTRIBUTING.md](CONTRIBUTING.md#changelog-format).

## Unit tests

Native zero-dependency suite (`src/tests/`, 597 tests across 12 categories).
Per-category counts and framework details:
[CONTRIBUTING.md](CONTRIBUTING.md#unit-tests).

## Documentation

<!-- doc-links:begin -->
- [CLI reference](docs/cli-reference.md)
- [CI/CD](docs/ci-cd.md)
- [Contributing](CONTRIBUTING.md)
- [Docstring spec](docs/api-docs/adacovex-docstring-spec.md)
- [DAL levels](docs/api-docs/adacovex-dal-levels.md)
- [Standards](docs/standards.md)
- [Platforms](docs/platforms.md)
- [Architecture](docs/architecture.md)
<!-- doc-links:end -->
