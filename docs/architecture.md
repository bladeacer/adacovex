# adacovex Architecture Decisions

## Dependency Management: Alire

adacovex uses [Alire](https://alire.ada.dev/) as its packaging and delivery
mechanism. The publishing manifest `alire.toml` declares **zero dependencies**
-- no libraries beyond the GNAT runtime and no tool dependencies. In
particular `gnatprove` is *not* a declared dependency: adacovex analyzes
`gnatprove.out` files produced externally, and the `prove` subcommand resolves
a gnatprove executable at run time (per-project manifest, `$PATH`, cached
toolchain, or download). Development-only tools (`gnatprove`, `gnatdoc_bin`,
`gnatformat_bin`) are declared in `alire-dev.toml`, which is never published to
the Alire community index.

### Manifest distinction (`alire.toml` vs `alire-dev.toml`)

- **`alire.toml`**: The clean publishing manifest. Declares no dependencies at
  all, so `alr install covex` (or `alr build` from source) pulls nothing beyond
  the binary and the GNAT compiler. Used for SBOM generation and dependency
  graph scanning.
- **`alire-dev.toml`**: The development manifest. Extends `alire.toml` with
  dev-only tools (`gnatprove`, `gnatdoc_bin`, `gnatformat_bin`) needed for
  `make prove`, `make doc`, and `make fmt`. Used for toolchain resolution when
  running `alr exec`.

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
   expression, e.g. `^16.1.0`, is reduced to the bare version alr accepts).
   This isolates the proof run from the target's other dev-manifest tools and
   never swaps manifests. A manifest pin always wins: when the pinned version
   cannot be deployed, the run fails instead of falling back.
2. **Global version pin**: the `ADACOVEX_GNATPROVE_VERSION` environment
   variable or the `[prove] gnatprove-version` key in
   `~/.adacovex/adacovex.toml`, deployed standalone via
   `alr -n get gnatprove=<version>` -- same never-fall-back semantics, folded
   into the proof result-cache identity.
3. **`$PATH`**: a `gnatprove` already installed (e.g. `alr install gnatprove`).
4. **Cached toolchain**: `~/.adacovex/toolchain/` -- the download layout
   (`<toolchain>/bin/gnatprove`) or a previously `alr get`-deployed
   `gnatprove_*/` crate.
5. **Download**: last-resort platform toolchain bundle.

Effective order: **manifest pin > global pin (config/env) > PATH > cache >
download**. If a project manifest declares `gnatprove` but `alr` is missing,
install Alire first; the remaining fallbacks then apply.

The `make doc` / `make fmt` targets still swap `alire-dev.toml` over
`alire.toml` for the duration of `gnatdoc` / `gnatformat` (the `_dev_cmd`
Makefile recipe backs up `alire.toml` / `alire.lock` / `alire/`, swaps, runs,
and restores via a `trap`). `prove` does not use that swap -- it deploys only
the single gnatprove crate.

The assessment and SBOM pipeline always scans the publishing `alire.toml`, so
dev-only tool declarations never leak into dependency graphs or SBOMs.

## Unix Philosophy

adacovex follows the Unix philosophy of doing one thing well:

- **Single-purpose pipeline**: Each step (scanning, proof parsing, test parsing, DAL assessment, rendering) is a focused, composable unit.
- **Text-based interfaces**: Input and output are plain text (Ada source, `.out` files, Markdown reports, ANSI terminal output).
- **No library dependencies**: Only the GNAT runtime is used. No external
  libraries or frameworks. Alire is the packaging/delivery mechanism but adds
  no runtime dependency: adacovex declares no library or tool dependencies
  (gnatprove is resolved at run time by the `prove` subcommand).
- **Composable tools**: The `prove` subcommand runs GNATprove and then falls through to the standard assessment pipeline. The `sbom` subcommand generates a proof-aware SBOM independently.
- **Exit codes**: `0` for success (DAL achieved), `1` for compliance failure. This enables straightforward CI integration.
- **Minimal user code**: users write as little code as possible while getting
  maximum value. The tool meets third-party and generated code where it is --
  recognizing common docstring conventions (Ada `--  @param`, Google
  `Args:`/`Returns:`, Sphinx `:param:`/`:returns:`), common test-result
  formats (TAP, Automake, Surefire, Unity), and lowering foreign type names
  (`int32_t`, `size_t`, ...) onto bounded Ada types -- so nothing needs to be
  rewritten to be assessed.

## Zero-Library-Dependency Design

adacovex declares no library dependencies beyond the GNAT runtime. All data structures use either:

- GNAT runtime containers (`Ada.Containers.Vectors` for unbounded collections)
- Fixed-size string buffers (`Max_Line = 262144`, `Max_Path = 4096`, etc.) for bounded I/O

