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

### Scalability limits

- **Max_Packages** raised from 64 → **128** (handles large projects).
- **Max_Subprogs** raised from 64 → **128** per package (handles large packages).
- **Max_Line** raised from 512 → **2048** characters (long contract lines).
- **Max_Path** raised from 256 → **512** characters (deep directory trees).
- **Max_VC_Count** raised from 128 → **512** (large proof campaigns).
- **Max_Hlrs** / **Max_Llrs** raised from 64 → **128** each (more HLR traceability).

All array storage remains stack-allocated with compile-time bounds — no heap
allocation, no dynamic dispatch. The 128/128 limits ensure the stack footprint
stays under ~4 MB, well within typical 8 MB Linux defaults.

### `--dal` validation

- `--dal=Z` (or any value outside A-E) now prints an error and exits with
  code 1, instead of silently defaulting to DAL-C.

## Changes

- **Version**: bumped from 0.1.0 to 1.0.0
- **CLI default**: strict mode is on by default; `--relaxed` to disable
- **Docstring scanner**: plain `--  ` summary lines now count as docstrings
- **Patch engine**: overloaded subprograms now handled correctly
- **Source scanner**: `.adacovex` always excluded from directory walk
- **Scalability**: all Max_* constants raised (see above)
- **CLI validation**: `--dal` rejects invalid levels
- **Tests**: 152 tests pass across 7 categories

## Known Issues

- `(null record)` typed parameters are counted as parameters by the scanner
  (benign — they are parameters, just parameterless).
- Docstring detection uses strict `--  ` prefix; `-- ` (one space) and `---`
  (three dashes) do not count.
- Relative `--target=PATH` is resolved against CWD, so behavior depends on
  invocation directory.
- All internal buffers are fixed-size (no heap). Projects exceeding 128
  packages or 128 subprograms per package will silently truncate. Raise the
  Max_* constants in `adacovex-types.ads` and recompile for such cases.

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
