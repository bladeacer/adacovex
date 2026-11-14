# adacovex 1.69.0

Date: _2026-11-11_

Version bumped 1.68.0 -> 1.69.0.

## Changes

### C1: A repeated prover diagnostic is shown once

gnatprove prints one warning per inlined call site, so the same file, line,
column, and message can arrive many times in one stream. The concise replay
kept every copy, and the diagnostics block counted one unproved check once per
report, so a failure looked larger than it was. `just run-ada-crdt` showed
both shapes: a warning repeated at one source line, and a check reported twice.

`Adacovex.Prove.Replay_Suppressed` now keeps the first copy of a diagnostic
line and drops the repeat with its `-->` location, code excerpt, caret ruler,
and `+` sub-messages. It states the count in a
`duplicates: N repeated diagnostic line(s) shown once (--verbose shows them)`
footer, next to the existing `filtered:` footer. `Adacovex.Prove.
Collect_Failures` applies the same rule to unproved findings: the block names
and counts each source location and check kind once, so a check reported per
call site does not inflate `Unproved`. Both passes keep their seen text in one
bounded blob; past the cap a later repeat is kept, so the output can be longer
but never wrong. `--verbose` still streams every raw line, and CI passes it.

### C2: Contextual help renders in the `--help` frame

`adacovex help serve`, `adacovex prove help`, and `adacovex --serve help`
printed a detached titled section with no usage header, so the program read
like two tools. Every topic now renders the `--help` frame: the version line,
a `Usage:` fence naming the topic's subcommand or flag form, an `Options:`
heading, the topic body, and a `Run 'adacovex --help'` footer.

`adacovex prove --help` selects the prove topic like `adacovex prove help`: a
bare subcommand before `--help` names the topic, while a flag before `--help`
still prints the full usage. `--help` and `help` with no topic stay
byte-identical.

### C3: A warm prove run prints the diagnostics of the run it serves

The proof result cache stored the two gnatprove artefacts but not the replay
text, so `just run-ada-crdt` (a warm hit) printed no warnings, diagnostics
block, or `filtered:` / `duplicates:` footers while `make prove` (a fresh
run) printed all of them. The quiet replay is now written to a temporary
file, printed with severity colours, and cached as plain text under
`provereplay:<proof input hash>`. A warm hit prints that text before the
coverage line, so a cached run and a fresh run tell the same story. The
text is stored without escape codes, and the printer colours it at output
time.

### C4: The concise prove replay is coloured by severity

Errors print red, warnings yellow, informational notices and their `-->`
locations dim, `Success:` green, and the `coverage:` / `cache:` / `proof:` /
`filtered:` / `duplicates:` lines bold. The printer reuses `Adacovex.Ansi`,
so colour stays off under CI, `NO_COLOR`, or `TERM=dumb` and a redirected
log remains plain text. `--verbose` still streams the raw prover output
unchanged.

### C5: Unproved findings print CI inline annotations

When `GITHUB_ACTIONS` is set, each distinct unproved finding also prints a
workflow command: `::error file=<path>,line=<line>,col=<column>,title=SPARK
proof failed::<kind>`. `Annotation_Line` splits the recorded
`file:line:column`, omits `col` when the location has none, and returns an
empty string for a malformed location, so a bad line never becomes an empty
file annotation. A local run prints the text block only.

### C6: Help options are separated by blank lines

`adacovex --help` and the contextual `prove` help listed every option in one
dense block. Each new option now starts after a blank line, while a wrapped
continuation line stays attached. The `prove` topic lists each flag on its
own line with a short description. `--help` and `help` remain byte-identical.

### C7: A finding reads like a compiler diagnostic

The diagnostics block named a location and a check kind. It did not name the
solver, the input that failed, or the line of source. `prove` now renders each
finding as `file:line:col: error: <kind>`, then its solver set, counterexample,
source excerpt with a caret ruler, and one fix hint.

`prove` always runs gnatprove with `--counterexamples=on`, so a failed check
states the input that breaks it. The solver is the prover set the gnatprove
summary attributes to the check's category; gnatprove 16.1 records solvers per
summary row, not per SARIF result. A finding reported once per inlined call
site is one finding, and the block states `call sites: N` when there are
several. A source file the location names is read from the target root or its
`src/` child.

The prove result cache key now includes the counterexample switch. A text run
and a JSON run keep separate replay entries, so each warm hit prints the shape
it asked for.

### C8: Findings are available as JSON

`--diagnostics=text|json` selects the shape of the finding detail. `text` is
the compiler-style block and the default. `json` prints one object after the
replay with the prover identity, the unproved total, and one entry per finding:
location, file, line, column, kind, solver, counterexample, flow and budget
flags, call-site count, source excerpt, and fix hint. The object is one line,
so a script can `grep '^{"'` it from a run log.