`Max_Path` and `Max_Line` scale with the auto-detected host word size
(`System.Word_Size`), keeping the classic 4096 / 262144 values on 64-bit
hosts while using proportionally smaller limits on narrower machines. The
semantic limits (`Max_Id_Str`, `Max_Desc_Str`, `Max_Filename`) are not
storage-size dependent and remain fixed.

`Max_Line` is deliberately generous (256 KiB on 64-bit) so that single-line
declarations from heavily code-generated projects parse cleanly. When a
physical line *does* exceed the buffer, it is **never truncated and then
processed** -- that would silently produce a partial (and wrong) result.
Instead the parser drains the remainder, reports the file and line to
standard error, and fails that parse explicitly. The source scanner counts
the skipped file in `Skipped_Ct`, which forces the DAL assessment to
`Unmet` and the exit code to `1` (no compliance claim can be made for
unread code). The same explicit-failure contract applies to every parser:
HLR/LLR markdown, GNATprove output (text and JSON), test results, and
Alire manifest / lockfile / GPR dependency graphs. An exact buffer-length
line is not an overflow (it parses normally), and paths exceeding
`Max_Path` are likewise reported and skipped rather than crashing.

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
not apply to an in-memory CLI audit. The design therefore scales to
arbitrarily large codebases by dynamic allocation, bounded per-item buffers,
and explicit overflow handling, without streaming encodings.

The bounded-buffer constants are tabulated in
`docs/api-docs/adacovex-types.md` (`Max_Line`, `Max_Path`, `Max_Desc_Str`,
`Max_Filename`, `Max_Id_Str`).

This ensures adacovex can be built and run on any system with a GNAT toolchain,
without requiring any additional package installation beyond Alire for
toolchain management.

## SPARK Formal Verification

adacovex itself is SPARK-proven at Platinum level (all VCs proved,
AoRTE-free). The tool analyzes GNATprove output (`gnatprove.out`) to assess
SPARK assurance levels (Stone through Platinum) for target projects.

The tool does not perform verification itself -- it parses and reports on proof results produced by GNATprove. This keeps the tool's scope narrow and aligns with the Unix philosophy of composing specialized tools.

### Proof scope and justification policy

- **Proof scope is the target's own units.** adacovex proves the Ada/SPARK
  code it is run against, never third-party dependencies. GNATprove units that
  are skipped (e.g. standard-library or vendor code that GNATprove itself does
  not analyze) are tracked via `Units_Skipped` and reported in the ANSI and
  Markdown reports; they are out of proof scope by design, not a proof
  failure.
- **Justifications are an accepted discharge mechanism.** A `Total` row's
  `Justified` count (GNATprove `pragma Annotate` justifications for decidedly
  unprovable checks, such as non-functional foreign-language calls) is counted
  neither as proved nor as unproved: `Proved = Total - Justified - Unproved`.
  Justified VCs do **not** downgrade the SPARK level -- only unproved VCs do.
  This is pinned by unit tests.
- **Gold is the minimum compliance baseline; Platinum is the ideal.**
  `Min_SPARK_For` thresholds (A=Gold, B=Silver, C=Bronze, D/E=Stone) are the
  gate for DAL compliance. Platinum is achieved and reported when every
  functional contract is proved, but it is a best-effort target, not a
  compliance requirement at any DAL level.

## IR Synthesiser

The `src/ir/` layer starts an intermediate representation for
cross-compilation assessments, so the tool can reason about types as they
exist on a target rather than only as they appear in Ada source:

- `Adacovex.Target_Profiles` defines bounded machine-integer types
  (`IR_Int8`..`IR_Int64`, `IR_UInt8`..`IR_UInt64`) with `Size` clauses and a
  `Target_Config` record (host/target/pointer word sizes). The types are
  SPARK-proved: `Checked_Add32` / `Checked_Add64` show overflow is detected,
  not undefined.
- `Adacovex.IR_Synthesiser` lowers foreign type names (`int8_t`, `size_t`,
  `usize`, `ptrdiff_t`, ...) onto the bounded IR types and synthesizes
  package declarations from a comma/whitespace-separated type list.
- `Adacovex.IR_Bounds` is a gnatprove fixture deriving synthesized-style
  `int32_t` / `int64_t` types and proving their `Add32` / `Add64` overflow
  checks, so absence of integer overflow on the lowered types is
  machine-checked.

## DO-178C DAL Compliance

The DAL assessment evaluates four criteria:

1. All HLRs defined in `docs/compliance/HLR.md` are traced by `-- HLR-XXXX` tags in source
2. No orphan tags (every in-source HLR maps to a defined HLR)
3. All tests passing (zero failures in `test_result.md`)
4. Minimum SPARK proof level met (varies by DAL level)

