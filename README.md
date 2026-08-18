[![covex Alire crate badge](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/covex.json)](https://alire.ada.dev/crates/covex)
![SPARK](docs/badges/spark.svg)
![Tests](docs/badges/tests.svg)
![DO-178C](docs/badges/do178c.svg)
![ISO 26262](docs/badges/iso26262.svg)
![IEC 62304](docs/badges/iec62304.svg)
![docs](docs/badges/docs.svg)

# adacovex

**Zero-dependency Ada/SPARK CLI tool** for coverage analysis, proof
verification, test-result parsing, multi-standard safety-compliance assessment
(DO-178C / ISO 26262 / IEC 62304), and interactive dashboards. No library
dependencies beyond the GNAT runtime; gnatprove is resolved at run time by the
`prove` subcommand, so installing adacovex pulls nothing but the binary.

## Features

- **Source scanning** -- walks `.ads` files, extracts subprogram declarations,
  [docstring annotations](docs/api-docs/adacovex-docstring-spec.md) (Ada
  `@param`/`@return`/`@field`/`@formal`/`@brief`/`@summary`, Google
  `Args:`/`Returns:`, Sphinx `:param:`/`:returns:`), and HLR traceability tags
- **Proof analysis** -- parses GNATprove `gnatprove.out` summaries; assesses
  [SPARK assurance levels](docs/api-docs/adacovex-spark-levels.md) (Stone--Platinum)
- **Test parsing** -- reads [test-result summaries](docs/api-docs/adacovex-test-format.md)
  (Markdown tables, TAP, Automake, Maven Surefire, Unity, AUnit-compatible)
- **[Compliance](docs/api-docs/adacovex-dal-levels.md)** -- assesses DO-178C
  DAL A-E criteria (HLR coverage, orphan tags, test status, minimum SPARK
  proof level), re-labelled for [ISO 26262](docs/standards.md)
  (ASIL A--D/QM) and [IEC 62304](docs/standards.md) (classes A--C) with
  dedicated `--dal` / `--asil` / `--class` flags
- **Multiple outputs** -- ANSI report, SVG badges, Markdown reports, web
  dashboard + JSON API, proof-aware SBOM (CycloneDX / SPDX)
- **[Differential assessment](docs/vcs.md)** -- `--compare-base` /
  `--coverage-delta` snapshot a base revision on **git, Mercurial,
  Subversion, Fossil, or jj** without touching your working tree
- **Result caching** -- a content-addressed on-disk cache (`~/.adacovex/cache`)
  serves unchanged scan, proof, test, HLR/LLR, and dependency-graph results
  without re-running the work
- **Tooling** -- `status` reports toolchain + VCS state, `man` installs a
  local man page, and `make check` runs the full quality gate in one command
- **Scalable** -- package/subprogram collections use `Ada.Containers.Vectors`
  (no compile-time limits on count); fixed-size buffers scale with host word size

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
[Installation](docs/installation.md)); `make run-self` assesses adacovex
itself and `make run-ada-crdt` runs the Ada_CRDT regression.

## Documentation

| Reference | Description |
|-----------|-------------|
| [CLI Reference](docs/cli-reference.md) | Full flag table, `--require-*` gates, exit codes |
| [Web Dashboard + JSON API](docs/dashboard.md) | `--serve` HTML dashboard, `/api/metrics`, themes |
| [SBOM](docs/sbom.md) | Proof-aware CycloneDX / SPDX bill of materials |
| [VCS Support](docs/vcs.md) | Differential modes across git/hg/svn/fossil/jj |
| [Target Projects](docs/target-projects.md) | What a project must provide for assessment |
| [CI/CD](docs/ci-cd.md) | GitHub Action, workflows, release bundling |
| [Standards](docs/standards.md) | DO-178C / ISO 26262 / IEC 62304 abstraction |
| [Platforms](docs/platforms.md) | Platform support, CPU core detection, `status` subcommand |
| [Architecture](docs/architecture.md) | Design decisions, patches, toolchain resolution, overflow contract |
| [Installation](docs/installation.md) | Alire manifest / `alr install` / release bundle / source build |
| [LLM usage](docs/llm-usage.md) | AI disclosure, trust, how LLM agents work under AGENTS.md |
| [Contributing](CONTRIBUTING.md) | Changelog format, test suite |
| [Changelog](docs/changelogs/index.md) | Release history |
| [API Reference](docs/api-docs/index.md) | Auto-generated package API docs |
| [Docstring Spec](docs/api-docs/adacovex-docstring-spec.md) | Annotation format, placement, conventions |
| [Test Format](docs/api-docs/adacovex-test-format.md) | Supported test-result output format |
| [SPARK Levels](docs/api-docs/adacovex-spark-levels.md) | Assurance level objectives (Stone--Platinum) |
| [DAL Levels](docs/api-docs/adacovex-dal-levels.md) | DO-178C DAL A - E criteria |
| [ASIL Levels](docs/api-docs/adacovex-asil-levels.md) | ISO 26262 ASIL A - D / QM criteria |
| [Safety Classes](docs/api-docs/adacovex-class-levels.md) | IEC 62304 Class A - C criteria |

