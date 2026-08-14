# adacovex 1.9.0

Date: _2026-08-14_

Version bumped 1.8.0 -> 1.9.0.

## Changes

### C1: Honest GNATprove parse across gnatprove v15/v16

`Adacovex.Parsers.GNATprove` now reconciles the command-line `Summary of
SPARK analysis` "Total" row between gnatprove 15.x and 16.x: the row layout
differs between versions (the prover and unproved columns are centered and
the "Justified"/"Unproved" columns are blank (`.`) in one format and populated
in the other). A field-based reader (`Get_Column_Number`) extracts each column
by its padded column span instead of by "nth number in the line", so a
justified-VC percentage that was mistaken for the unproved percentage on the
shared 15.x/16.x layout no longer corrupts the summary. This fixes the
self-assessment: the previous "Platinum / all VCs proved" report was a parser
artifact that read the unproved column as zero; the honest level is now
reported (Silver under 16.1.0).

### C2: Global gnatprove version pin (`adacovex.toml` / env)

`covex prove` resolves `gnatprove` as: **manifest pin > global pin > PATH >
cache > download**. A new global pin -- the `ADACOVEX_GNATPROVE_VERSION`
environment variable or the `[prove] gnatprove-version = "16.1.0"` key in
`~/.adacovex/adacovex.toml` -- deploys the exact gnatprove binary crate
standalone via `alr -n get` and runs it directly, with the same
authoritative, never-fall-back semantics as a manifest pin. It applies only
to projects whose own manifest does not declare gnatprove (the manifest pin
always wins), so a single workstation/CI can fix every proof on one prover
without touching each project's manifest. The provenance and the pin are
folded into the proof result-cache identity, so proofs from different provers
never mix.

### C3: CI threshold gates (`--require-spark` / `--require-docstrings` / `--require-tests` / `--require-proof`)

Four `--require-*` flags add explicit minimum-bar checks on top of the DAL
criteria. Off by default; when set, the assessment fails loudly (exit code 1
with an explicit `CI GATE:` reason) if the target falls below the required
level: `--require-spark=LVL` (Stone..Platinum), `--require-docstrings=PCT`
and `--require-proof=PCT` (percent, 0-100), and `--require-tests=N` (passing
test count). The GitHub Action exposes matching `require-spark`,
`require-docstrings`, `require-tests`, and `require-proof` inputs. Because a
stricter gnatprove can legitimately leave more VCs unproved, the gates are
designed to be set against the results of the prover actually pinned.

### C4: Honest SBOM proof level

`Adacovex.Renderers.SBOM.Proof_Level_Property` now reports the assessed level
verbatim (`Stone`..`Platinum`) instead of collapsing every non-Platinum result
to `"Gold"`, so an SBOM never overstates assurance (Silver with unproved VCs
is reported as `"Silver"`). The proof-level postcondition was widened to the
full range accordingly.

## Test Suite

361 tests (was 336 native + new cases). Added: gnatprove v15/v16 Total-row
reconciliation cases (`Get_Column_Number`), CI-threshold default/set checks in
`adacovex_config_tests` (the CLI gnatprove-version pin was removed), and the
honest SBOM proof-level mapping in `adacovex_sbom_tests`.

## Proof Results

Self-assessment now reports the honest level: **Silver** -- 509 VCs, 168
unproved under gnatprove 16.1.0 across 38 analyzed units. gnatprove 16.1.0
generates stricter overflow/counterexample checks than 15.x and leaves more
VCs unproved; the earlier "Platinum / 503/503 proved" self-assessment was a
parser artifact that read the unproved column as zero. The CI gates
(`require-spark=Silver`, `require-proof=65` in the Makefile and workflows)
now match this honest baseline.

## Traceability

No new HLR tags were added. The changed packages are covered by the existing
tags:
- `-- HLR-PROOF` on `Adacovex.Parsers.GNATprove` -- parser reconciliation.
- `-- HLR-PROVE` on `Adacovex.Prove` -- global gnatprove pin + resolution order.
- `-- HLR-CLI` on `Adacovex.Config` -- `--require-*` CI gates (CLI parsing).
- `-- HLR-SBOM` on `Adacovex.Renderers.SBOM` -- honest proof-level property.