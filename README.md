[![covex Alire crate badge](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/covex.json)](https://alire.ada.dev/crates/covex) ![SPARK](docs/badges/spark.svg) ![DO-178C](docs/badges/do178c.svg) ![ISO 26262](docs/badges/iso26262.svg) ![IEC 62304](docs/badges/iec62304.svg) ![Tests](docs/badges/tests.svg) ![docs](docs/badges/docs.svg)

# adacovex

A zero-dependency Ada/SPARK command line tool for coverage analysis, proof
verification, test-result parsing, multi-standard safety-compliance assessment
(DO-178C / ISO 26262 / IEC 62304), and interactive dashboards. It uses only the
GNAT runtime. The `prove` subcommand resolves gnatprove at run time, so
installing adacovex installs only the binary.

## Features

- **Source scanning** -- walks `.ads` files; extracts subprogram declarations,
  [docstring annotations](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-docstring-spec.html) (Ada
  `@param`/`@return`/`@field`/`@formal`/`@brief`/`@summary`, Google
  `Args:`/`Returns:`, Sphinx `:param:`/`:returns:`), and HLR traceability tags.
- **Proof analysis** -- parses GNATprove `gnatprove.out` summaries; assesses
  [SPARK assurance levels](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-spark-levels.html) (Stone to
  Platinum).
- **Test parsing** -- reads [test-result summaries](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-test-format.html)
  from CI or runner logs: Markdown tables (the native `test_runner` format, with
  or without an index column), TAP (`ok`/`not ok`), GNU Automake
  (`PASS:`/`FAIL:`), Maven Surefire (`Tests run: N`), Unity (`N Tests`), and
  AUnit reports.
- **[Compliance](https://adacovex.readthedocs.io/en/latest/usage/standards.html)** -- assesses DO-178C DAL A-E criteria (HLR
  coverage, orphan tags, test status, minimum SPARK proof level), re-labelled
  for [ISO 26262](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-asil-levels.html) (ASIL A to D / QM) and
  [IEC 62304](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-class-levels.html) (Class A to C) with
  dedicated `--dal` / `--asil` / `--class` flags.
- **Multiple outputs** -- ANSI report, SVG badges, Markdown reports, web
  dashboard + JSON API, and proof-aware SBOM (CycloneDX / SPDX).
- **[Differential assessment](https://adacovex.readthedocs.io/en/latest/usage/vcs.html)** -- `--compare-base` /
  `--coverage-delta` snapshot a base revision on **git, Mercurial,
  Subversion, Fossil, or jj** without touching the working tree.
- **Result caching** -- a content-addressed on-disk cache (`~/.adacovex/cache`)
  serves unchanged scan, proof, test, HLR/LLR, and dependency-graph results.
- **Tooling** -- `status` reports toolchain and VCS state, `man` installs a
  local man page, and `make check` runs the full quality gate in one command.
- **Scalable** -- package and subprogram collections use
  `Ada.Containers.Vectors` (no compile-time count limits); fixed-size buffers
  scale with host word size.

## Quick start

```bash
# Install (pick one)
alr install covex gnatprove       # Alire: binary on ~/.local/bin
# or the release bundle:
# curl -fsSL https://raw.githubusercontent.com/bladeacer/adacovex/main/install.sh | bash

# Assess a project (strict mode; DAL-C by default)
adacovex --target=.

# Toolchain + platform report
adacovex status --target=.

# Web dashboard at http://localhost:8080
adacovex --target=. --serve
```

Contributors build from source with `make build` (see
[Installation](https://adacovex.readthedocs.io/en/latest/usage/installation.html)). `make run-self` assesses adacovex itself.
`make run-ada-crdt` runs the Ada_CRDT regression.

## Documentation

### Getting started

| Reference | Description |
|-----------|-------------|
| [Installation](https://adacovex.readthedocs.io/en/latest/usage/installation.html) | Alire / release bundle / source build |
| [CLI Reference](https://adacovex.readthedocs.io/en/latest/usage/cli-reference.html) | Full flag table, `--require-*` gates, exit codes |
| [Target Projects](https://adacovex.readthedocs.io/en/latest/usage/target-projects.html) | What a project must provide for assessment |
| [Platforms](https://adacovex.readthedocs.io/en/latest/usage/platforms.html) | Platform support, CPU core detection, `status` subcommand |

### Usage and configuration

| Reference | Description |
|-----------|-------------|
| [Web Dashboard + JSON API](https://adacovex.readthedocs.io/en/latest/usage/dashboard.html) | `--serve` HTML dashboard, `/api/metrics`, themes |
| [SBOM](https://adacovex.readthedocs.io/en/latest/usage/sbom.html) | Proof-aware CycloneDX / SPDX bill of materials |
| [VCS Support](https://adacovex.readthedocs.io/en/latest/usage/vcs.html) | Differential modes across git/hg/svn/fossil/jj |
| [Proving and Writing Proofs](https://adacovex.readthedocs.io/en/latest/contributing/proving.html) | How proving works, SPARK contracts, proof patches for vendored deps |
| [Architecture](https://adacovex.readthedocs.io/en/latest/contributing/architecture.html) | Design decisions, patches, toolchain resolution, overflow contract |

### Compliance

| Reference | Description |
|-----------|-------------|
| [Standards](https://adacovex.readthedocs.io/en/latest/usage/standards.html) | DO-178C / ISO 26262 / IEC 62304 abstraction |
| [DAL Levels](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-dal-levels.html) | DO-178C DAL A to E criteria |
| [ASIL Levels](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-asil-levels.html) | ISO 26262 ASIL A to D / QM criteria |
| [Safety Classes](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-class-levels.html) | IEC 62304 Class A to C criteria |
| [HLR Index](https://adacovex.readthedocs.io/en/latest/HLR.html) | High-level requirements traceability index |
| [LLR Mapping](https://adacovex.readthedocs.io/en/latest/LLR.html) | Low-level requirement-to-HLR mapping |

### Development and auditing

| Reference | Description |
|-----------|-------------|
| [Contributing](CONTRIBUTING.md) | Changelog format, test suite |
| [Developer Guide](https://adacovex.readthedocs.io/en/latest/contributing/developer-guide.html) | Codebase structure and repo setup for contributors |
| [API Reference](https://adacovex.readthedocs.io/en/latest/api-docs/index.html) | Auto-generated package API docs (developers / auditors) |
| [Docstring Spec](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-docstring-spec.html) | Annotation format, placement, conventions |
| [Test Format](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-test-format.html) | Supported test-result output format |
| [SPARK Levels](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-spark-levels.html) | Assurance level objectives (Stone to Platinum) |
| [Changelog](https://adacovex.readthedocs.io/en/latest/changelogs/index.html) | Release history |
| [CI/CD](https://adacovex.readthedocs.io/en/latest/usage/ci-cd.html) | GitHub Action, workflows, release bundling |
| [LLM usage](https://adacovex.readthedocs.io/en/latest/contributing/llm-usage.html) | AI disclosure, trust, how LLM agents work under AGENTS.md |

## Installing adacovex

Declare `covex` in your project's `alire-dev.toml`, run `alr install covex`, or
download a release bundle and build from source.
[Installation](https://adacovex.readthedocs.io/en/latest/usage/installation.html) covers each route, including the version
source per method and the man-page sync.

## Platforms, toolchain, and VCS

- **Platforms** -- runs wherever a GNAT/Alire toolchain exists; the release
  binary is Linux x86-64 only for now (build from source for other platforms).
  See [https://adacovex.readthedocs.io/en/latest/usage/platforms.html](https://adacovex.readthedocs.io/en/latest/usage/platforms.html).
- **GNATprove resolution** -- manifest pin over global pin over `$PATH` over
  cached toolchain over download (a manifest pin is authoritative). See
  [https://adacovex.readthedocs.io/en/latest/contributing/architecture.html](https://adacovex.readthedocs.io/en/latest/contributing/architecture.html#gnatprove-toolchain-resolution-prove-subcommand).
- **VCS** -- not required for base functionality; only the differential modes
  need one, and they work across git, hg, svn, fossil, and jj. See
  [https://adacovex.readthedocs.io/en/latest/usage/vcs.html](https://adacovex.readthedocs.io/en/latest/usage/vcs.html).

## CLI reference

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
           [--standard=NAME|--dal=LEVEL|--asil=LEVEL|--class=LEVEL]
adacovex prove [--target=PATH] [prove options]
adacovex status [--target=PATH]
adacovex man [--check|--force] [--dir=PATH]
adacovex complexity [--target=PATH]
```

The full flag table (defaults, modes, `--require-*` CI gates, strict vs relaxed
mode, exit codes, contextual `help [TOPIC]`, and the `man` subcommand) lives in
[https://adacovex.readthedocs.io/en/latest/usage/cli-reference.html](https://adacovex.readthedocs.io/en/latest/usage/cli-reference.html). The web dashboard and JSON API
are in [https://adacovex.readthedocs.io/en/latest/usage/dashboard.html](https://adacovex.readthedocs.io/en/latest/usage/dashboard.html).

## Examples

```bash
adacovex --target=.                                 # self-assessment
adacovex --target=. --standard=all                  # badges for every standard
adacovex --target=. --serve                         # web dashboard at :8080
adacovex --target=. --compare-base=HEAD             # differential assessment
adacovex prove --target=.                           # run gnatprove, then assess
adacovex sbom --format=cyclonedx-json --target=.    # proof-aware SBOM
adacovex status --target=.                          # toolchain + platform report
adacovex complexity --target=.                      # cyclomatic complexity check
```

More examples: [https://adacovex.readthedocs.io/en/latest/usage/cli-reference.html](https://adacovex.readthedocs.io/en/latest/usage/cli-reference.html#examples).

## Target project requirements

To run adacovex against a project it needs Ada sources, GNATprove output
(`gnatprove.out`), a test-summary file, and (for DAL assessment) an `HLR.md`
document. Missing data shows `N/A`; DAL checks that depend on it report
`Unmet`. Full requirements, file-discovery rules, and the non-Ada-project note:
[https://adacovex.readthedocs.io/en/latest/usage/target-projects.html](https://adacovex.readthedocs.io/en/latest/usage/target-projects.html).

## Docstrings and patches

Subprograms are documented with `--  @param` / `--  @return` annotations
([full spec](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-docstring-spec.html)); strict mode requires
100% coverage. For vendored code you cannot modify, overlay docstrings with
patch files at `<target>/.adacovex/patches/` (see
[Architecture -- Patch System](https://adacovex.readthedocs.io/en/latest/contributing/architecture.html#patch-system)).

The same patch files can carry **SPARK proof aspects** (`SPARK_Mode`, `Pre`,
`Post`, `Global`): the `prove` subcommand merges them into a patched tree copy
and proves vendored dependencies against their contracts without touching the
originals. A `.ads` patch re-declares the spec with contracts. A `.adb` patch
opts a SPARK-clean vendored body into the proof. See
[Architecture -- Proof patches](https://adacovex.readthedocs.io/en/latest/contributing/architecture.html#proof-patches-spark-contracts-over-vendored-dependencies).

## Compliance levels

The same evidence (proof level, passing tests, HLR traceability) is re-labelled
for three functionally-equivalent safety standards. Pick a level with a
standard's own naming, or pass `--standard=all` to run one assessment at the
shared tier and emit badges for all three:

| Standard | Level flag | Levels | Example |
|----------|-----------|--------|---------|
| DO-178C (avionics) | `--dal=` | A, B, C, D, E | `--dal=C` = DAL-C |
| ISO 26262 (automotive) | `--asil=` | A, B, C, D, QM | `--asil=B` = ASIL B |
| IEC 62304 (medical) | `--class=` | A, B, C | `--class=A` = Class A |

The evidence is identical across standards; only the integrity-level label
changes (`DAL-C` vs `ASIL B` vs `Class A`).

Full tier mapping:
[Standards](https://adacovex.readthedocs.io/en/latest/usage/standards.html).

Per-level criteria:
[DAL Levels](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-dal-levels.html),
[ASIL Levels](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-asil-levels.html), and
[Safety Classes](https://adacovex.readthedocs.io/en/latest/api-docs/adacovex-class-levels.html).

## Development

`make check` runs the full quality gate (cheap static gates first, then build,
test, prove, doc, sbom, then tree-wide count-sync checks). Other targets
include `build`, `test`, `prove`, `doc`, `sbom`, `fmt`, `run-self`,
`run-ada-crdt`, `bump-version`, `release`, and `clean`.

Run `make help` or see
[AGENTS.md](AGENTS.md) for the full table. AI tools were used during
development; why the code is still trustworthy:
[https://adacovex.readthedocs.io/en/latest/contributing/llm-usage.html](https://adacovex.readthedocs.io/en/latest/contributing/llm-usage.html).

## CI/CD

A composite GitHub Action (`./action.yml`) plus `ci.yml`, `pr-check.yml`, and
`release.yml` workflows cover the `--standard=all` self-assessment, the native
test suite, the PR docstring-coverage gate, and releases.

Action inputs/outputs, result caching, and release bundling:
[https://adacovex.readthedocs.io/en/latest/usage/ci-cd.html](https://adacovex.readthedocs.io/en/latest/usage/ci-cd.html).

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 1186/1186 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | Platinum (725 VCs, 0 unproved under gnatprove 16.1.0) |
| Ada_CRDT regression | `make run-ada-crdt` | 100% docs, DAL-C (strict mode) |

See [changelogs](https://adacovex.readthedocs.io/en/latest/changelogs/index.html) for full release notes.

## Requirements

- **Alire** >= 2.0
- **GNAT** Ada compiler (managed by Alire)
- **Python 3** (required at **build time** to bundle the dashboard and the offline
  manual into the binary via `tools/gen-dashboard.py` and `tools/gen-docs.py`, the
  latter needing `sphinx` + `myst-parser` + `furo` from `requirements.txt`; the
  released binary itself has no Python or runtime dependency)
- **GNATprove** (optional; resolved at run time by `prove` -- no declared dependency)
- **gnatdoc_bin** and **gnatformat_bin** (dev dependencies managed by Alire,
  declared in `alire-dev.toml` and run via `alr exec` for the `make doc` and
  `make fmt` targets -- so the published crate still installs and builds with
  no toolchain beyond the GNAT compiler)

## Swapping the GNAT compiler (LLVM backend)

See
[https://adacovex.readthedocs.io/en/latest/contributing/architecture.html](https://adacovex.readthedocs.io/en/latest/contributing/architecture.html#swapping-the-gnat-compiler-llvm-backend)
for Alire-managed and system-installed GNAT LLVM options and caveats.

## Credits

Third-party attributions, licences, and bundled-asset notices: see
[https://adacovex.readthedocs.io/en/latest/CREDITS.html](https://adacovex.readthedocs.io/en/latest/CREDITS.html) and
[https://adacovex.readthedocs.io/en/latest/THIRD_PARTY_NOTICES.html](https://adacovex.readthedocs.io/en/latest/THIRD_PARTY_NOTICES.html).

## License

Apache-2.0 -- see [LICENSE](LICENSE) for details.
