# Adacovex platform and numeric-type plan

## Status

Open investigation. The user is on EndeavourOS x86_64 and will attempt a
Windows 64-bit reproduction of the numeric/Timestamp compile diagnostics.
This file records the initial findings and the remaining fields to fill in.

## Background

The tree ships (or must be made to ship) on Win32, Win64, ARM, Linux, and
niche combinations, and Alire itself must run and be installed on all of
them. Two concerns dominate:

1. **Numeric and timestamp correctness across word sizes and ABIs.**
2. **Obvious, explicit platform support documentation.**

## Initial findings

- `src/core/adacovex-types.ads` derives `Max_Path` and `Max_Line` from
  `System.Word_Size` (`64 * Host_Word_Bits`, `4096 * Host_Word_Bits`), so
  narrower hosts keep proportional buffers. The fixed-size strings
  (`Desc_Field`, `Path_Field`, `Name_Field`) are bounded at compile time
  and widen with the host word size.
- `src/core/adacovex-cpus.adb` is the only user of GNAT.OS_Lib in the
  tree, and `Run_Capture` passes command arguments as a GNAT.OS_Lib
  argument list (`Argument_List`, `new String'(...)`). The Windows
  variants of that ABI are the remaining unknown.
- `src/core/adacovex-cpus.ads` documents the detection cascade
  (Linux /proc/cpuinfo, macOS/FreeBSD sysctl, nproc fallback,
  NUMBER_OF_PROCESSORS, PowerShell CIM) and the two temp-directory env
  vars (TMPDIR, TEMP, TMP). The platform note in
  `docs/usage/platforms.md` is what the user-facing page must state.
- `docs/contributing/perf/benchmarks-server.md` already reflects the
  current 1.58.0 server numbers (`~45k/~94k/~84k` req/s; `0.02-0.15` ms
  latency).
- `docs/contributing/perf/prove-timing.md` keeps the one-column-per-phase
  rule with 1.58.0 as the open representative (1047 VCs; the only real
  v1.59.0 numbers would come from an actual `make prove` build, which is
  not something this tree can produce here).

## Remaining unknowns to fill in

- Exact Windows compile semantics of the four GNAT.OS_Lib usage sites
  in `adacovex-cache.adb` and the `Run_Capture` body of
  `adacovex-cpus.adb` once a Windows build is available. Until then,
  the plan records the contract the fix must satisfy: every
  `File_Time_Stamp` and `Current_Time` value must be carried as a
  `Long_Long_Integer` on every target, with no implicit 32/64 shrinking
  on Win32. `To_C` is the documented conversion; the guard is the
  `Long_Long_Integer` result of the conversion, never a hard-coded
  width assumption.
- Where `docs/usage/platforms.md` states which platforms and ABIs are
  supported, which adjectives the user-facing docs use for the
  platform matrix, and what `--standard=all` does for a non-avionics
  standard set.
- Any other numeric casts or `Integer` conversions in the tree that
  shrink a platform-dependent value before storage.

## Plan of record

1. Implement the numeric/Timestamp platform contract (already the case
   in the tree for the four `OS_Lib.To_C` sites; make it permanent).
2. Add unit tests that pin the `Long_Long_Integer` contract, register
   them in `test_runner.adb` as a new category (runner object, table
   row, both totals).
3. Document the platform matrix and the platform support story in
   `docs/usage/platforms.md`.
4. Close the v1.59.0 release record (changelog, manifest version, perf
   page, `AGENTS.md` perf reference) with a real `make prove` run on a
   machine that has `gprbuild`, `gnatprove`, and `System.OS_Lib`, not by
   manufacturing artifacts.

## Notes

- The tree has no vendored components, so a vendored-code regression
  cannot be measured on the self tree; that shape is only measurable on
  a fixture with the same shape.
- `make prove` on an unchanged tree (~1.12 s) is *not* the warm
  short-circuit: it also regenerates the bundled manual and the
  dashboard template and re-checks the generators.
- The v1.59.0 numeric/timestamp contract work does not include the
  1.59.0 release-record files.
