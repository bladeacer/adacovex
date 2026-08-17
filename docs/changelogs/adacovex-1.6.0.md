# adacovex 1.6.0

Date: _2026-08-05_

Version bumped 1.5.0 -> 1.6.0.

## Changes

### C1: Full SPARK proof coverage (Platinum, 0 unproved)

The whole SPARK-on codebase is now fully machine-proved. Previously only the
bounded IR types (`Checked_Add32/64`, `IR_Bounds.Add32/64`) carried complete
proofs; every other SPARK unit was analyzed but not fully discharged. Now
**all 491 VCs prove** with `--prover=z3 --timeout=20`, including the run-time
range checks, assertions, functional contracts, and loop termination:

- **Renderers**: `I2S` (fixed `10**Pos` overflow by replacing exponentiation
  with a constant `Pow10` power table, loop invariants carrying the digit
  count and value bound, `Buf` initialized), `Pad2` and `Escape_JSON`
  (uninitialized-buffer fixes via `(others => ' ')`), and `ISO_From_Epoch`
  (chained `&` concatenation upper-bound proofs replaced by a bounded
  `Field`-copy buffer procedure). Postconditions now document the result
  lengths (`I2S'Result'Length in 1 .. 10`, `Pad2'Result'Length in 1 .. 11`).
- **Parsers**: `Trim`, `Trim_Left`, `Number_After`, and `Number_Before_Word`
  gained `Pre => S'First >= 1 and S'Last < Natural'Last` preconditions plus
  strengthened loop invariants (carried array-index bounds and the digit-run
  range `for all Q in DStart .. K => S (Q) in '0' .. '9'`).
- **IR synthesiser**: `Bits`, `IR_Type_Name` (`Post => 'Result'Length <= 9`),
  `Lower_Type_Name`, and `Synthesize_Package` (buffer bounds, `Sub`/`Result`
  initialization, and `J >= I` for the outer-loop variant) all proved.
- **Termination**: every `while` loop across the codebase now carries an
  explicit `Loop_Variant` (increasing or decreasing bound), so the implicit
  `Always_Terminates` aspects discharge -- no loop is left as potentially
  non-terminating.

The self-assessment is now: 26 packages, 59 subprograms, 100% docstrings,
**Platinum (500/500 VCs, 0 unproved)**, 295/295 tests, DAL-C Achieved.

### C2: Host word-size auto-detection

Fixed-size buffers and the IR host model are now derived from the actual host
word size instead of being hard-coded to 64-bit assumptions:

- `Adacovex.Types.Host_Word_Bits : constant := System.Word_Size`; the
  `Max_Path` / `Max_Line` path and line buffers scale with it
  (`64 * Host_Word_Bits` = 4096, `4096 * Host_Word_Bits` = 262144 on a 64-bit
  host), so builds on narrower hosts use proportionally smaller limits. The
  semantic limits (`Max_Id_Str`, `Max_Desc_Str`, `Max_Filename`) stay fixed.
- `Adacovex.Target_Profiles.Host_Word_Size` auto-detects the host word size
  (8/16/32/64) from the Ada runtime for `Target_Config.Host_Bits`, with the
  dead-branch warning resolved by a `case System.Word_Size` structure.
- Test suite extended: 6 new checks (Types conversion + IR host-word-size
  detection). The suite is now **295 tests**.

### C3: Conventional test-result file discovery

The test-summary lookup is no longer hard-coded to `<target>/test_result.md`.
A new `Parse_Test_Result_From_Project` searches a conventional list of
test-result file names at the project root (and under `docs/`) and parses the
first file that exists -- `test_result.md`, `test_results.md`,
`test-result.md`, `test_report.md`, `test_output.md`, the equivalent `.txt`
and `.log` variants, `tests.md`/`tests.txt`, and the `docs/` mirrors. The
assessment, `sbom`, and `--compare-base` paths all use the new lookup, so
adacovex accepts common report conventions (e.g. CI that emits
`test_results.md` or `test-output.txt`) without configuration. The parser
itself already understood Markdown tables, plain `Passed:`/`Failed:` summary
lines, TAP, Automake, Maven Surefire, and Unity formats. The new candidate
search adds one SPARK-proved helper (`Trim_Right`, fully discharged) and 9 new
VCs, taking the self-assessment to **500/500 VCs Platinum**.

## Fixes

### H1: Changelog link in the release workflow

