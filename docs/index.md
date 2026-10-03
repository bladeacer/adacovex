# adacovex Documentation

This page is the index for all adacovex documentation. Pick a section
relevant to you, or read the pages in the order below.

**Read [Site transparency](site-transparency.md) first.** It is the first entry
in the sidebar, so you can reach it from every page. It states what the online
manual records when you read it: search, traffic analytics, advertising, and
the flyout menu.

All documentation uses British English and ASD-STE100 Simplified Technical
English. The controlled Technical Names dictionary lives in
[STE100 Technical Names](contributing/ste100/index.md); use it before you use
a technical word in any doc, docstring, or changelog.

## Getting started

- [Installation](usage/installation.md) -- install the binary or the action.
- [Target projects](usage/target-projects.md) -- what a target needs.

## Using adacovex

- [Usage guide](usage/index.md) -- the self-contained user guide, grouped by
  task: install and run, assess a project, read the results, publish in CI,
  and manage the toolchain. Start at
  [installation](usage/installation.md).
- [CLI reference](usage/cli-reference.md) -- every command, flag, and exit
  code. The detailed flag pages are
  [assessment flags and subcommands](usage/cli-reference-flags.md),
  [serving, CI, and tool options](usage/cli-reference-options.md), and
  [emitted reports and differential modes](usage/cli-reference-emit.md).
- [Web dashboard](usage/dashboard.md) -- the HTML report, the JSON API, the
  dependency views, the metric charts, the themes, and the bundled offline
  manual.
- [SBOM](usage/sbom.md) -- the bill-of-materials generator, with
  [dependency resolution](usage/sbom-resolution.md) for licences and versions.
- [Global configuration and state](usage/configuration.md) -- the optional
  `~/.adacovex/adacovex.toml` file, the environment variables, and the cache
  and toolchain directories.
- [Standards](usage/standards.md) -- DO-178C, ISO 26262, and IEC 62304
  levels. The per-standard detail is on
  [DO-178C and the DAL levels](usage/standards-do-178c.md),
  [ISO 26262 and the ASIL levels](usage/standards-iso-26262.md),
  [IEC 62304 and the safety classes](usage/standards-iec-62304.md), and
  [Selecting a standard](usage/standards-selection.md).
- [Platforms](usage/platforms.md) -- supported platforms and toolchain
  state.
- [VCS support](usage/vcs.md) -- differential assessment across git, hg,
  svn, fossil, and jj.
- [CI/CD](usage/ci-cd.md) -- the GitHub Action and the workflow summary.
  The workflow internals are on
  [CI/CD workflows, summaries, and release bundling](usage/ci-cd-workflows.md),
  the action's inputs and outputs are on
  [the composite action](usage/ci-cd-action.md), and the release bundling,
  floating tags, and consumer manifests are on
  [Release bundling, tags, and consumer manifests](usage/ci-cd-release.md).
- [Changelog](changelogs/index.md) -- release history.

## Contributing to adacovex

- [Developer guide](contributing/developer-guide.md) -- the contributor
  handbook: setup, gates, and release workflow. The source layout, the
  pipeline, and the generated artifacts are on the
  [repository layout](contributing/developer-guide-layout.md).
- [Proving and writing proofs](contributing/proving.md) -- how to run and
  write SPARK proofs. Writing proof patches over vendored code is on
  [Proof patches](contributing/proving-patches.md).
- [Architecture](contributing/architecture.md) -- the full technical
  design. The deeper pages are
  [dependency management and the toolchain](contributing/architecture-dependencies.md),
  [verification and proof patches](contributing/architecture-verification.md),
  [outputs and formats](contributing/architecture-outputs.md), and
  [pipeline, platforms, and delivery](contributing/architecture-pipeline.md).
- [Requirements](contributing/requirements.md) -- the dependency
  categorisation.
- [Performance](contributing/perf/index.md) -- the benchmark categories and
  the current numbers, with [how to run them](contributing/perf/benchmarks.md),
  the [per-phase prove timings](contributing/perf/prove-timing.md) and its
  [1.55.0 re-baseline](contributing/perf/prove-rebaseline.md), plus the
  [optimisation history](contributing/perf/optimisation-history.md).
