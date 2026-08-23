# adacovex 1.18.0

Date: _2026-08-23_
Version bumped 1.17.0 -> 1.18.0.

## Changes

### C1: quiet-by-default prove output -- `--quiet` and `--suppress-warnings=SETS`

The `prove` subcommand's stdout is now **quiet by default for local runs**:
GNATprove's benign informational messages (the default suppression set --
the loop-unrolling/inlining notice blocks) are filtered out of the replayed
output, so a local `adacovex prove` no longer prints the purely-informational
`cannot unroll loop (too many loop iterations) [info-unrolling-inlining]`
notices. The filter drops whole message blocks (tag line, `info:`/`-->`
header, and any `+` sub-message in the in-instantiation shape) while every
other gnatprove line -- checks, warnings, and the summary -- passes through
untouched. The proof outcome is never affected: the notices are informational
only.

Three ways to control it:

- `--quiet` -- explicit request for the default suppression set (which is
  already the default, so this is the documented spelling of the default
  behavior). Keep it for CI-adjacent scripts that want to say what they mean.
- `--suppress-warnings` -- alias of `--quiet`, kept for compatibility with
  1.17.0.
- `--suppress-warnings=SETS` -- suppress a custom comma-separated list of
  gnatprove info tags: a set name `S` suppresses blocks tagged `[info-S]`
  (or a bare `[S]`). Example: `--suppress-warnings=unrolling-inlining,xyz`.

`--verbose` always wins: it shows every message and disables suppression
entirely. **CI passes `--verbose`** in both this project's workflows
(`ci.yml`, `release.yml`) and the Ada_CRDT dogfood workflows, so CI output
stays authoritative -- the composite action forwards the `verbose` input to
both the assessment step and the `Run GNATprove` step. Local runs are quiet
without any flag; nothing is hidden in CI.

The filtering lives in `Adacovex.Prove.Replay_Suppressed`, which now takes
the comma-separated set list (empty = default set) instead of hardcoding the
single unrolling tag. `Prove_Options` carries the set list, and
`CLI_Config` tracks the effective quiet state plus an explicit-flag marker so
`--quiet`/`--suppress-warnings` still validate as prove-mode flags without a
plain local run tripping the "requires the prove subcommand" check.

### C2: loop-unrolling notices eliminated at the source

The `prove` subcommand always passes `--no-loop-unrolling` to gnatprove (as
of 1.17.0), so gnatprove never *emits* the "cannot unroll loop" notice in
the first place; the C1 suppression is the safety net for any residual info
messages from other tags or other gnatprove versions. Ada_CRDT's `make
prove` and its CI workflows also pass `--no-loop-unrolling` explicitly, so
the notices are gone there too with the current published binary, not just
the next release. Proof-neutral: 720/720 adacovex and 589/589 Ada_CRDT VCs,
0 unproved, with and without the flag.

## Test Suite

865 tests passing (was 853) across 14 categories: the config category grows
from 124 to 136 with the new `--quiet` / `--suppress-warnings` /
`--suppress-warnings=SETS` parsing checks (including the quiet-by-default
defaults: suppression on, empty set list, explicit flag unset). All other
categories unchanged. Counts synced with `make test-count`.

## Proof Results

Platinum, 720/720 VCs proved across 49 analyzed units (unchanged from
1.17.0): the C1/C2 changes touch CLI parsing, the prove option record, and
the output-replay filter -- all default-off or I/O-bound bodies, so no new
proof obligations. 0 unproved, 0 justified. Re-verified with
`adacovex prove --target=. --force` under gnatprove 16.1.0 (`--steps=10000`).
The Ada_CRDT dogfood target re-verified at Platinum, 589/589 VCs, 0
unproved, 0 justified.

## Traceability

No new HLRs. The quiet/suppression behavior extends the existing `HLR-CLI`
tag (`--quiet`, `--suppress-warnings=SETS` parsing in `adacovex-config`) and
`HLR-PROVE` (`Replay_Suppressed` set-list filtering in `adacovex-prove`),
covered by the C1 config tests and the `make run-ada-crdt` dogfood
regression. The CI `--verbose` wiring is covered by this project's and
Ada_CRDT's workflow files; see `docs/cli-reference.md` for the full flag
documentation.
