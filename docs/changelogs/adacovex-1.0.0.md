# adacovex 1.0.0

Date: _2026-07-29_

Version bumped 0.1.0 -> 1.0.0.

## Changes

### C1: Strict mode (default) + `--relaxed` flag

Strict mode is now the default: the scanner covers ALL directories (except the
always-excluded `.git`, `obj`, `tests`, `config`, `.adacovex`) and applies
`.adacovex/patches/` docstring overlays, ensuring full compliance coverage
including vendored code. The `--relaxed` flag disables strict mode: it enables
the directory skip list (default: `demo,deps,examples`) and disables patch file
application. Use case: strict for compliance audits, relaxed for quick dev-cycle
checks.

This reverses the 0.1.0 relaxed-by-default behavior. Existing commands that
relied on `demo`/`deps`/`examples` being skipped must add `--relaxed` (or
`--skip-dir=NAME` explicitly) to keep the old behavior.

### C2: `--skip-dir` flag

New `--skip-dir=NAME` (repeatable) adds directory names to the scanner's skip
list, complementing the default skip list (`demo,deps,examples`) for projects
with additional third-party code. Only effective in `--relaxed` mode.

### C3: `.adacovex/patches/` mechanism

Patch files at `<target>/.adacovex/patches/<relative-path>` allow documenting
vendored/third-party `.ads` files without modifying the originals. Patch files
are valid Ada specs with docstrings, merged by subprogram name; each overload
requires one patch entry, and the patch engine assigns entries to the next
undocumented original. The `.adacovex` directory is always excluded from source
scanning.

### C4: Plain docstring summary detection

Previously only `@param`/`@return`/`@field` tags counted as docstrings. Now any
`--  ` (two dashes + two spaces) comment line before a subprogram declaration
is recognized as a docstring, even without a tag, so no-param procedures with
only a summary line are correctly counted.

Known scanner quirks at this release: `(null record)` typed parameters are
still counted as parameters (benign -- they are parameters, just
parameterless), and docstring detection requires the strict `--  ` prefix --
`-- ` (one space) and `---` (three dashes) do not count.

### C5: `--verbose` output

The `--verbose` flag now produces pipeline diagnostic output to stderr: step
labels, package counts, SPARK level, test file path, and output paths
(previously a no-op placeholder).

### C6: `make bump-version` target

`make bump-version VERSION=x.y.z` bumps the version across `alire.toml`,
`alire-dev.toml`, `src/adacovex.ads`, and creates/updates the changelog,
modeled after the `Ada_CRDT` project's bump workflow.

### C7: `make run-ada-crdt` strict mode

`make run-ada-crdt` now runs in strict mode (no `--relaxed`) and achieves 100%
docstring coverage on Ada_CRDT including the vendored vt100 code via
`.adacovex/patches/demo/deps/vt100/vt100.ads`.

### C8: Patch overload handling

`Apply_Patches` now skips already-documented originals when searching for name
matches, so overloaded subprograms get correctly assigned to the next
undocumented overload instead of re-patching the first one.

### C9: Always-excluded directories

`config` and `.adacovex` added to the hardcoded always-excluded directories
(alongside `.git`, `obj`, `tests`): `config/` contains generated Alire
configuration, not production source, and `.adacovex/` contains patch metadata
relevant only to the patch engine.

### C10: Production scalability (unbounded)

