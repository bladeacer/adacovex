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
source -- all 19 packages, 34 subprograms -- and must always show:
- 100% docstring coverage (strict mode on by default, cannot be disabled)
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
|   |-- adacovex_dal_tests.ads/.adb           -- DAL compliance tests (2)
|   |-- adacovex_types_tests.ads/.adb         -- Type conversion tests (21)
|   |-- adacovex_scanner_tests.ads/.adb       -- Source scanner tests (40)
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

---



### .adacovex patch directory

Located at `<target-project>/.adacovex/patches/<relative-path>`.

Used to add docstrings to third-party or vendored code that you cannot or do not
want to modify directly. Only active in strict mode (default).

**Why patches exist.** When `--relaxed` is not passed, strict mode scans ALL
directories (except the always-excluded ones). Vendored dependencies (e.g. a
copy of vt100 in `demo/deps/vt100/`) will be scanned and their undocumented
subprograms will count against docstring coverage. Patches let you overlay
docstring info without touching the original files.

#### Patch file format

A patch file is a valid Ada `.ads` file. It must contain only the subprogram
declarations you want to document, with docstrings in adacovex format preceding
each declaration.

```
--  Package-level comment (optional, not used by patch engine).
package VT100 is

   --  Summary of the procedure.
   --  @param Name  Description.
   procedure Some_Procedure (Name : in Some_Type);

   --  Another procedure with no params.
   procedure No_Param_Proc;

end VT100;
```

**Rules:**
1. File name must match the original `.ads` (e.g. `vt100.ads`).
2. Subprogram names must match the originals exactly.
3. Only subprograms with preceding docstrings (`--  ` lines) are merged.
4. Overloaded subprograms: provide one patch entry per overload; each patches the
   next undocumented original with the same name.
5. The scanner parses the patch and merges `Has_Docstring`, `Doc_Param_Ct`, and
   `Doc_Return` into the matching originals.

#### Patch file location

```
<target-project>/.adacovex/patches/<relative-path>
```

Where `<relative-path>` is the path from the target root to the `.ads` file.

Example: to patch `Ada_CRDT/demo/deps/vt100/vt100.ads`, create:
```
Ada_CRDT/.adacovex/patches/demo/deps/vt100/vt100.ads
```

**The `.adacovex` directory is always excluded from source scanning** (same as
`.git`, `obj`, `tests`, `config`).

---

## CLI reference

```
adacovex [options]
```

### Flag summary

| Flag | Default | Mode | Description |
|------|---------|------|-------------|
| `--target=PATH` | `../Ada_CRDT` | both | Target project root directory |
| `--manifest=PATH` | auto-detected | both | Override project manifest path |
| `--dal=LEVEL` | `C` | both | Target DAL level (A-E) |
| `--serve` | off | both | Start HTTP dashboard server |
| `--port=N` | `8080` | serve | Dashboard server port |
| `--emit-svg=PATH` | `<target>/docs/badges` | both | Output directory for SVG badges |
| `--no-svg` | off | both | Suppress SVG badge output |
| `--emit-markdown=PATH` | off | both | Output directory for Markdown reports |
| `--skip-dir=NAME` | (see below) | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode |
| `--verbose` | off | both | Verbose diagnostics |
| `--help` | - | both | Print usage and exit |

### Detailed flag behavior

#### `--target=PATH`
- **Purpose**: Specifies the Ada/SPARK project to analyze.
- **Default**: `../Ada_CRDT` (relative to CWD).
- **Resolution**: Relative paths are resolved against the current working
  directory to an absolute path.
- **Effect**: Determines the root directory for source scanning, manifest
  detection, SVG badge output, and patch file resolution.
- **Example**: `--target=.` scans the current directory.

#### `--manifest=PATH`
- **Purpose**: Override the project manifest file path.
- **Default**: `<target>/alire-dev.toml` if it exists, otherwise
  `<target>/alire.toml`.
- **Effect**: The manifest path is displayed in stderr output but is not used
  internally by adacovex itself (it is metadata for the user/AI agent).
- **Example**: `--manifest=/path/to/alire.toml`.

