# AGENTS.md -- adacovex

## Project

**adacovex** -- zero-dependency Ada/SPARK 2014 CLI tool for coverage, proof analysis,
test-result parsing, DO-178C DAL compliance assessment, and interactive dashboards.

- **Repo**: https://github.com/bladeacer/adacovex
- **Language**: Ada 2012 / SPARK 2014 (GNAT, Alire)
- **SPARK target**: Platinum (AoRTE-free, all VCs proved)
- **Target project**: `../Ada_CRDT` (CRDT library -- 38 packages, ~135 subprograms)

## Architecture

```
src/
|-- adacovex.ads                    -- Version constant
|-- adacovex_main.adb               -- CLI entry point
|-- core/
|   |-- adacovex-types.ads/.adb     -- All domain types + conversion functions
|   `-- adacovex-config.ads/.adb    -- CLI argument parser
|-- parsers/
|   |-- adacovex-parsers-source.ads/.adb      -- Ada source scanner (procs/funcs/docstrings/HLR)
|   |-- adacovex-parsers-gnatprove.ads/.adb   -- GNATprove .out parser
|   |-- adacovex-parsers-tests.ads/.adb       -- AUnit test-result parser
|   `-- adacovex-parsers-do178c.ads/.adb      -- HLR/LLR markdown parser + source tag matcher
|-- compliance/
|   |-- adacovex-compliance-dal.ads/.adb       -- DAL-C assessment logic
|-- renderers/
|   |-- adacovex-renderers-ansi.ads/.adb       -- Terminal ANSI report
|   |-- adacovex-renderers-markdown.ads/.adb   -- VERIFICATION.md + TRACE.md
|   |-- adacovex-renderers-svg.ads/.adb        -- SVG badges (spark/tests/do178c)
|   `-- adacovex-renderers-html.ads/.adb       -- Web dashboard + JSON API
`-- server/
    |-- adacovex-server-http.ads/.adb          -- HTTP/1.1 server (GNAT.Sockets)
```

No dynamic allocation; all storage bounded at compile time.

## Makefile targets

| Target             | Description |
|--------------------|-------------|
| `build`            | `alr build` |
| `prove`            | `alr gnatprove` |
| `run-self`         | Run against adacovex itself (--target=.) |
| `run-ada-crdt`     | Run against ../Ada_CRDT, DAL-C |
| `run-self-serve`   | Run against adacovex with HTTP server on :8080 |
| `run-self-badges`  | Emit SVG badges + Markdown reports for adacovex |
| `clean`            | Remove bin/ obj/ docs/badges/ |

## CLI

```
adacovex [options]
  --target=PATH         Target project (default: ../Ada_CRDT)
  --manifest=PATH       Target manifest file override
  --dal=LEVEL           DAL A-E (default: C)
  --serve               Start HTTP dashboard on :8080 (or --port=N)
  --emit-svg=PATH       Write SVG badges to directory
  --emit-markdown=PATH  Write VERIFICATION.md + TRACE.md
  --verbose             Verbose output
  --help                Show help
```

## Docstring annotation spec

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
- Summary first, then tag lines, then declaration — no blank lines.
- Descriptions capitalized, end with period.
- Two spaces between tag name and description (alignment padding).

Placement is scanned correctly whether tags appear **before** or **after** the
subprogram declaration (before style is the canonical Ada convention).

## DAL-C assessment criteria

1. All HLRs traced in source tags (24/24)
2. No orphan tags
3. All tests passing (10290/0)
4. Minimum SPARK Level >= Bronze (target is Platinum)

## Unit tests

**None.** There are no AUnit tests for adacovex. All verification is done
via: (a) `make run-self` — docstring self-coverage must reach 100%,
(b) `make prove` — SPARK proof must reach Platinum (28/28 VCs),
(c) `make run-ada-crdt` — Ada_CRDT regression check must remain stable.

## Key constraints

- Ada 2012 / SPARK 2014
- Zero heap allocation (all arrays sized via `Max_*` constants)
- Fixed-size strings with explicit length fields
- No dependencies beyond GNAT runtime