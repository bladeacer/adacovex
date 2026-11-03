# adacovex 1.66.0

Date: _2026-11-03_

Version bumped 1.65.0 -> 1.66.0.

## Changes

### C1: Prove diagnostics name the prover, the failing check, and the fix

The quiet `prove` replay in 1.65.0 kept every actionable prover line, but it
still left the reader to read the failure out of the stream. The last line
only counted the error lines, the prover identity never appeared in the
output, and nothing said which source location to open or what contract the
unproved check needs. A developer with two unproved checks in a thousand-line
run had to scan the replay to find them.

`prove` now gathers the unproved findings from the captured stream and prints
a diagnostics block after the replay:

```
  proof:     2 unproved check(s) (prover 16.1.0)
    adacovex-types.adb:54:08  postcondition
    adacovex-prove.adb:120:14  range check
  fix:       add the missing fact to the loop invariant or the postcondition
             it derives from
```

The block states three things the replay alone did not. It names the
**prover identity** the run resolved (the pinned version, or the executable
path when no version was pinned), so a result is attributable to the prover
that produced it. It points at the **source location and check kind** of each
finding, up to `Max_Failure_Items` (8) entries, and it marks a flow finding
(an object read before its first write) as `(flow analysis)`. It closes with
one **fix hint** derived from the first check's kind: a bound check asks for a
subtype constraint or precondition, a postcondition asks for the missing loop
invariant, a termination check asks for a `Loop_Variant`, and so on. A run
with more than eight findings still counts them all and says how many the
block left out.

`Adacovex.Prove.Collect_Failures` reads the captured stream and returns the
counts in `Failure_Stats` (`Unproved`, `Count`, `Items`), and
`Diagnostics_Text` renders the block from them, so both are testable without
a terminal and a clean run renders nothing.

The pass reads the block shape gnatprove really emits: the message and its
severity on one line, the `--> file:line:column` location on the next, then
the code excerpt, the caret ruler, and the `+` sub-messages. A sub-message
that states `provers gave up before completing the proof` marks the finding
as a budget problem, so its fix hint raises `--steps` instead of naming a
missing contract. The single-line `file:line:column: message` shape (which
carries flow findings) reads the same way. The end-to-end fixture in C2 found
this shape mismatch before the release: the first pass required the location
on the message line, which real gnatprove output never does.

The two output modes are now fixed and documented rather than open.
**Concise** is the default locally: capture, replay, and the diagnostics
block. **Verbose** (`--verbose`) streams the raw prover output live and
prints no block; CI passes `--verbose`, so CI keeps the unedited stream and
the block never reaches a CI log. There is no third mode.

### C2: A generated broken/fixed fixture gates the prove output end to end

The 1.65.0 replay and the 1.66.0 diagnostics were covered by unit tests and
the CLI flag checks, but nothing ran a real proof and looked at what a reader
sees. `tests/e2e/prove_diagnostics.py` now generates one small SPARK project
per contract-writing mistake, each with a broken variant and a fixed
counterpart that differs in one contract line. The cases cover the mistakes
that dominate contract writing: `index` (a bound that does not imply the
table bounds), `overflow` (a bound too wide for the arithmetic), `division` (a
zero divisor), `precondition` (a caller that cannot establish the callee's
contract), `invariant` (a loop without the invariant its postcondition
needs), `flow` (an object read before it is written), `typo_attribute` (a
misspelled attribute), and `typo_identifier` (an unknown name). It also covers
`invariant_entry` (an invariant the loop body keeps but the first iteration
does not hold yet) and pins the coverage summary (a clean run prints it, and
`--no-coverage` hides it without changing the proof).

The suite checks the quiet replay (no `Phase N of M:` banners, and no
`filtered:` footer when nothing was hidden), the diagnostics block (the
unproved count, the prover identity, the source location, the check kind, and
the fix hint), the compile-error shape for the two typos (the replay keeps
the error with its location, the run exits non-zero, and no block appears),
the fixed counterpart proving cleanly, and the `--verbose` mode (the raw
prover line, no block, no filtering). The projects are generated at run time,
so they never enter this tree's own scan or proof, and `--keep` writes them
to `obj/prove-diagnostics/` for a reader who wants the before and after by
hand.

The suite runs as `just prove-e2e` (`python3 tools/tasks.py prove-e2e`), is a
gate of `just check`, and skips itself when no gnatprove is resolvable. The
user-facing explanation is the new
[Reading a prove failure](../contributing/proving-diagnostics.md)
page, which shows the two modes, a clean run, a failing run, a table of check
kinds and their actions, and the budget case.

### C3: `prove` reports proof coverage by default

The `prove` summary used to stop at the prover's own `Summary logged ...`
line, so a reader had to run `spark-coverage` (or read the badges) to learn
how much of the tree the proof actually covered. Zero unproved checks do not
imply full coverage: statements and subprograms can stay outside the proof.

A successful `prove` now prints one coverage line after the replay:

```
  coverage:  statements 96% (1448/1508)  subprograms 98% (392/400)  VCs 100% (1054/1054)
```

The line states the three metrics the `spark-coverage` report measures, each
with its proved count and its total. A total of zero prints `n/a`, never a
division by zero and never 100 percent. The line is a summary, not a gate:
`--require-proof` and `--fail-on` decide pass or fail. It prints after a real
run and after a warm cache hit (the restored artefacts are the ones read),
and it prints nothing when the artefacts are missing, so it can never turn a
proof failure into a misleading success line.

