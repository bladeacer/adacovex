# adacovex 1.48.0

Date: _2026-09-14_

Version bumped 1.47.0 -> 1.48.0.

## Changes

### C1: CLI shorthands and long aliases

Every flag keeps its explicit long spelling, and the common ones gain a
shorthand or an alias. The shorthands are `-t` (`--target`), `-m`
(`--manifest`), `-s` (`--serve`), `-p` (`--port`), `-c` (`--cache`), `-b`
(`--compare-base`), `-d` (`--coverage-delta`), `-l` (`--level`), `-r`
(`--require-proof`), and `-j` (`--jobs`). The bare words `serve`, `cache`,
and `relaxed` also select their flag, and `--strict` restores strict mode.
The long aliases are `--workers` (`--serve-workers`), `--svg-path`
(`--emit-svg`), `--emit-md` and `--md-path` (`--emit-markdown`), `--no-md`,
`--diff` and `--base` (`--compare-base`), `--delta` (`--coverage-delta`),
`--spark`, `--docstrs`, and `--tests` (the `--require-*` gates).

A new `Normalize_Aliases` pass rewrites an alias into its canonical long
flag before the token loop, so the parser keeps one spelling per option and
the per-function complexity gate is unaffected. A token that follows `help`
is never rewritten, and the topic lookup itself accepts a shorthand, so
`adacovex help serve` and `adacovex help -r` both resolve their topic.
`-l` is the GNATprove proof level only: compliance selection stays on
`--standard` and its level companions `--dal`, `--asil`, and `--class`.
The numeric shorthands (`-p`, `-l`, `-r`, `-j`) share one path, so `-j N`,
`-jN`, and `-j=N` all parse alike (`-j` used to reject the `=` form).

All short flags run through the one alias table. The numeric shorthands
accept the detached, glued, and `=` forms. The value shorthands accept the
detached and `=` forms. A glued value (`-tPATH`) is deliberately not
accepted, so a single-dash typo such as `-target` still gets a `did you
mean` suggestion rather than silently parsing as `-t arget`.

### C2: `--standard` accepts a combined tier token

`--standard` now also takes a tier token, so one flag selects the standard
and the rigour tier together: `dal-A`..`dal-E`, `asil-A`..`asil-D`,
`asil-QM`, and `class-A`..`class-C`. As a result `--standard=asil-b` is
equivalent to `--asil=B`. Inside a token `-` and `_` are interchangeable
and the value is case-insensitive. An unknown value is now rejected
loudly, where the old parser silently fell back to DO-178C.

### C3: `--serve` worker default scales to the host

`--serve` without an explicit `--serve-workers` / `--workers` now sizes its
task pool from the host's logical CPU count, clamped to `2`..`8`, instead
of always using `4`. The new `Adacovex.CPUs.Default_Serve_Workers`
function is pure, SPARK-proved, and covered by a postcondition. An explicit
worker count still wins.

### C4: Optional emit paths, `--no-md`, and a created output directory

`--emit-svg` and `--emit-markdown` now take an optional value. A bare
`--emit-md` writes `VERIFICATION.md` and `TRACE.md` into `<target>/docs`,
and a bare `--emit-svg` writes badges into `<target>/docs/badges`. A new
`--no-md` switch suppresses Markdown output and wins over the emit forms,
mirroring `--no-svg`. The Markdown renderer now creates its output
directory when it is missing, so the default `--emit-md` path works on a
fresh project, exactly like the SVG and SBOM writers.

### C5: Make targets and gates adopt the shorthands

`tools/run.py`, which owns the self-assessment invocation shape for
`prove`, `self`, `sbom`, and `ada-crdt`, now uses `-t=.`, `--svg-path=`,
`--spark=`, `--docstrs=`, and `-r=`. `tools/check-action-parity.py`
records every alias-only spelling as deliberately outside the GitHub
Action, so the action/CLI/docs parity gate stays green.

### C6: CLI end-to-end suite and alias equivalence tests

A new pure-stdlib CLI suite (`tests/e2e/cli_flags.py`, `make cli-e2e`) runs
the real binary and checks the shorthands, the long aliases, the
`--standard` tier tokens, the reject paths, the `complexity` subcommand
(its pass and fail gates, `--excludes`, and `--skip-path`), the VCS
differential modes (each `--compare-base` / `--coverage-delta` alias
equivalence, a real docstring-coverage regression, and the
not-a-repository failure), the `prove` subcommand (its `-t`/`-l`/`-j`
shorthands, the accepted option set, and the range and subcommand reject
paths), and the serve shorthands, the `--theme` values, and the `-p` port
forms against a live dashboard. It needs no browser and runs inside `make
check` and in the `e2e` target ahead of the Playwright run. The native
config suite gains equivalence tests: every alias must produce exactly the
same parsed option state as its canonical long spelling. A shorthand form
matrix covers every short flag: the numeric ones (`-p`, `-l`, `-r`, `-j`)
accept the detached, glued, and `=` spellings, the value ones (`-t`, `-m`,
`-b`, `-d`) the detached and `=` spellings, and a glued value is rejected
so a single-dash typo still gets a suggestion.

## Test Suite

The native suite grows from 1287 to 1404 tests across 17 categories, all
passing. The CLI-config category carries the new shorthand, alias,
tier-token, and form-matrix checks, and the alias-equivalence checks assert
that an alias and its canonical spelling leave the same option state. The
new CLI end-to-end suite adds 68 checks against the built binary (34 option
checks, 16 for `complexity` and the differential modes, 14 for `prove`, and
4 for the `--theme` values plus the `-p` port forms). The stdlib suite for
the dev tools stays at 59 tests, with its `assess-args` shape check updated
for the shorthand invocation.

## Proof Results

Platinum, 0 unproved, 0 justified, 880 VCs (880 proved) under gnatprove
16.1.0 across 58 analysed units. `Adacovex.CPUs.Default_Serve_Workers` is
the one new proved unit and adds four checks; the alias expansion and the
`--standard` tier parsing live in the default-off `Adacovex.Config`
helpers, so they add no proof surface. No proof metric regressed.

## Traceability

- No new HLRs. The release adds CLI spelling and a platform-sized server
  default; the existing tags below cover it.
- `HLR-CLI` -- C1 the shorthand/alias engine (`Normalize_Aliases`,
  `Alias_Canonical`, `Known_Flags`) and C2 the `--standard` tier tokens
  (`Set_Standard_Value`), with their config tests in
  `adacovex_config_tests.adb`.
- `HLR-CPU` -- C3 `Default_Serve_Workers` and the `--serve` auto default
  resolved in `Parse_All`.
- `HLR-RENDER-MD` -- C4 the optional `--emit-md` value, the `--no-md`
  override, and the created Markdown output directory.
- `HLR-ARCH` -- C5 the make-target/parity-gate updates and C6 the CLI
  end-to-end suite and the developer-guide note.
