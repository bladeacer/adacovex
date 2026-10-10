# High-Level Requirements -- adacovex

## Requirement Index

- HLR-ARCH: Architecture and build system
- HLR-CACHE: Result caching
- HLR-CPU: Cross-platform CPU core detection
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
- HLR-DIFF: Differential assessment (--compare-base)
- HLR-METRICS: Docstring coverage metrics
- HLR-MANIFEST: Alire manifest and dependency-graph parsing
- HLR-PROVE: GNATprove subcommand
- HLR-SBOM: Proof-aware SBOM generation
- HLR-IR: IR type profiles, host/target config, and foreign type-name lowering
- HLR-SPARK: SPARK proof-coverage report

## Requirements

- HLR-ARCH: The tool shall build with `alr build` and provide task targets
  (`just` tasks, mirrored by the Makefile shim) for build, prove, fmt, doc,
  changelog, and clean.

- HLR-CACHE: The tool shall cache per-file analysis results (source scans,
  GNATprove summaries, test summaries) on disk keyed by the SHA-256 hash of
  each analysed artifact, serve unchanged files from the cache instead of
  re-scanning / re-parsing / re-proving, evict oldest entries first when the
  configured cap is reached, and report cache hits, misses, and evictions;
  behaviour is controlled by `--cache` / `--no-cache` / `--cache-dir` /
  `--cache-max`.

- HLR-CPU: The tool shall detect the host logical CPU count across Linux,
  macOS, FreeBSD, and Windows using only the GNAT runtime (no external tools),
  detect CI environments, and resolve GNATprove parallelism: an auto default
  that reserves two cores for system responsiveness on developer machines, all
  cores inside CI, and explicit `-jN` overrides.

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

- HLR-ANSI: The tool shall colour its terminal output, and shall suppress
  colour inside CI or when NO_COLOR is set.

- HLR-TZ: The tool shall resolve a display timezone from the operating
  system or from a user timezone override, and format the current date and
  time in that zone.

- HLR-CLI: The tool shall accept CLI arguments in --key=value and --key value
  forms with sensible defaults, and print usage help on --help.

- HLR-COMPLEXITY: The tool shall compute per-file and per-subprogram cyclomatic
  complexity for Ada source files and enforce configurable LOC and complexity
  gates (max file LOC, max file percentage of codebase, max function
  complexity, max file complexity).

- HLR-DIFF: The tool shall support differential assessment via `--compare-base`. The tool shall compare the target at a git base ref against its current working tree. The tool shall report deltas in docstring coverage, HLR traceability, SPARK proof level, test results, and DAL status. The tool shall also support a lightweight docstring-coverage gate via `--coverage-delta`.

- HLR-METRICS: The tool shall compute docstring coverage as a percentage of
  documented subprograms over total subprograms.

- HLR-MANIFEST: The tool shall resolve the project dependency graph from Alire
  manifest files (alire.toml / alire-dev.toml), the alire.lock solved-crate
  list, and GNAT project (.gpr) with clauses, deduplicating across sources.

- HLR-SBOM: The tool shall generate proof-aware software bills of materials in
  CycloneDX 1.5 and SPDX 2.3 JSON, extending the root component with the
  adacovex:proof_level and adacovex:dal_target properties and dependency
  components with adacovex:proof_level = "Not proved" (third-party
  dependencies are not proved by the tool).

- HLR-PROVE: The tool shall provide a `prove` subcommand that runs GNATprove
  against the target project's root .gpr file. gnatprove is not a declared
  dependency of the tool; when the target's alire.toml / alire-dev.toml
  declares a gnatprove dependency, that pin is authoritative: the tool
  deploys only the gnatprove binary crate into the toolchain cache via
  `alr -n get` (one-time per version, reused after) and runs the deployed
  binary directly, so the tool only requires `alr` on PATH. Otherwise it
  falls back to a globally pinned version, a gnatprove on PATH, a cached
  the toolchain cache bin gnatprove, and finally a platform toolchain
  download, then hands off to the standard assessment pipeline.

- HLR-IR: The tool shall define bounded target machine-integer types
  (IR_Int8 through IR_Int64 and IR_UInt8 through IR_UInt64), a host/target
  word-size configuration, and lower foreign type names (int32_t, size_t,
  usize, ...) onto them, synthesizing bounded Ada declarations that gnatprove
  can prove free of integer overflow.

- HLR-SPARK: The tool shall report SPARK proof coverage from the gnatprove
  artefacts a proof run writes, and shall not run the prover itself. It shall
  report three metrics, and shall name the numerator and the denominator of
  each one: statement coverage, subprogram coverage, and VC coverage. It shall
  group the rows by source file, by folder, or by Ada package.

  Every subprogram gnatprove did not prove shall be placed in exactly one
  class: irreducible (the unit carries an explicit `SPARK_Mode (Off)` pragma or
  aspect), input/output bound (the subprogram references an input or output
  package, or spawns a process), or work queue (any other skipped
  subprogram). The three classes shall be counted separately, so that the
  provable backlog stays visible. Code gnatprove did not report on shall be
  counted as not covered, and shall never be folded into an off class.
