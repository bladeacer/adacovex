# CI scenario record

Status: **settled.** Every row records what CI does; the last column names the
decision that settled it. This page is the long-term record of which job runs
when, and it matches `.github/workflows/ci.yml`, `version-bump.yml`, and
`release.yml`.

## The rule this page answers

Run only as much as the change makes meaningful. A source change gets the
cheap quality gates, the build, and the native suite. A version bump adds the
non-Linux hosts. A release adds the end-to-end suites and the publish
pipeline. Nothing runs the same gate twice for one change.

## Workflows

| Workflow | Trigger | Jobs |
|----------|---------|------|
| `ci.yml` | push to `main`, every pull request, manual dispatch | quality gates, build + native tests, self-assessment (prove), docstring coverage delta (pull requests and manual dispatch), summary |
| `version-bump.yml` | push to `main` that changes `alire-dev.toml`, and only when its `version` differs from the parent commit | detect, native tests (macOS, Windows), summary |
| `release.yml` | push of a `v*` tag whose commit is on `main` | guard, quality gates, docstring coverage delta (pre-release), cross-platform build + tests (macOS, Windows), composite action regression, end-to-end suites, build + prove + publish, summary |

A manual dispatch of `ci.yml` can skip any job with its `run_*` boolean input
(`run_quality`, `run_build_test`, `run_self_assessment`,
`run_coverage_delta`); a push or a pull request always runs every job, because
the inputs are empty on those events.

## Scenario table

`Y` runs the job, `-` does not run it.

| Scenario | ci quality | ci build+test | ci self-assessment | ci coverage delta | version-bump platform suite | release guard | release quality | release coverage delta | release platform build | release action tests | release e2e | release publish |
|----------|-----------|---------------|--------------------|-------------------|-----------------------------|---------------|-----------------|------------------------|------------------------|----------------------|-------------|-----------------|
| Pull request, source only | Y | Y | Y | Y | - | - | - | - | - | - | - | - |
| Pull request, docs only | Y | Y | Y | Y | - | - | - | - | - | - | - | - |
| Push to `main`, source only | Y | Y | Y | - | - | - | - | - | - | - | - | - |
| Push to `main`, version bump | Y | Y | Y | - | Y | - | - | - | - | - | - | - |
| Push to `main`, docs only | Y | Y | Y | - | - | - | - | - | - | - | - | - |
| Tag `v*` on `main` | - | - | - | - | - | Y | Y | Y | Y | Y | Y | Y |
| Tag `v*` off `main` | - | - | - | - | - | Y (fails) | - | - | - | - | - | - |
| Manual dispatch | Y | Y | Y | Y | - | - | - | - | - | - | - | - |
| Failure on `main` after a merge | Y | Y | Y | - | - | - | - | - | - | - | - | - |

## Caching behaviour

Every cache is content-addressed, so a restored entry is either an exact hit
for the inputs or absent. A stale restore can never mask a regression. Each
cache uses the GitHub default eviction window; none is pinned.

| Cache | Written by | Key |
|-------|------------|-----|
| Alire toolchain | `setup-alire` `cache: true` | toolchain version and host |
| Alire home (gnatprove install) | the composite action | `gnat-version` + the target dev manifest's `[[depends-on]]` |
| adacovex result cache | `result-cache: true` | SHA-256 of the target's proof-relevant sources |
| gnatprove session store | `actions/cache` on `obj/gnatprove` | SHA-256 of the proof-relevant sources |

The result cache is branch-independent: a pull-request run and the post-merge
`main` run for the same tree state share one entry, and a release run on a tag
reads the same content-addressed entry. A pull request's cache is scoped to its
merge ref, so a release on `main` does not read a pull-request entry directly;
the content-addressed key makes the worst case an absent entry (a re-prove),
never a stale hit.

## Decisions taken

- Prove (`self-assessment`) runs on every pull request **and** on `main`.
- A docs-only change does **not** skip the build, the native suite, or the
  prove; the cheap gates are cheap, and a docs edit can still break a gate.
- The end-to-end suites run on a release tag only, never on a version bump.
  A suite whose tool path is absent in CI (the Playwright browser half without
  `pnpm`/Chromium, the prove half without a prover) is skipped with its reason,
  exactly as `just e2e` does locally.
- The quality gates run as one grouped job (one step per gate), not one job
  per gate.
- A manual dispatch can pick a subset of `ci.yml` jobs through its `run_*`
  inputs; the default runs the whole workflow.
- The release re-runs the full quality gate set on the tagged tree rather than
  trusting a green `main` that may have drifted.
- The release `guard` fails a tag whose commit is not on `main`, and every
  other release job waits on it.
- A failed release run never creates or updates the GitHub Release: the publish
  job is fully gated on every other job, and a re-pushed tag cancels the
  in-flight run (concurrency, `cancel-in-progress`). A red `main` does not block
  a tag; the tag is gated on its own tree, not on `main`'s CI colour.
- Each cache keeps the GitHub default eviction window.