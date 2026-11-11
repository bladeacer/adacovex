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

## Fixes

### H1: The coverage summary prints once per prove run

A `prove` run printed the proof-coverage line twice: once at the end of
`Run_Prove` (fresh run and cache hit alike) and again in the plain pipeline
that follows it. The pipeline now skips the line when the run is a prove-mode
run, and keeps printing it for a plain `adacovex` assessment over cached
artefacts.

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

Native suite: 2155/2155 passing (29 categories).

`just prove-e2e` passes 116 checks. `just run-ada-crdt` proves 972 checks on
Ada_CRDT and exits 0 on both a cold run and a warm cache hit.

## Proof Results

The change is outside the proof surface: `adacovex-prove.adb` is an I/O-bound
unit with no `SPARK_Mode` contracts, so the Gold assessment is unchanged
(gnatprove 16.1.0: 1054 VCs, 0 unproved, 0 justified).

## Traceability

HLR-PROVE: Proof diagnostics -- the replay and the diagnostics block report
each distinct finding once.

HLR-PROVE-CACHE: A warm proof cache hit replays the diagnostics of the run it
serves, so cached and fresh output agree.

HLR-PROVE-CI: Unproved findings print a GitHub Actions inline annotation when
`GITHUB_ACTIONS` is set.

HLR-ANSI: The concise replay colours errors, warnings, notices, success, and
the summary footers through `Adacovex.Ansi`.

HLR-CLI: Contextual help -- every topic renders the `--help` frame, and a bare
subcommand before `--help` selects that topic.
