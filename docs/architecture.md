# adacovex Architecture Decisions

## Dependency Management: Alire

adacovex uses [Alire](https://alire.ada.dev/) to manage all dependencies. The project declares `gnatprove` as a tool dependency in `alire.toml`, which is the canonical publishing manifest. Development-only tools (`gnatdoc_bin`, `gnatformat_bin`) are declared in `alire-dev.toml`, which is never published to the Alire community index.

### Manifest distinction (`alire.toml` vs `alire-dev.toml`)

- **`alire.toml`**: The clean publishing manifest. Contains only runtime and tool dependencies needed for the assessment pipeline (currently `gnatprove`). Used for SBOM generation and dependency graph scanning.
- **`alire-dev.toml`**: The development manifest. Extends `alire.toml` with dev-only tools (`gnatdoc_bin`, `gnatformat_bin`) needed for `make doc` and `make fmt`. Used for toolchain resolution when running `alr exec`.

When both files exist, `alire.toml` takes precedence for manifest scanning and SBOM generation. The `alire-dev.toml` is consulted only for toolchain resolution (gnatprove detection) via `Manifest_Declares_GNATprove`, which checks both manifests.

### Dev-manifest proof swap (`prove` subcommand)

Target projects may declare `gnatprove` only in `alire-dev.toml` (keeping the
publishing `alire.toml` clean). When the `prove` subcommand detects this
(`Gnatprove_Dev_Only`), it runs the proof through a temporary `sh` wrapper
that:

1. Backs up `alire.toml`, `alire.lock`, and `alire/` to a `mktemp -d`
   directory,
2. swaps `alire-dev.toml` over `alire.toml` so `alr exec` resolves the
   development toolchain,
3. runs `alr exec -- gnatprove -P <gpr>`,
4. restores the backed-up files via a `trap ... EXIT INT TERM` (also on
   failure or interruption).

The assessment and SBOM pipeline always scans the publishing `alire.toml`, so
dev-only tool declarations never leak into dependency graphs or SBOMs.

## Unix Philosophy

adacovex follows the Unix philosophy of doing one thing well:

- **Single-purpose pipeline**: Each step (scanning, proof parsing, test parsing, DAL assessment, rendering) is a focused, composable unit.
- **Text-based interfaces**: Input and output are plain text (Ada source, `.out` files, Markdown reports, ANSI terminal output).
- **No library dependencies**: Only the GNAT runtime is used. No external libraries, frameworks, or package managers beyond Alire for toolchain management.
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
declarations from heavily code-generated projects are never truncated or
silently drained.

This ensures adacovex can be built and run on any system with a GNAT toolchain, without requiring any additional package installation beyond Alire for toolchain management.

## SPARK Formal Verification

adacovex itself is SPARK-proven at Platinum level (491/491 VCs proved,
AoRTE-free). The tool analyzes GNATprove output (`gnatprove.out`) to assess
SPARK assurance levels (Stone through Platinum) for target projects.

The tool does not perform verification itself -- it parses and reports on proof results produced by GNATprove. This keeps the tool's scope narrow and aligns with the Unix philosophy of composing specialized tools.

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
- Subprogram declarations (`procedure`, `function`, `generic procedure`, `generic function`)
- Docstring annotations (`--  ` prefix with optional `@param`, `@return`, `@field`, `@formal` tags, plus Google `Args:`/`Returns:` blocks and Sphinx `:param:`/`:returns:` fields)
- HLR traceability tags (`-- HLR-XXXX`)

In strict mode (default), the scanner also applies docstring patches from `.adacovex/patches/` to document vendored/third-party code without modifying the originals.

## Patch System

The `.adacovex/patches/` directory allows overlaying docstring information onto third-party or vendored code. Patch files are valid Ada specs with docstrings; the scanner merges `Has_Docstring`, `Doc_Param_Ct`, and `Doc_Return` into matching originals. This enables 100% docstring coverage without modifying vendored dependencies.

## Output Formats

adacovex supports multiple output formats:

- **ANSI terminal report**: Color-coded summary for interactive use
- **SVG badges**: `spark.svg`, `tests.svg`, `do178c.svg`, `docs.svg` for CI badges
- **Markdown reports**: `VERIFICATION.md` and `TRACE.md` for compliance documentation
- **HTML dashboard**: Interactive web dashboard with JSON API (`--serve`)
- **SBOM**: CycloneDX 1.5, SPDX 2.3, or Markdown format with proof and DAL properties

## Testing

adacovex uses a native zero-dependency test framework (`Adacovex.Test_Support`) with 246 tests across 9 categories. No external test framework (AUnit, etc.) is required. Test results are written to `docs/test_result.md` in a parseable Markdown table format.

## Read Only

adacovex itself is read-only. It merely scans your codebase for target docstrings and proofs.

It does not make edits in place or on your behalf.

## Flexible

adacovex lets you write proofs and decide where proofs are pointless (e.g. code that has to involve manual memory management). You just have to justify your rationale. The tool should not be rigid and expect 100% proving for all use cases.

You write the proofs yourself, so there is no magic or hidden abstractions here.