## Installing adacovex

Three routes: declare `covex` in your project's `alire-dev.toml`, `alr install
covex`, or download a release bundle / build from source.
[Installation](docs/installation.md) covers each in detail, including the
version source per method and keeping the man page in sync.

## Platform support

adacovex runs anywhere a GNAT/Alire toolchain exists; the official **release
binary is Linux x86-64 only for now** (macOS, FreeBSD, Windows, and Linux
aarch64 build from source via Alire). Full platform table, CPU core-count
detection, CI detection, and prove-parallelism resolution:
[docs/platforms.md](docs/platforms.md). Use `adacovex status` to report your
own toolchain + platform state.

## GNATprove toolchain resolution

The `prove` subcommand resolves the `gnatprove` executable in this order:
**manifest pin > global pin (config/env) > `$PATH` > cached toolchain >
download**. A manifest pin is authoritative (fails rather than falls back).
Full resolution order and the doc/fmt manifest-swap:
[docs/architecture.md](docs/architecture.md#gnatprove-toolchain-resolution-prove-subcommand).

## Version control support

**A VCS is not required for base adacovex functionality** -- only the
differential modes (`--compare-base` / `--coverage-delta`) need one, and they
work across git, Mercurial, Subversion, Fossil, and jj without touching the
working tree. `adacovex status` reports which VCS tools are available and what
manages the target. Full details: [docs/vcs.md](docs/vcs.md).

## CLI reference

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
           [--standard=NAME|--dal=LEVEL|--asil=LEVEL|--class=LEVEL]
adacovex prove [--target=PATH] [prove options]
adacovex status [--target=PATH]
adacovex man [--check|--force] [--dir=PATH]
```

The full flag table (defaults, modes, `--require-*` CI gates, strict vs
relaxed mode, exit codes, contextual `help [TOPIC]`, and the `man`
subcommand) lives in [docs/cli-reference.md](docs/cli-reference.md). The web
dashboard + JSON API: [docs/dashboard.md](docs/dashboard.md).

## Examples

```bash
adacovex --target=.                                 # self-assessment
adacovex --target=. --dal=A                         # DAL-A (requires Gold SPARK)
adacovex --target=. --asil=B                        # ISO 26262 at ASIL B
adacovex --target=. --standard=all                  # badges for every standard
adacovex --target=. --emit-markdown=docs/compliance # Markdown reports
adacovex --target=. --serve --port=9090             # web dashboard
adacovex --target=. --compare-base=HEAD             # differential assessment
adacovex sbom --format=cyclonedx-json --target=.    # proof-aware SBOM
adacovex status --target=.                          # toolchain + platform report
adacovex man                                        # install the man page + mandb
```

