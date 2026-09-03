# AI / LLM Usage in this Project

This page collects everything about how AI tooling is used in the adacovex
project: the disclosure, why the code is trustworthy despite AI assistance, how
LLM agents are expected to work on the codebase, and the honest limits of
machine-generated code.

## AI Assistance Disclosure

AI tools were used during development for boilerplate generation, contract drafting, and docstring formatting. This is stated plainly rather than hidden. The project's own dogfood target is a zero-dependency, fully documented, SPARK-proven Ada codebase. AI-generated contributions must meet the same bar as hand-written ones.

That bar is 100% docstring coverage, Platinum proof, zero justified VCs, and the full `make check` gate before they count.

## Why trust this code?

Given the use of AI assistance, healthy skepticism is natural and encouraged.
Reliability is grounded in proof and design, not implicit trust:

- **Formal Verification:** core Ada logic is formally verified. It is Platinum
  under `gnatprove` 16.1.0, 876 VCs, 0 unproved (see
  [docs/proof/16.1.0-ledger.md](../proof/16.1.0-ledger.md)). The proof is re-run by
  `make prove` on every change. It is a hard gate before any release.
- **Read-Only Engine:** adacovex assesses input payloads, build artifacts, and
  reports without modifying your source files in place. An AI-assisted tool that
  cannot write to the tree it audits is a smaller blast radius by design.
- **Open Auditability:** fully open source under Apache-2.0. Every line, human
  or AI-written, is inspectable.

> *Still skeptical?* See Ken Thompson's landmark paper,
> [*Reflections on Trusting Trust*](https://dl.acm.org/doi/epdf/10.1145/358198.358210),
> on the fundamental nature of trust in software toolchains. The point is that no
> software, compiler, or model is trustworthy purely by assertion. It must be
> inspectable and independently verifiable.

## How LLM agents work on this codebase

[`AGENTS.md`](https://github.com/bladeacer/adacovex/blob/main/AGENTS.md) at the repo root is the machine-readable project
brief. It carries the architecture tree, the pipeline, the SPARK discipline,
the Makefile targets, and the verification gates. An agent (or human) working
on the tree must read it first. It must follow it. In particular:

- **Match existing conventions** and prefer editing existing files. Verify
  non-trivial changes with the project's typecheck and tests.
- **Zero library dependency** is a hard constraint. Use only the GNAT runtime.
  Keep `tools/*.py` pure-stdlib, `typing`-annotated Python.
- **SPARK proof discipline** (enforced by `make prove` and the
  `spark-off-check` gate): zero unproved VCs, zero justified VCs, no
  `SPARK_Mode (Off)` outside the `Types.Implementation` and `Complexity`
  container packages (non-formal `Ada.Containers` are illegal in
  SPARK_Mode-On code; see `docs/proof/16.1.0-ledger.md`).
- **The quality gate is the contract.** `make check` runs the same gates that
  CI enforces before a release. A contribution that fails it is not done.
- **Generated files are regenerated, not hand-edited.** The version constant,
  the dashboard template package, the architecture tree, the count-synced docs,
  and the descriptions all come from `tools/*.py` scripts. Their `--check`
  modes verify they did not drift.

The doc-sync tools (`tools/update-test-count.py` and `tools/update-proof-status.py`) derive their file set from the tree itself (`tools/live_files.py`). They do not use a hardcoded list. A stale metric cannot survive anywhere. Generated outputs and historical records (past-release changelogs, past proof ledgers) are excluded.

They keep their release-time numbers.

## Verifying claims instead of trusting them

Every number in this repository's documentation is anchored to a generated
artifact, not to a human- or AI-written claim:

- VC counts and the SPARK level come from `obj/gnatprove/gnatprove.out` (via
  `make proof-status`).
- Test counts come from [docs/test_result.md](../test_result.md) (via
  `make test-count`).
- Crate descriptions come from `alire/description.txt` and
  `alire/long-description.txt` (via `make description`).

The CI badge `docs/badges/*.svg` files are emitted by the assessment itself.
If a document carries a number that does not match the artifact, one of the
`--check` gates in `make check` fails loudly. That is the point.

## Working in a fork or branch (LLM or human)

Because the gates are cheap and deterministic, the safest workflow is to
iterate locally and let `make check` be the arbiter:

```bash
make build && make test      # native suite must stay 738/738
make prove                   # Platinum, 0 unproved, 0 justified
make check                   # full gate: static checks, build, test, prove,
                             # doc, sbom, then tree-wide count-sync checks
```

`make check` runs the cheap static gates first (ascii, spark-off, changelog, version source, doc links). A formatting or sync problem fails before the expensive build and SPARK proof. Then it verifies the count-sync checks (`test-count --check`, `proof-status --check`, `description --check`). A stale metric anywhere in the tree fails loudly.

Regenerated files that are byte-identical when nothing changed (the version constant, the dashboard template) are left untouched. `git status` stays quiet.

## The served dashboard as a trust surface

`adacovex --serve` renders a live HTML dashboard at `/`. It also renders a JSON API at `/api/metrics` and SVG badges at `/badge/*.svg`. The same numbers that an agent or reviewer quotes from the CLI are visible and machine-checkable in the browser. The dashboard shell is a real file (`resources/dashboard.html`).

It is bundled at build time by `tools/gen-dashboard.py`. Page chrome is a plain HTML edit with no Ada knowledge required. The dynamic cards are injected by the Ada renderer. The theme resolution chain (query param, then explicit `--theme`, then saved `localStorage`, then system preference) and the localStorage-only persistence are documented in [dashboard.md](../usage/dashboard.md).

## Honest limits

AI assistance raises the pace of contribution but does not change the bar:

- An AI-written docstring that is not provably accurate is a liability, not a
  contribution. The 100% docstring-coverage gate measures presence. Review
  measures accuracy.
- Generated code must still pass the SPARK proof. A `pragma Assume` or a
  `SPARK_Mode (Off)` outside the two allowed container packages is rejected
  by the gates.
- The changelog, the traceability tags, and the HLRs are written by people.
  They are also written by agents following AGENTS.md. The `changelog-check`
  validator enforces the canonical format. A machine-generated changelog that
  does not conform is caught before release.
