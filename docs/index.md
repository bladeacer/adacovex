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
  code.
- [Web dashboard](usage/dashboard.md) -- the HTML report and JSON API.
- [SBOM](usage/sbom.md) -- the software-bill-of-materials generator.
- [Standards](usage/standards.md) -- DO-178C, ISO 26262, and IEC 62304
  levels.
- [Platforms](usage/platforms.md) -- supported platforms and toolchain
  state.
- [VCS support](usage/vcs.md) -- differential assessment across git, hg,
  svn, fossil, and jj.
- [CI/CD](usage/ci-cd.md) -- the GitHub Action and the workflow summary.
- [Changelog](changelogs/index.md) -- release history.

## Contributing to adacovex

- [Developer guide](contributing/developer-guide.md) -- the contributor
  handbook: setup, codebase tour, gates, and release workflow.
- [Proving and writing proofs](contributing/proving.md) -- how to run and
  write SPARK proofs, including proof patches.
- [Architecture](contributing/architecture.md) -- the full technical
  design.
- [Requirements](contributing/requirements.md) -- the dependency
  categorisation.
- [Performance](contributing/perf.md) -- benchmarking and optimisation
  history.
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
- [HLR index](HLR.md) and [LLR mapping](LLR.md).
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
usage/dashboard
usage/sbom
usage/standards
usage/platforms
usage/vcs
usage/ci-cd
changelogs/index
```

```{toctree}
:caption: Contributing to adacovex
:maxdepth: 1
:hidden:

contributing/developer-guide
contributing/proving
contributing/architecture
contributing/requirements
contributing/perf
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