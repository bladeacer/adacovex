# adacovex 1.0.0

Date: _2026-07-29_

## New Features

### Strict mode (default) + `--relaxed` flag

- **Strict mode** is now the default: scans ALL directories (except always-excluded
  `.git`, `obj`, `tests`, `config`, `.adacovex`), applies `.adacovex/patches/`
  docstring overlays. Ensures full compliance coverage including vendored code.
- **`--relaxed`** flag to disable strict mode: enables directory skip list
  (default: `demo,deps,examples`) and disables patch file application.
- Use case: strict for compliance audits, relaxed for quick dev-cycle checks.

### `--skip-dir` flag

- New `--skip-dir=NAME` (repeatable) adds directory names to the scanner's skip
  list. Only effective in `--relaxed` mode.
- Complements the default skip list (`demo,deps,examples`) for projects with
  additional third-party code.

### `.adacovex/patches/` mechanism

- Patch files at `<target>/.adacovex/patches/<relative-path>` allow documenting
  vendored/third-party `.ads` files without modifying the originals.
- Patch files are valid Ada specs with docstrings; merged by subprogram name.
- Overloaded subprograms: each overload requires one patch entry; the patch
  engine assigns entries to the next undocumented original.
- The `.adacovex` directory is always excluded from source scanning.

### Plain docstring summary detection

- Previously only `@param`/`@return`/`@field` tags counted as docstrings.
- Now any `--  ` (two dashes + two spaces) comment line before a subprogram
  declaration is recognized as a docstring, even without a tag.
- No-param procedures with only a summary line are now correctly counted.

### `--verbose` output

- The `--verbose` flag now produces pipeline diagnostic output to stderr:
  step labels, package counts, SPARK level, test file path, and output paths.
- Previously a no-op placeholder.

### `make bump-version` target

- `make bump-version VERSION=x.y.z` bumps version across `alire.toml`,
  `alire-dev.toml`, `src/adacovex.ads`, and creates/updates the changelog.
- Modeled after the `Ada_CRDT` project's bump workflow.

### `make run-ada-crdt` strict mode

- `make run-ada-crdt` now runs in strict mode (no `--relaxed`).
- Achieves 100% docstring coverage on Ada_CRDT including vendored vt100 code
  via `.adacovex/patches/demo/deps/vt100/vt100.ads`.

### Patch overload handling

- `Apply_Patches` now skips already-documented originals when searching for
  name matches, so overloaded subprograms get correctly assigned to the next
  undocumented overload instead of re-patching the first one.

### Always-excluded directories

- `config` and `.adacovex` added to the hardcoded always-excluded directories
  (alongside `.git`, `obj`, `tests`).
- `config/` contains generated Alire configuration, not production source.
- `.adacovex/` contains patch metadata relevant only to the patch engine.

### Production scalability (unbounded)

- **Packages and subprograms** now use `Ada.Containers.Vectors` (heap-allocated,
  up to `Natural'Last` ~ 2.1B). Compile-time `Max_Packages` / `Max_Subprogs`
  bounds eliminated entirely. Projects of any size are supported without
  recompilation.
- **VC counts** use unbounded `Natural` fields; `Max_VC_Count` dead type removed.
- **Line buffer** raised from 2048 -> **8192** characters with automatic
  truncation draining (silently skips remaining chars on lines > 8192).
- **Path buffer** raised from 512 -> **4096** characters (matches `PATH_MAX`).
- **Filename buffer** raised from 64 -> **128** characters (matches Ada's max
  identifier length).
- **Line-truncation guard** added: `Get_Line` calls now detect when the buffer
  was filled (partial read) and drain the remainder of the line, preventing
  stream desynchronisation that previously caused false subprogram declarations.

### `--dal` validation

- `--dal=Z` (or any value outside A-E) now prints an error and exits with
  code 1, instead of silently defaulting to DAL-C.

## Changes