DAL-C is the default target level. Higher levels (A, B) require stricter proof levels (Gold, Silver respectively).

## Source Scanning

The scanner walks the target directory tree, skipping always-excluded directories (`.git`, `obj`, `tests`, `config`, `.adacovex`). For each `.ads` file found, it extracts:

- Package name from filename
- Subprogram declarations (`procedure`, `function`, `generic procedure`, `generic function`, and `overriding` / `not overriding` variants)
- Docstring annotations (`--  ` prefix with optional `@param`, `@return`, `@field`, `@formal` tags, plus Google `Args:`/`Returns:` blocks and Sphinx `:param:`/`:returns:` fields)
- HLR traceability tags (`-- HLR-XXXX`)

In strict mode (default), the scanner also applies docstring patches from `.adacovex/patches/` to document vendored/third-party code without modifying the originals.

## Patch System

The `.adacovex/patches/` directory overlays docstring information onto
third-party or vendored code that cannot be modified directly, so strict mode
can still reach 100% docstring coverage without touching the originals.

### Why patches exist

In strict mode (default), all directories except `.git`, `obj`, `tests`,
`config`, and `.adacovex` are scanned. Vendored dependencies (e.g. a copy of
vt100 in `demo/deps/vt100/`) are scanned, and their undocumented subprograms
count against docstring coverage. Patches document them in place.

### Patch file format

A patch file is a valid Ada `.ads` file containing only the subprogram
declarations to document, each preceded by a docstring:

```ada
--  Package-level comment (optional, not used by patch engine).
package VT100 is

   --  Summary of the procedure.
   --  @param Name  Description.
   procedure Some_Procedure (Name : in Some_Type);

   --  Another procedure with no params.
   procedure No_Param_Proc;

end VT100;
```

Rules:
1. File name must match the original `.ads` (e.g. `vt100.ads`).
2. Subprogram names must match the originals exactly.
3. Only subprograms with preceding docstrings (`--  ` lines) are merged.
4. Overloaded subprograms: one patch entry per overload; each patches the next
   undocumented original with the same name.
5. The scanner merges `Has_Docstring`, `Doc_Param_Ct`, and `Doc_Return` into
   the matching originals.

### Patch file location

```
<target-project>/.adacovex/patches/<relative-path>
```

`<relative-path>` is the path from the target root to the `.ads` file. Example:
to patch `Ada_CRDT/demo/deps/vt100/vt100.ads`, create
`Ada_CRDT/.adacovex/patches/demo/deps/vt100/vt100.ads`. The `.adacovex`
directory is always excluded from source scanning.

## Output Formats

adacovex supports multiple output formats:

- **ANSI terminal report**: Color-coded summary for interactive use
- **SVG badges**: `spark.svg`, `tests.svg`, `docs.svg`, plus `do178c.svg` /
  `iso26262.svg` / `iec62304.svg` compliance badges (`--standard=all` emits all
  three) for CI badges
- **Markdown reports**: `VERIFICATION.md` and `TRACE.md` for compliance documentation
- **HTML dashboard**: Interactive web dashboard with JSON API (`--serve`)
- **SBOM**: CycloneDX 1.5, SPDX 2.3, or Markdown format with proof, standard,
  and DAL/level properties

## Testing

adacovex uses a native zero-dependency test framework (`Adacovex.Test_Support`) with 549 tests across 12 categories. No external test framework (AUnit, etc.) is required. Test results are written to `docs/test_result.md` in a parseable Markdown table format.

## Supported Platforms

adacovex supports the same platforms Alire itself supports. Because Alire is
the packaging and delivery mechanism -- the crate builds via `alr build`, is
distributed through the Alire community index (`alr install covex`), and the
release workflow builds it with the Alire toolchain -- adacovex inherits
Alire's supported-platform matrix:

- **Binary distribution**: Linux x86-64, Windows x86-64, and macOS x86-64
  (the platforms for which Alire publishes binary releases and GNAT FSF
  toolchains, including cross compilers for ARM, RISC-V, and AVR).
- **From source**: any platform with a GNAT FSF 9.2+ compiler on which Alire
  can be built (Alire lists FreeBSD and OpenBSD among buildable hosts).
- **GitHub release bundles**: built on GitHub's Linux runners and distributed
  as `adacovex-vX.Y.Z.tar.gz` for every tag.

The GitHub Actions composite action pins `gnat-version` (default `15.2.1`) via
`alire-project/setup-alire`, and CI runs on `ubuntu-latest`, so the CI-verified
platform is Linux x86-64. The tool itself is written in portable Ada 2012 using
only the GNAT runtime, so no adacovex code is platform-specific beyond what the
GNAT runtime and Alire toolchain provide.

## Delivery and Versioning

