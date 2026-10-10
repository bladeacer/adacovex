# adacovex usage guide

This section holds the user guide for adacovex. Each page stands on its own.
You can read one page without the others, and every page links to the
[API reference](../api-docs/index.md) for the exact subprogram or flag.

All pages use British English and ASD-STE100 Simplified Technical English.
Paragraphs hold at most four sentences. The controlled Technical Names
dictionary lives in
[STE100 Technical Names](../contributing/ste100/index.md), and the web-site
terms used on the [site transparency](../site-transparency.md) page live in
[web site terms](../contributing/ste100/web-terms.md).

## Install and run

- [Installing adacovex](installation.md) -- the Alire crate, the release
  bundle, and the source build, with the version source for each route.
- [Target project requirements](target-projects.md) -- what a target project
  must contain before adacovex can assess it.
- [Web dashboard and JSON API](dashboard.md) -- `--serve`, the HTML report at
  `/`, the JSON API at `/api/metrics`, and the served badges.

## Assess a project

- [CLI reference](cli-reference.md) -- every command, flag, and exit code. The
  detailed flag pages are
  [assessment flags and subcommands](cli-reference-flags.md),
  [serving, CI, and tool options](cli-reference-options.md), and
  [emitted reports and differential modes](cli-reference-emit.md).
- [Compliance standards](standards.md) -- DO-178C, ISO 26262, and IEC 62304.
  The per-standard detail is on
  [DO-178C and the DAL levels](standards-do-178c.md),
  [ISO 26262 and the ASIL levels](standards-iso-26262.md),
  [IEC 62304 and the safety classes](standards-iec-62304.md), and
  [selecting a standard](standards-selection.md).
- [VCS support and differential assessment](vcs.md) -- the differential modes
  across git, hg, svn, fossil, and jj.

## Read the results

- [Dashboard document and dependency views](dashboard-html.md) -- the layout
  of the report and every dependency view it draws.
- [Dashboard metric charts and robustness tier](dashboard-charts.md) -- the
  charts, the sparklines, and the robustness tier.
- [Dashboard JSON API, playground, and themes](dashboard-api.md) -- the API
  schema, the theme resolution order, and the `localStorage` theme key.
- [Bundled offline manual](dashboard-docs.md) -- the manual that `--serve`
  exposes at `/docs`, and how it is embedded in the binary.
- [SBOM](sbom.md) -- the proof-aware CycloneDX and SPDX bill of materials.
  [SBOM dependency resolution](sbom-resolution.md) holds the licence and
  dependency lookup.
- [HLR index](../compliance/HLR.md) and
  [LLR mapping](../compliance/LLR.md) -- the requirement traceability, and
  [verification results](../compliance/VERIFICATION.md) for a full run.

## Publish in CI

- [CI/CD](ci-cd.md) -- the GitHub Action and the workflow summary. The
  internals are on
  [CI/CD workflows, summaries, and release bundling](ci-cd-workflows.md) and
  [the composite action](ci-cd-action.md), and the release path is on
  [release bundling, tags, and consumer manifests](ci-cd-release.md).

## Manage the toolchain

- [Global configuration and state](configuration.md) -- the optional
  the global configuration file file, the environment variables, and the cache
  and toolchain directories.
- [Platform support](platforms.md) -- supported platforms and the toolchain
  state of each.

## Where to look next

- The [API reference](../api-docs/index.md) lists every package, type, and
  subprogram with its contracts.
- The [site transparency page](../site-transparency.md) states what the
  online manual records when you read it.
- The [contributor guide](../contributing/developer-guide.md) covers setup,
  gates, and the release workflow for people who change adacovex itself.
- The [changelogs](../changelogs/index.md) hold the release history.
