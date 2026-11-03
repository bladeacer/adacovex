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
a terminal and a clean run renders nothing. Language-level details: a
prover failure line has the shape `unit.adb:54:08: medium: postcondition
might fail`, and a flow finding the shape `unit.adb:31:05: "X" is not
initialized`; the pass keeps the location, strips the optional severity word,
and derives the kind from the message.

The two output modes are now fixed and documented rather than open.
**Concise** is the default locally: capture, replay, and the diagnostics
block. **Verbose** (`--verbose`) streams the raw prover output live and
prints no block; CI passes `--verbose`, so CI keeps the unedited stream and
the block never reaches a CI log. There is no third mode.

## Fixes

No defect is fixed in this release.

## Test Suite

- 2079/2079 native tests passing across 29 categories (2060 at 1.65.0). The
  Prove runner category grows from 44 to 63 with the diagnostics tests: the
  finding count, the location and kind of each entry, the flow marking, the
  severity-word strip, the prover-identity line, the fix hint, the empty
  block for a clean run, and the eight-entry cap with its "N more" line.

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
  finalised concise/verbose output modes and the block they produce.