### C9: The action is tested against a project configuration file

The composite action passes the target through `--target`, so a target that
carries `adacovex.toml` changes the run exactly as a local run does. A new
`action-project-config` CI job runs the real action against a fixture that
sets `[prove] coverage = false` and `[prove] level = 1`, then asserts the
proof options carry `--level 1` and the run prints no `coverage:` line. The
action's prove log is teed to `$RUNNER_TEMP/adacovex-prove.out` for that
assertion. The `prove` end-to-end checks also run a broken fixture with
`GITHUB_ACTIONS=true` and assert one annotation per distinct finding, so the
annotation shape C5 introduced is tested end to end.

## Fixes

### H1: The coverage summary prints once per prove run

A `prove` run printed the proof-coverage line twice: once at the end of
`Run_Prove` (fresh run and cache hit alike) and again in the plain pipeline
that follows it. The pipeline now skips the line when the run is a prove-mode
run, and keeps printing it for a plain `adacovex` assessment over cached
artefacts.

### H2: A release starts only from main

`just release` could tag a feature branch and publish it, and the release
workflow accepted any `v*` tag. The recipe now reads the checked-out branch
and aborts before it builds or changes a file unless the branch is `main`.
The release workflow fetches `origin/main` and refuses a tag whose commit is
not on it; the guard job gates the build and publish jobs. The local and CI
rules are stated in `docs/usage/ci-cd-release.md`, the developer guide, and
`AGENTS.md`.

## Test Suite

The native suite adds two repeated-diagnostic fixtures to
`src/tests/adacovex_prove_runner_tests.adb`: one warning block printed three
times is replayed and counted once, and one unproved check printed twice is
named and counted once. Four annotation checks cover `Annotation_Line`: a
full `file:line:column` location, a `file:line` location without a column, a
malformed location, and a Windows drive-letter colon that must not be read as
a column. `tests/e2e/prove_diagnostics.py` now also checks that the replay
prints each diagnostic once, that every diagnostics block names each finding
once, and it runs with `NO_COLOR` set so its text assertions stay plain.

`tests/e2e/cli_flags.py` also pins the help frame: `--help` equals `help`, every
sampled topic starts with the version line and carries the `Usage:`,
`Options:`, and footer lines, `--serve help` equals `help serve`, and
`prove --help` equals `prove help` with the prove flags listed.

`tests/e2e/cli_flags.py` adds `check_sbom_siblings`: it runs `sbom` over the
sibling projects present on the machine (`../polars`, `../playwright`,
`../opencv`, `../lccst`, `../numpy`, `../yams`) and checks the component
table's shape. A sibling that is not checked out is skipped, so a clean clone
and CI stay green.

The replay framing checks normalise CRLF to LF before they compare the first
and last blank line, so the Windows runner reports the same result as Linux
and macOS. The release guard has tests for the branch read and the aborted
run.

Native suite: 2180/2180 passing (29 categories).

`just prove-e2e` passes 132 checks. `just run-ada-crdt` proves 972 checks on
Ada_CRDT and exits 0 on both a cold run and a warm cache hit.

## Proof Results

The change is outside the proof surface: `adacovex-prove.adb` is an I/O-bound
unit with no `SPARK_Mode` contracts. Adding `diagnostics` to `Known_Flags`
pushed one flag-suggestion length check to the 10 000-step limit, so the
writer now names its first index in a local constant and the check follows
directly from the guard. The tree proves at the default budget (gnatprove
16.1.0: 1057 VCs, 0 unproved, 0 justified), with no `--steps=20000`.

## Traceability

HLR-PROVE: Proof diagnostics -- the replay and the diagnostics block report
each distinct finding once.

HLR-PROVE-CACHE: A warm proof cache hit replays the diagnostics of the run it
serves, so cached and fresh output agree.

HLR-PROVE-CI: Unproved findings print a GitHub Actions inline annotation when
`GITHUB_ACTIONS` is set, and the prove end-to-end checks assert the shape.

HLR-PROVE: Compiler-style findings -- each finding states its location, kind,
solver set, counterexample, source excerpt, and one fix hint, and groups its
inlined call sites.

HLR-PROVE-JSON: `--diagnostics=json` prints the same finding facts as one
JSON object.

HLR-CONFIG: A target's `adacovex.toml` changes a run made through the
composite action exactly as it changes a local run.

HLR-ANSI: The concise replay colours errors, warnings, notices, success, and
the summary footers through `Adacovex.Ansi`.

HLR-CLI: Contextual help -- every topic renders the `--help` frame, and a bare
subcommand before `--help` selects that topic.