More examples: [docs/cli-reference.md](docs/cli-reference.md#examples).

## Target project requirements

To run adacovex against a project it needs Ada sources, GNATprove output
(`gnatprove.out`), a test-summary file, and (for DAL assessment) an
`HLR.md` document. Missing data shows `N/A`; DAL checks that depend on it
report `Unmet`. Full requirements, file-discovery rules, and the
non-Ada-project note: [docs/target-projects.md](docs/target-projects.md).

## Docstring format

```ada
--  Summary sentence describing what the subprogram does.
--  @param Name  Description of the parameter.
--  @return Description of the return value.
procedure Do_Something (Name : in Some_Type);

--  A plain summary line is sufficient for no-param procedures.
procedure Simple_Thing;
```

See the [full spec](docs/api-docs/adacovex-docstring-spec.md) for the tag
table and coverage rules. For vendored code you cannot modify, use patch
files at `<target>/.adacovex/patches/` (strict mode) -- see
[Architecture -- Patch System](docs/architecture.md#patch-system).

## Compliance levels

The same evidence (proof level, passing tests, HLR traceability) is
re-labelled for three functionally-equivalent safety standards. Pick a level
with a standard's own naming, or `--standard=all` to run one assessment at
the shared tier and emit badges for all three:

| Standard | Level flag | Levels | Example |
|----------|-----------|--------|---------|
| DO-178C (avionics) | `--dal=` | A, B, C, D, E | `--dal=C` = DAL-C |
| ISO 26262 (automotive) | `--asil=` | A, B, C, D, QM | `--asil=B` = ASIL B |
| IEC 62304 (medical) | `--class=` | A, B, C | `--class=A` = Class A |

| DAL | Min SPARK | Tests must pass | HLRs traced | No orphans |
|-----|-----------|-----------------|-------------|------------|
| A | Gold | Yes | Yes | Yes |
| B | Silver | Yes | Yes | Yes |
| C | Bronze | Yes | Yes | Yes |
| D | None (Stone) | Yes | Yes | Yes |
| E | None (Stone) | No | Yes | Yes |

The evidence and artifacts are identical across standards -- only the
integrity-level label changes (`DAL-C` vs `ASIL B` vs `Class A`). Full tier
mapping and rationale: [Standards](docs/standards.md) and
[DAL Levels](docs/api-docs/adacovex-dal-levels.md).

## Development

`make check` runs the full quality gate (cheap static gates first, then build
+ test + prove + doc + sbom, then tree-wide count-sync checks); other targets
include `build`, `test`, `prove`, `doc`, `sbom`, `fmt`, `run-self`,
`run-ada-crdt`, `bump-version`, `release`, and `clean`. Run `make help` or see
[AGENTS.md](AGENTS.md) for the full table. AI tools were used during
development; why the code is still trustworthy:
[docs/llm-usage.md](docs/llm-usage.md).

## CI/CD

A composite GitHub Action (`./action.yml`) plus `ci.yml`, `pr-check.yml`, and
`release.yml` workflows cover the `--standard=all` self-assessment, the native
test suite, the PR docstring-coverage gate, and releases. Action
inputs/outputs, result caching, and release bundling:
[docs/ci-cd.md](docs/ci-cd.md).

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 663/663 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | Platinum (408 VCs, 0 unproved under gnatprove 16.1.0) |
| Ada_CRDT regression | `make run-ada-crdt` | 100% docs, DAL-C (strict mode) |

See [changelogs](docs/changelogs/index.md) for full release notes.

## Requirements

- **Alire** >= 2.0
- **GNAT** Ada compiler (managed by Alire)
- **Python 3** (build/dev tooling only: `tools/*.py` are pure-stdlib and drive
  version generation, description sync, test/proof doc sync, changelog
  checks, and the architecture tree -- the adacovex binary itself has no
  Python dependency)
- **GNATprove** (optional; resolved at run time by `prove` -- no declared dependency)
- **gnatpp** / **gnatdoc** (optional, for fmt/doc targets)

## Swapping the GNAT compiler (LLVM backend)

See
[docs/architecture.md](docs/architecture.md#swapping-the-gnat-compiler-llvm-backend)
for Alire-managed and system-installed GNAT LLVM options and caveats.

## Credits

- **[setup-alire](https://github.com/alire-project/setup-alire)** GitHub Action (used in CI)
- **[CycloneDX](https://github.com/CycloneDX/specification)** SBOM specification (CycloneDX 1.5 JSON output)
- **[SPDX](https://spdx.dev)** Software Package Data Exchange specification (SPDX 2.3 JSON output)

## License

Apache-2.0 -- see [LICENSE](LICENSE) for details.