adacovex follows one version across every delivery channel, and each channel is
version-locked to the same release:

- **Single source of truth**: the `version` field in `alire.toml` /
  `alire-dev.toml`. `tools/gen-version.py` regenerates
  `src/adacovex_version_info.ads` at build time (and `make bump-version`),
  and `Adacovex.Version` in `src/adacovex.ads` re-exports it, so
  `--version`, the man page, the SBOM tool version, and the result-cache
  namespace all derive from the manifest and can never drift. Release builds
  bundle the release tag instead via the `ADACOVEX_VERSION` environment
  variable (release workflow / `make release`).
- **CI is tied to the release version**: the GitHub Actions composite action
  (`action.yml`) is version-matched to the adacovex binary. The release
  workflow bundles `adacovex-vX.Y.Z.tar.gz` and `adacovex-action-vX.Y.Z.tar.gz`
  for every `vX.Y.Z` tag, and the action downloads the binary for the tag it is
  referenced by (`@vX.Y.Z` runs that exact version). Floating tags
  (`vMAJOR`, `vMAJOR.MINOR`, `latest`) are force-pushed at release time so
  `@latest` / `@v1` / `@v1.3` always resolve to the newest matching release.
- **CI platform/compiler**: CI validates the self-assessment (build, prove,
  tests) with the pinned `gnat-version` on `ubuntu-latest`, so the CI-proven
  combination is the released binary built against that exact toolchain.
- **Attestation**: every release bundle is attested with
  `actions/attest` (OIDC), and the release notes link the
  signed attestation.

## Build-time linker output (SFrame)

The Alire GNAT toolchain's bundled `ld` (2.44) emits a benign message
(`error in ...(.sframe); no .sframe will be created`) when it reads the
`.sframe` section that newer system binutils wrote into the glibc startup
objects. The link still succeeds. `make build` filters only this one message;
all compiler and gnatprove warnings remain fully visible, so nothing real is
ever suppressed.

## Read Only

adacovex itself is read-only. It merely scans your codebase for target docstrings and proofs.

It does not make edits in place or on your behalf.

## Flexible

adacovex lets you write proofs and decide where proofs are pointless (e.g. code that has to involve manual memory management). You just have to justify your rationale. The tool should not be rigid and expect 100% proving for all use cases.

You write the proofs yourself, so there is no magic or hidden abstractions here.

## Pipeline (execution order)

When adacovex runs, it executes these steps in sequence:

```
0. Parse CLI args           -> CLI_Config record (prove / sbom / diff / man / normal)
0a. Early-exit modes        -> --help / --version / man / status exit before the pipeline
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

Differential modes (`--compare-base` / `--coverage-delta`) run before the
pipeline and snapshot a base revision via `Adacovex.VCS` (git `worktree add`,
hg `archive`, svn `export`, fossil `open` on a copied DB, or a git worktree
against the jj store), assess base and current tree, report the delta, and
exit. `man` installs the generated man page (`Adacovex.Renderers.Man`) into
the local man database (`~/.local/share/man`, Linux/WSL) and refreshes it with
`mandb`.

## Swapping the GNAT compiler (LLVM backend)

adacovex and Alire both default to the GCC-based **GNAT** (`gnat_native`)
compiler; no action is needed. Only swap if you specifically want an
LLVM-backend GNAT (e.g. GNAT LLVM) for your target project -- for example to
exercise dissimilar redundancy via diverse code generation.

GNAT LLVM is **not** yet packaged as a standard Alire toolchain crate, so two
paths exist:

1. **Alire-managed compiler (preferred when available).** If a GNAT LLVM binary
   release becomes available in the Alire index, declare it in your
   `alire.toml` / `alire-dev.toml`:

   ```toml
   [[depends-on]]
   gnat_llvm = "*"
   ```

   `alr` then selects it automatically for that project's builds. You can also
   pick a default compiler for all projects with
   `alr toolchain --select --disable-assistant` and choosing the LLVM GNAT.

2. **System-installed GNAT LLVM.** Install GNAT LLVM on `$PATH`, then force the
   Ada toolchain in the root `.gpr` so `gprbuild` doesn't fall back to the
   GCC GNAT:

   ```gpr
   for Toolchain_Name ("Ada") use "GNAT_LLVM";
   ```

   You can confirm which compiler built a given `.ali` file by its first line
   (`GNAT` vs `GNAT-LLVM`).

Notes:

- GNAT LLVM and GCC GNAT are not guaranteed ABI-compatible; compile all Ada in
  a project with the same compiler.
- GNAT LLVM's `-fstack-check` support is partial and some features
  (`Scalar_Storage_Order`, `Convention C++`) differ from GCC GNAT.
- SPARK proof results are compiler-independent, so `covex prove` and the
  DAL assessment are unaffected by the choice.
