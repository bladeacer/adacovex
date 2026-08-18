[![covex Alire crate badge](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/covex.json)](https://alire.ada.dev/crates/covex)
![SPARK](docs/badges/spark.svg)
![Tests](docs/badges/tests.svg)
![DO-178C](docs/badges/do178c.svg)
![ISO 26262](docs/badges/iso26262.svg)
![IEC 62304](docs/badges/iec62304.svg)
![docs](docs/badges/docs.svg)

# adacovex

**Zero-dependency Ada/SPARK CLI tool** for coverage analysis, proof verification,
test-result parsing, multi-standard safety-compliance assessment (DO-178C /
ISO 26262 / IEC 62304), and interactive dashboards. No library dependencies
beyond the GNAT runtime; gnatprove is resolved at run time by the `prove`
subcommand, so installing adacovex pulls nothing but the binary.

## Features

- **Source scanning** -- walks `.ads` files, extracts subprogram declarations,
  [docstring annotations](docs/api-docs/adacovex-docstring-spec.md) (Ada
  `@param`/`@return`/`@field`/`@formal`/`@brief`/`@summary`, Google
  `Args:`/`Returns:`, Sphinx `:param:`/`:returns:`), and HLR traceability tags
- **Proof analysis** -- parses GNATprove `gnatprove.out` summaries; assesses
  [SPARK assurance levels](docs/api-docs/adacovex-spark-levels.md) (Stone--Platinum)
- **Test parsing** -- reads [test-result summaries](docs/api-docs/adacovex-test-format.md)
  (Markdown tables, TAP, Automake, Maven Surefire, Unity, AUnit-compatible)
- **[Compliance](docs/api-docs/adacovex-dal-levels.md)** -- assesses DO-178C DAL A-E
  criteria (HLR coverage, orphan tags, test status, minimum SPARK proof level),
  re-labelled for [ISO 26262](docs/standards.md) (ASIL A--D/QM) and
  [IEC 62304](docs/standards.md) (safety classes A--C) with dedicated
  `--dal` / `--asil` / `--class` flags
- **Multiple outputs** -- ANSI report, SVG badges, Markdown reports, HTML
  dashboard + JSON API, proof-aware SBOM (CycloneDX / SPDX)
- **[Multi-VCS differential assessment](docs/cli-reference.md#vcs-support)** --
  `--compare-base` / `--coverage-delta` snapshot a base revision on **git,
  Mercurial, Subversion, Fossil, or jj** without touching your working tree,
  so regressions are caught before pushing even in legacy repositories
- **Result caching** -- a content-addressed on-disk cache (`~/.adacovex/cache`)
  serves unchanged scan, proof, test, HLR/LLR, and dependency-graph results
  without re-running the work; per-file granularity means a one-line change
  only invalidates that file's entry
- **Tooling** -- `status` reports your toolchain + VCS state, `man` installs
  a local man page (`man-db` detected and reported; the page still installs
  without it), and `make check` runs the full quality gate in one command
- **Scalable** -- package/subprogram collections use `Ada.Containers.Vectors`
  (no compile-time limits on count); fixed-size buffers scale with host word size

## AI assistance disclosure

AI tools were used during development (boilerplate, contract drafting,
docstring formatting) and LLM agents work on the tree under the rules in
`AGENTS.md`. Why the code is still trustworthy, how agents are expected to
work, and how every number in the docs is anchored to generated artifacts
rather than a written claim: [docs/llm-usage.md](docs/llm-usage.md).

## Quick start

```bash
# Build
make build

# Run against adacovex itself (strict mode, default)
make run-self

# Run against Ada_CRDT (strict mode)
make run-ada-crdt

# Explicit target
./bin/adacovex --target=../Ada_CRDT --dal=C
```

## Installing adacovex

Three routes: declare `covex` in your project's `alire-dev.toml`, `alr install
covex`, or download a release bundle / build from source.
[Installation](docs/installation.md) covers each in detail, including the
version source per method and keeping the man page in sync.

## Platform support

adacovex is a zero-dependency Ada/SPARK binary built on the GNAT runtime and
the standard library, so it runs anywhere a GNAT/Alire toolchain exists.
The official **release binary is plain Linux x86-64 only for now**; macOS,
FreeBSD, Windows, and Linux aarch64 build from source via Alire instead.

Full supported-platform table, CPU core-count detection order, CI detection,
and prove-parallelism resolution:
[docs/platforms.md](docs/platforms.md). Use `adacovex status` to report your
own toolchain + platform state.

## GNATprove toolchain resolution

The `prove` subcommand resolves the `gnatprove` executable in this order:
**manifest pin > global pin (config/env) > `$PATH` > cached toolchain >
download**. A manifest pin is authoritative (fails rather than falls back).

Full resolution order and the doc/fmt manifest-swap:
[docs/architecture.md](docs/architecture.md#gnatprove-toolchain-resolution-prove-subcommand).

## Version control support

**A VCS is not required for base adacovex functionality** -- scanning, proof
analysis, test parsing, compliance assessment, SBOM generation, dashboards,
and caching all work on a plain directory. A VCS is only needed for the
differential modes (`--compare-base` / `--coverage-delta`), which work across
git, Mercurial, Subversion, Fossil, and jj without touching the working tree.
`adacovex status` reports which VCS tools are available and what manages the
target. Full details:
[docs/cli-reference.md](docs/cli-reference.md#vcs-support).

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
relaxed mode, exit codes, the `sbom` subcommand, contextual `help [TOPIC]`
and the unknown-flag "did you mean" behavior) lives in
[docs/cli-reference.md](docs/cli-reference.md). `adacovex man` installs the
man page into `~/.local/share/man` (with `mandb` refresh when present);
`man --check` exits 0 when the installed page matches the binary,
`man --force` overwrites an up-to-date page.

### Web dashboard and JSON API

`adacovex --target=. --serve --port=8080` starts an HTTP server that serves a
**viewable HTML dashboard at `http://localhost:8080/`** (standard-aware,
light/dark/system themes via `--theme=` or `?theme=` on the URL, and a Save
settings button) plus a machine-readable endpoint for scripts and CI:

```bash
curl http://localhost:8080/api/metrics
```

The response carries `spark_level`, `total_vcs`, `proved_vcs`,
`tests_passed` / `tests_failed`, `doc_coverage`, `standard`, `level`,
`dal_status`, and a per-standard `standards` object. SVG badges are served
at `/badge/*.svg`. Full API details and a sample response:
[docs/cli-reference.md](docs/cli-reference.md#--serve).

## Examples

```bash
adacovex --target=.                                 # self-assessment
adacovex --target=../Ada_CRDT --dal=C --relaxed     # DAL-C, relaxed mode
adacovex --target=. --dal=A                         # DAL-A (requires Gold SPARK)
adacovex --target=. --asil=B                        # ISO 26262 at ASIL B
adacovex --target=. --class=A                       # IEC 62304 at Class A
adacovex --target=. --standard=iso26262 --dal=C     # ISO 26262 at ASIL B (alias)
adacovex --target=. --standard=all                  # badges for every standard
adacovex --target=. --emit-markdown=docs/compliance # Markdown reports
adacovex --target=. --serve --port=9090             # web dashboard
adacovex --target=. --compare-base=HEAD             # differential assessment
adacovex sbom --format=cyclonedx-json --target=. --dal=C   # proof-aware SBOM (all standards)
adacovex sbom --target=. --asil=B                         # SBOM for ISO 26262 at ASIL B
adacovex status --target=.                                # toolchain + platform report
adacovex --version                                   # print the bundled version
adacovex man                                         # install the man page + mandb
```

More examples: [docs/cli-reference.md](docs/cli-reference.md#examples).

## Requirements for target projects

To run adacovex against an Ada/SPARK project, it must have:

1. **Ada source files** (`.ads`) under the target root.
2. **GNATprove output**: `gnatprove.out` in the target root or
   `<target>/obj/gnatprove/gnatprove.out`.
3. **Test results**: a test-summary file in the target root (conventional names
   are auto-discovered; Markdown table, TAP, Automake, Surefire, Unity, or
   `Passed:`/`Failed:` formats are supported).
4. **HLR document** (for DAL assessment): `<target>/docs/compliance/HLR.md`.

Missing data shows "N/A"; DAL checks that depend on it report `Unmet`.

Non-Ada projects (C/C++, Python, JS, ...) provision their own
`alire.toml` / `alire-dev.toml` to manage the Ada deps needed to build
adacovex itself. Running `adacovex` from the repo scans it and uses its
manifest.

> We are currently working on support for other languages, stay tuned.

## Docstring format

```ada
--  Summary sentence describing what the subprogram does.
--  @param Name  Description of the parameter.
--  @return Description of the return value.
procedure Do_Something (Name : in Some_Type);

--  A plain summary line is sufficient for no-param procedures.
procedure Simple_Thing;
```

See the [full spec](docs/api-docs/adacovex-docstring-spec.md) for the tag table
and coverage rules.

## Patch files (strict mode)

For vendored/third-party code you cannot modify, create docstring patches at
`<target>/.adacovex/patches/<relative-path>` (a valid Ada `.ads` with
docstrings for the subprograms to document). Overloaded subprograms need one
patch entry per overload.

See [Architecture -- Patch System](docs/architecture.md#patch-system) for the
full format and rules.

## DAL levels

| DAL | Min SPARK | Tests must pass | HLRs traced | No orphans |
|-----|-----------|-----------------|-------------|------------|
| A | Gold | Yes | Yes | Yes |
| B | Silver | Yes | Yes | Yes |
| C | Bronze | Yes | Yes | Yes |
| D | None (Stone) | Yes | Yes | Yes |
| E | None (Stone) | No | Yes | Yes |

See [DAL Levels](docs/api-docs/adacovex-dal-levels.md) for the full criteria.

## Compliance standards

The same evidence (proof level, passing tests, HLR traceability) is re-labelled
for three functionally-equivalent safety standards. Pick a level with a
standard's own naming, or list every standard:

| Standard | Level flag | Levels | Example |
|----------|-----------|--------|---------|
| DO-178C (avionics) | `--dal=` | A, B, C, D, E | `--dal=C` = DAL-C |
| ISO 26262 (automotive) | `--asil=` | A, B, C, D, QM | `--asil=B` = ASIL B |
| IEC 62304 (medical) | `--class=` | A, B, C | `--class=A` = Class A |

`--standard=all` runs one assessment at the shared tier and emits badges for
all three standards. Full tier mapping and rationale:
[Standards](docs/standards.md).

The evidence and artifacts are identical across standards -- only the
integrity-level label changes (`DAL-C` vs `ASIL B` vs `Class A`). Full tier
mapping and rationale: [Standards](docs/standards.md).

## Makefile targets

`make check` runs the full quality gate (cheap static gates first, then build +
test + prove + doc + sbom, then tree-wide count-sync checks). Other key
targets: `build`, `test`, `prove`, `doc`, `sbom`, `fmt`, `description`,
`run-self`, `run-ada-crdt`, `bump-version`, `release`, `ascii-check`,
`spark-off-check`, `coverage-gate`, and `clean`. Run `make help` or see
[AGENTS.md](AGENTS.md) for the full table.

## CI/CD

A composite GitHub Action (`./action.yml`) plus `ci.yml`, `pr-check.yml`, and
`release.yml` workflows cover the `--standard=all` self-assessment (with prove
and the `--require-*` gates), the native test suite, the release-tag docstring
coverage gate, and releases. The action accepts `dal` / `standard` / `asil` /
`class` inputs plus the full `prove` subcommand options and the `--require-*`
CI gates. Action inputs/outputs, result caching, and release bundling:
[docs/ci-cd.md](docs/ci-cd.md).

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 663/663 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | Platinum (408 VCs, 0 unproved under gnatprove 16.1.0) |
| Ada_CRDT regression | `make run-ada-crdt` | 100% docs, DAL-C (strict mode) |

See [changelogs](docs/changelogs/index.md) for full release notes.

## Documentation

| Reference | Description |
|-----------|-------------|
| [Installation](docs/installation.md) | Alire manifest / `alr install` / release bundle / source build |
| [CLI Reference](docs/cli-reference.md) | Flags, `--require-*` gates, exit codes, `sbom` subcommand |
| [Web Dashboard + JSON API](docs/cli-reference.md#--serve) | `--serve` HTML dashboard, `/api/metrics`, badges |
| [CI/CD](docs/ci-cd.md) | GitHub Action, workflows, release bundling |
| [Standards](docs/standards.md) | DO-178C / ISO 26262 / IEC 62304 abstraction |
| [Platforms](docs/platforms.md) | Platform support, CPU core detection, `status` subcommand |
| [Architecture](docs/architecture.md) | Design decisions, patches, toolchain resolution, overflow contract |
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
