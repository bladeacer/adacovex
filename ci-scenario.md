# CI scenario worksheet

Status: **open for the maintainer to fill in.** Every row records what CI does
today; the last column is where a decision is still missing. Once the `?`
cells are settled, this page moves to `docs/usage/ci-cd-workflows.md` as the
long-term record of which job runs when.

## The rule this page answers

Run only as much as the change makes meaningful. A source change gets the
cheap quality gates, the build, and the native suite. A version bump adds the
non-Linux hosts. A release adds the end-to-end suites and the publish
pipeline. Nothing runs the same gate twice for one change.

## Workflows

| Workflow | Trigger | Jobs |
|----------|---------|------|
| `ci.yml` | push to `main`, every pull request, manual dispatch | quality gates, build + native tests, self-assessment (prove), docstring coverage delta (PR only), summary |
| `version-bump.yml` | push to `main` that changes `alire-dev.toml`, and only when its `version` differs from the parent commit | detect, native tests (macOS, Windows), summary |
| `release.yml` | push of a `v*` tag whose commit is on `main` | guard, cross-platform build + tests (macOS, Windows), composite action regression, end-to-end suites, build + prove + publish |

## Scenario table

`Y` runs the job, `-` does not run it, `?` needs the maintainer's decision.

| Scenario | ci quality | ci build+test | ci self-assessment | ci coverage delta | version-bump platform suite | release guard | release platform build | release action tests | release e2e | release publish | Open question |
|----------|-----------|---------------|--------------------|-------------------|-----------------------------|---------------|------------------------|----------------------|-------------|-----------------|---------------|
| Pull request, source only | Y | Y | Y | Y | - | - | - | - | - | - | `?` Is the full prove (`self-assessment`) wanted on every PR, or only on `main`? |
| Pull request, docs only | Y | Y | Y | Y | - | - | - | - | - | - | `?` Should a docs-only PR skip build, tests, and prove? |
| Push to `main`, source only | Y | Y | Y | - | - | - | - | - | - | - | `?` Wanted as is? |
| Push to `main`, version bump | Y | Y | Y | - | Y | - | - | - | - | - | `?` Should the bump also run the end-to-end suites before the tag exists? |
| Push to `main`, docs only | Y | Y | Y | - | - | - | - | - | - | - | `?` Same question as the docs-only PR. |
| Tag `v*` on `main` | - | - | - | - | - | Y | Y | Y | Y | Y | `?` Should the release re-run the quality gates, or trust the `main` run? |
| Tag `v*` off `main` | - | - | - | - | - | Y (fails) | - | - | - | - | `?` Is failing the guard the wanted behaviour? |
| Manual dispatch | Y | Y | Y | - | - | - | - | - | - | - | `?` Which jobs should a manual run be able to pick? |
| Failure on `main` after a merge | Y | Y | Y | - | - | - | - | - | - | - | `?` Should a red `main` block the next tag? |

## Caching behaviour

Every cache is content-addressed, so a restored entry is either an exact hit
for the inputs or absent. A stale restore can never mask a regression.

| Cache | Written by | Key | Question |
|-------|------------|-----|----------|
| Alire toolchain | `setup-alire` `cache: true` | toolchain version and host | `?` Keep the default retention, or pin a window? |
| Alire home (gnatprove install) | the composite action | `gnat-version` + the target dev manifest's `[[depends-on]]` | `?` Is a cross-workflow hit wanted between `ci.yml` and `release.yml`? |
| adacovex result cache | `result-cache: true` | SHA-256 of the target's proof-relevant sources | `?` Should the release job read the cache a PR wrote? |
| gnatprove session store | `actions/cache` on `obj/gnatprove` | SHA-256 of the proof-relevant sources | `?` Keep the 7-day default eviction for an idle tree? |

## Decisions already taken

- The macOS and Windows native suites run on a version bump, not on every
  commit. A non-Linux host proves nothing new about an ordinary source
  change, and the queue cost is real.
- The end-to-end suites (CLI, prove diagnostics, dashboard) run on a release
  tag. They need a prover and a browser, and they are released-tree gates.
- `pr-check.yml` no longer exists. `ci.yml` handles both events, so a pull
  request runs each gate once.
- The release pipeline refuses a tag whose commit is not on `main`.

## Open questions

1. Prove on every pull request, or only on `main`? Today: every PR.
2. Skip build, test, and prove for a docs-only change? Today: no skip.
3. Run the e2e suites on a version bump, before the tag? Today: no.
4. One job per gate, or fewer grouped jobs? Today: grouped (quality is one
   job with one step per gate).
5. Should a manual dispatch choose a subset of jobs? Today: it runs the whole
   workflow.
