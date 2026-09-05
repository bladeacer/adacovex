# adacovex Documentation

This page is the index for all adacovex documentation.  Pick a section
relevant to you, or read the pages in the order below.

All documentation uses British English and ASD-STE100 Simplified Technical
English.  The controlled Technical Names dictionary lives in
[STE100 Technical Names](contributing/ste100-technical-names.md).  Use it
before you use a technical word in any doc, docstring, or changelog.

## Getting started

- [Installation](usage/installation.md) -- install the binary or the GitHub
  Action.
- [Target projects](usage/target-projects.md) -- what a target project must
  contain.

## Using adacovex

- [CLI reference](usage/cli-reference.md) -- every command, flag, and exit
  code.  The detailed flag pages are
  [assessment flags and subcommands](usage/cli-reference-flags.md) and
  [output and CI options](usage/cli-reference-options.md).
- [Web dashboard](usage/dashboard.md) -- the HTML report and JSON API.  The
  deeper pages are
  [the dashboard document and its dependency views](usage/dashboard-html.md)
  and [the JSON API, playground, and themes](usage/dashboard-api.md).
- [SBOM](usage/sbom.md) -- the software-bill-of-materials generator.  Licence
  and dependency resolution is on
  [SBOM dependency resolution](usage/sbom-resolution.md).
- [Standards](usage/standards.md) -- DO-178C, ISO 26262, and IEC 62304
  levels.
- [Platforms](usage/platforms.md) -- supported platforms and toolchain
  state.
- [VCS support](usage/vcs.md) -- differential assessment across git, hg,
  svn, fossil, and jj.
- [CI/CD](usage/ci-cd.md) -- the GitHub Action and the workflow summary.
  The workflow internals are on
  [CI/CD workflows, summaries, and release bundling](usage/ci-cd-workflows.md).
- [Changelog](changelogs/index.md) -- release history.

## Contributing to adacovex

- [Developer guide](contributing/developer-guide.md) -- the contributor
  handbook: setup, codebase tour, gates, and release workflow.
- [Proving and writing proofs](contributing/proving.md) -- how to run and
  write SPARK proofs.  Writing proof patches over vendored code is on
  [Proof patches](contributing/proving-patches.md).
- [Architecture](contributing/architecture.md) -- the full technical
  design.  The deeper pages are
  [verification and proof patches](contributing/architecture-verification.md)
  and [outputs, pipeline, and delivery](contributing/architecture-outputs.md).
- [Requirements](contributing/requirements.md) -- the dependency
  categorisation.
- [Performance](contributing/perf.md) -- benchmarking and the current
  numbers.  [Prove timing and the optimisation review]
  (contributing/perf-prove-timing.md) and
  [the optimisation history](contributing/perf-optimisation-history.md)
  cover the detail.
- [gnatprove-friendly IR](contributing/ir.md) -- the design exploration for
  synthesising bounded, contract-carrying code.
- [STE100 Technical Names](contributing/ste100-technical-names.md) -- the
  controlled dictionary.
- [LLM usage](contributing/llm-usage.md) -- guidance for AI agents.

## Maintainer references

- [Proof ledger](proof/index.md) -- the verified-VC history and the skipped
  units audit.
- [Compliance outputs](compliance/index.md) -- VERIFICATION.md, TRACE.md,
  and the HLR/LLR indexes.
- [HLR index](compliance/HLR.md) and [LLR mapping](compliance/LLR.md).
- [Badges](badges/index.md) -- the badge set the self-assessment emits.
- [API reference](api-docs/index.md) -- the generated package
  documentation.

The docs live under `docs/` as a **Sphinx** project (`docs/conf.py` with
MyST, plus a root `docs/index.md` holding the toctree).  The pages are
grouped by audience: `docs/usage/` for end users, `docs/contributing/` for
contributors, and the top-level references plus `docs/proof/`,
`docs/compliance/`, and `docs/badges/` for maintainers.  How to build the
manual, regenerate the bundled offline manual, and keep the generated
outputs in sync is covered in the
[developer guide](contributing/developer-guide.md), not here: this index
stays focused on what each page contains.

```{toctree}
:caption: Getting started
:maxdepth: 1
:hidden:

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
usage/dashboard
usage/dashboard-html
usage/dashboard-api
usage/sbom
usage/sbom-resolution
usage/standards
usage/platforms
usage/vcs
usage/ci-cd
usage/ci-cd-workflows
changelogs/index
```

```{toctree}
:caption: Contributing to adacovex
:maxdepth: 1
:hidden:

contributing/developer-guide
contributing/proving
contributing/proving-patches
contributing/architecture
contributing/architecture-verification
contributing/architecture-outputs
contributing/requirements
contributing/perf
contributing/perf-prove-timing
contributing/perf-optimisation-history
contributing/ir
contributing/ste100-technical-names
contributing/llm-usage
```

```{toctree}
:caption: Maintainer references
:maxdepth: 1
:hidden:

HLR
LLR
proof/index
compliance/index
badges/index
api-docs/index
CREDITS
THIRD_PARTY_NOTICES
```