# AGENTS.md -- adacovex

## Project

**adacovex** -- zero-dependency Ada/SPARK CLI tool for coverage, proof analysis,
test-result parsing, DO-178C DAL compliance assessment, and interactive dashboards.

- **Repo**: https://github.com/bladeacer/adacovex
- **Language**: Ada 2012 / SPARK 2014 (GNAT, Alire)
- **Zero library dependency**: uses only GNAT runtime (GNAT.Sockets, Ada tasking, standard libs);
  no declared tool dependency either -- gnatprove is resolved at run time by the
  `prove` subcommand (per-project manifest, `$PATH`, `~/.adacovex/toolchain/`, or
  download) and lives only in the dev manifest for the local make targets
- **SPARK target**: Platinum (AoRTE-free, all VCs proved) on adacovex itself

## Dogfood target

adacovex was designed to audit the Ada_CRDT library at `../Ada_CRDT` (26 packages,
~219 subprograms). Running `make run-ada-crdt` runs the full pipeline against it.
The `--target=PATH` option can point at any Ada/SPARK project.

Self-assessment (`make run-self`, default target: cwd) verifies adacovex against its own
source -- 28 packages, 86 subprograms -- and must always show:
- 100% docstring coverage (strict mode on by default, cannot be disabled)
- Platinum SPARK level (all VCs proved)
- 336/336 native tests passing
- DAL-C Achieved

## Architecture

