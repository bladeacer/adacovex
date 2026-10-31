# adacovex 1.65.0

Date: _2026-10-31_

Version bumped 1.64.0 -> 1.65.0.

## Changes

### C1: CLI surface parity gate

The surfaces that describe the CLI -- the `--help` usage block, the man
page SYNOPSIS, the cli-reference usage fence, the completion subcommand
lists, and the tldr examples -- can drift away from the parser's own
subcommand set, and nothing failed when they did. A stale flag could sit
in the help text for a release before a reader noticed it.

`tools/check-surface-parity.py` now compares every one of those surfaces
against the parser's subcommand set and fails on a stale or missing
entry. It also pins the README tagline where the project promises it: the
tldr description, the `--help` footer, the man DESCRIPTION, and the
AGENTS.md blurb. The gate runs as `just surface-parity-check`, sits in
the `just check` gate list, and runs in CI as the `surface-parity` job of
`ci.yml` and as a step of `release.yml`. The tldr page may still
advertise a subset, because it is a cheat sheet, and the README quick
start fence stays a link-out summary: both only have to stay true.

### C2: Quiet prove replay states what it hid and what failed

A local `prove` run replayed the captured gnatprove output as one flat
dump. The phase-progress lines survived into a replay that runs after the
run has finished, the suppression filter left orphan blank lines and
fragment lines behind, and nothing said that output had been edited or
where a failure stood.

The replay now drops the `Phase N of M:` progress lines together with the
suppression-tagged notice blocks and their continuation lines, collapses
runs of blank lines to one, and frames the block with one blank line at
each end so it never runs into the lines adacovex prints around it. When
it removes notices it reports them, as in
`filtered: 9 informational notice(s) hidden (--verbose shows them)`. When
gnatprove fails, the final line carries the failure detail, as in
`ERROR: gnatprove exited with code 1 (error lines: 2 above)`.

The counts come from the new `Adacovex.Prove.Replay_Stats`, and the
replay takes a destination path, so the filter is testable without a
terminal. `--verbose` keeps the previous behaviour exactly: it streams
the raw prover output live and never edits it, and CI passes `--verbose`,
so the quieter local default never reaches CI.

## Fixes

### H1: tldr cheat sheet and the CLI usage block advertise the real command set

The audit in front of the new gate found the cheat sheet drifting. It
showed `adacovex tldr --check` where the install command is `adacovex
tldr`, it described `spark-coverage` as a proof-coverage check rather
than the metrics and CI-gate report, and it never showed `completion` or
`--version` at all. The usage block that presents the CLI had also been
mangled by an earlier edit.

`docs/tldr/adacovex.md` now lists what a cheat-sheet reader needs:
assessment, a target path, a standard tier, `prove`, `--serve`,
`spark-coverage`, `man`, `tldr`, `completion bash`, `sbom`, and
`--version`, each with a description that matches what the command does.
The bundled tldr page regenerated from it, and the cli-reference carries
the same corrections.

## Test Suite

- 2060/2060 native tests passing across 29 categories (2040 at 1.64.0).
  The Prove runner category grows from 24 to 44 with the quiet-replay
  tests: the phase-progress drop, the tagged-block drop with its
  continuation lines, the blank-run collapse, the block framing at both
  ends, the filtered footer, the hidden/error/warning counts, and a
  custom suppression set that matches nothing.
- The tools suite (`tools/tests.py`) gained the surface-parity gate
  tests: the subcommand-set comparison, the tagline check, and the
  surfaces the gate reads.

## Proof Results

- gnatprove 16.1.0: SPARK Gold, 1054/1054 VCs proved across 75 analyzed
  units, 0 unproved, 0 justified, 100% VC coverage, and 121/616
  subprograms proved by the coverage report. No proof metrics changed:
  `Adacovex.Prove` stays a default-off I/O body, so the replay work adds
  no proof surface (see `docs/proof/16.1.0-ledger.md`).

## Traceability

No new HLR record enters this release. The changed packages keep their
existing tags:

- `-- HLR-PROVE` (`adacovex-prove`): the quiet replay, its
  `Replay_Stats` counts, and the failure-detail line;
- `-- HLR-CLI` (`adacovex-config`, `adacovex-completion`,
  `adacovex-renderers-man`): the usage block, the completion subcommand
  lists, and the man page the gate reads;
- `-- HLR-TLDR` (`adacovex-renderers-tldr`, `docs/tldr/adacovex.md`): the
  corrected cheat sheet and its bundled template;
- `-- HLR-ARCH` (`tools/check-surface-parity.py`, `justfile`, the CI
  workflows): the new gate in the check and release paths.
