# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-26

### Added

- Source scanner: walks `.ads` files, extracts subprogram declarations,
  docstring tags (`@param`, `@return`, `@field`, `@formal`), and HLR tags
- GNATprove parser: reads `gnatprove.out` summary tables per check category
- Test parser: reads AUnit Markdown test results and raw stdout
- DO-178C parser: reads HLR.md and LLR.md requirements documents
- DAL compliance assessment: evaluates HLR trace, orphan tags, test status,
  and minimum SPARK proof level
- ANSI terminal renderer with color-coded report
- SVG badge renderer for SPARK level, test status, and DO-178C status
- Markdown report renderer (VERIFICATION.md + TRACE.md)
- HTML dashboard with embedded CSS and JSON API endpoint
- HTTP/1.1 server built on GNAT.Sockets
- CLI argument parser supporting `--key=value` and `--key value` forms
- Self-compliance documentation (HLR.md, LLR.md, TRACE.md)
- Zero-dependency design: only GNAT runtime required
- Compile-time bounded storage, no heap allocation

### Targets

- `make build` / `alr build`
- `make prove` / `alr gnatprove`
- `make fmt` -- format with gnatpp
- `make lint` -- check build warnings
- `make api-docs` -- generate gnatdoc output
- `make changelog` -- git-log based changelog
- `make run-self` / `run-self-serve` / `run-self-badges`