<!-- agents-tree:begin -->
```
src/
|-- adacovex.ads                              -- Version constant
|-- adacovex_main.adb                         -- CLI entry point (builds as bin/adacovex; covex alias)
|-- compliance/
|   |-- adacovex-compliance.ads               -- Parent package for DO-178C compliance assessment
|   `-- adacovex-compliance-dal.ads/.adb      -- DAL level assessment logic (DAL-A..E criteria)
|-- core/
|   |-- adacovex-cache.ads/.adb               -- On-disk result cache (content-hashed per-file, oldest-first eviction, size policy)
|   |-- adacovex-config.ads/.adb              -- CLI argument parser (prove mode, --no-sbom, --sbom-format)
|   |-- adacovex-core.ads                     -- Parent package for core data types and configuration
|   |-- adacovex-cpus.ads/.adb                -- Host CPU/CI detection + GNATprove parallelism resolution
|   |-- adacovex-diff.ads/.adb                -- Differential assessment (--compare-base / --coverage-delta)
|   |-- adacovex-prove.ads/.adb               -- GNATprove runner for the `prove` subcommand (alire-first toolchain resolution)
|   `-- adacovex-types.ads/.adb               -- All domain types + conversion functions
|-- ir/
|   |-- adacovex-ir_bounds.ads/.adb           -- Bounds-verification fixture (synthesized lowered types, gnatprove-proved)
|   |-- adacovex-ir_synthesiser.ads/.adb      -- Future-use IR synthesiser (foreign type-name lowering to bounded Ada)
|   `-- adacovex-target_profiles.ads/.adb     -- Bounded IR scalar types (IR_Int8..IR_Int64 / IR_UInt8..IR_UInt64) + host/target config
|-- parsers/
|   |-- adacovex-parsers.ads/.adb             -- Parent package for all input-file parsers
|   |-- adacovex-parsers-do178c.ads/.adb      -- HLR/LLR markdown parser + source tag matcher
|   |-- adacovex-parsers-gnatprove.ads/.adb   -- GNATprove .out parser
|   |-- adacovex-parsers-manifest.ads/.adb    -- Alire manifest / alire.lock / .gpr dep graph
|   |-- adacovex-parsers-source.ads/.adb      -- Ada source scanner (procs/funcs/docstrings/HLR)
|   `-- adacovex-parsers-tests.ads/.adb       -- AUnit test-result parser
|-- renderers/
|   |-- adacovex-renderers.ads                -- Parent package for all output renderers
|   |-- adacovex-renderers-ansi.ads/.adb      -- Terminal ANSI report (NO_COLOR aware)
|   |-- adacovex-renderers-html.ads/.adb      -- Web dashboard + JSON API
|   |-- adacovex-renderers-markdown.ads/.adb  -- VERIFICATION.md + TRACE.md
|   |-- adacovex-renderers-sbom.ads/.adb      -- CycloneDX 1.5 / SPDX 2.3 / Markdown SBOM generator
|   `-- adacovex-renderers-svg.ads/.adb       -- SVG badges (spark/tests/do178c/docs)
|-- server/
|   |-- adacovex-server.ads                   -- Parent package for the HTTP server subsystem
|   |-- adacovex-server-http.ads/.adb         -- HTTP/1.1 server (4-worker task pool)
|   `-- adacovex-server-router.ads            -- Parent package for HTTP request routing (future expansion)
`-- tests/
    |-- adacovex-test_support.ads/.adb        -- Native test Runner type
    |-- adacovex_config_tests.ads/.adb        -- CLI config tests (19)
    |-- adacovex_dal_tests.ads/.adb           -- DAL compliance tests (7)
    |-- adacovex_ir_tests.ads/.adb            -- IR synthesis tests (27)
    |-- adacovex_prove_tests.ads/.adb         -- GNATprove parser tests (52)
    |-- adacovex_renderer_svg_tests.ads/.adb  -- SVG renderer tests (30)
    |-- adacovex_sbom_tests.ads/.adb          -- SBOM / manifest graph tests (53)
    |-- adacovex_scanner_tests.ads/.adb       -- Source scanner tests (79)
    |-- adacovex_testparser_tests.ads/.adb    -- Test-result parser tests (43)
    |-- adacovex_types_tests.ads/.adb         -- Type conversion tests (26)
    `-- test_runner.adb                       -- Test suite entry point (336 tests)
```
<!-- agents-tree:end -->


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
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
```

### Flag summary

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
| `--skip-dir=NAME` | (see below) | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode |
| `--compare-base=REF` | off | both | Differential mode vs a git base ref |
| `--coverage-delta=REF` | off | both | Docstring-coverage gate vs a git base ref |
| `--cache` | on | both | Enable on-disk result caching |
| `--no-cache` | off | both | Disable result caching (always re-scan/re-parse/re-prove) |
| `--cache-dir=PATH` | `~/.adacovex/cache/<ver>` | both | Cache directory for analysis results |
| `--cache-max=N` | `4096` | both | Max cache entries before oldest-first eviction |
| `--verbose` | off | both | Verbose diagnostics |
| `--help` | - | both | Print usage and exit |

### Detailed flag behavior

#### `--target=PATH`
- **Purpose**: Specifies the Ada/SPARK project to analyze.
- **Default**: current working directory.
- **Resolution**: Relative paths are resolved against the current working
  directory to an absolute path.
- **Effect**: Determines the root directory for source scanning, manifest
  detection, SVG badge output, and patch file resolution.
- **Example**: `--target=.` scans the current directory.

#### `--manifest=PATH`
- **Purpose**: Override the project manifest file path.
- **Default**: `<target>/alire.toml` if it exists, otherwise
  `<target>/alire-dev.toml`.
- **Effect**: The manifest path is displayed in stderr output and is used by
  `adacovex sbom` to resolve the root project metadata for the dependency
  graph.
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

#### `--compare-base=REF`
- **Purpose**: Run in differential mode: assess a git base revision and compare
  it against the current working tree.
- **Default**: Off (normal single-target assessment).
- **Prerequisite**: The `--target` directory must be a git repository, and the
  `git` executable must be on `PATH`.
- **Effect**: Creates a temporary git worktree at `/tmp/adacovex-diff-<pid>`,
  runs the full assessment (scan, patches, doc metrics, GNATprove, tests, DAL)
  on the base revision and the current tree, then prints a side-by-side table
  (packages, subprograms, docstring %, HLR traced, orphan tags, SPARK level,
  VCs proved, tests, DAL status).
- **Exit code**: `0` if no regressions AND current DAL is Achieved; `1`
  otherwise (regression, or current DAL Unmet).
- **Missing artifacts**: If the base revision does not commit `gnatprove.out`
  or a test-result summary (e.g. `test_result.md`), those rows report `N/A`
  and are not compared.
- **Example**: `adacovex --target=. --compare-base=HEAD`.

#### `--verbose`
- **Purpose**: Enable verbose diagnostic output.
- **Default**: Off.
- **Effect**: Prints pipeline step diagnostics to stderr.

#### `--coverage-delta=REF`
- **Purpose**: Lightweight docstring-coverage gate for PR-style CI checks.
- **Default**: Off (normal single-target assessment).
- **Prerequisite**: The `--target` directory must be a git repository, and the
  `git` executable must be on `PATH`. Mutually exclusive with
  `--compare-base`.
- **Effect**: Creates a temporary git worktree, scans sources + applies
  patches + computes docstring metrics on both the base ref and the current
  tree (no GNATprove/tests/DAL, so it works even when the base does not commit
  build artifacts), prints a compact coverage table and a machine-parseable
  `coverage_delta:` line, and cleans up the worktree.
- **Exit code**: `0` if current docstring coverage is `>=` the base (or the
  base has no sources); `1` if coverage regressed.
- **Example**: `adacovex --target=. --coverage-delta=origin/main`.
- **Release usage**: `make release` runs the same gate against the last release
  tag (e.g. `--coverage-delta=v1.1.0`) and aborts if docstring coverage
  regressed between releases.

#### Result caching (`--cache` / `--no-cache` / `--cache-dir` / `--cache-max`)
- **Purpose**: Persist parsed analysis results between runs so unchanged inputs
  are not re-scanned / re-parsed / re-proved.
- **Keys**: Each cache entry is `"scan:" | "prove:" | "tests:" + SHA-256` of the
  artifact it was derived from (a `.ads` file's bytes, `gnatprove.out`, or the
  test-result file). Re-parsing a byte-identical artifact yields a cache hit
  regardless of the target directory or command line used.
- **Schema namespace**: The default cache root is
  `~/.adacovex/cache/<version>/<Cache_Schema>`. `Cache_Schema` (in
  `src/core/adacovex-cache.ads`) must be bumped whenever the serialized layout
  of a cached record or the scanner/parser semantics change, so blobs written
  by an incompatible build are never served as if valid.
- **Eviction**: `Put_Cached` calls `Evict_If_Needed(--cache-max)` (default
  4096), deleting oldest-first by modification time. `Eviction_Count` tracks
  removals and is reported in the ANSI cache line.
- **Overflow safety**: `Serialize` returns an empty blob when a package would
  exceed `Max_Cache_Blob`; callers skip storing it and `Deserialize` rejects
  empty/oversized input, so truncated data can never be served as a hit.
- **`--target` normalization**: `--target` is normalized (`.`/`..` collapsed to
  a canonical absolute path) before scanning. This keeps the `File_Path`
  values stored in cached `Package_Info` consistent across invocations that
  spell the same directory differently (e.g. `--target=../Ada_CRDT` vs
  `--target=.`), which matters because docstring patches are matched by the
  package's path relative to the target root.
- **CI**: The GitHub action persists `~/.adacovex/cache` between workflow runs
  (`result-cache` input, default true), so incremental branches get mostly
  cache hits; content-addressed keys make restoring a stale cache always safe.

#### `--help`
- **Purpose**: Print usage information and exit.
- **Effect**: Prints all options, defaults, examples to stdout, then the
  program exits. No scanning or assessment is performed.

### The `sbom` subcommand (`adacovex sbom`)

- **Purpose**: Generate a proof-aware software bill of materials for the target
  project.
- **Usage**: `adacovex sbom [--format=FMT] [--out=PATH]`.
- **Effect**: Scans sources, parses GNATprove output and test results, and
  assesses DAL first, then resolves the dependency graph from the Alire
  manifest (`alire.toml` / `alire-dev.toml`), `alire/alire.lock`, and the root
  `.gpr` `with` clauses (via `Adacovex.Parsers.Manifest.Build_Dependency_Graph`)
  and writes the SBOM via `Adacovex.Renderers.SBOM.Write_SBOM`.
- **Properties**: Only the root component -- the project adacovex actually
  assessed -- carries `adacovex:proof_level` (`Gold`/`Platinum`) and
  `adacovex:dal_target` (`DAL-A`..`DAL-D`; empty for `DAL-E`). Dependency
  components report `adacovex:proof_level = "Not proved"` (adacovex only
  proves the target itself, never third-party dependencies). Encoded as
  `attributionTexts` in SPDX.
- **Default output**: `<target>/sbom.json` for `cyclonedx-json`,
  `<target>/sbom.spdx.json` for `spdx-json`. The containing directory is
  created automatically.
- **Determinism**: The `metadata.timestamp` / `creationInfo.created` field
  honors the `SOURCE_DATE_EPOCH` environment variable (reproducible-builds
  convention); when set to a Unix epoch second count the timestamp is derived
  from it in UTC via pure integer math, so SBOM output is byte-for-byte
  deterministic across runs and machines. To tie it to a specific git commit,
  run `export SOURCE_DATE_EPOCH=$(git -C <target> log -1 --format=%ct)` before
  adacovex. The `make` targets (`run-self`, `run-ada-crdt`, `prove`,
  `release`, and Ada_CRDT's `prove`/`badges`) already set it from the target's
  git `HEAD` commit time.
- **Exclusivity**: Mutually exclusive with `--compare-base` and
  `--coverage-delta`.
- **Exit code**: `0` when the SBOM was written, `1` otherwise.
- **Examples**: `adacovex sbom --format=cyclonedx-json --target=. --dal=C`,
  `adacovex sbom --format=spdx-json --out=sbom.spdx.json`.

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
0. Parse CLI args           -> CLI_Config record (prove / sbom / diff / normal)
1. Determine ANSI color     -> NO_COLOR check
2. (prove mode) Run GNATprove -> fresh obj/gnatprove/gnatprove.out
3. Scan source files        -> Package_Vectors.Vector (subprograms, HLR tags, docstrings)
4. Apply docstring patches  -> Merge .adacovex/patches/ (strict mode only)
5. Compute doc metrics      -> Docstring_Metrics (coverage %)
6. Parse GNATprove output   -> Proof_Summary (VC counts, SPARK level)
7. Parse test results       -> Test_Summary (pass/fail counts)
8. Assess DAL compliance    -> DAL_Assessment (Achieved / Unmet + reasons)
9. Render ANSI summary      -> stdout (terminal report)
10. Emit SVG badges          -> <svg-dir>/*.svg (if enabled)
11. Emit Markdown reports    -> <md-dir>/VERIFICATION.md + TRACE.md (if enabled)
12. Emit automatic SBOM      -> <target>/sbom.json | sbom.spdx.json | docs/compliance/SBOM.md (unless --no-sbom)
13. Start HTTP server        -> :<port> (if --serve)
14. Set exit code            -> 0 if Achieved, 1 if Unmet
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
    4. Associates preceding docstring lines (`--  `, `-- `, or `--<TAB>`
       prefix) with the subprogram.
    5. Detects docstring tags (`@param`/`@parameter`, `@return`/`@returns`,
       `@field`, `@formal`, `@brief`, `@summary`).
    6. Detects HLR tags (`-- HLR-XXXX`) and accumulates them.
  - A subprogram is counted as having a docstring if any preceding comment line
    uses a recognized prefix (`--  `, `-- `, or `--<TAB>`), OR has
    `@param`/`@return`/`@brief`/`@summary` tags. A plain summary line
    (`--  Clears the screen.`) alone is sufficient.

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

Every docstring line starts with `--  ` (two dashes + two spaces). The
single-space (`-- `) and tab-separated (`--<TAB>`) comment styles are also
recognized as docstrings.

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
| `@parameter` | `--  @parameter Name  Description.` | Alias of `@param` | Yes |
| `@return` | `--  @return Description.` | Function return value | Yes |
| `@returns` | `--  @returns Description.` | Alias of `@return` | Yes |
| `@field` | `--  @field Description.` | Record component | Yes |
| `@formal` | `--  @formal Name  Description.` | Generic formal parameter | No |
| `@brief` | `--  @brief Summary.` | Short summary | Yes |
| `@summary` | `--  @summary Description.` | Summary | Yes |

### Google / Sphinx styles

The scanner also recognizes the two most common non-Ada docstring conventions,
so the same subprogram can be documented with `Args:` / `Returns:` blocks
(Google style) or `:param:` / `:returns:` fields (Sphinx style):

```
--  Do something useful.
--
--  Args:
--    X:  The first argument.
--
--  Returns:
--    The result.
function Foo (X : Integer) return Integer;