Packages and subprograms now use `Ada.Containers.Vectors` (heap-allocated, up
to `Natural'Last` ~ 2.1B); the compile-time `Max_Packages` / `Max_Subprogs`
bounds are eliminated entirely, so projects of any size are supported without
recompilation. VC counts use unbounded `Natural` fields (the `Max_VC_Count`
dead type removed). The line buffer was raised 2048 -> 8192 characters with
automatic truncation draining (silently skips remaining chars on lines >
8192), the path buffer 512 -> 4096 (matches `PATH_MAX`), and the filename
buffer 64 -> 128 (matches Ada's max identifier length). A line-truncation
guard detects when the buffer was filled (partial read) and drains the
remainder of the line, preventing stream desynchronisation that previously
caused false subprogram declarations. Dead code removed: `Max_Params`,
`Max_VC_Count`, `Max_Badge_Path`, `Max_Metrics`, `Max_Skip_Dirs`, `VC_Info`,
`VC_Vector`, `Param_Count`.

### C11: `--dal` validation

`--dal=Z` (or any value outside A-E) now prints an error and exits with code 1
instead of silently defaulting to DAL-C. Related CLI caveat: a relative
`--target=PATH` is resolved against the CWD, so behavior depends on the
invocation directory.

### C12: Post-release: Alire crate renamed to `covex`

The Alire crate was renamed from `adacovex` to `covex` to comply with Alire
naming rules. The binary name stays `adacovex_main` via
`project-files = ["adacovex.gpr"]` in all manifest files.
`alire/releases/covex-*.toml` and `index/ad/covex/*.toml` were created and
`index/ad/adacovex/` removed. New `make release`, `make publish`, and `make
test-publish` targets support the Alire community-index publishing workflow.

### C13: Post-release: SPARK proof restored to Platinum (28 VCs)

Restored `pragma SPARK_Mode (On)` at package level in `adacovex-types.ads`;
vector instantiations and vector-containing types (`Package_Info`,
`Test_Summary`, `DAL_Assessment`, `Badge_Config`) moved into a nested
`Implementation` package with `pragma SPARK_Mode (Off)`. SPARK-clean types
(`SPARK_Level`, `Proof_Summary`, `Docstring_Metrics`, conversion functions)
remain in the outer `On` region, restoring 28 VCs. `SPARK_Mode (On)` was
removed from `adacovex-parsers-tests.ads` and `adacovex-renderers-svg.ads`
(reference vector-containing types), and `gnatprove/gnatprove.out` was added
to the search paths in `Parse_Prove_From_Project` so `make run-self` finds the
proof output.

## Fixes

### H1: Post-release: `make fmt` non-determinism

Replaced the non-ASCII almost-equal sign (U+2248) with ASCII `~` in an
`adacovex-types.ads` source comment. gnatformat was re-encoding the UTF-8
character on each run, creating an oscillating diff that never converged; the
format is now idempotent across repeated runs.

### H2: Post-release: `make doc` non-determinism

Propagated the ASCII-only fix to the generated API docs; `make doc` now
produces identical output on repeated runs.

### H3: Post-release: `compliance-dal.adb` `Desc_Field` overflow

`Append` to the `Failed_Reasons` vector now properly constructs a 128-char
`Desc_Field` before pushing, fixing a `Constraint_Error` on long messages.

### H4: Post-release: guarded `--port` `Positive'Value` crash

`--port` argument parsing in `adacovex-config.adb` now wraps `Positive'Value`
in an exception handler. Non-integer or zero/negative port values produce a
clear error message instead of crashing with `Constraint_Error`.

### H5: Post-release: file-descriptor leak protection in parser read loops

All five `while not End_Of_File` read loops across the four parser units
(`adacovex-parsers-gnatprove.adb`, `adacovex-parsers-tests.adb`,
`adacovex-parsers-do178c.adb`, `adacovex-parsers-source.adb`) are wrapped in
an inner `exception when others => Close(F); raise;` block: if `Get_Line`
raises mid-file, the file handle is closed and the exception propagates,
preventing FD leaks.

### H6: Post-release: server graceful shutdown and backoff

Worker tasks now check `Svr_State.Running` at the top of the loop and exit
when `False`. On `Socket_Error`, workers increment a backoff counter and
`delay 0.1`; after 100 consecutive errors they set `Running := False` and
exit, fixing the busy-loop. The main server loop changed from `delay 3600.0`
to `delay 1.0` with `exit when not Svr_State.Running`, enabling timely
shutdown, and `Running` is set `False` on any exception in `Start`, ensuring
socket cleanup via the existing `Close_Socket (Listener)` handler.

### H7: Post-release: iterative directory traversal (no recursion)

`Search_Dir` in `adacovex-parsers-source.adb` was converted from recursive to
iterative using an explicit `Dir_Stacks` vector, eliminating stack overflow
risk at deep directory nestings (> ~1000 levels).

### H8: Post-release: dynamic HTML buffer (no 32KB cap)

`Render_Dashboard` and `Render_Metrics_JSON` in `adacovex-renderers-html.adb`
replaced their fixed 32768-byte and 4096-byte stack buffers with
`Ada.Strings.Unbounded.Unbounded_String`, so dashboard output for large
projects is no longer silently truncated.

## Test Suite

152 tests pass across 7 categories: Types conversions (21), DAL compliance
(2), Source scanner (40), GNATprove parser (24), Test-result parser (27), CLI
config (8), SVG renderer (30).

## Proof Results

Self-assessment: **Platinum** (28/28 VCs proved, AoRTE-free).
Ada_CRDT (strict): **Platinum** (273 VCs, 5 justified overflow checks).
Ada_CRDT (relaxed): **Platinum** (273 VCs, 5 justified).

## Traceability

No new HLRs were recorded for this release. The tags tracked in `docs/HLR.md`
at this release: `HLR-SCAN`, `HLR-PROOF`, `HLR-TEST`, `HLR-COMPLIANCE`,
`HLR-DAL-A..E`, `HLR-RENDER-ANSI`, `HLR-RENDER-SVG`, `HLR-RENDER-MD`,
`HLR-RENDER-HTML`, `HLR-SERVER`, `HLR-CLI`, `HLR-METRICS`, `HLR-ARCH`.
