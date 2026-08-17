# adacovex 0.1.0

Date: _2026-07-26_

Version bumped 0.0.0 -> 0.1.0.

## Changes

### C1: Source scanner

Walks `.ads` files and extracts subprogram declarations, docstring tags
(`@param`, `@return`, `@field`, `@formal`), and HLR tags.

### C2: GNATprove parser

Reads `gnatprove.out` summary tables per check category.

### C3: Test-result parser

Reads AUnit Markdown test results and raw stdout.

### C4: DO-178C parser

Reads `HLR.md` and `LLR.md` requirements documents.

### C5: DAL compliance assessment

Evaluates HLR trace, orphan tags, test status, and minimum SPARK proof level.

### C6: ANSI terminal renderer

Color-coded terminal report.

### C7: SVG badge renderer

SPARK level, test status, and DO-178C status badges.

### C8: Markdown report renderer

`VERIFICATION.md` + `TRACE.md` reports.

### C9: HTML dashboard with JSON API

Web dashboard with embedded CSS and a JSON API endpoint.

### C10: HTTP/1.1 server

Built on `GNAT.Sockets`.

### C11: CLI argument parser

Supports `--key=value` and `--key value` forms.

### C12: Self-compliance documentation

`HLR.md`, `LLR.md`, and `TRACE.md` documenting the project itself.

### C13: Zero-dependency design

Only the GNAT runtime required, with compile-time bounded storage and no heap
allocation.

### C14: Makefile targets

`build` / `alr build`, `prove` / `alr gnatprove`, `fmt` (gnatpp), `lint`,
`api-docs` (gnatdoc), a git-log based `changelog`, and `run-self` /
`run-self-serve` / `run-self-badges`.

## Test Suite

No native test suite at this release; the zero-dependency test framework
(`src/tests/`) shipped with 1.0.0 (152 tests across 7 categories).

## Proof Results

No proof campaign was recorded for this release; the first recorded SPARK
metrics are in 1.0.0 (Platinum, 28/28 VCs proved, AoRTE-free).

## Traceability

Introduced `docs/HLR.md`, `docs/LLR.md`, and `docs/TRACE.md` self-compliance
documentation. Tags tracked at this release (from `docs/HLR.md`):
`HLR-SCAN`, `HLR-PROOF`, `HLR-TEST`, `HLR-COMPLIANCE`, `HLR-RENDER-ANSI`,
`HLR-RENDER-SVG`, `HLR-RENDER-MD`, `HLR-RENDER-HTML`, `HLR-SERVER`,
`HLR-CLI`, `HLR-METRICS`, `HLR-ARCH`.
