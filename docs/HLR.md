# High-Level Requirements -- adacovex

## Requirement Index

- HLR-ARCH: Architecture and build system
- HLR-SCAN: Ada source scanning
- HLR-PROOF: SPARK / GNATprove proof analysis
- HLR-TEST: Test result parsing
- HLR-COMPLIANCE: DO-178C compliance assessment
- HLR-RENDER-ANSI: ANSI terminal rendering
- HLR-RENDER-SVG: SVG badge generation
- HLR-RENDER-MD: Markdown report generation
- HLR-RENDER-HTML: HTML dashboard and JSON API
- HLR-SERVER: HTTP server
- HLR-CLI: CLI argument parsing
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

- HLR-COMPLIANCE: The tool shall assess DO-178C DAL-C compliance: HLR trace
  coverage, orphan tag detection, test pass status, and minimum SPARK proof
  level.

- HLR-RENDER-ANSI: The tool shall render a color-annotated summary report to
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

- HLR-METRICS: The tool shall compute docstring coverage as a percentage of
  documented subprograms over total subprograms.
