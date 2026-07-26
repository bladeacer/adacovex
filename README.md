# adacovex

**Zero-dependency Ada/SPARK CLI tool** for coverage analysis, proof verification,
test-result parsing, DO-178C DAL compliance assessment, and interactive dashboards.

[![SPARK](docs/badges/spark.svg)](https://github.com/bladeacer/adacovex)
[![Tests](docs/badges/tests.svg)](https://github.com/bladeacer/adacovex)
[![DO-178C](docs/badges/do178c.svg)](https://github.com/bladeacer/adacovex)

## Features

- **Source scanning** -- walks `.ads` files, extracts subprogram declarations, docstring
  annotations (`@param`, `@return`, `@field`, `@formal`), and HLR traceability tags
- **Proof analysis** -- parses GNATprove `gnatprove.out` summaries per check category
  (flow, run-time, assertions, contracts, termination)
- **Test parsing** -- reads AUnit test-result markdown or stdout for pass/fail counts
- **DAL compliance** -- assesses DO-178C DAL A-E criteria (HLR coverage, orphan tags,
  test status, minimum SPARK proof level)
- **Multiple outputs**:
  - ANSI terminal report
  - SVG badges (Shields.io style) -- SPARK level, test status, DO-178C status
  - Markdown reports -- `VERIFICATION.md` + `TRACE.md`
  - HTML dashboard + JSON API via built-in HTTP server
- **Zero dynamic allocation** -- all storage is bounded at compile time

## Quick start

```bash
# Default run against ../Ada_CRDT at DAL-C
make run-self

# Explicit target
./bin/adacovex --target=../Ada_CRDT --dal=C

# Single-argument form
./bin/adacovex --target=../Ada_CRDT --dal=C
```

## CLI reference

```
adacovex v0.1.0

Usage:
  adacovex [options]

Options:
  --target=PATH         Target project path (default: ../Ada_CRDT)
  --target PATH         Alternative form

  --dal=LEVEL           Target DAL level: A, B, C, D, E (default: C)
  --dal LEVEL           Alternative form

  --serve               Start HTTP dashboard server on :8080
  --port=N              Server port (default: 8080)

  --emit-svg=PATH       Write SVG badges to directory
  --emit-svg PATH       Alternative form
  --emit-markdown=PATH  Write VERIFICATION.md + TRACE.md to directory
  --emit-markdown PATH  Alternative form

  --verbose             Verbose output
  --help                Show this help
```

## Examples

### Basic usage

```bash
# Scan target project and print ANSI report
adacovex --target=../Ada_CRDT

# Assess at DAL-C
adacovex --target=../Ada_CRDT --dal=C

# Use the long form
adacovex --target ../Ada_CRDT --dal C
```

### Generate badges and reports

```bash
# Write SVG badges to docs/badges/
adacovex --target=../Ada_CRDT --dal=C --emit-svg=docs/badges/

# Write Markdown compliance reports to docs/compliance/
adacovex --target=../Ada_CRDT --dal=C --emit-markdown=docs/compliance/

# Both at once
adacovex --target=../Ada_CRDT --dal=C \
  --emit-svg=docs/badges/ \
  --emit-markdown=docs/compliance/
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

| Target             | Description                                      |
|--------------------|--------------------------------------------------|
| `build`            | `alr build`                                      |
| `prove`            | `alr gnatprove` (requires GNATprove installed)   |
| `fmt`              | Format all Ada sources with `gnatpp`             |
| `lint`             | Check for warnings in build output               |
| `api-docs`         | Generate Ada API docs with `gnatdoc`             |
| `run-self`         | Run against `../Ada_CRDT`, DAL-C                 |
| `run-self-serve`   | Run with HTTP server on `:8080`                  |
| `run-self-badges`  | Emit SVG badges + Markdown reports               |
| `changelog`        | Generate changelog from git log                  |
| `clean`            | Remove `bin/`, `obj/`, `docs/badges/`            |

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

## Requirements

- **Alire** >= 2.0 (for building)
- **GNAT** Ada compiler (toolchain provided by `alr setup`)
- **GNATprove** (optional, for proof targets)
- **gnatpp** (optional, for `make fmt`)
- **gnatdoc** (optional, for `make api-docs`)

## License

Apache-2.0 -- see [LICENSE](LICENSE) for details.
