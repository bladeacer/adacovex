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

When both files exist, `alire.toml` takes precedence for manifest scanning and
SBOM generation. The `alire-dev.toml` is consulted only for toolchain
resolution (gnatprove detection) via `Manifest_Declares_GNATprove`, which
checks both manifests.

### Dev-manifest proof swap (`prove` subcommand)

adacovex declares `gnatprove` only in its own `alire-dev.toml` (keeping the
publishing `alire.toml` clean). The `prove` subcommand detects this
(`Gnatprove_Dev_Only`), and runs the proof through a temporary `sh` wrapper
that:

1. Backs up `alire.toml`, `alire.lock`, and `alire/` to a `mktemp -d`
   directory,
2. swaps `alire-dev.toml` over `alire.toml` so `alr exec` resolves the
   development toolchain,
3. runs `alr exec -- gnatprove -P <gpr>`,
4. restores the backed-up files via a `trap ... EXIT INT TERM` (also on
   failure or interruption).

The same rule applies to target projects: a target that keeps gnatprove in its
own `alire-dev.toml` gets the identical dev-manifest swap, so the publishing
`alire.toml` is always clean.

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
declarations from heavily code-generated projects are never truncated or
silently drained.

This ensures adacovex can be built and run on any system with a GNAT toolchain,
without requiring any additional package installation beyond Alire for
toolchain management.

## SPARK Formal Verification

adacovex itself is SPARK-proven at Platinum level (500/500 VCs proved,
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

adacovex uses a native zero-dependency test framework (`Adacovex.Test_Support`) with 295 tests across 10 categories. No external test framework (AUnit, etc.) is required. Test results are written to `docs/test_result.md` in a parseable Markdown table format.

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
  `alire-dev.toml` and `Adacovex.Version` in `src/adacovex.ads`, bumped together
  by `make bump-version`.
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
  `actions/attest-build-provenance` (OIDC), and the release notes link the
  signed attestation.

## Read Only

adacovex itself is read-only. It merely scans your codebase for target docstrings and proofs.

It does not make edits in place or on your behalf.

## Flexible

adacovex lets you write proofs and decide where proofs are pointless (e.g. code that has to involve manual memory management). You just have to justify your rationale. The tool should not be rigid and expect 100% proving for all use cases.

You write the proofs yourself, so there is no magic or hidden abstractions here.