--  Do something else.
--
--  :param X: The argument.
--  :returns: The result.
function Bar (X : Integer) return Integer;
```

- A `Args:` / `Args: ...` header opens a block; deeper-indented following
  comment lines count as parameters.
- A `Returns:` header (or `@return`) marks the return-value description.
- Sphinx `:param Name:`, `:parameter Name:`, `:type Name:`, `:return:`,
  `:returns:`, and `:rtype:` fields are all recognized.

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

Per-level criteria follow `docs/HLR.md` (HLR-DAL-A through HLR-DAL-E) and the
`Min_SPARK_For` table in `src/compliance/adacovex-compliance-dal.adb`.

| DAL Level | Min SPARK Level | Tests must pass | HLRs traced | No orphans |
|-----------|-----------------|-----------------|-------------|------------|
| A | Gold | Yes | Yes | Yes |
| B | Silver | Yes | Yes | Yes |
| C | Bronze | Yes | Yes | Yes |
| D | None (Stone) | Yes | Yes | Yes |
| E | None (Stone) | No | Yes | Yes |

DAL-C is the default. The DAL assessment evaluates all four criteria and reports
specific failure reasons when the assessment is `Unmet`.

### DAL-C criteria (default)

1. All HLRs defined in `<target>/docs/compliance/HLR.md` must be traced by
   at least one `-- HLR-XXXX` tag in source `.ads` files.
2. Every `-- HLR-XXXX` tag in source must map to a defined HLR (no orphans).
3. All tests passing (zero failures in the discovered test-result file,
   e.g. `<target>/test_result.md`).
4. Minimum SPARK level `>= Bronze` (flow analysis passing).

---

## Makefile targets

| Target             | Description |
|--------------------|-------------|
| `build`            | `alr build` (builds adacovex + test_runner, covex alias) |
| `test`             | Build + run test_runner |
| `prove`            | `./bin/adacovex prove --target=. --no-svg` (runs gnatprove via the `prove` subcommand; gnatprove lives only in alire-dev.toml, so it is run via `alr exec` with the dev-manifest swap, else falls back to PATH / `~/.adacovex/toolchain` / download) |
| `doc` / `api-docs` | Generate API docs via gnatdoc + rst2md (auto-swaps alire-dev.toml) |
| `fmt`              | Format Ada sources with gnatformat (auto-swaps alire-dev.toml) |
| `run-self`         | Run against adacovex itself (default target: cwd) |
| `run-ada-crdt`     | Run against `../Ada_CRDT`, DAL-C (strict mode) |
| `coverage-gate`    | Run the docstring-coverage gate between the latest two release tags (`--coverage-delta` in a worktree at the latest tag) |
| `bump-version`     | Bump version across alire.toml, alire-dev.toml, adacovex.ads, changelog (`VERSION=x.y.z`) |
| `agents-tree`      | Regenerate the AGENTS.md `src/` architecture tree (`tools/gen-agents-tree.py` + `tools/agents-tree.map`) |
| `release`          | Build `--release`, prove, validate self-assessment, run docstring-coverage gate vs last release tag, bundle `dist/` + tarballs (attested via actions/attest in CI, best-effort `gh attest` locally), then tag & push (`VERSION=x.y.z`) |
| `ascii-check`      | Verify all source files are pure ASCII |
| `clean`            | Remove bin/ obj/ docs/badges/ |
| `help`             | Print available targets |

---

## Workflows

### GitHub Actions

- `./action.yml` at the repository root -- composite action (`branding`:
  shield/green, `author`: bladeacer): installs Alire + GNAT, obtains
  the version-matched adacovex binary (downloads the release bundle by default,
  or builds from source with `build: true`), optionally runs GNATprove
  (`prove`), the native tests (`run-tests`), and a `--release` build
  (`release-build`), then runs the assessment and publishes
  outputs (`dal-status`, `spark-level`, `test-count`, `coverage-pct`), a
  Markdown step summary, and SVG badge artifacts (`assess: false` skips the
  assessment for build/test-only jobs). The Alire toolchain install
  (`setup-alire`) selects only the compiler and `gprbuild` at `gnat-version`
  (`gnatprove` is NOT an `alr toolchain` component); gnatprove is resolved by
  the `prove` subcommand via the target project's `alire-dev.toml`
  (README-preferred method, `alr exec` with the dev-manifest swap), falling
  back to `$PATH`, `~/.adacovex/toolchain`, or download. When
  `generate-sbom` (default `true`)
  is set and the assessment runs, it also generates a proof-aware SBOM
  (`adacovex sbom --format=${{ sbom-format }}`, default `cyclonedx-json`) and
  uploads it as an `adacovex-sbom` artifact. Inputs: `target`, `dal`,
  `gnat-version`, `version`, `build`, `release-build`, `prove`, `run-tests`,
  `assess`, `compare-base`, `coverage-delta`, `emit-markdown`, `generate-sbom`,
  `sbom-format`, `cache`, `result-cache`. `result-cache` (default `true`)
  persists adacovex's on-disk result cache (`~/.adacovex/cache`) across runs
  with `actions/cache`; entries are SHA-256 content-hashed per artifact, so
  unchanged sources/proofs/tests are served from the previous run's cache
  without re-parsing. Once
  listed on the GitHub Actions marketplace, each `vX.Y.Z` tag auto-publishes
  the matching action version. Consumers should reference the floating `@latest`
  tag to always use the newest published release; the narrower `@v1` (or
  `@v1.3`) refs track the latest release within a major or minor version, and a
  specific `@vX.Y.Z` can be pinned for reproducibility. Floating refs and the
  `latest` keyword are resolved to the matching release tag by the
  binary-download step.
- `.github/workflows/ci.yml` -- self-assessment (build + prove + assess) and
  build + native tests (build + run-tests, assess: false) on push to main and
  pull requests.
- `.github/workflows/pr-check.yml` -- runs `--coverage-delta` against
  `pull_request.base.sha` to fail PRs that drop docstring coverage.
- `.github/workflows/release.yml` -- on a `v*` tag, runs the action with
  `build: true`, `release-build: true`, `prove: true` to build the release
  binary, run GNATprove, and validate the self-assessment, then creates a
  GitHub Release with the binary tarball (`adacovex-vX.Y.Z.tar.gz`: `adacovex`
  + the `covex` alias) and the action tarball
  (`adacovex-action-vX.Y.Z.tar.gz`). Both bundles are attested via
  `actions/attest` (OIDC); the release notes link the signed
  attestation (`attestation-url` output), a *Git Changelog* compare link
  (`compare/v1.5.0...v1.6.0`), and the human-readable changelog. The action
  downloads the matching
  binary tarball for the tag it is referenced by, so `@v1.4.0` runs adacovex
  `v1.4.0`.
  The tag itself publishes the action for
  `uses: <owner>/adacovex@vX.Y.Z`, and once the
  action is listed on the marketplace, each tag auto-publishes that version.
  A final step force-pushes the floating tags `vMAJOR`, `vMAJOR.MINOR`, and
  `latest` (e.g. `v1`, `v1.3`, and `latest` from `v1.3.0`) so users can
  reference `@v1` / `@v1.3` / `@latest` for the latest matching release.

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

# DAL-A assessment (requires Gold SPARK level)
adacovex --target=/path/to/project --dal=A
```

