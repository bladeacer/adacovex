# adacovex task runner (just).
#
# Every recipe delegates to tools/tasks.py, which owns the logic that used to
# live inline in the Makefile.  Run `just --list` for the task list, or
# `just <task>`.  Environment variables pass through, so
# `VERSION=1.59.0 just release` and `CHECK=1 just description` work.
#
# The Makefile is kept as a thin compatibility shim that calls the same
# Python tasks; `just` is the primary developer runner.

# The docs-bundling virtualenv.  sphinx, myst-parser, and furo are dev-only
# and live in .venv.  Their single source is pyproject.toml
# ([project].dependencies); `just requirements` renders it into the committed
# requirements.txt, and the `requirements sync` gate fails when the two
# drift.  Recipes that build or serve the manual put .venv on PATH first, so
# tools/gen-docs.py finds sphinx-build; every other recipe runs with the
# system interpreter.  The path is absolute: a Python 3.13 interpreter started
# from a relative venv path reports sys.prefix as the relative `.venv` and
# <frozen site> prints a RuntimeWarning about it.
venv-bin := justfile_directory() / (if os() == "windows" { ".venv/Scripts" } else { ".venv/bin" })

# Show the task list with each recipe's description (the default action).
default:
    @just --list

# Show the task list (alias for the default recipe, mirrors `make help`).
help:
    @just --list

# Create or refresh the docs-bundling virtualenv.  Bootstrap order when .venv
# is missing: uv when present, else the project's install.sh --python-venv,
# else python3 -m venv; install.sh installs the requirements itself, the
# other two creators leave it to this recipe.  Dependency installation is
# idempotent, so a pre-existing .venv is topped up on every run.
docs-venv:
    @set -e; SH_DONE=0; \
        if [ ! -d .venv ]; then \
            if command -v uv >/dev/null 2>&1; then \
                echo "docs-venv: creating .venv with uv"; \
                uv venv --python 3.13 .venv; \
            elif [ -f install.sh ]; then \
                echo "docs-venv: creating .venv with install.sh --python-venv"; \
                bash install.sh --python-venv .venv; SH_DONE=1; \
            else \
                echo "docs-venv: creating .venv with python3 -m venv"; \
                PYEXE="$(command -v python3 || command -v python)"; \
                "$PYEXE" -m venv .venv; \
            fi; \
        fi; \
        if [ "$SH_DONE" = 1 ]; then exit 0; fi; \
        PYBIN=.venv/bin/python; [ -x "$PYBIN" ] || PYBIN=.venv/Scripts/python.exe; \
        if command -v uv >/dev/null 2>&1; then \
            uv pip install --python .venv -r requirements.txt; \
        else \
            "$PYBIN" -m pip install --quiet -r requirements.txt; \
        fi

# Regenerate requirements.txt from pyproject.toml (CHECK=1 verifies only).
requirements:
    @python3 tools/tasks.py requirements

# Build the project (adacovex + test_runner, covex alias).
build: docs-venv
    @PATH="{{venv-bin}}:$PATH" python3 tools/tasks.py build

# Install the man page into the local man database.
man:
    @python3 tools/tasks.py man

# Build and run the native test suite.
test:
    @python3 tools/tasks.py test

# Run the SPARK proof (Platinum gate) and refresh the SVG badges.
prove:
    @python3 tools/tasks.py prove

# Format the Ada sources with gnatformat.
fmt:
    @python3 tools/tasks.py fmt

# Generate the API docs (gnatdoc + rst2md).
doc:
    @python3 tools/tasks.py doc

# Build the bundled offline manual (needs the docs venv).
book: docs-venv
    @PATH="{{venv-bin}}:$PATH" python3 tools/tasks.py book

# Run the assessment against adacovex itself.
run-self:
    @python3 tools/tasks.py run-self

# Run the assessment against ../Ada_CRDT.
run-ada-crdt:
    @python3 tools/tasks.py run-ada-crdt

# Generate the proof-aware SBOM (sbom.json).
sbom:
    @python3 tools/tasks.py sbom

# Regenerate the committed compliance reports.
compliance:
    @python3 tools/tasks.py compliance

