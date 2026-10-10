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
# and live in .venv, managed with uv from requirements.txt.  Recipes that
# build or serve the manual put .venv on PATH first, so tools/gen-docs.py
# finds sphinx-build; every other recipe runs with the system interpreter.
venv-bin := if os() == "windows" { ".venv/Scripts" } else { ".venv/bin" }

# Show the task list with each recipe's description (the default action).
default:
    @just --list

# Show the task list (alias for the default recipe, mirrors `make help`).
help:
    @just --list

# Create or refresh the docs-bundling virtualenv with uv.
docs-venv:
    @test -d .venv || uv venv --python 3.13 .venv
    @uv pip install --python .venv -r requirements.txt

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

# Bump the version across the manifests and changelog (VERSION=x.y.z).
bump-version:
    @python3 tools/tasks.py bump-version

# Build, verify, prove, tag, and push a release (VERSION=x.y.z, DRY_RUN=1).
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