- [gnatprove-friendly IR](contributing/ir.md) -- the design exploration for
  synthesising bounded, contract-carrying code.
- [STE100 Technical Names](contributing/ste100/index.md) -- the controlled
  dictionary of rules and entries, split into seven lexicons: the Ada
  language, proof and compliance, tooling, hardware, the tools and files, the
  reports and concepts, and the web site terms.
- [LLM usage](contributing/llm-usage.md) -- guidance for AI agents.

## Maintainer references

- [Proof ledger](proof/index.md) -- the verified-VC history and the skipped
  units audit.
- [Compliance outputs](compliance/index.md) -- VERIFICATION.md, TRACE.md,
  and the HLR/LLR indexes.
- [HLR index](compliance/HLR.md) and [LLR mapping](compliance/LLR.md).
- [Badges](badges/index.md) -- the badge set the self-assessment emits.
- [Archive](archive/index.md) -- dated records kept for traceability.
- [API reference](api-docs/index.md) -- the generated package
  documentation.

The docs live under `docs/` as a **Sphinx** project (`docs/conf.py` with
MyST, plus a root `docs/index.md` holding the toctree). The pages are grouped
by audience: `docs/usage/` for end users, `docs/contributing/` for
contributors, and the top-level references plus `docs/proof/`,
`docs/compliance/`, and `docs/badges/` for maintainers. Build and sync
instructions live in the [developer guide](contributing/developer-guide.md).

```{toctree}
:caption: Read this first
:maxdepth: 1
:hidden:

site-transparency
```

```{toctree}
:caption: Getting started
:maxdepth: 1
:hidden:

usage/index
usage/installation
usage/target-projects
```

```{toctree}
:caption: Using adacovex
:maxdepth: 1
:hidden:

usage/cli-reference
usage/cli-reference-flags
usage/cli-reference-options
usage/cli-reference-emit
usage/dashboard
usage/dashboard-html
usage/dashboard-api
usage/dashboard-charts
usage/dashboard-docs
usage/sbom
usage/sbom-resolution
usage/configuration
usage/platforms
usage/vcs
usage/ci-cd
usage/ci-cd-action
usage/ci-cd-workflows
usage/ci-cd-release
changelogs/index
```

```{toctree}
:caption: Standards
:maxdepth: 1
:hidden:

usage/standards
usage/standards-do-178c
usage/standards-iso-26262
usage/standards-iec-62304
usage/standards-selection
```

```{toctree}
:caption: Contributing to adacovex
:maxdepth: 1
:hidden:

contributing/developer-guide
contributing/developer-guide-layout
contributing/requirements
contributing/ir
contributing/llm-usage
```

```{toctree}
:caption: Architecture
:maxdepth: 1
:hidden:

contributing/architecture
contributing/architecture-dependencies
contributing/architecture-verification
contributing/architecture-outputs
contributing/architecture-pipeline
```

```{toctree}
:caption: Proving and proofs
:maxdepth: 1
:hidden:

contributing/proving
contributing/proving-patches
```

```{toctree}
:caption: Performance
:maxdepth: 1
:hidden:

contributing/perf/index
contributing/perf/benchmarks
contributing/perf/benchmarks-timings
contributing/perf/benchmarks-binary-size
contributing/perf/benchmarks-server
contributing/perf/prove-timing
contributing/perf/prove-rebaseline
contributing/perf/optimisation-history
```

```{toctree}
:caption: STE100 technical names
:maxdepth: 1
:hidden:

contributing/ste100/index
contributing/ste100/ada-terms
contributing/ste100/proof-terms
contributing/ste100/tooling-terms
contributing/ste100/entities
contributing/ste100/identifiers
contributing/ste100/concepts
contributing/ste100/web-terms
```

```{toctree}
:caption: Maintainer references
:maxdepth: 1
:hidden:

compliance/HLR
compliance/LLR
proof/index
compliance/index
badges/index
api-docs/index
CREDITS
THIRD_PARTY_NOTICES
```

```{toctree}
:caption: Archive
:maxdepth: 1
:hidden:

archive/index
archive/16.1.0-ledger-audit
archive/optimisation-history-archive
```