# Benchmark the pipeline and the prove subcommand.
bench:
    @python3 tools/tasks.py bench

# Profile the binary with perf and strace.
perf-bench:
    @python3 tools/tasks.py perf-bench

# Docstring-coverage gate between the latest two release tags.
coverage-gate:
    @python3 tools/tasks.py coverage-gate

# Verify every markdown link resolves.
link-check:
    @python3 tools/tasks.py link-check

# Fail when the GitHub Action drifts from the base CLI option set.
action-parity-check:
    @python3 tools/tasks.py action-parity-check

# Fail when a CLI flag, server route, or page is missing from the user docs.
docs-coverage-check:
    @python3 tools/tasks.py docs-coverage-check

# Fail when the help/man/tldr/cli-reference/completion surfaces drift.
surface-parity-check:
    @python3 tools/tasks.py surface-parity-check

# Regenerate the AGENTS.md source tree.
agents-tree:
    @python3 tools/tasks.py agents-tree

# Sync the VC count and SPARK level from gnatprove.out.
proof-status:
    @python3 tools/tasks.py proof-status

# Sync the test counts from docs/test_result.md.
test-count:
    @python3 tools/tasks.py test-count

# Regenerate the AGENTS.md documentation block.
doc-links:
    @python3 tools/tasks.py doc-links

# Run every sync task.
sync:
    @python3 tools/tasks.py sync

# Validate the changelog format.
changelog-check:
    @python3 tools/tasks.py changelog-check

# Cyclomatic-complexity and LOC gate.
complexity-check:
    @python3 tools/tasks.py complexity-check

# Dashboard CSS 4px spacing gate.
csslint-check:
    @python3 tools/tasks.py csslint-check

# Verify all source files are pure ASCII.
ascii-check:
    @python3 tools/tasks.py ascii-check

# Check the user documentation rules.
docs-check:
    @python3 tools/tasks.py docs-check

# Paragraph-splitter gate.
para-split-check:
    @python3 tools/tasks.py para-split-check

# Structural check of the in-repo tldr page.
tldr-check:
    @python3 tools/tasks.py tldr-check

# Run the upstream tldr-lint when it is installed.
tldr-lint:
    @python3 tools/tasks.py tldr-lint

# Verify every link in the bundled offline manual resolves.
book-links-check: docs-venv
    @PATH="{{venv-bin}}:$PATH" python3 tools/tasks.py book-links-check

# Serve the docs source at http://localhost:8000.
docs-serve:
    @python3 tools/tasks.py docs-serve

# Build and serve the manual at http://localhost:8000.
book-serve: docs-venv
    @PATH="{{venv-bin}}:$PATH" python3 tools/tasks.py book-serve

# Run the tools unit tests.
tools-check:
    @python3 tools/tasks.py tools-check

# Fail on any SPARK_Mode (Off) outside the two exempt packages.
spark-off-check:
    @python3 tools/tasks.py spark-off-check

# Fail when a manifest, spec, binary, or SBOM names a different version.
version-consistency-check:
    @python3 tools/tasks.py version-consistency-check

# Sync the crate description into every manifest (CHECK=1 verifies only).
description:
    @python3 tools/tasks.py description

# Bump the version across the manifests and changelog (VERSION=x.y.z as an
# environment variable: `VERSION=x.y.z just bump-version`).
bump-version:
    @python3 tools/tasks.py bump-version

# Build, verify, prove, tag, and push a release (VERSION=x.y.z as an
# environment variable: `VERSION=x.y.z just release`, DRY_RUN=1).
release:
    @python3 tools/tasks.py release

# Publish to the Alire community index.
publish:
    @python3 tools/tasks.py publish

# Dry-run of the publish step.
test-publish:
    @python3 tools/tasks.py test-publish

# Remove build artifacts.
clean:
    @python3 tools/tasks.py clean

# Run the CLI end-to-end checks.
cli-e2e:
    @python3 tools/tasks.py cli-e2e

# Run cli-e2e then the Playwright dashboard tests.
e2e:
    @python3 tools/tasks.py e2e

# The single everything-check entry point.
check: docs-venv
    @PATH="{{venv-bin}}:$PATH" python3 tools/tasks.py check
