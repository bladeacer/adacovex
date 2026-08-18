# AI / LLM Usage in this Project

This page collects everything about how AI tooling is used in the adacovex
project: the disclosure, why the code is trustworthy despite AI assistance,
how LLM agents are expected to work on the codebase, and the honest limits
of machine-generated code.

## AI Assistance Disclosure

AI tools were used during development for boilerplate generation, contract
drafting, and docstring formatting. This is stated plainly rather than
hidden: the project's own dogfood target is a zero-dependency, fully
documented, SPARK-proven Ada codebase, and AI-generated contributions must
meet the same bar as hand-written ones -- 100% docstring coverage, Platinum
proof, zero justified VCs, and the full `make check` gate before they count.

## "Why should I trust your code?"

Given the use of AI assistance, healthy skepticism is natural and encouraged.
Reliability is grounded in proof and design, not implicit trust:

- **Formal Verification:** core Ada logic is formally verified (Platinum under
  `gnatprove` 16.1.0 -- 408 VCs, 0 unproved; see
  [docs/proof/16.1.0-ledger.md](proof/16.1.0-ledger.md)). The proof is
  re-run by `make prove` on every
  change and is a hard gate before any release.
- **Read-Only Engine:** adacovex assesses input payloads, build artifacts, and
  reports without modifying your source files in place. An AI-assisted tool
  that cannot write to the tree it audits is a smaller blast radius by design.
- **Open Auditability:** fully open source under Apache-2.0 -- every line,
  human or AI-written, is inspectable.

> *Still skeptical?* See Ken Thompson's landmark paper,
> [*Reflections on Trusting Trust*](https://dl.acm.org/doi/epdf/10.1145/358198.358210),
> on the fundamental nature of trust in software toolchains -- the point being
> that no software (and no compiler, and no model) is trustworthy purely by
> assertion; it must be inspectable and independently verifiable.

## How LLM agents work on this codebase

[`AGENTS.md`](../AGENTS.md) at the repo root is the machine-readable project
brief. It carries the architecture tree, the pipeline, the SPARK discipline,
the Makefile targets, and the verification gates. An agent (or human) working on
the tree is expected to read it first and to follow it -- in particular:

- **Match existing conventions** and prefer editing existing files; verify
  non-trivial changes with the project's typecheck and tests.
- **Zero library dependency** is a hard constraint: use only the GNAT runtime,
  and keep `tools/*.py` pure-stdlib, `typing`-annotated Python.
- **SPARK proof discipline** (enforced by `make prove` and the
  `spark-off-check` gate): zero unproved VCs, zero justified VCs, no
  `SPARK_Mode (Off)` outside the Types.Implementation container package.
- **The quality gate is the contract**: `make check` runs the same gates CI
  enforces before a release, and a contribution that fails it is not done.
- **Generated files are regenerated, not hand-edited**: the version constant,
  the dashboard template package, the architecture tree, the count-synced
  docs, and the descriptions all come from `tools/*.py` scripts whose
  `--check` modes verify they did not drift.

The doc-sync tools (`tools/update-test-count.py` and
`tools/update-proof-status.py`) derive their file set from the tree itself
(`tools/live_files.py`) rather than a hardcoded list, precisely so that a
stale metric cannot survive anywhere -- generated outputs and historical
records (past-release changelogs, past proof ledgers) are excluded and keep
their release-time numbers.

## Verifying claims instead of trusting them

Every number in this repository's documentation is anchored to a generated
artifact, not to a human- or AI-written claim:

- VC counts and the SPARK level come from `obj/gnatprove/gnatprove.out`
  (via `make proof-status`).
- Test counts come from [docs/test_result.md](test_result.md) (via
  `make test-count`).
- Crate descriptions come from `alire/description.txt` and
  `alire/long-description.txt` (via `make description`).

The CI badge `docs/badges/*.svg` files are emitted by the assessment itself.
If a document carries a number that does not match the artifact, one of the
`--check` gates in `make check` fails loudly -- that is the point.

## Working in a fork or branch (LLM or human)

Because the gates are cheap and deterministic, the safest workflow is to
iterate locally and let `make check` be the arbiter:

```bash
make build && make test      # native suite must stay 666/666
make prove                   # Platinum, 0 unproved, 0 justified
make check                   # full gate: static checks, build, test, prove,
                             # doc, sbom, then tree-wide count-sync checks
```

`make check` runs the cheap static gates first (ascii, spark-off, changelog,
version source, doc links) so a formatting or sync problem fails before the
expensive build + SPARK proof, then verifies the count-sync checks
(`test-count --check`, `proof-status --check`, `description --check`) so a
stale metric anywhere in the tree fails loudly. Regenerated files that are
byte-identical when nothing changed (the version constant, the dashboard
template) are left untouched so `git status` stays quiet.

## The served dashboard as a trust surface

`adacovex --serve` renders a live HTML dashboard at `/` plus a JSON API at
`/api/metrics` and SVG badges at `/badge/*.svg` -- the same numbers an agent
or reviewer would quote from the CLI are visible (and machine-checkable) in
the browser. The dashboard shell is a real file
(`resources/dashboard.html`) bundled at build time by
`tools/gen-dashboard.py`, so page chrome is a plain HTML edit with no Ada
knowledge required; the dynamic cards are injected by the Ada renderer. The
theme resolution chain (query param, then explicit `--theme`, then saved
`localStorage`, then system preference) and the localStorage-only
persistence are documented in [dashboard.md](dashboard.md).

## Honest limits

AI assistance raises the pace of contribution but does not change the bar:

- An AI-written docstring that is not provably accurate is a liability, not a
  contribution -- the 100% docstring-coverage gate measures presence, and
  review measures accuracy.
- Generated code must still pass the SPARK proof; a `pragma Assume` or a
  `SPARK_Mode (Off)` outside the one allowed container package is rejected
  by the gates.
- The changelog, the traceability tags, and the HLRs are written by people
  (or by agents following AGENTS.md), and the `changelog-check` validator
  enforces the canonical format -- a machine-generated changelog that does
  not conform is caught before release.
