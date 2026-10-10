# adacovex 1.59.0

Date: _2026-10-10_

Version bumped 1.58.0 -> 1.59.0.

## Changes

### C1: `Adacovex.Paths` is the one place a platform path decision lives

adacovex grew on Linux and WSL, so POSIX assumptions sat inline in several
packages. `src/adacovex-config.adb` tested a target with a leading `/`, the
directory-snapshot memo re-joined a Windows absolute path with the working
directory, and the cache root fell back to `/tmp` on a host that has no `/tmp`.
On Windows this made a bare run fail with an invalid path name, because the
default target `C:\project` was treated as relative and joined onto itself.

`Adacovex.Paths` now owns every such decision in one unit:

- `Is_Separator` accepts both `/` and `\`, and `Is_Absolute` recognises a
  POSIX root, a Windows drive letter (`C:\project`), and a UNC root.
- `Join` and `Strip_Trailing_Separators` answer the common path composition
  and normalisation questions with one rule each.
- `Home_Directory` reads `HOME`, then `USERPROFILE`, then the system temp
  directory; `Expand_User` expands `~` and `~/rest` (also `~\rest`).
- `Executable_Suffix` and `Executable_Name` append `.exe` once on Windows,
  so a bare-name probe of a deployed prover or an installed tool finds it.

`adacovex-config.adb`, `adacovex-dir_cache.adb`, `adacovex-cache.adb`, and
`adacovex_main.adb` now call the helper instead of spelling the rule inline.
The new Platform paths test category (41 checks) pins the separator, absolute,
join, strip, home, and executable-name rules on any host.

### C2: Every `GNAT.OS_Lib.To_C` result is carried as a `Long_Long_Integer`

Some GNAT runtimes declare `GNAT.OS_Lib.To_C` to return `Long_Integer`, and
others declare `Long_Long_Integer`. A bare assignment therefore compiled on
one toolchain and failed on another. Each call now wraps its argument in an
explicit `Long_Long_Integer` conversion, which is legal for both signatures,
so a 64-bit time stamp is never shrunk by an implicit 32-bit conversion on
Win32. The convention is recorded in the platform-agnostic design notes.

### C3: `just` is the task runner, and the `Makefile` is a shim

The build recipes moved from shell in the `Makefile` to `tools/tasks.py`, with
one recipe per task in a `justfile`. The `Makefile` now delegates every target
to the same Python task, so an existing `make <task>` reference still works
while `just <task>` is the primary form. The migration removes the GNU-only
`sed -i` and `grep \+` constructs that could not run on BSD or macOS, and it
makes the task list discoverable with `just --list`.

## Fixes

### H1: `parse_gpr` no longer raises `Constraint_Error` on a `with` clause

`Adacovex.Parsers.Manifest.Parse_GPR` assigned a shorter slice to a string
object whose length was fixed by its initial value, so a `with "x.gpr";`
clause raised `Constraint_Error` (length check failed). The parser now binds
the stripped name to a fresh constant, and a fixture with a `.gpr` suffix
covers the case the earlier fixtures missed.

### H2: The Windows build reserves a larger main-thread stack

Windows reserves about 1 MiB for the main-thread stack, and a few functions
hold several large fixed-size line buffers in one frame. The build reserved
32 MiB so a deep tree cannot trip `STORAGE_ERROR`. The reserve moved into
`adacovex.gpr` in 1.60.0, so a plain `alr build` carries it too.

## Test Suite

1815 tests across 27 categories, up from 1796 across 26 in 1.58.0. The new
Platform paths category carries 41 checks over the separator, absolute, join,
strip, home, and executable-name rules. The cache tests now rebuild the
stamp and probe paths from the platform cache directory instead of a literal
`~/.adacovex`.

`just test` runs the native suite, `just cli-e2e` runs the end-to-end suite,
and both pass on this tree.

## Proof Results

**Platinum**, 0 unproved, 0 justified, **1047 of 1047 VCs across 70 analysed
units** under gnatprove 16.1.0 at `--level=4`. The counter is unchanged from
1.58.0: the new predicates and the bounded conversions add no runtime check
that gnatprove must discharge beyond what the campaign already carried.

`Adacovex.Paths` is a default-off I/O body: the package spec is SPARK-visible,
so its predicates and contracts are usable in proved code, while the body
reads the environment and probes the filesystem. A concatenation of two
unbounded strings is not provable without bounding every component, so the
body joins the default-off set that AGENTS.md allows for an I/O-heavy unit.
It carries no explicit `pragma SPARK_Mode (Off)`, so `spark-off-check` stays
green.

## Traceability

No new HLR record enters this release, and no tag is added or removed. The
new `Adacovex.Paths` unit is covered by `HLR-ARCH`, on record for the
architecture and path handling of the tool. The packages changed by this
release, and the tags already on record that cover them: `Adacovex.Config`
(`HLR-CLI`), `Adacovex.Cache` (`HLR-CACHE`), `Adacovex.Dir_Cache`
(`HLR-SCAN`), `Adacovex.Parsers.Manifest` (`HLR-SBOM`), and the CLI entry
point (`HLR-ARCH`). C2 and H1 change no requirement: they make an existing
contract portable and fix a parser defect.