The summary is on by default. `--no-coverage` hides it for one run,
`--coverage` forces it on, and `[prove] coverage = false` in
`<config>/adacovex.toml` hides it for every local run. An explicit flag wins
over the file, so a developer drops the line once in the config file and a CI
job puts it back with the flag. `Adacovex.Prove.Config_Show_Coverage` reads the
key and `Report_Coverage` prints the line; both are default-off I/O code, so
the work adds no proof surface.

### C4: `--fail-on` states a CI policy in one flag

`--fail-on=DIM[=VAL]` names the existing CI gates as one policy flag. The
dimensions are `spark=LVL`, `docstrings=PCT`, `proof=PCT`, `tests=N`, and
`coverage=PCT`, and the value may be comma-separated or the flag repeated:
`--fail-on=spark=Gold,proof=100,coverage=80`.

The flag does not replace the `--require-*` gates; it maps each dimension onto
the field that gate already uses. A policy and an explicit gate therefore fail
the same way: exit 1 and one `CI GATE:` line per unmet dimension. A bare
dimension reuses the threshold its `--require-*` flag set (`--require-proof=90
--fail-on=proof`), and it is an error without one, because a gate with no
threshold would pass silently. An unknown dimension, an unknown SPARK level,
and an out-of-range percentage are all rejected at parse time.

One defect was caught before the release: the first setter took the threshold
as an `out` parameter, and an `out` scalar clears its actual object on entry,
so a bare dimension erased the value it was meant to reuse. The new unit test
failed on that, and the setter takes the field `in out` instead.

The flag is documented in the CLI reference, in the `prove` flag page, in the
configuration page, in the man page, in `--help`, and as a `fail-on` action
input, and it joins `Known_Flags`, so completion and the typo suggestion know
it without a second list.

### C5: One ignore marker excludes a whole directory subtree

The per-file header markers (`no-covex-complexity-scan`,
`no-covex-docstrings`, `no-covex-spark-proof`, and the `no-covex-analysis`
catch-all) could exclude a file, and the command line could skip a directory
name in relaxed mode (`--skip-dir`) or a path fragment for complexity
(`--skip-path`). Nothing excluded a directory subtree from the assessment
itself, so a vendored or generated tree had to be marked file by file.

A file named `.covex-ignore` in a directory now excludes that directory and
every directory below it from the source scan (docstrings, HLR tags, and the
DAL assessment) and from the complexity walk. An empty file is enough. The
walker checks the marker before it enumerates a directory, so an ignored
subtree is never read.

The two mechanisms stay deliberately distinct. A marker file cannot opt one
gate out; a header marker cannot exclude a directory. Neither form stops
`gnatprove`, which analyses the project: a unit leaves the proof through the
per-file `no-covex-spark-proof` marker or a proof patch, never through the
directory marker. `--skip-dir`, `--skip-path`, and `--excludes` keep their
narrower command-line scopes, and the CLI reference states the granularity and
the analyses of each form in one place.

`Adacovex.Opt_Outs.Dir_Ignored` is the single detector, used by both the
source walk and the complexity walk, and the four new unit checks pin the
marker: present, absent, parent directory, and a missing directory. The CLI
end-to-end suite adds one check: a `complexity` run prints no file from a
directory that carries the marker.

## Fixes

No defect is fixed in this release.

## Test Suite

- 2115/2115 native tests passing across 29 categories (2060 at 1.65.0). The
  per-file opt-out category grows from 16 to 20 with the `.covex-ignore`
  checks, and the CLI end-to-end suite gains its directory-marker check. The
  CLI config category grows from 349 to 366 with the `--fail-on` precedence
  tests (every dimension, a comma-separated list, threshold reuse, the
  unknown/out-of-range rejections) and the coverage-summary defaults. The
  Prove runner category grows from 44 to 78 with the diagnostics tests: the
  finding count, the location and kind of each entry, the flow marking, the
  severity-word strip, the prover-identity line, the fix hint, the empty
  block for a clean run, the eight-entry cap with its "N more" line, the
  real block shape (message line, `-->` location, and `+` sub-message), the
  gave-up marking, the budget hint, and the divide-by-zero hint.
- `just prove-e2e` adds 101 end-to-end checks over the nine generated broken
  and fixed fixture projects, one case per contract-writing mistake, plus the
  coverage-summary checks on every fixed project.

## Proof Results

- gnatprove 16.1.0: SPARK Gold, 1054/1054 VCs proved across 75 analyzed
  units, 0 unproved, 0 justified, 100% VC coverage, and 121/616
  subprograms proved by the coverage report. No proof metrics changed:
  `Adacovex.Prove` stays a default-off I/O body, so the diagnostics work adds
  no proof surface (see `docs/proof/16.1.0-ledger.md`).

## Traceability

No new HLR record enters this release. The changed packages keep their
existing tags:

- `-- HLR-PROVE` (`adacovex-prove`): the failure collection, its
  `Failure_Stats` counts, the fix hints, and the diagnostics block;
- `-- HLR-CLI` (`adacovex-prove`, the CLI reference, the proving guide): the
  finalised concise/verbose output modes and the block they produce;
- `-- HLR-PROVE` plus `-- HLR-ARCH`
  (`tests/e2e/prove_diagnostics.py`, `tools/tasks.py`, the new proving
  diagnostics page): the generated fixture gate and the reader guidance;
- `-- HLR-CLI` (`adacovex-config`, `adacovex-prove`, `adacovex-renderers-man`,
  the CLI reference, the configuration page): the coverage summary and its
  `--coverage` / `--no-coverage` flags, the `[prove] coverage` key, and
  `--fail-on`;
- `-- HLR-SCAN` (`adacovex-opt_outs`, the source walk) and
  `-- HLR-COMPLEXITY` (the complexity walk): the `.covex-ignore` directory
  marker, its detector, and the separate granularity from the header markers.
