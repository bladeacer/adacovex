# adacovex Architecture Decisions

adacovex's architecture spans three pages. This page records the design
decisions: dependency management, the zero-dependency rule, the
formal-verification policy, and result caching. The companion pages cover
[verification and proof patches](architecture-verification.md) and
[outputs, pipeline, and delivery](architecture-outputs.md).

## Dependency Management: Alire

adacovex uses [Alire](https://alire.ada.dev/) as its packaging and delivery mechanism. The publishing manifest `alire.toml` declares **zero dependencies**. It declares no libraries beyond the GNAT runtime. It declares no tool dependencies.

In particular `gnatprove` is *not* a declared dependency. adacovex analyses `gnatprove.out` files produced externally. The `prove` subcommand resolves a gnatprove executable at run time (per-project manifest, `$PATH`, cached toolchain, or download). Development-only tools (`gnatprove`, `gnatdoc_bin`, `gnatformat_bin`) are declared in `alire-dev.toml`, which is never published to the Alire community index.

### Manifest distinction (`alire.toml` vs `alire-dev.toml`)

- **`alire.toml`**: The clean publishing manifest. Declares no dependencies at
  all, so `alr install covex` (or `alr build` from source) pulls nothing beyond
  the binary and the GNAT compiler. Used for SBOM generation and dependency
  graph scanning.
- **`alire-dev.toml`**: The development manifest. Extends `alire.toml` with
  dev-only tools (`gnatprove`, `gnatdoc_bin`, `gnatformat_bin`) needed for
  `make prove`, `make doc`, and `make fmt`. The `prove` subcommand reads the
  gnatprove pin from it and deploys that exact version into
  `~/.adacovex/toolchain/` via `alr -n get` (reused after the first run);
  `make doc`/`make fmt` run their tools through `alr exec`.

When both files exist, `Build_Dependency_Graph` reads **both**: a dependency
declared in `alire.toml` is classified `Scope_Base` (explicit/clean dep) and
one declared only in `alire-dev.toml` is `Scope_Dev`. The scope is surfaced in
the SBOM as the `adacovex:dep_scope` property (`base` / `dev` / `transitive` /
`vendored`), so it is always clear which file a dependency came from.
`alire-dev.toml` is also consulted for gnatprove detection
(`Manifest_Declares_GNATprove` checks both manifests).

### GNATprove toolchain resolution (`prove` subcommand)

adacovex declares `gnatprove` only in its own `alire-dev.toml` (keeping the
publishing `alire.toml` clean). The `prove` subcommand resolves the `gnatprove`
executable in this order:

1. **Per-project manifest (authoritative)**: if `<target>/alire.toml` /
   `<target>/alire-dev.toml` declares a `gnatprove` dependency, the pinned
   gnatprove binary crate is deployed standalone into `~/.adacovex/toolchain/`
   via `alr -n get gnatprove=<version>` and executed directly (the version-set
   expression, for example `^16.1.0`, is reduced to the bare version alr
   accepts). This isolates the proof run from the target's other dev-manifest
   tools and never swaps manifests. A manifest pin always wins. When the pinned
   version cannot be deployed, the run fails instead of falling back.
2. **Global version pin**: the `ADACOVEX_GNATPROVE_VERSION` environment
   variable or the `[prove] gnatprove-version` key in
   `~/.adacovex/adacovex.toml`, deployed standalone via
   `alr -n get gnatprove=<version>`. It uses the same never-fall-back
   semantics. It is folded into the proof result-cache identity.
3. **`$PATH`**: a `gnatprove` already installed (for example `alr install gnatprove`).
4. **Cached toolchain**: `~/.adacovex/toolchain/`. The download layout
   (`<toolchain>/bin/gnatprove`) is used. A previously `alr get`-deployed
   `gnatprove_*/` crate is also used.
5. **Download**: last-resort platform toolchain bundle.

Effective order: **manifest pin > global pin (config/env) > PATH > cache >
download**. If a project manifest declares `gnatprove` but `alr` is missing,
install Alire first. The remaining fallbacks then apply.

The `make doc` / `make fmt` targets still swap `alire-dev.toml` over
`alire.toml` for the duration of `gnatdoc` / `gnatformat` (the `_dev_cmd`
Makefile recipe backs up `alire.toml` / `alire.lock` / `alire/`, swaps, runs,
and restores via a `trap`). `prove` does not use that swap. It deploys only
the single gnatprove crate.

The assessment and SBOM pipeline always scans the publishing `alire.toml`, so
dev-only tool declarations never leak into dependency graphs or SBOMs.

### System-tool dev dependencies (SBOM)

Beyond the Alire graph, `Discover_System_Dev_Deps` adds the system binaries a project interacts with at development time (`python3`, `git`, `gnatprove`, `make`, and more) as `Scope_Dev` SBOM components. It scans the project's dev-facing files (Makefile variants, `.sh` / `.py` / `.gpr` / `.yml` / `.toml` / `.ads` / `.adb`) for a curated toolchain list and registers every referenced tool that is actually installed on `$PATH` under a `pkg:generic/<tool>` purl. Tools referenced nowhere in the project, or referenced but not installed, are skipped. A Makefile at the project root implies `make`.

The scan runs after the cached manifest graph is resolved (so cache hits and misses agree). Each registered tool's version is probed by running `--version` (or a tool-specific subcommand such as fossil's `version`) and extracting the version token, so the SBOM records the installed version. A probe that fails or prints no digit token leaves the version empty. The source file declaring the `System_Tools` table is skipped by the scan.