`.github/workflows/release.yml` built the changelog permalink from the raw tag
name (`v1.6.0`), producing a broken `/docs/changelogs/adacovex-v1.6.0.md`
URL. The link now strips the leading `v` (`${VERSION#v}`) so it points at
`docs/changelogs/adacovex-1.6.0.md`.

The same release step now also:

- **Links the build-provenance attestation** in the release notes. The
  `actions/attest@v4` step is captured (`id: attest`) and its
  `attestation-url` output is included as a *Build Provenance Attestation*
  entry, so consumers can jump straight from the release to the signed
  SLSA provenance bundle.
- **Fixes the *Git Changelog* compare link** to use the tag form
  `compare/v1.5.0...v1.6.0` (previous version keeps its `v` prefix), matching
  GitHub's tag-to-tag compare URL convention instead of the version-only form
  produced by stripping the `v`.

### H2: Honest SBOM proof levels + badge contrast + install docs

- **SBOM proof levels**: Only the root component -- the project adacovex
  actually assessed -- now carries `adacovex:proof_level`
  (`Gold`/`Platinum`) and `adacovex:dal_target`. Dependency components report
  `adacovex:proof_level = "Not proved"`: adacovex only proves the target
  itself, never third-party dependencies, so they no longer claim a
  Gold/Platinum level they did not earn. Applied to CycloneDX, SPDX, and
  Markdown outputs; the `Write_SBOM` summary line now says "root proof level".
- **Platinum badge contrast**: the SPARK badge used white text on the light
  platinum background (`#E5E4E2`), which failed contrast. Added a
  `Spark_Text_Color` selector (`#1a1a1a` on Platinum/Gold/Silver, white on
  Bronze/Stone) and a `Value_Text_Color` parameter to `Badge_SVG`.
