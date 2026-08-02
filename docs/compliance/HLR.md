# High-Level Requirements -- adacovex

## Requirement Index

- HLR-ARCH: Architecture and build system
- HLR-SCAN: Ada source scanning
- HLR-PROOF: SPARK / GNATprove proof analysis
- HLR-TEST: Test result parsing
- HLR-COMPLIANCE: DO-178C compliance assessment (all DAL levels A-E)
- HLR-DAL-A to E: Per-level DAL criteria (see below)
- HLR-DAL-A: DAL-A criteria -- all HLRs traced, no orphans, tests pass, Gold SPARK
- HLR-DAL-B: DAL-B criteria -- all HLRs traced, no orphans, tests pass, Silver SPARK
- HLR-DAL-C: DAL-C criteria -- all HLRs traced, no orphans, tests pass, Bronze SPARK
- HLR-DAL-D: DAL-D criteria -- all HLRs traced, tests pass
- HLR-DAL-E: DAL-E criteria -- all HLRs traced
- HLR-RENDER-ANSI: ANSI terminal rendering
- HLR-RENDER-SVG: SVG badge generation
- HLR-RENDER-MD: Markdown report generation
- HLR-RENDER-HTML: HTML dashboard and JSON API
- HLR-SERVER: HTTP server
- HLR-CLI: CLI argument parsing
- HLR-DIFF: Differential assessment (--compare-base)
- HLR-METRICS: Docstring coverage metrics

## Requirements

- HLR-ARCH: The tool shall build with `alr build` and support Makefile targets
  for build, prove, fmt, lint, api-docs, changelog, and clean.

- HLR-SCAN: The tool shall recursively scan Ada source files, extract subprogram
  declarations, docstring annotations, and HLR traceability tags.

- HLR-PROOF: The tool shall parse GNATprove summary output and categorize
  verification conditions (flow, run-time, assertions, contracts, termination).

- HLR-TEST: The tool shall parse AUnit test results (Markdown or stdout) and
  report total passed / failed test counts.

- HLR-COMPLIANCE: The tool shall assess DO-178C compliance for any DAL level
  A through E. Assessment criteria per level are defined in HLR-DAL-A through
  HLR-DAL-E and implemented in the compliance package.

- HLR-DAL-A: DAL-A assessment shall verify HLR trace coverage (all HLRs found
  in source), no orphan tags, all tests passing, and minimum SPARK Gold level
  (all run-time checks proved, all assertions proved, all functional contracts
  proved, all termination proved).

- HLR-DAL-B: DAL-B assessment shall verify HLR trace coverage, no orphan tags,
  all tests passing, and minimum SPARK Silver level (all run-time checks proved,
  all assertions proved, AoRTE-free).

- HLR-DAL-C: DAL-C assessment shall verify HLR trace coverage, no orphan tags,
  all tests passing, and minimum SPARK Bronze level (flow analysis passes).

- HLR-DAL-D: DAL-D assessment shall verify HLR trace coverage and all tests
  passing. No SPARK proof requirement.

- HLR-DAL-E: DAL-E assessment shall verify HLR trace coverage only. No test or
  proof requirements.

- HLR-RENDER-ANSI: The tool shall render a colour-annotated summary report to
  standard output using ANSI escape codes.

- HLR-RENDER-SVG: The tool shall generate Shields.io-style SVG badges for
  SPARK level, test status, and DO-178C compliance status.

- HLR-RENDER-MD: The tool shall generate Markdown verification reports
  (VERIFICATION.md) and traceability matrices (TRACE.md).

- HLR-RENDER-HTML: The tool shall generate a self-contained HTML dashboard
  page and a JSON metrics API.

- HLR-SERVER: The tool shall serve the dashboard, API, and badge endpoints
  via a built-in HTTP/1.1 server on a configurable port.

- HLR-CLI: The tool shall accept CLI arguments in --key=value and --key value
  forms with sensible defaults, and print usage help on --help.

- HLR-DIFF: The tool shall support differential assessment via --compare-base,
  comparing the target at a git base ref against its current working tree and
  reporting deltas in docstring coverage, HLR traceability, SPARK proof level,
  test results, and DAL status.

- HLR-METRICS: The tool shall compute docstring coverage as a percentage of
  documented subprograms over total subprograms.
