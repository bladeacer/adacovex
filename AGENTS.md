# AGENTS.md -- adacovex

## Project

**adacovex** -- zero-dependency Ada/SPARK CLI tool for coverage, proof analysis,
test-result parsing, DO-178C DAL compliance assessment, and interactive dashboards.

- **Repo**: https://github.com/bladeacer/adacovex
- **Language**: Ada 2012 / SPARK 2014 (GNAT, Alire)
- **Zero dependency**: uses only GNAT runtime (GNAT.Sockets, Ada tasking, standard libs)
- **SPARK target**: Platinum (AoRTE-free, all VCs proved) on adacovex itself

## Dogfood target

adacovex was designed to audit the Ada_CRDT library at `../Ada_CRDT` (26 packages,
~219 subprograms). Running `make run-ada-crdt` runs the full pipeline against it.
The `--target=PATH` option can point at any Ada/SPARK project.

Self-assessment (`make run-self` / `--target=.`) verifies adacovex against its own
source -- all 19 packages, 32 subprograms -- and must always show:
- 100% docstring coverage
- Platinum SPARK level (28/28 VCs proved)
- 152/152 native tests passing
- DAL-C Achieved

## Architecture

```
src/
|-- adacovex.ads                    -- Version constant
|-- adacovex_main.adb               -- CLI entry point (ANSI, exit codes, NO_COLOR)
|-- core/
|   |-- adacovex-types.ads/.adb     -- All domain types + conversion functions
|   `-- adacovex-config.ads/.adb    -- CLI argument parser
|-- parsers/
|   |-- adacovex-parsers-source.ads/.adb      -- Ada source scanner (procs/funcs/docstrings/HLR)
|   |-- adacovex-parsers-gnatprove.ads/.adb   -- GNATprove .out parser
|   |-- adacovex-parsers-tests.ads/.adb       -- AUnit test-result parser
|   `-- adacovex-parsers-do178c.ads/.adb      -- HLR/LLR markdown parser + source tag matcher
|-- tests/
|   |-- adacovex-test_support.ads/.adb        -- Native test Runner type
|   |-- adacovex_dal_tests.ads/.adb           -- DAL compliance tests
|   |-- adacovex_types_tests.ads/.adb         -- Type conversion tests
|   |-- adacovex_scanner_tests.ads/.adb       -- Source scanner tests (28)
|   |-- adacovex_prove_tests.ads/.adb         -- GNATprove parser tests (24)
|   |-- adacovex_test_parser_tests.ads/.adb   -- Test-result parser tests (27)
|   |-- adacovex_config_tests.ads/.adb        -- CLI config tests (8)
|   |-- adacovex_svg_tests.ads/.adb          -- SVG renderer tests (30)
|   `-- test_runner.adb                       -- Test suite entry point (152 tests)
|-- compliance/
|   |-- adacovex-compliance-dal.ads/.adb       -- DAL-C assessment logic
|-- renderers/
|   |-- adacovex-renderers-ansi.ads/.adb       -- Terminal ANSI report (NO_COLOR aware)
|   |-- adacovex-renderers-markdown.ads/.adb   -- VERIFICATION.md + TRACE.md
|   |-- adacovex-renderers-svg.ads/.adb        -- SVG badges (spark/tests/do178c/docs)
|   `-- adacovex-renderers-html.ads/.adb       -- Web dashboard + JSON API
`-- server/
    |-- adacovex-server-http.ads/.adb          -- HTTP/1.1 server (4-worker task pool)
```

No dynamic allocation; all storage bounded at compile time.

## Makefile targets

| Target             | Description |
|--------------------|-------------|
| `build`            | `alr build` (builds adacovex_main + test_runner) |
| `test`             | Build + run test_runner |
| `prove`            | `alr gnatprove` (uses alire-dev.toml) |
| `doc` / `api-docs` | Generate API docs via gnatdoc + rst2md |
| `fmt`              | Format Ada sources with gnatformat |
| `run-self`         | Run against adacovex itself (--target=.) |
| `run-ada-crdt`     | Run against ../Ada_CRDT, DAL-C |
| `ascii-check`      | Verify all source files are pure ASCII |
| `dev-setup`        | Copy alire-dev.toml over alire.toml |
| `prod-setup`       | Restore clean publishing alire.toml |
| `clean`            | Remove bin/ obj/ docs/badges/ |

## CLI

```
adacovex [options]
  --target=PATH         Target project (default: ../Ada_CRDT)
  --manifest=PATH       Target manifest file override
  --dal=LEVEL           DAL A-E (default: C)
  --serve               Start HTTP dashboard on :8080 (or --port=N)
  --emit-svg=PATH       Write SVG badges to directory (default: docs/badges)
  --no-svg              Suppress default SVG badge output
  --emit-markdown=PATH  Write VERIFICATION.md + TRACE.md
  --verbose             Verbose output
  --port=N              HTTP server port (default: 8080)
  --help                Show help

