![SPARK level badge](badges/spark.svg)
![Test badge](badges/tests.svg)
![DO-178C badge](badges/do178c.svg)
![ISO 26262 badge](badges/iso26262.svg)
![IEC 62304 badge](badges/iec62304.svg)
![Documentation coverage badge](badges/docs.svg)

# adacovex Documentation

<!-- no-covex-docs-loc: landing page with the full navigation map, the line cap does not apply -->

This page is the index for all adacovex documentation. Pick a section
relevant to you, or read the pages in the order below.

**Read [Site transparency](site-transparency.md) first.** It is the first entry
in the sidebar, so you can reach it from every page. It states what the online
manual records when you read it: search, traffic analytics, advertising, and
the flyout menu.

## Documentation map

Each directory has one job:

- `usage/` -- user guides: install, run, read results, publish in CI.
- `glossary/` -- the reader-facing Technical Names glossary, split into
  seven lexicons.
- `contributing/` -- contributor method: architecture, proving, tools, and
  the benchmark how-to. The per-phase proof timings live under `perf/`.
- `api-docs/` -- generated package reference from the Ada docstrings.
- `changelogs/`, `proof/`, `compliance/`, `badges/` -- the release record,
  proof ledgers, compliance outputs, and badge previews.

All documentation uses British English and ASD-STE100 Simplified Technical
English. The controlled Technical Names glossary lives in
[STE100 Technical Names](glossary/ste100/index.md); use it before you use
a technical word in any doc, docstring, or changelog.

## Getting started

- [Installation](usage/installation.md) -- install the binary or the action.
- [Target projects](usage/target-projects.md) -- what a target needs.

## Using adacovex

- [Usage guide](usage/index.md) -- the self-contained user guide, grouped by
  task: install and run, assess a project, read the results, publish in CI,
  and manage the toolkit. Start at
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
  [dependency resolution](usage/sbom-resolution.md) for licences and versions,
  [transitive lockfile and workflow dependencies](usage/sbom-transitive.md),
  [system dependencies](usage/sbom-system.md), and the
  [syft comparison](usage/sbom-syft.md).
- [Global configuration and state](usage/configuration.md) -- the optional
  project and global configuration files, every key, and the sample
  configuration. The [state directories, environment variables, and
  reset](usage/configuration-state.md) are on the next page.
- [Standards](usage/standards.md) -- DO-178C, ISO 26262, and IEC 62304
  levels. The per-standard detail is on
  [DO-178C and the DAL levels](usage/standards-do-178c.md),
  [ISO 26262 and the ASIL levels](usage/standards-iso-26262.md),
  [IEC 62304 and the safety classes](usage/standards-iec-62304.md), and
  [Selecting a standard](usage/standards-selection.md).
- [Performance and benchmarks](usage/performance.md) -- run times and the
  cache shapes behind them. The current measured figures are on
  [Measured figures](stats/index.md).
- [Platforms](usage/platforms.md) -- supported platforms and toolkit
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

## Glossary

- [STE100 Technical Names](glossary/ste100/index.md) -- the controlled
  dictionary of rules and entries, split into seven lexicons: the Ada
  language, proof and compliance, tooling, hardware, the tools and files, the
  reports and concepts, and the web site terms. Link the first mention of a
  term on a page to its glossary heading.

## Contributing to adacovex

- [Developer guide](contributing/developer-guide.md) -- the contributor
  handbook: setup, gates, and release workflow. The source layout, the
  pipeline, and the generated artifacts are on the
  [repository layout](contributing/developer-guide-layout.md).
- [Proving and writing proofs](contributing/proving.md) -- how to run and
  write SPARK proofs, [proof patches](contributing/proving-patches.md), and
  [reading a prove failure](contributing/proving-diagnostics.md).
- [Architecture](contributing/architecture.md) -- the full technical
  design. The deeper pages are
  [dependency management and the toolkit](contributing/architecture-dependencies.md),
  [verification and proof patches](contributing/architecture-verification.md),
  [outputs and formats](contributing/architecture-outputs.md), and
  [pipeline, platforms, and delivery](contributing/architecture-pipeline.md).
- [Technical debt register](contributing/debt.md) -- the open debt, the
  condition that closes each entry, and the standing SPARK constraints.
- [Requirements](contributing/requirements.md) -- the dependency
  categorisation.
- [Performance](contributing/perf/index.md) -- the benchmark categories and
  the method, with [how to run them](contributing/perf/benchmarks.md),
  the [measured figures](stats/index.md),
  the [per-phase prove timings](contributing/perf/prove-timing.md) and its
  [1.55.0 re-baseline](contributing/perf/prove-rebaseline.md), plus the
  [optimisation history](contributing/perf/optimisation-history.md).
- [gnatprove-friendly IR](contributing/ir.md) -- the design exploration for
  synthesising bounded, contract-carrying code.
- [LLM usage](contributing/llm-usage.md) -- guidance for AI agents.

## Maintainer references

- [Proof ledger](proof/index.md) -- the verified-VC history and the skipped
  units audit.
- [Compliance outputs](compliance/index.md) -- VERIFICATION.md, TRACE.md,
  and the HLR/LLR indexes.
- [HLR index](compliance/HLR.md) and [LLR mapping](compliance/LLR.md).
- [Badges](badges/index.md) -- the badge set the self-assessment emits.
- [Measured figures](stats/index.md) -- the current timings, binary size,
  syscall profile, cache hit rate, bundle size, and test counts, each with
  its host profile and the command that produced it.
- [API reference](api-docs/index.md) -- the generated package
  documentation.
- [tldr page](tldr/adacovex.md) -- the cheat sheet for the CLI, which `adacovex tldr` installs into the local tldr client.

The docs live under `docs/` as a **Sphinx** project (`docs/conf.py` with MyST,
plus a root `docs/index.md` holding the toctree). `docs/usage/` serves end
users, `docs/contributing/` serves contributors, and the top-level references
plus `docs/proof/`, `docs/compliance/`, and `docs/badges/` serve maintainers.
Build and sync instructions live in the [developer guide](contributing/developer-guide.md).

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
tldr/adacovex
usage/dashboard
usage/dashboard-html
usage/dashboard-api
usage/dashboard-charts
usage/dashboard-docs
usage/sbom
usage/sbom-resolution
usage/sbom-transitive
usage/sbom-system
usage/sbom-syft
usage/configuration
usage/configuration-state
usage/platforms
usage/vcs
usage/ci-cd
usage/ci-cd-action
usage/ci-cd-workflows
usage/ci-cd-release
usage/performance
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
:caption: Glossary
:maxdepth: 1
:hidden:

glossary/ste100/index
glossary/ste100/ada-terms
glossary/ste100/proof-terms
glossary/ste100/tooling-terms
glossary/ste100/entities
glossary/ste100/identifiers
glossary/ste100/concepts
glossary/ste100/web-terms
```

```{toctree}
:caption: Contributing to adacovex
:maxdepth: 1
:hidden:

contributing/developer-guide
contributing/developer-guide-layout
contributing/debt
contributing/requirements
contributing/ir
contributing/llm-usage
contributing/commits
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
contributing/proving-diagnostics
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
contributing/perf/check-pipeline
contributing/perf/optimisation-history
```

```{toctree}
:caption: Measured figures
:maxdepth: 1
:hidden:

stats/index
stats/timings
stats/binary-size
stats/syscalls
stats/cache
stats/bundle
stats/tests
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

