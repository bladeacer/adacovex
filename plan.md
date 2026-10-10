# Adacovex platform and numeric-type plan

## Status

Implemented in the working tree. The Windows portability fixes, the
`Long_Long_Integer` time-stamp contract, the path abstraction, the task-runner
migration, and the supporting docs and tests are in place. The remaining step
is to run the tree's sync and gate commands on a machine with the GNAT
toolchain and Python 3, because this host has no `bash` and cannot run them
(see "Verification" below).

## What changed

- **`Adacovex.Paths`** (`src/core/adacovex-paths.ads`/`.adb`) is the single
  place for a platform path decision: `Is_Separator` (both `/` and `\`),
  `Is_Absolute` (POSIX root, Windows drive letter, UNC root), `Join`,
  `Strip_Trailing_Separators`, `Home_Directory` (HOME, then USERPROFILE, then
  the temp directory), and `Expand_User` (`~` and `~/rest`, also `~\rest`).
- **`adacovex-config.adb`** resolves a target with `Paths.Is_Absolute` instead
  of a leading-`/` test, and `Expand_User_Path` delegates to
  `Paths.Expand_User`.
- **`adacovex-dir_cache.adb`** uses `Paths.Is_Absolute` in `Abs_Key`, so a
  Windows absolute path is no longer re-joined with the working directory.
- **`adacovex-cache.adb`** derives the cache, stamp, probe, and meta roots
  from `Paths.Home_Directory`, strips either separator in `Set_Cache_Dir`,
  and carries the result of every `OS_Lib.To_C` call as an explicit
  `Long_Long_Integer`.
- **`adacovex_main.adb`** normalises a path with both separators, keeps a
  drive or UNC root, and emits a canonical `/` form.
- **`parse_gpr.adb`** binds the `.gpr`-stripped name to a constant, so a
  `with "x.gpr"` clause no longer raises `Constraint_Error`.
- **`tools/build.py`** reserves a larger Windows main-thread stack
  (`-Wl,--stack,33554432`) and falls back to a copy when a symlink is refused.
- **`tools/tasks.py`** and **`justfile`** are the new task runner; the
  `Makefile` is a thin shim that delegates to the same Python tasks.
- **`Adacovex_Paths_Tests`** (25 checks) pins the separator, absolute, join,
  strip, and home rules.

## Verification

Run these on a machine with `gprbuild`, `gnatprove`, and Python 3 (the
generated files and the metrics are refreshed by them and are not hand-written
artifacts):

```
just test
just test-count
just description
just agents-tree
just book
just doc
just prove
just check
```

`just release` and its version bump stay a separate release action, as before.

## Notes

- The tree has no vendored components; a vendored-code regression is only
  measurable on a fixture with the same shape.
- `just check` resolves `gnatprove` for you, so no manual prover installation
  is required.

## Deferred to the EndeavourOS machine (v1.59.0 and v1.60.0 proof timing)

The `docs/contributing/perf/prove-timing.md` phase table still names
`1.57.0-1.58.0` as the open phase. 1.59.0 and 1.60.0 change no measurement
methodology, so they fold into that phase, but the fold-in and any re-measured
`make prove` / `make bench` figures must be taken on the EndeavourOS machine,
where the figures are comparable with the Linux columns. This Windows host
cannot produce a comparable wall, so the table is left as-is for now.

When the EndeavourOS machine is available:

1. Check out this tree and run `just prove` and `just bench` on the release
   profile (gnatprove 16.1.0, the same logical-core and job settings the page
   records), with `/proc/loadavg` recorded beside each figure.
2. Re-measure the warm `newfstatat` count with strace for the current tree.
3. Fold 1.59.0 and 1.60.0 into the open phase: rename the phase range to
   `1.57.0-1.60.0`, keep 1.58.0 as the representative unless the new figures
   justify a different representative, and add the fold-in bullet to the
   reading notes. State the reason in the reading notes if the representative
   changes.
4. Update the AGENTS.md phase-list sentence ("so far 1.45.0-1.47.0,
   1.48.0-1.54.0, 1.55.0-1.56.0, 1.57.0-1.58.0") to the new open-phase range.
5. Run `just check` on that machine to re-verify the whole gate with sphinx
   installed, so the committed offline-manual spec is regenerated.
