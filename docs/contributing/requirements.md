# Dependencies

This table groups adacovex dependencies by category. Alire-managed
dependencies are listed under their Alire crate names.

## Core

These are required to build or run adacovex.

| Dependency | Category | Managed by | Notes |
|------------|----------|------------|-------|
| GNAT runtime | Core | GNAT toolchain | Required. No other library is needed. |
| GNAT compiler | Core | GNAT toolchain | Required for build. |
| gnatprove | Core | Alire (dev) or PATH | Required for `covex prove`. Resolved at run time. |

## Development

These are required to develop, test, or document adacovex.

| Dependency | Category | Managed by | Notes |
|------------|----------|------------|-------|
| Alire (`alr`) | Development | System PATH | Required for build, test, and release. |
| gnatprove | Development | Alire (dev) | Required for `make prove`. |
| gnatdoc | Development | Alire (dev) | Required for `make doc`. |
| gnatformat | Development | Alire (dev) | Required for `make fmt`. |
| Python 3 | Development | System | Required for tools/*.py scripts. |
| Playwright | Development | npm/pnpm | Required for `make e2e`. |

## Good to have

These are optional but improve the workflow.

| Dependency | Category | Managed by | Notes |
|------------|----------|------------|-------|
| hyperfine | Good to have | System | Improves `make bench` with stable timings. |
| strace | Good to have | System | Required for `make perf-bench`. |
| linux-tools-common (`perf`) | Good to have | System | Required for `make perf-bench`. |
| mandb | Good to have | System | Refreshes the man page after `adacovex man`. |