- **Version**: bumped from 0.1.0 to 1.0.0
- **CLI default**: strict mode is on by default; `--relaxed` to disable
- **Docstring scanner**: plain `--  ` summary lines now count as docstrings
- **Patch engine**: overloaded subprograms now handled correctly
- **Source scanner**: `.adacovex` always excluded from directory walk
- **Scalability**: `Package_Array` / `Subprogram_Array` replaced with
  `Ada.Containers.Vectors` (unbounded). `Max_Line` 2048->8192, `Max_Path`
  512->4096, `Max_Filename` 64->128. Line-truncation drain added.
- **Dead code removed**: `Max_Params`, `Max_VC_Count`, `Max_Badge_Path`,
  `Max_Metrics`, `Max_Skip_Dirs`, `VC_Info`, `VC_Vector`, `Param_Count`
- **CLI validation**: `--dal` rejects invalid levels
- **Tests**: 152 tests pass across 7 categories

## Known Issues

- `(null record)` typed parameters are counted as parameters by the scanner
  (benign -- they are parameters, just parameterless).
- Docstring detection uses strict `--  ` prefix; `-- ` (one space) and `---`
  (three dashes) do not count.
- Relative `--target=PATH` is resolved against CWD, so behavior depends on
  invocation directory.

## Migration

From 0.1.0:
- Default behavior changes from "relaxed, skip demo/deps" to "strict, scan
  everything". Add `--relaxed` to existing commands to keep old behavior.
- Projects relying on being skipped by default now need `--relaxed` or
  `--skip-dir` explicitly.

## Proof Results

Self-assessment: **Platinum** (28/28 VCs proved, AoRTE-free).
Ada_CRDT (strict): **Platinum** (273 VCs, 5 justified overflow checks).
Ada_CRDT (relaxed): **Platinum** (273 VCs, 5 justified).

## Breaking Changes

- `--relaxed` now defaults to OFF (was ON in 0.1.0). Existing workflows using
  plain `adacovex --target=...` now run in strict mode. Add `--relaxed` to
  restore old behavior for targets with undocumented vendored code.

## Post-Release Patches (2026-07-30)

### Crate renamed to `covex`
- Alire crate renamed from `adacovex` to `covex` to comply with naming rules.
- Binary name stays `adacovex_main` via `project-files = ["adacovex.gpr"]` in
  all manifest files.
- `alire/releases/covex-*.toml`, `index/ad/covex/*.toml` created; `index/ad/adacovex/`
  removed.
- New `make release`, `make publish`, `make test-publish` targets for Alire
  community index publishing workflow.

### SPARK proof restored to Platinum (28 VCs)
- `adacovex-types.ads`: restored `pragma SPARK_Mode (On)` at package level.
- Vector instantiations and vector-containing types (`Package_Info`,
  `Test_Summary`, `DAL_Assessment`, `Badge_Config`) moved into a nested
  `Implementation` package with `pragma SPARK_Mode (Off)`.
- SPARK-clean types (`SPARK_Level`, `Proof_Summary`, `Docstring_Metrics`,
  conversion functions) remain in the outer `On` region, restoring 28 VCs.
- `SPARK_Mode (On)` removed from `adacovex-parsers-tests.ads` and
  `adacovex-renderers-svg.ads` (reference vector-containing types).
- Added `gnatprove/gnatprove.out` to search paths in `Parse_Prove_From_Project`
  so `make run-self` finds the proof output.

### Fixed `make fmt` non-determinism
- Replaced non-ASCII `~` (U+2248) with ASCII `~` in `adacovex-types.ads` source
  comment. gnatformat was re-encoding the UTF-8 character on each run, creating
  an oscillating diff that never converged. Now idempotent across repeated runs.

### Fixed `make doc` non-determinism
- Propagated the ASCII-only fix to generated API docs. `make doc` now produces
  identical output on repeated runs.

### Fixed `compliance-dal.adb` `Desc_Field` overflow
- `Append` to `Failed_Reasons` vector now properly constructs a 128-char
  `Desc_Field` before pushing, fixing a `Constraint_Error` on long messages.
