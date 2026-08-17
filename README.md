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
- **Scalable** -- package/subprogram collections use `Ada.Containers.Vectors`
  (no compile-time limits on count); fixed-size buffers scale with host word size

## AI Assistance Disclosure

AI tools were utilized during the development of this project for tasks
such as boilerplate generation, contract drafting, and docstring formatting.

### "Why should I trust your code?"

Given the use of AI assistance, healthy skepticism is natural and encouraged.
However, project reliability is grounded in mathematical proof and
non-invasive design rather than implicit trust:

- **Formal Verification:** Core Ada logic is formally verified using
  SPARK Ada (Platinum under `gnatprove` 16.1.0 -- 401 VCs, 0 unproved; see
  `docs/proof/16.1.0-ledger.md`).
- **Read-Only Engine:** `adacovex` acts strictly as an assessment engine.
  It processes input payloads, parses build artifacts, and produces reports
  without modifying your source files in place.
- **Open Auditability:** The codebase is fully open source under the Apache-2.0
  license for independent inspection and review.

> *Still skeptical?* See Ken Thompson's landmark paper,
[*Reflections on Trusting Trust*](https://dl.acm.org/doi/epdf/10.1145/358198.358210),
on the fundamental nature of trust in software toolchains.

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

### Option 1: declare it in your project's Alire manifest (recommended)

Put `covex` in your project's `alire-dev.toml` (never `alire.toml`, so release
builds stay clean), alongside `gnatprove`:

```toml
# <project>/alire-dev.toml
[[depends-on]]
covex = "*"
gnatprove = "^16.1.0"
```

Then `alr build` produces `bin/adacovex` inside the project and `covex prove`
deploys the pinned gnatprove crate standalone via `alr -n get` and runs it
directly -- each project pins its own exact toolchain version, no global
install needed:

```bash
alr build
./bin/adacovex --target=. --dal=C
./bin/adacovex prove --target=.   # deploys gnatprove via alr get, then runs it
```

### Option 2: `alr install` (global, to `$PATH`)

```bash
alr install covex gnatprove
export PATH="$HOME/.local/bin:$PATH"
```

