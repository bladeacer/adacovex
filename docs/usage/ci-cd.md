# adacovex CI/CD

## GitHub Actions

The composite action at `./action.yml` mirrors the base CLI. CI can drive every
assessment feature the same way the binary does.

### Quick start

```yaml
# .github/workflows/adacovex.yml
on:
  push:
    branches: [main]
  pull_request:

jobs:
  adacovex:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: bladeacer/adacovex@v1
        with:
          target: .
          standard: all          # DO-178C + ISO 26262 + IEC 62304
          require-spark: Platinum
          require-docstrings: 100
          require-tests: 1637
          run-tests: true
          generate-sbom: true
```

This job builds adacovex. It runs the target's native tests and the full
assessment. It gates on Platinum SPARK, 100% docstring coverage, and 900
passing tests. On failure, the job publishes `adacovex-assessment` artifacts
and Markdown summaries.

### PR coverage gate

Use `--coverage-delta` to fail PRs that drop docstring coverage:

```yaml
# .github/workflows/pr-coverage.yml
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
          coverage-delta: ${{ github.event.pull_request.base.sha }}
```

### Release workflow

Tag a release. The bundled workflow (`release.yml`) builds the binary and runs GNATprove. It validates the self-assessment. It publishes `adacovex-vX.

Y. Z.tar.gz` and the composite action bundle. Floating tags (`@latest`, `@v1`, `@v1.3`) always point at the newest release. Pin `@vX.

Y. Z` for reproducibility.

## GitLab CI

The same inputs map to GitLab CI variables:

```yaml
# .gitlab-ci.yml
adacovex:
  image: ubuntu:latest
  before_script:
    - apt-get update -qq && apt-get install -y -qq curl
    - curl -fsSL https://raw.githubusercontent.com/bladeacer/adacovex/main/install.sh | bash
  script:
    - adacovex --target=. --standard=all --dal=C --require-spark=Platinum --require-docstrings=100
  artifacts:
    when: always
    paths:
      - sbom.json
      - docs/badges/*.svg
```

If your runner already has Alire, replace the `install.sh` step with
`alr install covex gnatprove`.

## Other CI systems

The action is a pure composite of shell steps. It works on any runner that can
run `bash` and install Alire:

1. Install Alire + GNAT (`alr toolchain --install gnat_native`).
2. Download the release bundle or build from source.
3. Run `adacovex` with the same flags as the GitHub Action inputs.

The JSON API (`/api/metrics` when using `--serve`, or `--emit-metrics`) lets
you parse results in any language.

**Action/CLI/docs parity is a feature gate.** CI runs the action-parity
check (`tools/check-action-parity.py`), which fails when the action's inputs
stop mirroring the base CLI option set, and also fails when the `### Inputs`
table below drifts from `action.yml`. See `tools/check-action-parity.py` for
the mapping rules (maintainers run the same check locally via
`make action-parity-check`; see the [developer guide](../contributing/developer-guide.md)).

The `### Inputs` table lives on the [composite action
page](ci-cd-action.md#inputs), next to the rest of the action detail.

## Composite action

The action's design, the full `### Inputs` table, the `### Outputs` table, and
its result caching are on [the composite action](ci-cd-action.md).

The workflows themselves -- the `.github` workflow files, the Markdown
summaries and loud failures, the debugging guide, release version bundling,
floating tags, and the consumer-manifest prerequisites -- are covered on
[CI/CD workflows, summaries, and release bundling](ci-cd-workflows.md).