Exit codes:
  0  Success (DAL achieved, all checks pass)
  1  Compliance failure (DAL unmet, tests failing, etc.)
```

## Docstring annotation spec

See [docs/api-docs/adacovex-docstring-spec.md](docs/api-docs/adacovex-docstring-spec.md)
for full reference.

Supported tags (`adacovex-parsers-source.ads`), placed **immediately before**
the subprogram declaration (no blank lines between tags and declaration):

| Tag | Format | Purpose |
|-----|--------|---------|
| `@param` | `--  @param Name  Description.` | Subprogram formal parameter |
| `@return` | `--  @return Description.` | Function return value |
| `@field` | `--  @field Description.` | Record component |
| `@formal` | `--  @formal Name  Description.` | Generic formal parameter |

Conventions (following `../Ada_CRDT` style):
- Prefix: `--  ` (two dashes + two spaces) for all doc lines.
- Summary first, then tag lines, then declaration -- no blank lines.
- Descriptions capitalized, end with period.
- Two spaces between tag name and description (alignment padding).

Placement is scanned correctly whether tags appear **before** or **after** the
subprogram declaration (before style is the canonical Ada convention).

## DAL-C assessment criteria

See [docs/api-docs/adacovex-dal-levels.md](docs/api-docs/adacovex-dal-levels.md)
for full DAL A--E criteria.

1. All HLRs traced in source tags (24/24 for adacovex self)
2. No orphan tags
3. All tests passing (152/0 for self)
4. Minimum SPARK Level >= Bronze (target is Platinum)

## Unit tests

**Native (zero-dependency).** Tests use `Adacovex.Test_Support` -- a minimal
`Runner` type with a `Check` procedure. No AUnit or other external framework.

Test source: `src/tests/`. Entry point: `test_runner.adb` (builds as
`bin/test_runner` from `for Main use ("adacovex_main.adb", "test_runner.adb")`
in `adacovex.gpr`).

`make test` builds and runs the 152-test suite. Test results are written to
`docs/test_result.md` in a Markdown table format that can be parsed by
`adacovex-parsers-tests`. This means adacovex **supports both** native test
running (via test_runner) and AUnit test-result parsing (via Parse_Test_Result).

### Test categories (152 total)

| Category | Tests | What it covers |
|----------|-------|----------------|
| Types conversions | 21 | SPARK_Level/DAL_Level/DAL_Status/Test_Status strings |
| DAL compliance | 2 | DAL assessment status |
| Source scanner | 40 | Package scan, docstring parsing, HLR tags, name extraction, @field/@formal/after-decl |
| GNATprove parser | 24 | .out parsing, proof summary, SPARK level detection |
| Test-result parser | 27 | Markdown test result parsing |
| CLI config | 8 | Default option values, --no-svg field |
| SVG renderer | 30 | SVG badge content and format |

### Known scanner quirks
- `(null record)` typed parameters are counted as parameters

### Directory exclusions
The scanner skips these directories during source traversal: `.git`, `obj`, `tests`,
`config`, `demo`, `deps`, `examples`. Third-party vendored code (e.g.
`demo/deps/vt100/`) is excluded from docstring coverage and metric counts.

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 152/152 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | 28/28 VCs Platinum |
| Ada_CRDT regression | `make run-ada-crdt` | Stable against CRDT library |

## Key constraints

- Ada 2012 / SPARK 2014
- Zero heap allocation (all arrays sized via `Max_*` constants)
- Fixed-size strings with explicit length fields
- No dependencies beyond GNAT runtime