`covex` is the Alire crate name for adacovex
([crate page](https://alire.ada.dev/crates/covex)); once on `$PATH` it scans
the current directory by default. A `gnatprove` installed this way is picked up
from `$PATH` by `covex prove` when the target project declares no manifest
dependency of its own.

### Option 3: download a release bundle from GitHub

Every `vX.Y.Z` tag publishes `adacovex-vX.Y.Z.tar.gz` (`adacovex` plus a
`covex` alias) on the
[GitHub Releases page](https://github.com/bladeacer/adacovex/releases).

```bash
curl -fsSL https://raw.githubusercontent.com/bladeacer/adacovex/main/install.sh | bash
```

Or fetch the bundle manually and unpack anywhere on `$PATH`:

```bash
VERSION=v1.9.0
curl -fL -o adacovex.tar.gz \
  "https://github.com/bladeacer/adacovex/releases/download/$VERSION/adacovex-$VERSION.tar.gz"
mkdir -p ~/.local/bin
tar -xzf adacovex.tar.gz -C ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
adacovex --help
```

Release bundles are attested with
[`actions/attest`](https://github.com/actions/attest); verify with
`gh attestation verify`.

> Release binaries are built for **Linux x86-64 only at the moment**. Every
> other platform (Linux aarch64, macOS, FreeBSD, Windows) builds adacovex from
> source via Alire -- no prebuilt bundle is published for those platforms yet.

### Building from source

Clone the repo (shallow is fine) and `make build`. Adacovex builds with a
stock Alire toolchain (`gnat_native` + `gprbuild`) plus the standard GNAT
runtime -- no other dependencies:

```bash
# latest development snapshot (main branch)
git clone --depth 1 https://github.com/bladeacer/adacovex.git
cd adacovex
make build

# or a specific released tag (vX.Y.Z) for reproducibility
git clone --depth 1 --branch v1.10.0 https://github.com/bladeacer/adacovex.git
cd adacovex
make build
```

`make build` produces `bin/adacovex` (with a `bin/covex` alias on Linux
symlinks). Alternatively manage adacovex as an Alire dev dependency (see
Option 1 above).

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

## CLI reference

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
adacovex prove [--target=PATH] [prove options]
adacovex status [--target=PATH]
adacovex man [--check] [--dir=PATH]
```

| Flag | Default | Mode | Description |
|------|---------|------|-------------|
| `--target=PATH` | `.` (CWD) | both | Target project root directory |
| `--manifest=PATH` | auto-detected | both | Override project manifest path |
| `--dal=LEVEL` | `C` | both | DO-178C DAL level (A-E; also the shared rigor tier) |
| `--asil=LEVEL` | - | both | ISO 26262 level: `A`\|`B`\|`C`\|`D`\|`QM` (e.g. `--asil=B`) |
| `--class=LEVEL` | - | both | IEC 62304 safety class: `A`\|`B`\|`C` (e.g. `--class=A`) |
| `--standard=NAME` | `do178c` | both | `do178c`\|`iso26262`\|`iec62304`\|`all` (all emits every badge) |
| `--serve` | off | both | Start HTTP dashboard server |
| `--port=N` | `8080` | serve | Dashboard server port |
| `--emit-svg=PATH` | `<target>/docs/badges` | both | Output directory for SVG badges |
| `--no-svg` | off | both | Suppress SVG badge output |
| `--emit-markdown=PATH` | off | both | Output directory for Markdown reports |
| `--skip-dir=NAME` | `demo,deps,examples` | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode (skip dirs, no patches) |
| `--compare-base=REF` | off | both | Differential mode vs a base rev (git/hg/svn/fossil/jj) |
| `--coverage-delta=REF` | off | both | Docstring-coverage gate vs a base rev (git/hg/svn/fossil/jj) |
| `--cache` | on | both | Enable on-disk result caching |
| `--no-cache` | off | both | Disable result caching |
| `--cache-dir=PATH` | `~/.adacovex/cache/<ver>/<schema>` | both | Cache directory |
| `--cache-max=N` | `4096` | both | Max cache entries before eviction |
| `--require-spark=LVL` | off | both | Fail (exit 1) if SPARK level < LVL |
| `--require-docstrings=PCT` | off | both | Fail if docstring coverage < PCT% |
| `--require-tests=N` | off | both | Fail if passing test count < N |
| `--require-proof=PCT` | off | both | Fail if proved-VC coverage < PCT% |
| `--verbose` | off | both | Verbose diagnostics |
| `--version` | - | - | Print the bundled version and exit |
| `man` | - | - | Install the man page into the local man database (Linux/WSL) |
| `man --check` | - | - | Exit 0 if the installed man page matches the binary version |
| `--help` | - | both | Print usage and exit |

The version is read from `alire/alire-dev.toml` at build time; release builds
bundle the release tag. `adacovex man` installs the man page (which embeds
the version) into `~/.local/share/man` and refreshes `mandb`; `--check` lets a
prompt hook auto-install when a newer version is available. Differential
modes (`--compare-base` / `--coverage-delta`) run on git, Mercurial,
Subversion, Fossil, and jj repos; for Subversion/Fossil adacovex recommends
converting to git.

Full flag details, the `--require-*` CI threshold gates, strict vs relaxed
mode, exit codes, and the `sbom` subcommand:
[docs/cli-reference.md](docs/cli-reference.md).

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
adacovex sbom --format=cyclonedx-json --target=. --dal=C   # proof-aware SBOM
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

**Compliance artifacts are identical across standards.** ISO 26262 and
IEC 62304 do not require different evidence than DO-178C: all three consume
the same HLR traceability, orphan-tag check, passing-test requirement, and
minimum-SPARK proof bar, and adacovex emits the same artifacts
(`HLR.md` source traceability, `VERIFICATION.md`, `TRACE.md`, the proof-aware
SBOM, and the compliance SVG badges) for every standard. Only the integrity
level's name differs (`DAL-C` vs `ASIL B` vs `Class A`); the underlying
assessment and the artifacts describing it are shared.

## Makefile targets

| Target | Description |
|--------|-------------|
| `build` | `alr build` (adacovex + test_runner, covex alias) |
| `test` | Build and run native test suite (555 tests) |
| `prove` | `./bin/adacovex prove --target=. --no-svg` |
| `fmt` | Format Ada sources with `gnatformat` |
| `doc` | Generate API docs via gnatdoc + rst2md |
| `run-self` | Run against adacovex itself (default target: cwd) |
| `run-ada-crdt` | Run against `../Ada_CRDT` (strict mode) |
| `coverage-gate` | Run `--coverage-delta` between the latest two release tags |
| `bump-version` | Bump version across manifests + changelog (`VERSION=x.y.z`) |
| `release` | Build `--release`, prove, validate, bundle + push (`VERSION=x.y.z`) |
| `ascii-check` | Verify all source files are pure ASCII |
| `clean` | Remove `bin/`, `obj/`, generated reports |

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
| Unit tests | `make test` | 555/555 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | Platinum (401 VCs, 0 unproved under gnatprove 16.1.0) |
| Ada_CRDT regression | `make run-ada-crdt` | 100% docs, DAL-C (strict mode) |

See [changelogs](docs/changelogs/index.md) for full release notes.

## Documentation

| Reference | Description |
|-----------|-------------|
| [CLI Reference](docs/cli-reference.md) | Flags, `--require-*` gates, exit codes, `sbom` subcommand |
| [CI/CD](docs/ci-cd.md) | GitHub Action, workflows, release bundling |
| [Docstring Spec](docs/api-docs/adacovex-docstring-spec.md) | Annotation format, placement, conventions |
| [Test Format](docs/api-docs/adacovex-test-format.md) | Supported test-result output format |
| [SPARK Levels](docs/api-docs/adacovex-spark-levels.md) | Assurance level objectives (Stone--Platinum) |
| [DAL Levels](docs/api-docs/adacovex-dal-levels.md) | DO-178C DAL A - E criteria |
| [ASIL Levels](docs/api-docs/adacovex-asil-levels.md) | ISO 26262 ASIL A - D / QM criteria |
| [Safety Classes](docs/api-docs/adacovex-class-levels.md) | IEC 62304 Class A - C criteria |
| [Standards](docs/standards.md) | DO-178C / ISO 26262 / IEC 62304 abstraction |
| [Platforms](docs/platforms.md) | Platform support, CPU core detection, `status` subcommand |
| [Architecture](docs/architecture.md) | Design decisions, patches, toolchain resolution, overflow contract |
| [Contributing](CONTRIBUTING.md) | Changelog format, test suite |
| [API Reference](docs/api-docs/index.md) | Auto-generated package API docs |
| [Changelog](docs/changelogs/index.md) | Release history |

## Requirements

- **Alire** >= 2.0
- **GNAT** Ada compiler (managed by Alire)
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
