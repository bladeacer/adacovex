[![covex Alire crate badge](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/covex.json)](https://alire.ada.dev/crates/covex)
![SPARK](docs/badges/spark.svg)
![Tests](docs/badges/tests.svg)
![DO-178C](docs/badges/do178c.svg)
![docs](docs/badges/docs.svg)

# adacovex

**Zero-dependency Ada/SPARK CLI tool** for coverage analysis, proof verification,
test-result parsing, DO-178C DAL compliance assessment, and interactive dashboards.

## Features

- **Source scanning** -- walks `.ads` files, extracts subprogram declarations, [docstring
  annotations](docs/api-docs/adacovex-docstring-spec.md)
  (`@param`, `@return`, `@field`, `@formal`), and HLR traceability tags
- **Proof analysis** -- parses GNATprove `gnatprove.out` summaries per check category
  (flow, run-time, assertions, contracts, termination); assesses [SPARK assurance
  levels](docs/api-docs/adacovex-spark-levels.md) (Stone--Platinum)
- **Test parsing** -- reads [test-result markdown](docs/api-docs/adacovex-test-format.md)
  for pass/fail counts (supports both native Ada test output and AUnit format)
- **[DAL compliance](docs/api-docs/adacovex-dal-levels.md)** -- assesses DO-178C DAL A-E
  criteria (HLR coverage, orphan tags, test status, minimum SPARK proof level)
- **Multiple outputs**:
  - ANSI terminal report
  - SVG badges (Shields.io style) -- SPARK level, test status, DO-178C status, docstring coverage
  - Markdown reports -- `VERIFICATION.md` + `TRACE.md`
  - HTML dashboard + JSON API via built-in HTTP server
- **Scalable** -- package/subprogram collections use `Ada.Containers.Vectors`
(heap-allocated, no compile-time limits on count). Fixed-size buffers: 8192-char
lines, 4096-char paths.

## Quick start

```bash
# Build
make build

# Run against adacovex itself (strict mode, default)
make run-self

# Run against Ada_CRDT (relaxed mode, skip demo/deps/examples)
make run-ada-crdt

# Explicit target
./bin/adacovex_main --target=../Ada_CRDT --dal=C
```

## CLI reference

```
adacovex [options]
```

| Flag | Default | Mode | Description |
|------|---------|------|-------------|
| `--target=PATH` | `.` (CWD) | both | Target project root directory |
| `--manifest=PATH` | auto-detected | both | Override project manifest path |
| `--dal=LEVEL` | `C` | both | Target DAL level (A-E) |
| `--serve` | off | both | Start HTTP dashboard server |
| `--port=N` | `8080` | serve | Dashboard server port |
| `--emit-svg=PATH` | `<target>/docs/badges` | both | Output directory for SVG badges |
| `--no-svg` | off | both | Suppress SVG badge output |
| `--emit-markdown=PATH` | off | both | Output directory for Markdown reports |
| `--skip-dir=NAME` | `demo,deps,examples` | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode (skip dirs, no patches) |
| `--verbose` | off | both | Verbose diagnostics |
| `--help` | - | both | Print usage and exit |

### Flag details

**`--target=PATH`** -- Project to analyze. Relative paths resolved against CWD.
Default: current working directory.

**`--manifest=PATH`** -- Override project manifest file. Auto-detected from
`<target>/alire-dev.toml` or `<target>/alire.toml`. Displayed as metadata only.

**`--dal=LEVEL`** -- Target DAL level: `A`, `B`, `C`, `D`, or `E` (case-insensitive).
Determines minimum SPARK level and criteria checked. See [DAL levels](#dal-levels).

**`--serve`** -- After scanning, start HTTP server on `--port` (default 8080):
- `GET /` -- HTML dashboard
- `GET /api/metrics` -- JSON metrics
- `GET /badge/spark.svg`, `GET /badge/tests.svg`, `GET /badge/do178c.svg` -- SVG badges

**`--emit-svg=PATH`** -- Write SVG badges (`spark.svg`, `tests.svg`, `do178c.svg`, `docs.svg`)
to directory. Default: `<target>/docs/badges`. Override with `--no-svg`.

**`--no-svg`** -- Suppress all SVG badge output. Overrides `--emit-svg`.

**`--emit-markdown=PATH`** -- Write `VERIFICATION.md` (full report) and `TRACE.md`
(HLR traceability matrix) to the given directory.

**`--skip-dir=NAME`** -- Add directory name to skip list (repeatable).
Only effective in relaxed mode. Default skip list: `demo,deps,examples`.

**`--relaxed`** -- Disable strict mode. Enables the skip list (default: `demo,deps,examples`
plus any `--skip-dir` entries). Does NOT apply `.adacovex/patches/`.
Default: OFF (strict mode is on by default).

**`--verbose`** -- Print pipeline step diagnostics to stderr.

### Strict vs relaxed mode

| Aspect | Strict (default) | Relaxed (`--relaxed`) |
|--------|-----------------|----------------------|
| Directory exclusions | `.git`, `obj`, `tests`, `config`, `.adacovex` only | Same + `demo,deps,examples` + `--skip-dir` additions |
| Vendored code | Scanned and counted | Skipped |
| Patch files | Applied from `.adacovex/patches/` | Not applied |
| Use case | Full compliance audit | Quick assessment of production code |

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (DAL achieved, all checks pass) |
| `1` | Compliance failure (DAL unmet, tests failing, etc.) |

## Examples

```bash
# Self-assessment (strict mode, 100% docs required)
adacovex --target=.

# Assess a CRDT library at DAL-C in relaxed mode
adacovex --target=../Ada_CRDT --dal=C --relaxed

# DAL-A assessment (requires Gold SPARK)
adacovex --target=. --dal=A

# Without SVG output
adacovex --target=../Ada_CRDT --no-svg

# Custom skip dirs
adacovex --target=../Ada_CRDT --relaxed --skip-dir=vendor

# With Markdown reports
adacovex --target=. --emit-markdown=docs/compliance

# Web dashboard on custom port
adacovex --target=. --serve --port=9090
```

## Requirements for target projects

To run adacovex against a project, it must have:

1. **Ada source files** (`.ads`) under the target root.
2. **GNATprove output**: `gnatprove.out` in the target root or
   `<target>/obj/gnatprove/gnatprove.out`.
3. **Test results**: `<target>/test_result.md` with a Markdown table
   containing `Tests` and `Status` columns (PASS/FAIL).
4. **HLR document** (for DAL assessment): `<target>/docs/compliance/HLR.md`.

Missing data shows "N/A" and relevant DAL checks report `Unmet`.

## Docstring format

```ada
--  Summary sentence describing what the subprogram does.
--  @param Name  Description of the parameter.
--  @return Description of the return value.
procedure Do_Something (Name : in Some_Type);

--  A plain summary line is sufficient for no-param procedures.
procedure Simple_Thing;
```

Tags: `@param`, `@return`, `@field`, `@formal`. Prefix: `--  ` (two dashes + two spaces).

See [full spec](docs/api-docs/adacovex-docstring-spec.md).

## Patch files (strict mode)

For vendored/third-party code that you cannot modify, create docstring patches:

```
<target>/.adacovex/patches/<relative-path>
```

Example: to patch `Ada_CRDT/demo/deps/vt100/vt100.ads`:

```
Ada_CRDT/.adacovex/patches/demo/deps/vt100/vt100.ads
```

The patch file is a valid Ada `.ads` with docstrings for subprograms you want
to document. Overloaded subprograms require one patch entry per overload.

## DAL levels

| DAL | Min SPARK | Tests must pass | HLRs traced | No orphans |
|-----|-----------|-----------------|-------------|------------|
| A | Gold | Yes | Yes | Yes |
| B | Silver | Yes | Yes | Yes |
| C | Bronze | Yes | Yes | Yes |
| D | None (Stone) | Yes | Yes | Yes |
| E | None (Stone) | No | Yes | Yes |

## Makefile targets

| Target | Description |
|--------|-------------|
| `build` | `alr build` (adacovex_main + test_runner) |
| `test` | Build and run native test suite (167 tests) |
| `prove` | `alr gnatprove` (auto-swaps alire-dev.toml) |
| `fmt` | Format Ada sources with `gnatformat` |
| `doc` | Generate API docs via gnatdoc + rst2md |
| `run-self` | Run against adacovex itself (default target: cwd) |
| `run-ada-crdt` | Run against `../Ada_CRDT` (strict mode) |
| `bump-version` | Bump version across manifests + changelog (`VERSION=x.y.z`) |
| `ascii-check` | Verify all source files are pure ASCII |
| `dev-setup` | Copy alire-dev.toml over alire.toml |
| `prod-setup` | Restore clean publishing alire.toml |
| `clean` | Remove `bin/`, `obj/`, generated reports |

## Project structure

```
src/
|-- adacovex.ads                  -- Version constant
|-- adacovex_main.adb             -- CLI entry point
|-- core/                         -- Types + CLI config
|-- parsers/                      -- Source, proof, test, DO-178C parsers
|-- compliance/                   -- DAL assessment logic
|-- renderers/                    -- ANSI, SVG, Markdown, HTML output
|-- server/                       -- HTTP/1.1 dashboard server
|-- tests/                        -- Native test suite (167 tests)
```

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 167/167 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C |
| SPARK proof | `make prove` | 28/28 VCs Platinum |
| Ada_CRDT regression | `make run-ada-crdt` | 100% docs, Platinum, DAL-C (strict mode) |

See [changelogs](docs/changelogs/index.md) for full release notes.

## Documentation

| Reference | Description |
|-----------|-------------|
| [Docstring Spec](docs/api-docs/adacovex-docstring-spec.md) | Annotation format, placement, conventions |
| [Test Format](docs/api-docs/adacovex-test-format.md) | Supported test-result output format |
| [SPARK Levels](docs/api-docs/adacovex-spark-levels.md) | Assurance level objectives (Stone--Platinum) |
| [DAL Levels](docs/api-docs/adacovex-dal-levels.md) | DO-178C DAL A--E criteria |
| [API Reference](docs/api-docs/index.md) | Auto-generated package API docs |
| [Changelog](docs/changelogs/index.md) | Release history |

## Requirements

- **Alire** >= 2.0
- **GNAT** Ada compiler (managed by Alire)
- **GNATprove** (optional, for proof targets, managed by Alire)
- **gnatpp** / **gnatdoc** (optional, for fmt/doc targets, managed by Alire)

## License

Apache-2.0 -- see [LICENSE](LICENSE) for details.