#### `--dal=LEVEL`
- **Purpose**: Target DO-178C DAL level for compliance assessment.
- **Values**: `A`, `B`, `C`, `D`, `E` (case-insensitive).
- **Default**: `C`.
- **Effect**: Determines the minimum SPARK proof level required and the specific
  DAL criteria checked. Higher DAL levels (A, B) require stricter proofs. See
  [DAL levels](#dal-levels) for per-level requirements.
- **Examples**: `--dal=A`, `--dal=e`.

#### `--serve`
- **Purpose**: Start the built-in HTTP/1.1 web dashboard.
- **Default**: Off (CLI mode).
- **Effect**: After scanning and assessment, starts a web server on the
  configured port serving:
  - `GET /` -- HTML dashboard with coverage, proof, test, and compliance cards
  - `GET /api/metrics` -- JSON object with key metrics
  - `GET /badge/spark.svg` -- SPARK level badge
  - `GET /badge/tests.svg` -- Test status badge
  - `GET /badge/do178c.svg` -- DO-178C status badge
- **Note**: The server blocks (does not return to shell) until interrupted.
- **Example**: `adacovex --target=. --serve --port=9090`.

#### `--port=N`
- **Purpose**: HTTP server port when `--serve` is used.
- **Default**: `8080`.
- **Effect**: Only relevant when `--serve` is passed. Must be a valid
  `Positive` integer.
- **Example**: `--port=3000`.

#### `--emit-svg=PATH`
- **Purpose**: Generate SVG badges and write them to a directory.
- **Default**: `<target>/docs/badges` (project-scoped).
- **Effect**: Creates four SVG files:
  - `spark.svg` -- SPARK assurance level (Stone through Platinum)
  - `tests.svg` -- Test pass/fail count
  - `do178c.svg` -- DO-178C DAL status (Achieved / Unmet)
  - `docs.svg` -- Docstring coverage percentage
- **Interaction**: `--no-svg` overrides and disables SVG output entirely.
- **Example**: `--emit-svg=/tmp/badges`.

#### `--no-svg`
- **Purpose**: Suppress SVG badge output.
- **Default**: Off (badges are emitted by default).
- **Effect**: Sets `Emit_SVG` to `False`. Overrides `--emit-svg` if both given.
- **Example**: `--no-svg`.

#### `--emit-markdown=PATH`
- **Purpose**: Generate Markdown compliance reports.
- **Default**: Off (no Markdown output).
- **Effect**: Creates two Markdown files:
  - `VERIFICATION.md` -- Full verification report with all metrics
  - `TRACE.md` -- HLR traceability matrix (source-to-requirement mapping)
- **Example**: `--emit-markdown=docs/compliance/`.

#### `--skip-dir=NAME`
- **Purpose**: Add a directory name to the scanner's skip list.
- **Default**: `demo,deps,examples` (only used in relaxed mode).
- **Effect**: Directories whose simple name matches an entry in the skip list
  are not recursed into during source scanning. Repeatable: each invocation
  appends to the list.
- **Example**: `--skip-dir=vendor --skip-dir=external`.
- **Important**: In strict mode (default), the skip list is always empty
  regardless of `--skip-dir` flags. Only `--relaxed` enables the skip list.

#### `--relaxed`
- **Purpose**: Disable strict mode.
- **Default**: Off (strict mode is on by default).
- **Effect**:
  - **Skip list is active**: the comma-separated skip list (default:
    `demo,deps,examples` plus any `--skip-dir` additions) is passed to the
    scanner.
  - **No patches applied**: `Apply_Patches` is NOT called.
  - Target use case: running against a project with vendored deps that you
    don't want to patch.
- **Strict mode (--relaxed off)**:
  - **Skip list is empty**: ALL directories except always-excluded ones are
    scanned. No user-provided `--skip-dir` values are used.
  - **Patches applied**: scans `<target>/.adacovex/patches/` for each package
    and merges docstring info.
  - Target use case: running against adacovex itself, where total coverage
    (including vendored code with patches) must be 100%.

#### `--verbose`
- **Purpose**: Enable verbose diagnostic output.
- **Default**: Off.
- **Effect**: Prints pipeline step diagnostics to stderr.

#### `--help`
- **Purpose**: Print usage information and exit.
- **Effect**: Prints all options, defaults, examples to stdout, then the
  program exits. No scanning or assessment is performed.

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (DAL achieved, all checks pass) |
| `1` | Compliance failure (DAL unmet, tests failing, etc.) |

### NO_COLOR support

adacovex respects the `NO_COLOR` environment variable. If `NO_COLOR` is set,
ANSI color codes are suppressed in terminal output. Color is enabled by default.

---

## Pipeline (execution order)

When adacovex runs, it executes these steps in sequence:

```
1. Parse CLI args           -> CLI_Config record
2. Determine ANSI color     -> NO_COLOR check
3. Scan source files        -> Package_Vectors.Vector (subprograms, HLR tags, docstrings)
4. Apply docstring patches  -> Merge .adacovex/patches/ (strict mode only)
5. Compute doc metrics      -> Docstring_Metrics (coverage %)
6. Parse GNATprove output   -> Proof_Summary (VC counts, SPARK level)
7. Parse test results       -> Test_Summary (pass/fail counts)
8. Assess DAL compliance    -> DAL_Assessment (Achieved / Unmet + reasons)
9. Render ANSI summary      -> stdout (terminal report)
10. Emit SVG badges          -> <svg-dir>/*.svg (if enabled)
11. Emit Markdown reports    -> <md-dir>/VERIFICATION.md + TRACE.md (if enabled)
12. Start HTTP server        -> :<port> (if --serve)
13. Set exit code            -> 0 if Achieved, 1 if Unmet
```

### Step details

#### 3. Source scanning (`Scan_Project`)
- Walks the target directory tree recursively.
- Always skips: `.git`, `obj`, `tests`, `config`, `.adacovex`.
- In relaxed mode: additionally skips directories matching the comma-separated
  skip list (default: `demo,deps,examples` plus user `--skip-dir` entries).
- For each `.ads` file found (excluding `b__*.ads` junk files):
  - Calls `Scan_Ads_File` which:
    1. Extracts package name from the filename.
    2. Scans lines for subprogram declarations (`procedure`, `function`,
       `generic procedure`, `generic function`).
    3. Extracts subprogram name (first identifier after keyword).
    4. Associates preceding docstring lines (`--  ` prefix) with the subprogram.
    5. Detects docstring tags (`@param`, `@return`, `@field`, `@formal`).
    6. Detects HLR tags (`-- HLR-XXXX`) and accumulates them.
  - A subprogram is counted as having a docstring if any preceding comment line
    uses the `--  ` (two dashes + two spaces) prefix, OR has `@param`/`@return`
    tags. A plain summary line (`--  Clears the screen.`) alone is sufficient.

#### 4. Patch application (`Apply_Patches`)
- Only runs in strict mode (default).
- For each scanned package, computes its relative path from the target root.
- Checks for `<target>/.adacovex/patches/<relative-path>`.
- If the patch file exists, it is scanned by `Scan_Ads_File` to extract
  subprogram info.
- For each subprogram in the patch that has `Has_Docstring = True`:
  - Matches by name against originals.
  - If the original does not already have `Has_Docstring`, merges the docstring
    metadata (`Has_Docstring`, `Doc_Param_Ct`, `Doc_Return`).
  - Handles overloaded subprograms: each patch entry patches the next
    undocumented original with the same name.

#### 8. DAL assessment (`Assess_DAL`)
- Evaluates four criteria (see [DAL levels](#dal-levels)):
  1. All HLRs traced in source tags.
  2. No orphan tags (every in-source HLR maps to a defined HLR).
  3. All tests passing (zero failures).
  4. Minimum SPARK proof level met (varies by DAL level).
- Populates `DAL_Assessment` with `Achieved` or `Unmet` plus failure reasons.

---

## Directory exclusions

### Always excluded (hardcoded, cannot be overridden)
| Directory | Reason |
|-----------|--------|
| `.git` | Version control metadata, binary blobs |
| `obj` | Build artifacts |
| `tests` | Test code (not production) |
| `config` | Generated configuration (e.g. Alire config) |
| `.adacovex` | Patch metadata (would create circular scan) |

These are excluded at ANY depth. E.g. `demo/config/` is skipped because the
directory simple name is `config`.

### Default skip list (relaxed mode only)
`demo,deps,examples`

These directories are skipped only when `--relaxed` is used. In strict mode,
they ARE scanned and their subprograms must be documented (either natively or
via `.adacovex/patches/`).

Use `--skip-dir=NAME` to add more directories to the skip list (relaxed mode
only).

---

## Docstring annotation spec

### Format

Every docstring line starts with `--  ` (two dashes + two spaces).

```
--  Summary sentence describing what the subprogram does.
--  @param Name  Description of the parameter.
--  @return Description of the return value.
procedure Do_Something (Name : in Some_Type) return Result_Type;
```

### Placement

Docstring may appear **before** (preferred) or **after** the subprogram
declaration. The scanner associates preceding docstring lines with the next
subprogram declaration. No blank lines between docstring and declaration.

```
--  Preferred: docstring before declaration.
--  @param X  First parameter.
procedure Foo (X : Integer);

procedure Bar (Y : Integer);
--  Also accepted: docstring after declaration.
--  @param Y  First parameter.
```

### Tags

| Tag | Syntax | Purpose | Sets Has_Docstring |
|-----|--------|---------|--------------------|
| `@param` | `--  @param Name  Description.` | Subprogram formal parameter | Yes |
| `@return` | `--  @return Description.` | Function return value | Yes |
| `@field` | `--  @field Description.` | Record component | Yes |
| `@formal` | `--  @formal Name  Description.` | Generic formal parameter | No |

### Rules
- Descriptions are capitalized and end with a period.
- Two spaces between tag name and description text (alignment padding).
- A plain `--  Summary.` line (no tag) is sufficient to mark a subprogram as
  documented. Tags are not required for no-param procedures.

### HLR traceability tags

HLR (High-Level Requirement) tags use the format `-- HLR-XXXX` on their own
comment line:

```
--  HLR-SCAN: Source scanning
```

Multiple HLR tags can appear on one line:
```
--  HLR-ARCH: Version constant  HLR-ARCH: Package hierarchy
```

---

## DAL levels

### Per-level requirements

| DAL Level | Min SPARK Level | Tests must pass | HLRs traced | No orphans |
|-----------|-----------------|-----------------|-------------|------------|
| A | Platinum | Yes | Yes | Yes |
| B | Gold | Yes | Yes | Yes |
| C | Bronze | Yes | Yes | Yes |
| D | Bronze | No (0 required) | No | No |
| E | Stone | No (0 required) | No | No |

DAL-C is the default. The DAL assessment evaluates all four criteria and reports
specific failure reasons when the assessment is `Unmet`.

### DAL-C criteria (default)

1. All HLRs defined in `<target>/docs/compliance/HLR.md` must be traced by
   at least one `-- HLR-XXXX` tag in source `.ads` files.
2. Every `-- HLR-XXXX` tag in source must map to a defined HLR (no orphans).
3. All tests passing (zero failures in `<target>/test_result.md`).
4. Minimum SPARK level `>= Bronze` (flow analysis passing).

---

## Makefile targets

| Target             | Description |
|--------------------|-------------|
| `build`            | `alr build` (builds adacovex_main + test_runner) |
| `test`             | Build + run test_runner |
| `prove`            | `alr gnatprove` (uses alire-dev.toml) |
| `doc` / `api-docs` | Generate API docs via gnatdoc + rst2md |
| `fmt`              | Format Ada sources with gnatformat |
| `run-self`         | Run against adacovex itself (`--target=.`) |
| `run-ada-crdt`     | Run against `../Ada_CRDT`, DAL-C (strict mode) |
| `bump-version`     | Bump version across alire.toml, alire-dev.toml, adacovex.ads, changelog (`VERSION=x.y.z`) |
| `ascii-check`      | Verify all source files are pure ASCII |
| `dev-setup`        | Copy alire-dev.toml over alire.toml |
| `prod-setup`       | Restore clean publishing alire.toml |
| `clean`            | Remove bin/ obj/ docs/badges/ |
| `help`             | Print available targets |

---

## Workflows

### Run adacovex on any Ada project

```bash
# Basic assessment
adacovex --target=/path/to/project

# Without SVG badges
adacovex --target=/path/to/project --no-svg

# With Markdown reports
adacovex --target=/path/to/project --emit-markdown=docs/reports

# With web dashboard
adacovex --target=/path/to/project --serve

# Relaxed mode (skip demo/deps/examples, no patches)
adacovex --target=/path/to/project --relaxed

# Custom skip list
adacovex --target=/path/to/project --relaxed --skip-dir=vendor --skip-dir=external

# DAL-A assessment (requires Platinum SPARK level)
adacovex --target=/path/to/project --dal=A
```

### Requirements for running adacovex against a project

The target project must have:

1. **Ada source files** (`.ads`) -- scanned for subprograms and docstrings.
2. **GNATprove output** -- either `gnatprove.out` in the target root or
   `<target>/obj/gnatprove/gnatprove.out`. Adacovex parses the proof summary
   to determine the SPARK level.
3. **Test results** -- a `test_result.md` file in the target root containing
   a Markdown table with `Tests` and `Status` columns (PASS/FAIL).
4. **HLR document** (for DAL assessment) -- `<target>/docs/compliance/HLR.md`
   defining the High-Level Requirements.

Projects that do not have GNATprove output or test results will show "N/A"
for those metrics. DAL compliance checks that depend on missing data will
report as `Unmet` with appropriate failure reasons.

### Creating patch files for vendored code

1. Run adacovex in strict mode to identify undocumented subprograms:
   ```
   adacovex --target=/path/to/project
   ```
2. Find the undocumented packages and subprograms in the report.
3. Create `<target>/.adacovex/patches/<relative-path>` with matching
   subprogram declarations and docstrings.
4. Re-run to verify 100% coverage:
   ```
   adacovex --target=/path/to/project
   ```

---

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 152/152 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | 28/28 VCs Platinum |
| Ada_CRDT regression | `make run-ada-crdt` | Stable against CRDT library (strict mode) |

See [docs/changelogs/adacovex-1.0.0.md](docs/changelogs/adacovex-1.0.0.md) for full release notes.

---

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

---

## Known quirks

- `(null record)` typed parameters are counted as parameters by the scanner.
- Overloaded subprograms in patch files: each overload requires a separate
  patch entry. The first patch entry for a name patches the first undocumented
  original, the second patches the second, etc.
- `Is_Subprogram_Decl` matches `procedure`, `function`, `generic procedure`,
  and `generic function` only (not `type`, `package`, `task`, etc.).
- Docstring detection: any `--  ` (dash dash space space) line before a
  subprogram counts as a docstring. Other comment formats (`-- ` with one
  space, `---` with three dashes) do not.
- `--verbose` prints pipeline step diagnostics to stderr.
- Relative `--target=PATH` is resolved against CWD, so behavior depends on
  where adacovex is invoked.

---

## Key constraints

- Ada 2012 / SPARK 2014
- **Package/subprogram collections**: `Ada.Containers.Vectors`
  (heap, `Natural'Last` ~ 2.1B). No `Max_Packages` / `Max_Subprogs` limits.
- **HLR tags, test metrics, DAL failures**: also `Ada.Containers.Vectors`
  (unbounded). No `Max_Hlrs`, `Max_Categories`, `Max_Failures` limits.
- **Fixed-size string buffers** (`Max_Path`, `Max_Line`, etc.) remain bounded.
- No external dependencies beyond GNAT runtime (`Ada.Containers` is
  part of the standard Ada runtime library).

## Bounded resources

The following compile-time constants in `src/core/adacovex-types.ads`
govern fixed-size string/VC buffers (package and subprogram vectors
are unbounded via `Ada.Containers.Vectors`):

| Constant | Value | Notes |
|----------|-------|-------|
| `Max_Line` | 8192 | Source line length (long lines drained silently) |
| `Max_Path` | 4096 | File path length (matches `PATH_MAX`) |
| `Max_Desc_Str` | 128 | Subprogram name / description|
| `Max_Filename` | 128 | Package name from filename |
| `Max_Id_Str` | 64 | HLR/LLR tag ID length |

Package and subprogram collections grow dynamically via `Ada.Containers.Vectors`
(heap allocation, up to `Natural'Last` ~ 2.1B). The fixed-size constants above
apply only to individual line/path/description buffers.
