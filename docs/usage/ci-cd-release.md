# Release bundling, tags, and consumer manifests

This page covers the release version bundling, the floating tags, and the
consumer-manifest prerequisites. The workflow files, the Markdown summaries
and loud failures, and the debugging guide are on [CI/CD workflows,
summaries, and release bundling](ci-cd-workflows.md). The composite action
and its inputs are on [the composite action](ci-cd-action.md).

## Release bundling

Every `vX. Y. Z` tag triggers `.github/workflows/release.yml`. The workflow calls the composite action with `build`, `release-build`, and `prove`.

It builds the release binary, runs GNATprove, and validates the self-assessment. Then it packages and publishes:

- `adacovex-vX.Y.Z.tar.gz` -- the version-matched binary (`adacovex` plus the
  `covex` alias). The action downloads this asset for the tag it is referenced
  by, so `@v1.9.0` runs adacovex `v1.9.0`.
- `adacovex-action-vX.Y.Z.tar.gz` -- a copy of the composite action itself for
  vendoring or air-gapped use.

Both bundles are attested with
[`actions/attest`](https://github.com/actions/attest)
on every tag. OIDC attestations appear under the release's attestations tab.
The release notes link the signed attestation via the action's
`attestation-url` output. They also link a *Git Changelog* compare link
(`compare/v1.9.0...v1.14.0`) and the human-readable changelogs.

**Changelog listing.** The `Create GitHub Release` step derives the changelog
list from the available `docs/changelogs/adacovex-*.md` entries. The entries
are between the previous release tag and the released version.

It resolves the previous three-component release tag
(`git tag --sort=-version:refname`, for example `v1.9.0` when releasing
`v1.14.0`). Then it lists every changelog whose version is strictly above the
previous release and at or below the released version. Releasing `v1.14.0`
after `v1.9.0` links the `1.10.0`..`1.14.0` changelogs in one release.

The list is emitted **newest-first** (version-sorted, not shell glob order).
The entries read `1.14.0` down to `1.10.0`.

The list is derived from the changelog files present in the tree, not from
tags. A version that was never released has no entry. A release that skips
versions still links every changelog in the range. Each entry links the
release's changelog page on the deployed **Read the Docs** site
(`https://adacovex.readthedocs.io/en/latest/changelogs/adacovex-<v>.html`),
not a GitHub blob URL: the manual is a Sphinx project and the changelogs are
part of the published book.

**The CI release binary is Linux x86-64 only for now.** The release workflow
runs on `ubuntu-latest`. It packages the Linux binary and the prebuilt
GNATprove toolchain bundle for that target. macOS, FreeBSD, Windows, and Linux
aarch64 build adacovex from source via Alire instead. See
[Platforms](platforms.md#release-binaries).

Maintainers reproduce the release locally with `make release VERSION=x.y.z`
(see the [developer guide](../contributing/developer-guide.md)): it builds
`--release`, generates proofs, validates DAL-C, and bundles `dist/`, then
tags and pushes to trigger the workflow. The bundled version is always the
build's version (`src/adacovex_version_info.ads` comes from `alire-dev.toml`
or `ADACOVEX_VERSION` at build time).

## Floating tags

The release workflow force-pushes the floating tags `vMAJOR`, `vMAJOR. MINOR`, and `latest`. For example: `v1`, `v1.3`, and `latest` from `v1.3.0`. Reference `@latest` to always get the newest published release.

Use `@v1` or `@v1.3` for the latest release within a major or minor version. Pin an exact `@vX. Y. Z` for a fixed version.

Once the action is listed on the GitHub Actions marketplace, each `vX. Y. Z` tag auto-publishes that version.

## Consumer manifest prerequisites (avoid a broken CI)

adacovex's `prove` subcommand and the GitHub Action resolve `gnatprove`
through the *target project's* manifest. The pinned gnatprove crate is
deployed via `alr -n get gnatprove=<version>`. It is run directly, with no
`alr exec` over the whole workspace.

For the command to succeed in a clean checkout or on CI, the consumer's
manifests must follow two rules:

1. **`alire.toml` must be the clean publishing manifest.** It must contain no
   dev tooling (`gnatprove`, `gnatdoc_bin`, `gnatformat_bin`, `covex`). It must
   contain **no `[[pins]]`**. Alire reads this manifest when the action runs
   `alr build`. It must resolve with nothing but Alire + GNAT.
2. **`alire-dev.toml` must declare `covex` as a normal index dependency**
   (`covex = "*"`). It must never be pinned to a local path such as
   `covex = { path = "../adacovex" }`. A path pin resolves only on the machine
   that has the sibling checkout. In a consumer workspace or on CI, Alire
   fails the whole workspace load with a confusing error. This happens before
   adacovex or `alr` runs:

    ```
    ERROR: Failed to load alire.toml:
    ERROR:    pins:
    ERROR:    covex:
    ERROR:    Pin path is not a valid directory: /home/runner/work/<repo>/<repo>/../adacovex
    ```

If you see that, drop the `covex` path pin. Use `covex = "*"`. Strip the dev
deps and pins out of `alire.toml`. Keep them only in `alire-dev.toml`.

The Makefile pattern in many projects keeps the published `alire.toml` clean.
It swaps `alire-dev.toml` over `alire.toml` only for the duration of a
`prove`/`fmt`/`doc` target, then restores it. This gives local tooling the dev
deps.

## See also

- [CI/CD](ci-cd.md) -- the CI/CD home page.
- [The composite action](ci-cd-action.md) -- the action's inputs and outputs.
- [CI/CD workflows, summaries, and release bundling](ci-cd-workflows.md) --
  the workflow files and the Markdown summaries.
