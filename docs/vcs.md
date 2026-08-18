# VCS support and differential assessment

**A version control system is not required for base adacovex functionality**
(scanning, proof analysis, test parsing, compliance assessment, SBOM
generation, dashboards, caching). A VCS is only needed for the differential
modes below, which snapshot a base revision to compare against the current
tree. Since adacovex assesses source code, assuming the audited project lives
in a VCS is sensible -- but the base tool never requires one.

Works on **Linux and WSL** (the snapshot commands run through `sh -c`, which
WSL provides).

## Supported VCS

The differential modes run against the VCS that manages the target. Detection
is marker-file based, with a command-probe fallback:

| VCS | Marker | Base snapshot mechanism |
|-----|--------|-------------------------|
| git | `.git` | `git worktree add --detach` (linked worktree) |
| jj | `.jj` | `jj git export` into the internal git store, then a git worktree against `.jj/repo/store/git` (jj commits are git commits) |
| Mercurial | `.hg` | `hg archive -r REF DIR` (pure export) |
| Subversion | `.svn` | `svn info --show-item url` + `svn export -r REF URL DIR` |
| Fossil | `.fslckout` / `_FOSSIL_` | copy the repo DB and `fossil open` it at REF in a scratch dir |

For colocated git+jj repos git wins (exact interop). All snapshots land in
`/tmp/adacovex-diff-<pid>` and are cleaned up afterwards; the working tree is
never touched.

**UX recommendation**: git (and jj, its git-compatible sibling) give the best
experience. Mercurial is fully supported. For VCS whose snapshot UX is poor,
adacovex prints a note recommending the developers **convert the repository
to git** (or a git-compatible VCS):

- **Subversion** -- no local history, network-dependent checkouts, slow
  `svn export` per snapshot. Converting gives you local branches, offline
  history, and faster diffs.
- **Fossil** -- workable, but the tooling is niche and the single-file DB
  model complicates CI integration.

These notes are informational only: the assessment still runs and gates still
apply on every supported VCS.

`adacovex status` reports which VCS command-line tools are on `$PATH` (git,
mercurial/`hg`, subversion/`svn`, fossil, jj, and `mandb`), the VCS detected
for the target repository, and a note when the target's VCS tool is missing
-- see [Platforms](platforms.md#status-subcommand).

## `--compare-base=REF`

Differential mode: snapshot a base revision in a temporary directory
(`/tmp/adacovex-diff-<pid>`) and print a side-by-side comparison against the
current tree (packages, subprograms, docstring %, HLR traced, orphan tags,
SPARK level, VCs proved, tests, DAL status). The `--target` directory must be
a supported VCS repository with the VCS command-line tool on `PATH`.

Exit `0` only if there are no regressions AND the current DAL is Achieved;
`1` otherwise. Artifacts the base does not commit (`gnatprove.out`, a
test-result summary) report `N/A` and are not compared.

## `--coverage-delta=REF`

Lightweight docstring-coverage gate for PR-style CI checks. Scans sources +
patches + computes docstring metrics on both a base revision and the current
tree (no GNATprove/tests/DAL, so it works when the base does not commit build
artifacts), prints a compact coverage table plus a machine-parseable
`coverage_delta:` line, and cleans up the snapshot.

Exit `0` if current docstring coverage is `>=` the base (or the base has no
sources); `1` if coverage regressed. Mutually exclusive with `--compare-base`.
`make release` runs the same gate against the last release tag (e.g.
`--coverage-delta=v1.1.0`) and aborts if docstring coverage regressed between
releases.