- **Installation docs**: README now documents installing adacovex via
  `alr install covex gnatprove` (add Alire's bin dir to `$PATH`), downloading
  the version-matched release bundle with `curl` from the GitHub Releases page
  (verifiable with `gh attestation verify`), or building from source. The
  `prove`-mode GNATprove toolchain resolution order
  (per-project manifest -> `$PATH` -> cached toolchain -> download) is
  documented, including the "install Alire first" fallback when a manifest
  declares gnatprove but `alr` is missing.
- **SBOM timestamp to git commit**: documented how to tie the deterministic
  `SOURCE_DATE_EPOCH` timestamp to the exact commit (`git -C <target> log -1
  --format=%ct`); the make targets already do this from `HEAD`.

### H3: Back to zero-dependency -- gnatprove moved out of `alire.toml`

- **`alire.toml` no longer declares gnatprove.** The covex crate is once again
  fully zero-dependency: no library or tool dependencies. `gnatprove` lives
  only in `alire-dev.toml` (used by the local make targets), and the `prove`
  subcommand resolves it at run time via the dev-manifest swap, `$PATH`,
  `~/.adacovex/toolchain/`, or a download. Installing `covex` no longer drags
  in gnatprove or the proof solvers.
- **Install docs prefer the per-project manifest.** README/AGENTS now lead
  with declaring `covex` (plus `gnatprove` when proofs are wanted) in the
  project's `alire-dev.toml`, keeping `alr install covex gnatprove` as the
  documented global alternative, alongside the GitHub release bundle and
  from-source installs.
- **Architecture decision: supported platforms.** Since Alire is the packaging
  and delivery mechanism, adacovex supports the platforms Alire itself
  supports -- binary distribution on Linux x86-64, Windows x86-64, and macOS
  x86-64, and building from source on any host with GNAT FSF 9.2+ that can
  build Alire. Added to `docs/architecture.md`.
- **Architecture decision: CI tied to release version.** Documented that the
  GitHub Actions action is version-matched to the binary (the release workflow
  bundles `adacovex-vX.Y.Z.tar.gz` for each tag, and the action downloads the
  binary for the tag it is referenced by, with floating `vMAJOR` / `vMAJOR.MINOR`
  / `latest` tags force-pushed at release time). CI runs on `ubuntu-latest`
  with the pinned `gnat-version`.
- **Release/index manifest templates** (`alire/releases/covex-0.0.0.toml`,
  `index/ad/covex/covex-0.1.0-dev.toml`, and the 1.6.0 variants) dropped the
  gnatprove dependency; `alire/alire.lock` regenerated accordingly.
- The toolchain-resolution and THIRD_PARTY_NOTICES wording now state plainly
  that adacovex declares no gnatprove dependency and resolves it at run time.

### H4: Compiler/proof warning cleanup + gnatprove standard companion

- **Remaining build warnings fixed.**
  - `Adacovex.Renderers.SBOM`: the compiler inlined `Field` and constant-folded
    its `Sep /= ASCII.NUL` guard, so the check reported "statement has no
    effect" at the call sites. Kept the original single-loop form and wrapped
    it in `pragma Warnings (Off/On, "statement has no effect")`; the
    two-loop `String` alternative was tried and reverted because it cost 35
    unproved VCs. Proof remains intact: 500/500 VCs, Platinum, 0 unproved.
  - `Adacovex.Target_Profiles`: `Host_Word_Size` is now a return-expression
    `case` (instead of an unreachable multi-branch `case` statement on the
    64-bit archive host), eliminating the "statement is never reached"
    warnings at lines 10/13/16.
  - Forced rebuild: **0 warnings**. `make prove`: **Platinum, 500/500 VCs,
    0 unproved, 0 justified**. `make test`: **295/295**.
- **`gnatprove` is now the standard companion in every covex TOML usage.**
  README (Option 1) and AGENTS (install item 1, dev-manifest usage) declare
  `covex = "*"` with `gnatprove = "^15.1.0"` in the same manifest. The GitHub
  Actions `action.yml` no longer passes `gnatprove` to `alr toolchain`
  (`gnatprove` is not a toolchain component; that failed CI with "The requested
  crate is not a toolchain component") -- it selects only `gnat_native` and
  `gprbuild`, and the `prove` subcommand resolves gnatprove via the target
  project's `alire-dev.toml` (README-preferred method), falling back to
  `$PATH`, the cached toolchain, or download. The "if you also want proof runs"
  phrasing was removed.
- **GitHub Actions attestation migrated to `actions/attest`.** The release
  workflow now uses `actions/attest@v4` with `subject-path:
  adacovex-*.tar.gz` (kept `id: attest` + `attestation-url` output);
  `attest-build-provenance@v2` is gone. All prose references (README, AGENTS,
  `docs/architecture.md`, Makefile) updated.
- **Crate tags expanded to 11** across `alire.toml`, `alire-dev.toml`, the
  release templates, and the index templates: `ada`, `spark`,
  `formal-verify`, `cli`, `gnatprove`, `sbom`, `tests`, `code-coverage`,
  `do-178c`, `compliance`, `developer-tools`. (`formal-verify` is used because
  Alire caps tag strings at 15 characters.)
- **Remaining badge contrast fixed.** The bright-green (`#4c1`) and yellow
  (`#dfb317`) badge values used white text. Added a `Badge_Text_Color`
  selector: dark `#1a1a1a` text on `#4c1`/`#dfb317`, white on the red
  `#e05d44`, matching the SPARK badge's approach. `tests.svg`, `do178c.svg`,
  and `docs.svg` regenerate with dark value text; SVG tests still pass.
- **`install.sh` documents `curl | bash` and checks for Alire.** README Option
  3 now leads with the one-liner
  (`curl -fsSL .../main/install.sh | bash`), and the script warns when `alr`
  is missing from `$PATH`, pointing at `curl https://alire.ada.dev -sSf | sh`
  and the remaining gnatprove fallbacks (`$PATH`, cached toolchain, download).
- **"zero-library-dependency" -> "zero-dependency".** Renamed across README,
  AGENTS, and the `alire.toml` long-description (the published 1.0.0-1.5.0
  release records keep their historical wording).

## Test Suite

Test suite extended: IR synthesis 26 -> **27** checks plus six new word-size
checks (Types conversion + IR host-word-size detection); the suite is now
**295 tests** (passing).

## Proof Results

Self-assessment: **Platinum** (500/500 VCs proved, 0 unproved, AoRTE-free).
Every SPARK-on unit is fully discharged -- run-time checks 358/358,
assertions 60/60, functional contracts 13/13, termination 44/44, flow
69/69. Proof invocation: `gnatprove -P adacovex.gpr --prover=z3 --timeout=20`.

## Traceability

No new HLRs. Existing tags continue to cover the changed packages:
`-- HLR-SCAN` on `Adacovex.Parsers.Source`, `-- HLR-TEST` on
`Adacovex.Parsers.Tests`, `-- HLR-PROVE` / `-- HLR-METRICS` on
`Adacovex.Types`, `-- HLR-IR` on `Adacovex.Target_Profiles` and
`Adacovex.IR_Synthesiser`, `-- HLR-SBOM` on `Adacovex.Renderers.SBOM`.
The HLR-SBOM wording was tightened to reflect that only the root component
carries proof-aware properties while dependencies are reported as "Not proved".
