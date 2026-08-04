# adacovex 1.5.0

Date: _2026-08-05_

Version bumped 1.4.0 -> 1.5.0.

## Changes

### C1: More standard docstring styles

The source scanner now recognizes additional standard docstring conventions,
so third-party and code-generated Ada is counted correctly:

- Comment prefixes: besides the canonical `--  ` (two dashes + two spaces),
  the single-space `-- ` and tab-separated (`--<TAB>`) styles are recognized
  as docstrings. A bare `--` or `---` divider is still not a docstring.
- Tag aliases: `@parameter` == `@param`, `@returns` == `@return`.
- Summary tags: `@brief` and `@summary` mark a subprogram as documented.

### C2: More test-result formats

`Adacovex.Parsers.Tests` now also parses the following standard formats
(additively with the existing Markdown-table parser):

- **TAP** -- `ok N - name` / `not ok N - name` lines
- **Automake** test-suite -- `PASS: name` / `FAIL: name` lines
- **Maven Surefire** -- `Tests run: N, Failures: M, Errors: E` summaries
  (failed = failures + errors)
- **Unity** -- `N Tests M Failures` summaries (the count may be separated
  from the word by spaces)

### C3: Longer source lines

`Max_Line` is raised from 8192 to **262144** characters, so single-line
declarations from heavily code-generated projects (previously drained
silently) are parsed in full.

### C4: Dev-manifest proof swap (`prove` subcommand)

When the target project declares `gnatprove` only in `alire-dev.toml` (keeping
the publishing `alire.toml` clean), the `prove` subcommand now runs the proof
through a temporary shell wrapper that backs up `alire.toml` / `alire.lock` /
`alire/`, swaps the dev manifest over the publishing one, runs
`alr exec -- gnatprove -P <gpr>`, and restores everything (via `trap ...
EXIT INT TERM`) even on failure or interruption. The assessment and SBOM
pipeline always scans the publishing `alire.toml`, so dev-only tool
declarations never leak into dependency graphs or SBOMs. This fixes
`make run-ada-crdt` / `make prove` against projects (e.g. Ada_CRDT) that keep
gnatprove out of their publishing manifest.

### C5: IR layer -- bounded target type profiles

New `src/ir/` layer implements the first stage of an intermediate
representation for cross-compilation assessments:

- `Adacovex.Target_Profiles` (SPARK On): bounded machine-integer types
  `IR_Int8`..`IR_Int64` (fixed-width signed ranges with `Size` clauses) and
  `IR_UInt8`..`IR_UInt64` (modular unsigned), plus `Word_Size` and a
  `Target_Config` record carrying `Host_Bits` / `Target_Bits` / `Pointer_Bits`.
  `Checked_Add32` / `Checked_Add64` perform overflow-checked addition on the
  bounded types.
- `Adacovex.IR_Synthesiser` (SPARK Off, string generation): `IR_Type_Name`,
  `Lower_Type_Name` (case-sensitive: `int8_t`..`uint64_t`, `size_t`/`usize`
  -> unsigned target-width, `isize` -> signed target-width, `ptrdiff_t` /
  `uintptr_t` -> pointer-width), and `Synthesize_Package` that splits a
  comma/whitespace-separated type list into synthesized bounded Ada
  declarations.
- `Adacovex.IR_Bounds` (SPARK On): a gnatprove fixture that derives
  `int32_t` / `int64_t` from the bounded IR types and proves the overflow
  checks on `Add32` / `Add64` -- absence of integer overflow on the lowered
  types is machine-checked.

### C6: Google / Sphinx docstring styles

The source scanner now also recognizes the two most common non-Ada docstring
conventions, so the same subprogram can be documented in Ada, Google, or
Sphinx style:

- **Google**: `Args:` / `Args: ...` headers open a parameter block
  (deeper-indented following comment lines count as parameters); a `Returns:`
  header marks the return-value description.
- **Sphinx**: `:param Name:`, `:parameter Name:`, `:type Name:`, `:return:`,
  `:returns:`, and `:rtype:` fields are all recognized.

## Fixes

### H1: Unity summary count separated by a space

`Number_Before_Word` only looked at the character immediately before the
keyword, so `1 Failures` (number + space + word) parsed as zero failures and
overwrote the correct totals. It now skips spaces back to the preceding digit
run.

## Notes

- Test suite extended: Source scanner 40 -> **68** checks (comment-style
  variants, tag aliases, Google/Sphinx styles, 12000-char single-line
  declaration); Test-result parser 27 -> **35** checks (TAP, Automake,
  Surefire, Unity); new **IR synthesis** category (**26** checks). The suite
  is now **284 tests**.
- Self-assessment metrics: 26 packages, 57 subprograms, 100% docstrings,
  Platinum (36/36 VCs), 284 tests, DAL-C Achieved.

## Proof Results

Self-assessment: **Platinum** (36/36 VCs proved, AoRTE-free) -- the four
overflow-checked adds on the bounded IR types
(`Target_Profiles.Checked_Add32/64`, `IR_Bounds.Add32/64`) are all machine
proved. Ada_CRDT proof run verified end-to-end via the dev-manifest swap
(279 VCs, 5 justified).

## Traceability

New HLR `HLR-IR` (IR type profiles, host/target config, and foreign type-name
lowering) covers the new `src/ir/` packages. Existing tags continue to cover
the changed packages (`-- HLR-SCAN` on `Adacovex.Parsers.Source`,
`-- HLR-TEST` on `Adacovex.Parsers.Tests`, `-- HLR-PROVE` on
`Adacovex.Core.Prove`).