Otherwise, every installed tool on the list can be registered as a self-reference.

### Vendored components and test-labelled dependencies (SBOM)

`Discover_Generic_Vendored` walks the target tree for vendor roots
(`node_modules`, `vendor`, `third_party`, and the other recognised names).
Each directory inside a vendor root that carries an ecosystem manifest
(`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `composer.json`,
`Gemfile`, `pom.xml`, `Package.swift`, `requirements*.txt`) becomes one
component with its ecosystem purl (`pkg:npm/...`, `pkg:cargo/...`, and
more).  Its scope defaults to `vendored`.

A component is classified `test` when the project manifest that owns the
vendor root declares it under a test-only label:

- `package.json` sections whose key contains `test` (for example
  `testDependencies`);
- Cargo `[dev-dependencies]` (Cargo's native test-only section) and any
  section containing `test`;
- composer `require-dev`;
- Gemfile `group :test` blocks;
- `pom.xml` dependencies whose `<scope>` is `test`;
- `pyproject.toml` test extras and Poetry `[tool.poetry.group.test.*]`
  sections;
- `Package.swift` dependencies declared inside a `.testTarget(...)` block.

The **name heuristic** is the fallback for every ecosystem.  A component
whose name starts or ends with the literal word `test` is test-labelled.
The check covers the full name and then the last segment after any `/` or
`:`, so `@playwright/test`, `test-case`, `github.com/stretchr/testify` and
`org.testng:testng` all match.  Ecosystems without a native test-only
section (`go.mod`, `requirements*.txt`) rely on this heuristic.

The heuristic also applies to **lockfile-resolved names**:
`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` entries next to an
owner `package.json`, `Cargo.lock` crate names, and `alire.lock` crates
that the manifest sets leave transitive.

The scope is surfaced as the SBOM `adacovex:dep_scope` property (`test`)
and in the dashboard dependency badges, scope filter, legend, and rings.
The Alire-side `[[test-depends-on]]` sections and test project files are
the other source of `test` scope; see the
[SBOM reference](../usage/sbom-resolution.md#test-dependencies).

## Unix Philosophy

adacovex follows the Unix philosophy of doing one thing well:

- **Single-purpose pipeline**: Each step (scanning, proof parsing, test parsing, DAL assessment, rendering) is a focused, composable unit.
- **Text-based interfaces**: Input and output are plain text (Ada source, `.out` files, Markdown reports, ANSI terminal output).
- **No library dependencies**: Only the GNAT runtime is used. No external
  libraries or frameworks. Alire is the packaging/delivery mechanism but adds
  no runtime dependency. adacovex declares no library or tool dependencies
  (gnatprove is resolved at run time by the `prove` subcommand).
- **Composable tools**: The `prove` subcommand runs GNATprove and then falls through to the standard assessment pipeline. The `sbom` subcommand generates a proof-aware SBOM independently.
- **Exit codes**: `0` for success (DAL achieved), `1` for compliance failure. This enables straightforward CI integration.
- **Minimal user code**: users write as little code as possible while getting
maximum value. The tool accepts third-party and generated code as it is. It recognises common docstring conventions (Ada `--  @param`, Google `Args:`/`Returns:`, Sphinx `:param:`/`:returns:`). It recognises common test-result formats (TAP, Automake, Surefire, Unity).

It lowers foreign type names (`int32_t`, `size_t`, and more) onto bounded Ada types. Nothing needs to be rewritten to be assessed.

## Zero-Library-Dependency Design

adacovex declares no library dependencies beyond the GNAT runtime. All data structures use either:

- GNAT runtime containers (`Ada.Containers.Vectors` for unbounded collections)
- Fixed-size string buffers (`Max_Line = 262144`, `Max_Path = 4096`, etc.) for bounded I/O

`Max_Path` and `Max_Line` scale with the auto-detected host word size
(`System.Word_Size`), keeping the classic 4096 / 262144 values on 64-bit
hosts while using proportionally smaller limits on narrower machines. The
semantic limits (`Max_Id_Str`, `Max_Desc_Str`, `Max_Filename`) are not
storage-size dependent and remain fixed.

`Max_Line` is deliberately generous (256 KiB on 64-bit) so that single-line declarations from heavily code-generated projects parse cleanly. When a physical line *does* exceed the buffer, adacovex **never truncates it and then processes it**. Truncation can silently produce a partial (and wrong) result. Instead the parser drains the remainder, reports the file and line to standard error, and fails that parse explicitly.

The source scanner counts the skipped file in `Skipped_Ct`, which forces the DAL assessment to `Unmet` and the exit code to `1` (no compliance claim can be made for unread code). The same explicit-failure contract applies to every parser: HLR/LLR markdown, GNATprove output (text and JSON), test results, and Alire manifest / lockfile / GPR dependency graphs. An exact buffer-length line is not an overflow (it parses normally), and paths exceeding `Max_Path` are likewise reported and skipped rather than crashing.

**Overflow contract (two tiers).** Path and line buffers *fail loudly*. An
overlong physical line is drained and reported (`line exceeds Max_Line buffer`). The file is not parsed. `Skipped_Ct` increments. DAL becomes `Unmet`. An overlong path is reported and the file/subtree is skipped.

No partial results ever flow downstream. Semantic text fields (subprogram names, HLR/LLR IDs, descriptions, docstring tag names/values, CLI strings) are

*clamped* to their fixed buffer with the length field (`Name_Len`, `Id_Len`,
`D_Len`, ...) recording the recorded prefix, so adversarial or generated
input can never raise `Constraint_Error`. Clamping keeps the scan correct.
The full token is still consumed so following tokens are not misparsed.

**Why no chunking / LEB128.** adacovex audits in memory. Counts (packages,
subprograms, HLR tags, tests, SBOM components) are unbounded vectors. Each scanned unit is processed line-at-a-time into fixed per-item buffers. A single Ada declaration does not admit streaming/chunked parsing. Truncating a declaration is worse than a loud failure.

Chunking can gain nothing. LEB128 (variable-length integer encoding) is a serialization concern and does not apply to an in-memory CLI audit. The design therefore scales to arbitrarily large codebases by dynamic allocation, bounded per-item buffers, and explicit overflow handling, without streaming encodings.

The bounded-buffer constants are tabulated in
`docs/api-docs/adacovex-types.md` (`Max_Line`, `Max_Path`, `Max_Desc_Str`,
`Max_Filename`, `Max_Id_Str`).

This ensures adacovex can be built and run on any system with a GNAT toolchain,
without requiring any additional package installation beyond Alire for
toolchain management.

## SPARK Formal Verification

adacovex itself is SPARK-proven at Platinum level (all VCs proved,
AoRTE-free). The tool analyses GNATprove output (`gnatprove.out`) to assess
SPARK assurance levels (Stone through Platinum) for target projects.

The tool does not perform verification itself. It parses and reports on proof
results produced by GNATprove. This keeps the tool's scope narrow and aligns
with the Unix philosophy of composing specialised tools.

### Proof scope and justification policy

- **Proof scope is the target's own units.** adacovex proves the Ada/SPARK
   code it is run against, never third-party dependencies. GNATprove units that
   are skipped (for example standard-library or vendor code that GNATprove
   itself does not analyse) are tracked via `Units_Skipped` and reported in the
   ANSI and Markdown reports. They are out of proof scope by design, not a
   proof failure.
- **Justifications are an accepted discharge mechanism.** A `Total` row's
  `Justified` count (GNATprove `pragma Annotate` justifications for decidedly
  unprovable checks, such as non-functional foreign-language calls) is counted
  neither as proved nor as unproved: `Proved = Total - Justified - Unproved`.
  Justified VCs do **not** downgrade the SPARK level. Only unproved VCs do.
  This is pinned by unit tests.
- **Gold is the minimum compliance baseline. Platinum is the ideal.**
  `Min_SPARK_For` thresholds (A=Gold, B=Silver, C=Bronze, D/E=Stone) are the
  gate for DAL compliance. Platinum is achieved and reported when every
  functional contract is proved, but it is a best-effort target, not a
  compliance requirement at any DAL level.

## Result caching

adacovex persists parsed analysis results on disk so unchanged inputs are not re-scanned, re-parsed, or re-proved. Source scans, GNATprove summaries, test summaries, `compliance/HLR.md`/`compliance/LLR.md` requirement parses, the resolved SBOM dependency graph, and the differential-mode scans are each keyed by a namespace prefix plus the SHA-256 of the artifact(s) they were derived from. For example: `"scan:" | "prove:" | "tests:" | "hlr:" | "llr:" | "graph:" + digest`. Re-parsing a byte-identical artifact yields a cache hit regardless of the target directory or command line.

An unchanged manifest/lockfile/.gpr set serves the cached dependency graph. Unchanged `compliance/HLR.md`/`compliance/LLR.md` serve the cached requirement parses. `--compare-base` / `--coverage-delta` reuse cached source scans for the current tree.

- **Schema namespace**: the default cache root is
  `~/.adacovex/cache/<version>/<Cache_Schema>`. `Cache_Schema` (in
  `src/core/adacovex-cache.ads`) is bumped whenever the serialized layout of a
  cached record or the scanner/parser semantics change, so blobs written by an
  incompatible build are never served as if valid. System-tool version probes
  are *not* under the result cache: they live in `~/.adacovex/probes/` (a
  stable machine-level store; wiping the result cache must not re-probe every
  tool).
- **Graph key**: the dependency-graph key hashes the Alire manifests, the
  `alire.lock`, every `.gpr`, the vendored trees, and the root language mix.
  It also hashes the supported-language project manifests that can own a
  vendored directory (`package.json`, `Cargo.toml`, `Cargo.lock`, `go.mod`,
  `composer.json`, `Gemfile`, `pom.xml`, `pyproject.toml`, `Package.swift`,
  and the npm lockfiles), so an edit to a test-labelled section or lockfile
  invalidates the cached graph and the scope classification is recomputed.
- **Eviction**: `Put_Cached` evicts oldest-first by modification time when more
  than `--cache-max` entries (default `4096`) accumulate. `Eviction_Count`
  tracks removals and is reported in the ANSI cache line.
- **Overflow safety**: `Serialize` returns an empty blob when a package is
   larger than `Max_Cache_Blob`. Callers skip storing it and `Deserialize`
   rejects empty/oversized input, so truncated data can never be served as a
   hit.
- **`--target` normalization**: `--target` is normalised (`.`/`..` collapsed to
  a canonical absolute path) before scanning, keeping the `File_Path` values in
  cached `Package_Info` consistent across invocations that spell the same
  directory differently.
- **CI**: the GitHub action persists `~/.adacovex/cache` between workflow runs
  (`result-cache` input, default true).

`--no-cache` bypasses it entirely (useful when artifacts change without their
content hash changing, or to measure rescan cost) and `--cache-dir` relocates
it. The ANSI report shows a
`result cache: X hit(s), Y miss(es), Z evicted` line per run.
