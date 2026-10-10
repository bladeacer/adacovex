# Thin compatibility shim.
#
# The task logic now lives in tools/tasks.py, which both this Makefile and the
# `justfile` call.  `just <task>` is the primary developer runner; this shim
# keeps every existing `make <task>` reference (CI workflows, docs, muscle
# memory) working.  A target is added here only when it is added to
# tools/tasks.py, so the two front ends never drift.
#
# Environment variables pass through unchanged: `make release VERSION=1.59.0`,
# `make description CHECK=1`, and `make release DRY_RUN=1` behave as before.

.PHONY: help build man test prove fmt doc book book-serve docs-serve clean \
        run-self run-ada-crdt ascii-check spark-off-check bump-version \
        coverage-gate release publish test-publish agents-tree sbom compliance \
        description proof-status test-count doc-links link-check \
        changelog-check action-parity-check docs-coverage-check tools-check \
        bench perf-bench complexity-check csslint-check \
        version-consistency-check sync docs-check para-split-check tldr-check \
        tldr-lint book-links-check cli-e2e e2e check

.DEFAULT_GOAL := help

# List the available tasks (tools/tasks.py --list).
help:
	@python3 tools/tasks.py --list

build:
	@python3 tools/tasks.py build

man:
	@python3 tools/tasks.py man

test:
	@python3 tools/tasks.py test

prove:
	@python3 tools/tasks.py prove

fmt:
	@python3 tools/tasks.py fmt

doc:
	@python3 tools/tasks.py doc

book:
	@python3 tools/tasks.py book

book-serve:
	@python3 tools/tasks.py book-serve

docs-serve:
	@python3 tools/tasks.py docs-serve

clean:
	@python3 tools/tasks.py clean

run-self:
	@python3 tools/tasks.py run-self

run-ada-crdt:
	@python3 tools/tasks.py run-ada-crdt

ascii-check:
	@python3 tools/tasks.py ascii-check

spark-off-check:
	@python3 tools/tasks.py spark-off-check

bump-version:
	@python3 tools/tasks.py bump-version

coverage-gate:
	@python3 tools/tasks.py coverage-gate

release:
	@python3 tools/tasks.py release

publish:
	@python3 tools/tasks.py publish

test-publish:
	@python3 tools/tasks.py test-publish

agents-tree:
	@python3 tools/tasks.py agents-tree

sbom:
	@python3 tools/tasks.py sbom

compliance:
	@python3 tools/tasks.py compliance

description:
	@python3 tools/tasks.py description

proof-status:
	@python3 tools/tasks.py proof-status

test-count:
	@python3 tools/tasks.py test-count

doc-links:
	@python3 tools/tasks.py doc-links

link-check:
	@python3 tools/tasks.py link-check

changelog-check:
	@python3 tools/tasks.py changelog-check

action-parity-check:
	@python3 tools/tasks.py action-parity-check

docs-coverage-check:
	@python3 tools/tasks.py docs-coverage-check

tools-check:
	@python3 tools/tasks.py tools-check

bench:
	@python3 tools/tasks.py bench

perf-bench:
	@python3 tools/tasks.py perf-bench

complexity-check:
	@python3 tools/tasks.py complexity-check

csslint-check:
	@python3 tools/tasks.py csslint-check

version-consistency-check:
	@python3 tools/tasks.py version-consistency-check

sync:
	@python3 tools/tasks.py sync

docs-check:
	@python3 tools/tasks.py docs-check

para-split-check:
	@python3 tools/tasks.py para-split-check

tldr-check:
	@python3 tools/tasks.py tldr-check

tldr-lint:
	@python3 tools/tasks.py tldr-lint

book-links-check:
	@python3 tools/tasks.py book-links-check

cli-e2e:
	@python3 tools/tasks.py cli-e2e

e2e:
	@python3 tools/tasks.py e2e

check:
	@python3 tools/tasks.py check
