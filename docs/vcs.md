# VCS support and differential assessment

**A version control system is not required for base adacovex functionality.**

This covers scanning, proof analysis, test parsing, compliance assessment, SBOM generation, dashboards, and caching.

A VCS is only needed for the differential modes below. They snapshot a base revision to compare against the current tree.

We assume that the audited project lives in a VCS. The base tool never requires one.

adacovex works on **Linux and WSL**. The snapshot commands run through `sh -c`, which WSL provides.

## When to use differential modes

Differential modes are useful when you want to enforce that changes do not regress quality gates:

- **PR checks** -- `--coverage-delta` makes sure that docstring coverage does not drop between the base branch and the PR head. This is the lightest check. It works even when the base does not commit proof or test artifacts.
- **Release gates** -- `adacovex --compare-base=v1.2.0` compares the current tree against the last release tag. It fails if a metric regressed. These metrics are packages, docstrings, HLR tags, SPARK level, tests, and DAL status.
- **Audit trails** -- a side-by-side report shows exactly what changed between two revisions. This is useful for compliance audits that need a narrative diff.

## Supported VCS

The differential modes run against the VCS that manages the target. Detection is marker-file based, with a command-probe fallback:

| VCS | Marker | Base snapshot mechanism |
|-----|--------|-------------------------|
| git | `.git` | `git worktree add --detach` (linked worktree) |
| jj | `.jj` | `jj git export` into the internal git store, then a git worktree against `.jj/repo/store/git` (jj commits are git commits) |
| Mercurial | `.hg` | `hg archive -r REF DIR` (pure export) |
| Subversion | `.svn` | `svn info --show-item url` + `svn export -r REF URL DIR` |
| Fossil | `.fslckout` / `_FOSSIL_` | copy the repo DB and `fossil open` it at REF in a scratch dir |

For colocated git+jj repos, git wins (exact interop). All snapshots land in `/tmp/adacovex-diff-<pid>` and are cleaned up afterwards. The working tree is never touched.

**UX recommendation**: Git gives the best experience. Jj is its git-compatible sibling. Mercurial is fully supported. For VCS whose snapshot UX is poor, adacovex prints a note. The note recommends that developers convert the repository to git (or a git-compatible VCS):

- **Subversion** -- no local history, network-dependent checkouts, slow `svn export` per snapshot. Converting gives local branches, offline history, and faster diffs.
- **Fossil** -- workable, but the tooling is niche and the single-file DB model complicates CI integration.

These notes are informational only. The assessment still runs and gates still apply on every supported VCS.

`adacovex status` reports the VCS command-line tools on `$PATH`. These tools are git, mercurial/`hg`, subversion/`svn`, fossil, jj, and `mandb`. It reports the VCS detected for the target repository. It prints a note when the target's VCS tool is missing. See [Platforms](platforms.md#status-subcommand).

## `--compare-base=REF`

Differential mode: adacovex snapshots a base revision in a temporary directory (`/tmp/adacovex-diff-<pid>`). It prints a side-by-side comparison against the current tree. The comparison shows packages, subprograms, docstring percentage, traced HLR, orphan tags, SPARK level, proved VCs, tests, and DAL status.

The `--target` directory must be a supported VCS repository. The VCS command-line tool must be on `PATH`.

Exit `0` only if there are no regressions and the current DAL is Achieved. Otherwise, exit `1`. Artifacts that the base does not commit report `N/A` and are not compared. These artifacts are `gnatprove.out` and a test-result summary.

## `--coverage-delta=REF`

Lightweight docstring-coverage gate for PR-style CI checks. It scans sources, patches, and computes docstring metrics on a base revision and the current tree. It does not use GNATprove, tests, or DAL. Thus it works when the base does not commit build artifacts. It prints a compact coverage table and a machine-parseable `coverage_delta:` line. Then it cleans up the snapshot.

Exit `0` if the current docstring coverage is `>=` the base. Exit `0` also if the base has no sources. Exit `1` if coverage regressed. This mode is mutually exclusive with `--compare-base`.

`make release` runs the same gate against the last release tag. For example, `--coverage-delta=v1.1.0` aborts if docstring coverage regressed between releases.
