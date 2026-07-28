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
- **Zero dynamic allocation** -- all storage is bounded at compile time

## Quick start

```bash
# Run against adacovex itself
make run-self

# Run against Ada_CRDT (default target)
make run-ada-crdt

# Explicit target at DAL-C
./bin/adacovex --target=../Ada_CRDT --dal=C
```

## CLI reference

```
adacovex v0.1.0

Usage: adacovex [options]

Options:
  --target=PATH         Target project path (default: ../Ada_CRDT)
  --manifest=PATH       Target project manifest override
  --dal=LEVEL           DAL level: A | B | C | D | E (default: C)
  --serve               Start HTTP dashboard on :8080
  --port=N              HTTP server port (default: 8080)
  --emit-svg=PATH       Write SVG badges (default: docs/badges)
  --no-svg              Suppress automatic SVG output
  --emit-markdown=PATH  Write VERIFICATION.md + TRACE.md
  --verbose             Verbose diagnostics
  --help                Show this message
```

## Examples

### Basic usage

```bash
# Self-assessment: scan adacovex itself (SVGs written to docs/badges/)
adacovex --target=.

# Assess a CRDT library at DAL-C
adacovex --target=../Ada_CRDT --dal=C

# Without SVG output
adacovex --target=../Ada_CRDT --no-svg

# With explicit manifest
adacovex --target=. --manifest=./alire-dev.toml
```

### Additional outputs

```bash
# Write SVG badges to a custom directory (default: docs/badges/)
adacovex --target=../Ada_CRDT --emit-svg=docs/badges/

# Write Markdown compliance reports
adacovex --target=../Ada_CRDT --emit-markdown=docs/compliance/

# Web dashboard
adacovex --target=../Ada_CRDT --serve
```

### Start the web dashboard

```bash
# Default port 8080
adacovex --target=../Ada_CRDT --serve

# Custom port
adacovex --target=../Ada_CRDT --serve --port=9090
```

Then open http://localhost:8080/ in a browser:
- Dashboard: `GET /` -- full HTML page with coverage, proof, test, and compliance cards
- API: `GET /api/metrics` -- JSON object with key metrics
- Badges: `GET /badge/spark.svg`, `/badge/tests.svg`, `/badge/do178c.svg`

### API response

```json
GET /api/metrics
{
    "spark_level": "Silver",
    "total_vcs": 273,
    "proved_vcs": 47,
    "tests_passed": 10290,
    "tests_failed": 0,
    "doc_coverage": 57,
    "dal_status": "Achieved"
}
```

## Makefile targets

| Target     | Description                                      |
|------------|--------------------------------------------------|
| `build`    | `alr build` (adacovex_main + test_runner)        |
| `test`     | Build and run native test suite                  |
| `prove`    | `alr gnatprove` (auto-swaps alire-dev.toml)      |
| `fmt`      | Format Ada sources with `gnatformat`             |
| `doc`      | Generate API docs via gnatdoc + rst2md           |
| `run-self` | Run against adacovex itself (`--target=.`)        |
| `run-ada-crdt` | Run against `../Ada_CRDT` (default target)   |
| `clean`    | Remove `bin/`, `obj/`, generated reports         |

## Project structure

```
src/
|-- adacovex.ads
|-- adacovex_main.adb
|-- core/
|   |-- adacovex-types.ads/.adb
|   `-- adacovex-config.ads/.adb
|-- parsers/
|   |-- adacovex-parsers-source.ads/.adb
|   |-- adacovex-parsers-gnatprove.ads/.adb
|   |-- adacovex-parsers-tests.ads/.adb
|   `-- adacovex-parsers-do178c.ads/.adb
|-- tests/
|   |-- adacovex-test_support.ads/.adb    -- Native test Runner type
|   |-- adacovex_dal_tests.ads/.adb       -- DAL compliance tests
|   |-- adacovex_types_tests.ads/.adb     -- Type conversion tests
|   `-- test_runner.adb                   -- Test suite entry point
|-- compliance/
|   |-- adacovex-compliance-dal.ads/.adb
|-- renderers/
|   |-- adacovex-renderers-ansi.ads/.adb
|   |-- adacovex-renderers-markdown.ads/.adb
|   |-- adacovex-renderers-svg.ads/.adb
|   `-- adacovex-renderers-html.ads/.adb
`-- server/
    |-- adacovex-server-http.ads/.adb
```

## DO-178C / DAL-C

adacovex can assess a target project against DO-178C DAL-C criteria:

1. **All HLRs traced** -- each HLR-XXXX tag in `HLR.md` must appear as `-- HLR-XXXX`
   in at least one `.ads` source file  
2. **No orphan tags** -- every in-source HLR tag must correspond to a defined HLR  
3. **All tests passing** -- the target project must report 0 failures  
4. **Minimum SPARK Level >= Bronze** -- the target must pass flow analysis

When running against itself (`adacovex --target=.`), the tool verifies its own
compliance documentation.

## Documentation

| Reference | Description |
|-----------|-------------|
| [Docstring Spec](docs/api-docs/adacovex-docstring-spec.md) | Annotation format, placement, conventions |
| [Test Format](docs/api-docs/adacovex-test-format.md) | Supported test-result output format |
| [SPARK Levels](docs/api-docs/adacovex-spark-levels.md) | Assurance level objectives (Stone--Platinum) |
| [DAL Levels](docs/api-docs/adacovex-dal-levels.md) | DO-178C DAL A--E criteria |
| [API Reference](docs/api-docs/index.md) | Auto-generated package API docs (`make doc`) |
| [Changelog](docs/changelogs/index.md) | Release history

## Test suite

```bash
make test
```

Test source: `src/tests/`. Uses a native zero-dependency `Runner` type
(`Adacovex.Test_Support`, modeled after Ada_CRDT's `CRDT.Test_Support`).
Results are written to `docs/test_result.md` and printed to stdout.

## Credits

Technology Stack:

- [Ada / SPARK 2014](https://www.adacore.com/languages/spark): (AdaCore) language and dialect of choice
- [gnatprove](https://docs.adacore.com/spark2014-docs/html/ug/index.html): (AdaCore) formal verification
- [Alire](https://alire.ada.dev): (AdaCore) Ada/SPARK package manager
- [gnatformat](https://github.com/AdaCore/gnatformat): (AdaCore) code formatter
- [gnatdoc](https://github.com/AdaCore/gnatdoc): (AdaCore) API documentation generator
- [GNAT.Sockets](https://www.adacore.com): (AdaCore) networking library

Test framework inspired by:

- [Ada_CRDT](https://github.com/bladeacer/Ada_CRDT): Native zero-dependency test
  runner with `Runner.Check` pattern

AUnit test-output parsing supported for compatibility with projects using
the [AUnit](https://github.com/AdaCore/aunit) test framework.

## Requirements

- **Alire** >= 2.0 (for building)
- **GNAT** Ada compiler (toolchain provided by `alr setup`)
- **GNATprove** (optional, for proof targets)
- **gnatpp** (optional, for `make fmt`)
- **gnatdoc** (optional, for `make api-docs`)

## License

Apache-2.0 -- see [LICENSE](LICENSE) for details.
