# adacovex CI/CD (GitHub Actions)

A composite action at the repository root (`./action.yml`) runs the full
adacovex pipeline in CI, and three workflows (`ci.yml`, `pr-check.yml`,
`release.yml`) cover self-assessment, PR coverage gating, and releases.

## Composite action (`./action.yml`)

Installs Alire via
[`alire-project/setup-alire`](https://github.com/alire-project/setup-alire)
(GNAT at `gnat-version` plus `gprbuild`; `gnatprove` is NOT an `alr toolchain`
component and is resolved by the `prove` subcommand via the target project's
manifest, `$PATH`, cached toolchain, or download), obtains the version-matched
adacovex binary (downloads the release bundle by default, or builds from source
with `build: true`), optionally runs GNATprove (`prove`) and the native tests
(`run-tests`), then runs the assessment, generates a proof-aware SBOM
(`generate-sbom`, default `true`), and publishes a Markdown step summary,
machine-readable outputs, and SVG badge artifacts.

The action is version-matched to the adacovex binary: the release workflow
bundles `adacovex-vX.Y.Z.tar.gz` for every `vX.Y.Z` tag, and the action
downloads the binary for the tag it is referenced by. Reference it by a
floating tag to always get the latest published release, or pin to an exact
release for reproducibility:

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: bladeacer/adacovex@v1
    with:
      target: .
      dal: C
```

### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `target` | `.` | Target project root (relative to workspace root) |
| `dal` | `C` | DO-178C DAL level to assess (A-E) |
| `gnat-version` | `15.2.1` | GNAT toolchain version to select via `alr` |
| `version` | `''` | adacovex version; defaults to the tag the action is referenced by |
| `build` | `false` | Build adacovex from source instead of downloading the version-matched binary |
| `prove` | `false` | Run GNATprove before assessing, for repos that don't commit `gnatprove.out` |
| `require-spark` | `''` | Minimum SPARK level (Stone..Platinum); CI threshold gate |
| `require-docstrings` | `''` | Minimum docstring coverage % (0-100); CI threshold gate |
| `require-tests` | `''` | Minimum passing test count; CI threshold gate |
| `require-proof` | `''` | Minimum proved-VC coverage % (0-100); CI threshold gate |
| `run-tests` | `false` | Build and run the native test suite (requires `build: true`) |
| `test-command` | `./bin/test_runner` | Command (relative to workspace root) that runs the target's test suite |
| `release-build` | `false` | Pass `--release` to `alr build` |
| `assess` | `true` | Run the assessment and publish outputs/badges (`false` for build/test-only jobs) |
| `compare-base` | `''` | Git ref to run `--compare-base` against (fails on regression) |
| `coverage-delta` | `''` | Git ref to run `--coverage-delta` against (fails if coverage dropped) |
| `emit-markdown` | `''` | Write `VERIFICATION.md` + `TRACE.md` into this directory |
| `generate-sbom` | `true` | Generate a proof-aware SBOM after the assessment and upload it |
| `sbom-format` | `cyclonedx-json` | SBOM format: `cyclonedx-json`, `spdx-json`, or `md` |
| `cache` | `true` | Cache Alire toolchain/deps with `actions/cache` |
| `result-cache` | `true` | Persist adacovex's on-disk result cache across runs |

### Outputs

| Output | Description |
|--------|-------------|
| `dal-status` | `Achieved` or `Unmet` |
| `spark-level` | SPARK level detected (Stone..Platinum) |
| `test-count` | Number of passing tests |
| `coverage-pct` | Current docstring coverage (in `--coverage-delta` mode) |

### Result caching

The action restores `~/.adacovex/cache` before running adacovex and saves it
when the job finishes (`result-cache`, default `true`). Because every entry is
keyed by its artifact's SHA-256 content hash, restoring a cache saved by an
earlier run or commit is always safe: only files that are byte-for-byte
unchanged are served from it, and the rest are rescanned / re-parsed
automatically.

## Workflows

- **`.github/workflows/ci.yml`** -- self-assessment (build + prove + assess) and
  build + native tests (build + run-tests, assess: false) on push to `main` and
  pull requests.
- **`.github/workflows/pr-check.yml`** -- runs `--coverage-delta` against
  `pull_request.base.sha` to fail PRs that drop docstring coverage.
- **`.github/workflows/release.yml`** -- on a `v*` tag, builds the release
  binary, runs GNATprove, validates the self-assessment, and publishes the
  GitHub Release (see [Release bundling](#release-bundling)).

### PR coverage gate

Gate every pull request on docstring coverage not regressing against the base
branch (this is exactly what `--coverage-delta` was built for):

```yaml
# .github/workflows/pr-check.yml
on:
  pull_request:
jobs:
  coverage-delta:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: bladeacer/adacovex@v1
        with:
          target: .
          dal: C
          coverage-delta: ${{ github.event.pull_request.base.sha }}
```

The action exits non-zero when coverage drops, failing the check. This
workflow ships in the repo at `.github/workflows/pr-check.yml`.

## Release bundling

Every `vX.Y.Z` tag triggers `.github/workflows/release.yml`, which calls the
composite action with `build`, `release-build`, and `prove` to build the
release binary, run GNATprove, and validate the self-assessment, then packages
and publishes:

- `adacovex-vX.Y.Z.tar.gz` -- the version-matched binary (`adacovex` plus the
  `covex` alias). The action downloads this asset for the tag it is referenced
  by, so `@v1.9.0` runs adacovex `v1.9.0`.
- `adacovex-action-vX.Y.Z.tar.gz` -- a copy of the composite action itself for
  vendoring or air-gapped use.

Both bundles are attested with
[`actions/attest`](https://github.com/actions/attest)
on every tag (OIDC attestations appear under the release's attestations tab).
The release notes link the signed attestation via the action's
`attestation-url` output, a *Git Changelog* compare link
(`compare/v1.8.0...v1.9.0`), and the human-readable changelog.

`make release VERSION=x.y.z` does the same locally (build `--release`,
generate proofs, validate DAL-C, bundle `dist/`), then tags and pushes to
trigger the workflow.

## Floating tags

The release workflow force-pushes the floating tags `vMAJOR`, `vMAJOR.MINOR`,
and `latest` (e.g. `v1`, `v1.3`, and `latest` from `v1.3.0`). Reference
`@latest` to always get the newest published release, `@v1` / `@v1.3` for the
latest release within a major or minor version, or pin an exact `@vX.Y.Z` for a
fixed version. Once the action is listed on the GitHub Actions marketplace,
each `vX.Y.Z` tag auto-publishes that version.

## Consumer manifest prerequisites (avoid a broken CI)

adacovex's `prove` subcommand and the GitHub Action resolve `gnatprove` through
the *target project's* manifest: the pinned gnatprove crate is deployed via
`alr -n get gnatprove=<version>` and run directly, with no `alr exec` over the
whole workspace. For that to succeed in a clean checkout or on CI, the
consumer's manifests must still follow two rules:

1. **`alire.toml` must be the clean publishing manifest** -- no dev tooling
   (`gnatprove`, `gnatdoc_bin`, `gnatformat_bin`, `covex`) and **no
   `[[pins]]`**. This is the manifest Alire reads when the action runs
   `alr build`, so it must resolve with nothing but Alire + GNAT.
2. **`alire-dev.toml` must declare `covex` as a normal index dependency**
   (`covex = "*"`), never pinned to a local path such as
   `covex = { path = "../adacovex" }`. A path pin resolves only on the machine
   that has the sibling checkout; in a consumer workspace or on CI Alire fails
   the whole workspace load with a confusing error before adacovex or `alr`
   even runs:

   ```
   ERROR: Failed to load alire.toml:
   ERROR:    pins:
   ERROR:    covex:
   ERROR:    Pin path is not a valid directory: /home/runner/work/<repo>/<repo>/../adacovex
   ```

If you see that, drop the `covex` path pin (use `covex = "*"`) and strip the dev
deps + pins out of `alire.toml`; keep them only in `alire-dev.toml`. The
Makefile pattern in many projects (swap `alire-dev.toml` over `alire.toml` only
for the duration of a `prove`/`fmt`/`doc` target, then restore) keeps the
published `alire.toml` clean while still giving local tooling the dev deps.
