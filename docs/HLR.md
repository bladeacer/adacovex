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
- HLR-ANSI: Terminal colour support
- HLR-TZ: Timezone resolution and local-time formatting
- HLR-CLI: CLI argument parsing
- HLR-COMPLEXITY: Cyclomatic complexity and LOC gating
- HLR-METRICS: Docstring coverage metrics
- HLR-DIFF: Differential assessment (--compare-base / --coverage-delta)
- HLR-MANIFEST: Alire manifest and dependency-graph parsing
- HLR-PROVE: GNATprove subcommand
- HLR-SBOM: Proof-aware SBOM generation
- HLR-IR: IR type profiles, host/target config, and foreign type-name lowering

## Requirements

- HLR-ARCH: The tool shall build with `alr build` and support Makefile targets for build, prove, fmt, lint, api-docs, changelog, and clean.

- HLR-SCAN: The tool shall recursively scan Ada source files. It shall extract subprogram declarations, docstring annotations, and HLR traceability tags.

- HLR-PROOF: The tool shall parse GNATprove summary output. It shall categorise verification conditions (flow, run-time, assertions, contracts, termination).

- HLR-TEST: The tool shall parse AUnit test results (Markdown or stdout). It shall report total passed / failed test counts.

- HLR-COMPLIANCE: The tool shall assess DO-178C compliance for any DAL level A through E. The compliance package defines and implements the assessment criteria per level. The criteria appear in HLR-DAL-A through HLR-DAL-E.

- HLR-DAL-A: DAL-A assessment shall verify HLR trace coverage. All HLRs found in source must be traced. The assessment shall find no orphan tags. All tests must pass. The SPARK Gold level is the minimum requirement. All run-time checks, assertions, functional contracts, and termination must be proved.

- HLR-DAL-B: DAL-B assessment shall verify HLR trace coverage. The assessment shall find no orphan tags. All tests must pass. The SPARK Silver level is the minimum requirement. All run-time checks and assertions must be proved. The code must be AoRTE-free.

- HLR-DAL-C: DAL-C assessment shall verify HLR trace coverage. The assessment shall find no orphan tags. All tests must pass. The SPARK Bronze level is the minimum requirement. Flow analysis must pass.

- HLR-DAL-D: DAL-D assessment shall verify HLR trace coverage. All tests must pass. There is no SPARK proof requirement.

- HLR-DAL-E: DAL-E assessment shall verify HLR trace coverage only. There is no test or proof requirement.

- HLR-RENDER-ANSI: The tool shall render a colour-annotated summary report to standard output. It shall use ANSI escape codes.

- HLR-RENDER-SVG: The tool shall generate Shields.io-style SVG badges. The badges show SPARK level, test status, and DO-178C compliance status.

- HLR-RENDER-MD: The tool shall generate Markdown verification reports (VERIFICATION.md). It shall generate traceability matrices (TRACE.md).

- HLR-RENDER-HTML: The tool shall generate a self-contained HTML dashboard page. It shall generate a JSON metrics API.

- HLR-SERVER: The tool shall serve the dashboard, API, and badge endpoints. It shall use a built-in HTTP/1.1 server on a configurable port.
- HLR-ANSI: The tool shall colour its terminal output, and shall suppress colour inside CI or when NO_COLOR is set.
- HLR-TZ: The tool shall resolve a display timezone from the operating system or from a user timezone override, and format the current date and time in that zone.

- HLR-CLI: The tool shall accept CLI arguments in --key=value and --key value forms. It shall use sensible defaults. It shall print usage help on --help.

- HLR-COMPLEXITY: The tool shall compute per-file and per-subprogram cyclomatic complexity for Ada source files. The tool shall enforce configurable LOC and complexity gates. The gates cover maximum file LOC, maximum file percentage of the codebase, maximum function complexity, and maximum file complexity.

- HLR-METRICS: The tool shall compute docstring coverage as a percentage of documented subprograms over total subprograms.

- HLR-DIFF: The tool shall support differential assessment via `--compare-base`. The tool shall compare the target at a git base ref against its current working tree. The tool shall report deltas in docstring coverage, HLR traceability, SPARK proof level, test results, and DAL status. The tool shall also support a lightweight docstring-coverage gate via `--coverage-delta`.

- HLR-MANIFEST: The tool shall resolve the project dependency graph from Alire manifest files (alire.toml / alire-dev.toml). It shall resolve the alire.lock solved-crate list and GNAT project (.gpr) with clauses. It shall deduplicate results across sources.

- HLR-SBOM: The tool shall generate proof-aware software bills of materials. It shall use CycloneDX 1.5 and SPDX 2.3 JSON. It shall extend every component with the adacovex:proof_level and adacovex:dal_target properties.

- HLR-PROVE: The tool shall provide a `prove` subcommand that runs GNATprove against the root .gpr file of the target project. gnatprove is not a declared dependency of the tool. When the alire.toml / alire-dev.toml of the target project declares a gnatprove dependency, that pin is authoritative: the tool deploys only the gnatprove binary crate into ~/.adacovex/toolchain via `alr -n get` (one-time per version, reused after) and runs the deployed binary directly. The tool then requires only `alr` on PATH. Otherwise it falls back to a globally pinned version, a gnatprove on PATH, a cached ~/.adacovex/toolchain/bin gnatprove, and finally a platform toolchain download. It transfers control to the standard assessment pipeline.

- HLR-IR: The tool shall define bounded target machine-integer types. The types are IR_Int8 through IR_Int64 and IR_UInt8 through IR_UInt64. The tool shall define a host/target word-size configuration. The tool shall lower foreign type names (int32_t, size_t, usize, and more) onto these types. The tool shall synthesise bounded Ada declarations. GNATprove can prove these declarations free of integer overflow.