### Requirements for running adacovex against a project

The target project must have:

1. **Ada source files** (`.ads`) -- scanned for subprograms and docstrings.
2. **GNATprove output** -- either `gnatprove.out` in the target root or
   `<target>/obj/gnatprove/gnatprove.out`. Adacovex parses the proof summary
   to determine the SPARK level.
3. **Test results** -- a test-summary file in the target root. Adacovex
   auto-discovers conventional names (`test_result.md`, `test_results.md`,
   `test-result.md`, `test_report.md`, `test_output.md`, plus `.txt`/`.log`
   variants and the `docs/` mirrors) containing a Markdown table with `Tests`
   and `Status` columns (PASS/FAIL) or a supported summary format (TAP,
   Automake `PASS:`/`FAIL:`, Maven Surefire `Tests run:`, Unity `N Tests M
   Failures`, `Passed:`/`Failed:`).
4. **HLR document** (for DAL assessment) -- `<target>/docs/compliance/HLR.md`
   defining the High-Level Requirements.

Projects that do not have GNATprove output or test results will show "N/A"
for those metrics. DAL compliance checks that depend on missing data will
report as `Unmet` with appropriate failure reasons.

Non-Ada projects (e.g. a C/C++, Python, or JS repo) that run adacovex should
provision their own `alire.toml` or `alire-dev.toml` to manage the Ada-related
dependencies required to build and run adacovex itself (adacovex + GNAT
toolchain). The default `--target` is the current working directory, so running
`adacovex` from a non-Ada repo scans that repo and uses its `alire.toml` as the
manifest.

