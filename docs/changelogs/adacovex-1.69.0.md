# adacovex 1.69.0

Date: _2026-11-06_

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

## Fixes

## Test Suite

The native suite adds two repeated-diagnostic fixtures to
`src/tests/adacovex_prove_runner_tests.adb`: one warning block printed three
times is replayed and counted once, and one unproved check printed twice is
named and counted once. `tests/e2e/prove_diagnostics.py` now also checks that
the replay prints each diagnostic once and that every diagnostics block names
each finding once.

`tests/e2e/cli_flags.py` also pins the help frame: `--help` equals `help`, every
sampled topic starts with the version line and carries the `Usage:`,
`Options:`, and footer lines, `--serve help` equals `help serve`, and
`prove --help` equals `prove help` with the prove flags listed.

`tests/e2e/cli_flags.py` adds `check_sbom_siblings`: it runs `sbom` over the
sibling projects present on the machine (`../polars`, `../playwright`,
`../opencv`, `../lccst`, `../numpy`, `../yams`) and checks the component
table's shape. A sibling that is not checked out is skipped, so a clean clone
and CI stay green.

Native suite: 2151/2151 passing (29 categories).

## Proof Results

The change is outside the proof surface: `adacovex-prove.adb` is an I/O-bound
unit with no `SPARK_Mode` contracts, so the Gold assessment is unchanged
(gnatprove 16.1.0: 1054 VCs, 0 unproved, 0 justified).

## Traceability

HLR-PROVE: Proof diagnostics -- the replay and the diagnostics block report
each distinct finding once.

HLR-CLI: Contextual help -- every topic renders the `--help` frame, and a bare
subcommand before `--help` selects that topic.