### Installing adacovex

adacovex is a zero-dependency Alire crate: it declares no library or tool
dependencies, so installing it never drags in gnatprove. Pick whichever
method fits:

1. **Per-project Alire manifest (preferred).** Declare `covex` in the
   project's `alire-dev.toml` (never `alire.toml`, so release builds stay
   clean), with `gnatprove` as its standard companion in the same manifest --
   proof runs are part of the workflow:
   ```toml
   # <project>/alire-dev.toml
   [[depends-on]]
   covex = "*"
   gnatprove = "^15.1.0"
   ```
   `alr build` then produces `bin/adacovex` in the project and
   `covex prove` runs gnatprove through `alr exec` (Alire pins the exact
   toolchain version per project; no global install needed).
2. **`alr install` (global, to `$PATH`).** Install the binary and the prover
   together, then put Alire's bin directory on `$PATH`:
   ```bash
   alr install covex gnatprove
   export PATH="$HOME/.local/bin:$PATH"
   ```
   `covex` is the Alire crate name for adacovex
   ([crate page](https://alire.ada.dev/crates/covex)); the installed binary
   scans the current directory by default, so once on `$PATH` it runs from any
   project with no further setup. Alire installs to its bin directory (default
   `~/.local/bin`; `alr install` prints the exact location, `alr toolchain
   --install-dir` shows the toolchain dir). A `gnatprove` installed this way is
   picked up from `$PATH` when the target project declares no manifest
   dependency of its own.
3. **GitHub release bundle.** Every `vX.Y.Z` tag publishes
   `adacovex-vX.Y.Z.tar.gz` (`adacovex` + `covex` alias) on the Releases page.
   Fetch it with `curl` and unpack onto `$PATH`:
   ```bash
   VERSION=v1.6.0
   curl -fL -o adacovex.tar.gz \
     "https://github.com/bladeacer/adacovex/releases/download/$VERSION/adacovex-$VERSION.tar.gz"
   mkdir -p ~/.local/bin
   tar -xzf adacovex.tar.gz -C ~/.local/bin
   export PATH="$HOME/.local/bin:$PATH"
   ```
   Bundles are attested with `actions/attest`; verify with
   `gh attestation verify`.
4. **From source.** `make build` in the repo, or manage adacovex as a dev
   dependency (see below).

### GNATprove toolchain resolution (prove mode)

`covex prove` finds `gnatprove` in this order:

1. **Per-project manifest (preferred)**: if `<target>/alire.toml` /
   `<target>/alire-dev.toml` declares a `gnatprove` dependency, run via
   `alr exec gnatprove`.
2. **`$PATH`**: a `gnatprove` installed beforehand (e.g. `alr install gnatprove`).
3. **Cached toolchain**: `~/.adacovex/toolchain/`.
4. **Download**: last-resort platform toolchain bundle.

If a project manifest declares `gnatprove` but `alr` is missing, install Alire
first; the remaining fallbacks then apply.

### Using adacovex from another project (Ada or non-Ada)

Two approaches are equally valid; pick whichever fits the project:

1. **Pass `--target` to the adacovex dev source (no install needed).** Build
   adacovex once, then point it at the project:
   ```bash
   cd /path/to/adacovex && make build
   cd /path/to/project
   /path/to/adacovex/bin/adacovex --target=. --dal=C
   ```
   Because `--target` defaults to the current directory, running the binary
   from inside the project scans it without extra flags. The project does not
   need any Ada tooling of its own; only the adacovex working tree needs GNAT
   and Alire.

2. **Manage adacovex as an Alire dev dependency (preferred for real usage).**
   Add it -- and `gnatprove`, its standard proof companion -- to the project's
   `alire-dev.toml` (never `alire.toml`, so release builds stay clean):
   ```toml
   [[depends-on]]
   covex = "*"
   gnatprove = "^15.1.0"
   ```
   Then `alr build` produces `bin/adacovex` inside the project,
   `adacovex` runs against the current directory by default, and `covex prove`
   runs gnatprove through `alr exec` (see
   [Installing adacovex](#installing-adacovex)).

In both cases the assessed project is the directory given to `--target` (or
CWD when omitted); the two approaches differ only in how the adacovex binary
is obtained and built.

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
| Unit tests | `make test` | 336/336 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | all VCs proved, Platinum |
| Ada_CRDT regression | `make run-ada-crdt` | Stable against CRDT library (strict mode) |

See [docs/changelogs/adacovex-1.0.0.md](docs/changelogs/adacovex-1.0.0.md) for full release notes.
See [docs/architecture.md](docs/architecture.md) for architectural decisions.

---

## Changelog format

Each release gets one file at `docs/changelogs/adacovex-<version>.md`, linked
from `docs/changelogs/index.md` under the `<!-- CHANGELOG_LIST -->` marker
(newest first). Follow the structure used by the existing entries (1.5.0+):

```
# adacovex <version>                    -- H1 title
Date: _YYYY-MM-DD_                      -- release date
Version bumped <old> -> <new>.          -- version diff line

## Changes                              -- features / behavior changes
### C1: <Short title>                   -- numbered, one subsection per change
### C2: ...
## Fixes                                -- bugfixes only (omit if none)
### H1: <Short title>
### H2: ...
## Test Suite                           -- suite size + what changed
## Proof Results                        -- SPARK level, VC counts, invocation
## Traceability                         -- new HLRs + tags covering changes
```

Rules:
- `## Changes` and `## Fixes` use numbered subsections (`### C#:` / `### H#:`)
  with a short bold-worthy title, then prose -- no bare bullet lists.
- Fixes are grouped under `## Fixes` (`### H#:`), distinct from Changes.
- `## Proof Results` states the SPARK level (Stone..Platinum), the exact VC
  totals (e.g. `503/503 VCs proved across 38 analyzed units`), and calls out
  whether any proof metrics changed. It notes when changed units are
  non-SPARK and therefore unaffected.
- `## Traceability` lists any new HLRs by tag name and package, then the
  existing `-- HLR-*` tags covering the changed packages.
- `make bump-version` (`VERSION=x.y.z`) creates/updates the changelog; keep
  the section headings and numbering style identical across releases.

---

## Unit tests

**Native (zero-dependency).** Tests use `Adacovex.Test_Support` -- a minimal
`Runner` type with a `Check` procedure. No AUnit or other external framework.

Test source: `src/tests/`. Entry point: `test_runner.adb` (builds as
`bin/test_runner` from `for Main use ("adacovex_main.adb", "test_runner.adb")`
in `adacovex.gpr`; the CLI entry point builds as `bin/adacovex` via the
`Builder.Executable` override, with a `bin/covex` alias symlink).

`make test` builds and runs the 336-test suite. Test results are written to
`docs/test_result.md` in a Markdown table format that can be parsed by
`adacovex-parsers-tests`. This means adacovex **supports both** native test
running (via test_runner) and AUnit test-result parsing (via Parse_Test_Result).

### Test categories (336 total)

| Category | Tests | What it covers |
|----------|-------|----------------|
| Types conversions | 26 | SPARK_Level/DAL_Level/DAL_Status/Test_Status strings, host word-size detection |
| DAL compliance | 7 | DAL assessment status, oversized HLR/LLR entry clamping |
| Source scanner | 79 | Package scan, docstring parsing (Ada/Google/Sphinx styles), HLR tags, name extraction, @field/@formal/after-decl, comment-style variants, tag aliases, long generated lines, Max_Line overflow/exact-fit rejection, oversized-name/tag/value clamping, Skipped_Ct |
| IR synthesis | 27 | Bounded type bounds, Target_Config defaults, host word-size detection, foreign type-name lowering, package synthesis |
| GNATprove parser | 52 | .out parsing, proof summary, SPARK level detection, Units_Analyzed/Skipped, justified-VC handling, --help handling, Max_Line overflow rejection |
| Test-result parser | 43 | Markdown table, TAP, Automake, Maven Surefire, and Unity test-result parsing; conventional file-name discovery; Max_Line overflow rejection |
| CLI config | 19 | Default option values, --help, --no-svg field, --compare-base and --coverage-delta defaults, prove-option defaults |
| SVG renderer | 30 | SVG badge content and format |
| SBOM generator | 53 | Proof/DAL property mapping, Alire manifest + GPR dependency graph, CycloneDX/SPDX rendering |

---

## Known quirks

- `(null record)` typed parameters are counted as parameters by the scanner.
- Overloaded subprograms in patch files: each overload requires a separate
  patch entry. The first patch entry for a name patches the first undocumented
  original, the second patches the second, etc.
- `Is_Subprogram_Decl` matches `procedure`, `function`, `generic procedure`,
  and `generic function` only (not `type`, `package`, `task`, etc.).
- Docstring detection: any `--  ` (two dashes + two spaces), `-- ` (single
  space), or `--<TAB>` line before a subprogram counts as a docstring. Other
  comment formats (bare `--`, `---` with three dashes) do not.
- A physical line longer than `Max_Line` (262144 bytes on 64-bit) is drained
  and reported to stderr (`Error: <path>:<line>: line exceeds Max_Line
  buffer`); the file is not parsed and the scanner increments `Skipped_Ct`,
  which forces DAL `Unmet` and exit code 1. A line exactly `Max_Line` long
  (exact buffer fit) parses normally. Paths longer than `Max_Path` are
  likewise reported and skipped. The same explicit-overflow contract applies
  to every parser (HLR/LLR, GNATprove, test results, manifest/lock/gpr).
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
- No library dependencies beyond GNAT runtime (`Ada.Containers` is
  part of the standard Ada runtime library). No declared tool dependency
  either: gnatprove is resolved at run time by the `prove` subcommand.

## Bounded resources

The following compile-time constants in `src/core/adacovex-types.ads`
govern fixed-size string/VC buffers (package and subprogram vectors
are unbounded via `Ada.Containers.Vectors`):

| Constant | Value | Notes |
|----------|-------|-------|
| `Max_Line` | 262144 | Source line length (overlong lines fail loudly, never silently truncated) |
| `Max_Path` | 4096 | File path length (matches `PATH_MAX`) |
| `Max_Desc_Str` | 128 | Subprogram name / description|
| `Max_Filename` | 128 | Package name from filename |
| `Max_Id_Str` | 64 | HLR/LLR tag ID length |

Package and subprogram collections grow dynamically via `Ada.Containers.Vectors`
(heap allocation, up to `Natural'Last` ~ 2.1B). The fixed-size constants above
apply only to individual line/path/description buffers.

**Overflow contract (two tiers).** Path and line buffers *fail loudly*: an
overlong physical line is drained and reported (`line exceeds Max_Line
buffer`), the file is not parsed, `Skipped_Ct` increments, and DAL becomes
`Unmet`; an overlong path is reported and the file/subtree is skipped. No
partial results ever flow downstream. Semantic text fields (subprogram names,
HLR/LLR IDs, descriptions, docstring tag names/values, CLI strings) are
*clamped* to their fixed buffer with the length field (`Name_Len`, `Id_Len`,
`D_Len`, ...) recording the recorded prefix, so adversarial or generated input
can never raise `Constraint_Error`. Clamping keeps the scan correct -- the
full token is still consumed so following tokens are not misparsed.

**Why no chunking / LEB128.** adacovex audits in memory: counts (packages,
subprograms, HLR tags, tests, SBOM components) are unbounded vectors, and each
scanned unit is processed line-at-a-time into fixed per-item buffers. A single
Ada declaration does not admit streaming/chunked parsing -- truncating a
declaration is worse than a loud failure, so chunking would gain nothing.
LEB128 (variable-length integer encoding) is a serialization concern and does
not apply to an in-memory CLI audit. The design therefore scales to arbitrarily
large codebases by dynamic allocation, bounded per-item buffers, and explicit
overflow handling, without streaming encodings.
