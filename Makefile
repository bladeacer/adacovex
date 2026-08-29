.PHONY: help check build test prove doc docs-serve clean run-self run-ada-crdt ascii-check spark-off-check fmt bump-version coverage-gate release publish test-publish agents-tree sbom description proof-status test-count doc-links link-check changelog-check action-parity-check tools-check man bench perf-bench complexity-check sync docs-check

.DEFAULT_GOAL := help

help:
	@echo 'adacovex -- Ada Coverage and Verification Tool'
	@echo ''
	@echo 'Usage: make <target>  (targets are grouped; `make check` is the full gate)'
	@echo ''
	@echo '  Core:'
	@echo '    check         Full quality gate (CI before release): cheap'
	@echo '                  static gates first (ascii, complexity, spark-off,'
	@echo '                  changelog, version, doc-links, action-parity,'
	@echo '                  tools-check), then build+test+prove+doc+sbom,'
	@echo '                  then count-sync checks (test-count, proof-status,'
	@echo '                  description)'
	@echo '    build         Build project (adacovex + test_runner, covex alias);'
	@echo '                  regenerates src/adacovex_version_info.ads from'
	@echo '                  alire-dev.toml (or ADACOVEX_VERSION for releases)'
	@echo '    test          Build and run native test suite (1066 tests)'
	@echo '    prove         Run SPARK proofs (gnatprove via prove subcommand,'
	@echo '                  resolved from alire-dev.toml / PATH / cache / download)'
	@echo '                  (also auto-regenerates SVG badges in docs/badges/)'
	@echo ''
	@echo '  Assessment:'
	@echo '    run-self      Run against adacovex itself (default target: cwd)'
	@echo '                  (auto-updates docs/badges/*.svg)'
	@echo '    run-ada-crdt  Run against ../Ada_CRDT (strict mode)'
	@echo '                  (auto-updates ../Ada_CRDT/docs/badges/*.svg)'
	@echo '    sbom          Generate a proof-aware CycloneDX SBOM (sbom.json)'
	@echo '    bench         Benchmark the assessment pipeline + binary size'
	@echo '                  (tools/bench.py: hyperfine when installed, cold +'
	@echo '                  warm timings, raw and stripped binary sizes)'
	@echo '    perf-bench   Run perf and strace profiles over the adacovex binary'
	@echo '                  (requires linux-tools-common and strace)'
	@echo ''
	@echo '  Docs & sync (use `make sync` to run all):'
	@echo '    sync          Alias for agents-tree + proof-status + test-count + doc-links + description'
	@echo '    doc           Generate API docs via gnatdoc + rst2md (alire-dev.toml)'
	@echo '    fmt           Format Ada sources with gnatformat (alire-dev.toml)'
	@echo '    agents-tree   Regenerate the AGENTS.md src/ architecture tree'
	@echo '                  (tools/gen-agents-tree.py + tools/agents-tree.map)'
	@echo '    proof-status  Update the VC count + SPARK level in the docs from'
	@echo '                  the current gnatprove.out (tools/update-proof-status.py)'
	@echo '    test-count    Update the test counts in the docs from'
	@echo '                  docs/test_result.md (tools/update-test-count.py)'
	@echo '    doc-links     Regenerate the AGENTS.md Documentation block from'
	@echo '                  tools/doc-links.map (tools/update-doc-links.py)'
	@echo '    description   Sync the crate description + long description from'
	@echo '                  alire/description.txt + alire/long-description.txt'
	@echo '                  into every manifest (tools/update-description.py;'
	@echo '                  add CHECK=1 for a verify-only run)'
	@echo '    link-check    Verify every markdown link in the repo resolves'
	@echo '                  (tools/check-links.py)'
	@echo ''
	@echo '  Gates (also run by `make check`):'
	@echo '    complexity-check  Cyclomatic-complexity + LOC gate (no god objects,'
	@echo '                  no god functions, no extra-long files): fails when a'
	@echo '                  function exceeds the decision-point cap or a file'
	@echo '                  exceeds its LOC / percentage-of-codebase caps'
	@echo '    ascii-check   Verify all source files are pure ASCII'
	@echo '    tools-check   Run the stdlib-unittest suite for the tools/*.py'
	@echo '                  dev scripts (tools/tests.py)'
	@echo '    spark-off-check  Fail if any SPARK_Mode (Off) appears outside the'
	@echo '                  Types.Implementation container package'
	@echo '    changelog-check Validate all docs/changelogs follow the canonical'
	@echo '                  format (tools/check-changelogs.py)'
	@echo '    action-parity-check  Fail if the GitHub Action drifts from the base'
	@echo '                  CLI option set or the docs/ci-cd.md input table'
	@echo ''
	@echo '  Release:'
	@echo '    coverage-gate Compare docstring coverage between the latest two'
	@echo '                  release tags (tools/coverage-gate.py: --coverage-delta'
	@echo '                  in a temporary worktree at the latest tag)'
	@echo '    bump-version  Bump version across alire.toml, alire-dev.toml,'
	@echo '                  adacovex.ads, releases, index (VERSION=x.y.z)'
	@echo '    release       Tag, update releases+index, push (tools/release.py).'
	@echo '                  Use VERSION=x.y.z; DRY_RUN=1 runs everything except'
	@echo '                  commit/tag/push. (Runs a docstring-coverage gate'
	@echo '                  comparing the last release against the current tree,'
	@echo '                  then CI force-pushes vMAJOR / vMAJOR.MINOR floating'
	@echo '                  tags so @v1 / @v1.3 refs track the latest release.'
	@echo '                  Release artifacts are attested via actions/attest.)'
	@echo '    publish       Publish to Alire community index (run after make release)'
	@echo '    test-publish  Dry-run showing what make publish would do'
	@echo '    man           Install the man page into the local man database'
	@echo '                  (~/.local/share/man, Linux/WSL) and refresh mandb'
	@echo '    e2e           Run Playwright dashboard layout tests (pnpm)'
	@echo '    clean         Remove build artifacts'
	@echo ''
	@echo 'check runs the same gates CI enforces before a release, cheap static'
	@echo '  gates first (ascii, spark-off, changelog, version, doc-links,'
	@echo '  action-parity, tools), then'
	@echo '  build + native tests + SPARK proof (Platinum, 723 VCs) + SVG badges'
	@echo '  + API docs + SBOM, then tree-wide count-sync checks (test-count,'
	@echo '  proof-status, description) that fail when any live file carries a'
	@echo '  stale metric. `make prove` / `make run-self` both emit badges, so'
	@echo '  check does not re-run them separately (no duplicate work).'
	@echo ''
	@echo 'Note: doc/fmt temporarily swap in alire-dev.toml for the duration'
	@echo '      of the command, then restore alire.toml and alire.lock untouched.'
	@echo ''
	@echo 'Prerequisites: alr (Alire), GNAT toolchain, Python 3 (for the'
	@echo '              tools/*.py dev scripts: version/description sync, test/'
	@echo '              proof/doc sync, changelog check, agents-tree, and the'
	@echo '              parsing ports: ascii/spark-off/bench-size/versions/bump)'

# The build steps (gen-version + gen-dashboard + alr build + SFrame log
# filter + covex symlink) live in tools/build.py; see its docstring for the
# SFrame note (the benign ld 2.44 message is the only deliberately silenced
# build output -- compiler and gnatprove warnings stay fully visible).
build:
	@python3 tools/build.py

man: build
	./bin/adacovex man

test: build
	./bin/test_runner

prove: build
	@python3 tools/run.py prove

fmt:
	@python3 tools/dev-cmd.py 'alr exec -- gnatformat -P adacovex.gpr -U' && \
	python3 tools/gen-version.py && \
	python3 tools/gen-dashboard.py

doc:
	@python3 tools/dev-cmd.py 'mkdir -p obj && \
	  alr exec -- gnatdoc -P adacovex.gpr --backend=rst \
	    --generate private --output-dir=obj/gnatdoc-rst && \
	  python3 tools/rst2md.py obj/gnatdoc-rst docs/api-docs --prune-test-pages && \
	  rm -f docs/api-docs/test_*.md docs/api-docs/adacovex-test_support.md'

run-self: build
	@python3 tools/run.py self

run-ada-crdt: build
	@python3 tools/run.py ada-crdt

sbom: build
	@python3 tools/run.py sbom

# Cold vs warm pipeline timings (hyperfine preferred, measured fallback)
# plus the binary-size report live in tools/bench.py; see its docstring for
# the sample sizes (hyperfine 10 cold + 15 warm, fallback 5 + 5).
bench: build
	@python3 tools/bench.py

perf-bench: build
	python3 tools/perf-bench.py

coverage-gate: build
	@python3 tools/coverage-gate.py

link-check:
	@python3 tools/check-links.py

# Fail if the GitHub Action drifts from the base CLI option set or the
# docs/ci-cd.md input table (see tools/check-action-parity.py for the
# mapping rules).  Cheap static gate wired into make check + CI.
action-parity-check:
	@python3 tools/check-action-parity.py

agents-tree:
	@python3 tools/gen-agents-tree.py > /tmp/agents-tree.out && \
	python3 tools/apply-agents-tree.py /tmp/agents-tree.out && \
	rm -f /tmp/agents-tree.out

proof-status:
	@python3 tools/update-proof-status.py

test-count:
	@python3 tools/update-test-count.py

doc-links:
	@python3 tools/update-doc-links.py

sync: agents-tree proof-status test-count doc-links description
	@echo "All sync targets up to date."

changelog-check:
	@python3 tools/check-changelogs.py

complexity-check: build
	./bin/adacovex complexity

ascii-check:
	@python3 tools/ascii-check.py

docs-check:
	@python3 tools/check-docs.py

docs-serve:
	@python3 -m http.server 8000 --directory docs

tools-check:
	@python3 tools/tests.py

# Quality gate: no `SPARK_Mode (Off)` may appear anywhere in src/ except the
# `Types.Implementation` container package and the `Complexity` checker package --
# SPARK forbids instantiating the non-formal Ada.Containers in SPARK_Mode On
# code (gnatprove 16.1.0 rejects such instantiations with "not allowed in
# SPARK (due to entity declared with SPARK_Mode Off)"), so those packages are
# the two required exceptions (see AGENTS.md "SPARK proof discipline" and
# docs/proof/16.1.0-ledger.md).  CPUs.Get_Temp_Directory returned to
# SPARK_Mode On in 1.27.0: gnatprove 16 analyses Ada.Environment_Variables
# with [assumed-global-null] warnings instead.
spark-off-check:
	@python3 tools/spark-off-check.py

# Quality gate: everything CI enforces before a release.  Cheap static
# gates run first so a formatting / sync problem fails before the expensive
# build+prove; the count-sync checks then verify test/proof metrics stayed
# in sync across the whole tree after `make test` / `make prove` refreshed
# them (both prove and run-self emit docs/badges/*.svg, so badges are
# produced exactly once here).
check:
	@echo "=== Quality gate: ASCII ==="; $(MAKE) ascii-check
	@echo "=== Quality gate: complexity (no god objects/functions/files) ==="; $(MAKE) complexity-check
	@echo "=== Quality gate: SPARK_Mode Off ==="; $(MAKE) spark-off-check
	@echo "=== Quality gate: changelog format ==="; $(MAKE) changelog-check
	@echo "=== Quality gate: action/CLI/docs parity ==="; $(MAKE) action-parity-check
	@echo "=== Quality gate: tools unit tests ==="; $(MAKE) tools-check
	@echo "=== Quality gate: version source ==="; python3 tools/gen-version.py --check
	@echo "=== Quality gate: doc links ==="; python3 tools/update-doc-links.py --check
	@echo "=== Quality gate: markdown links ==="; $(MAKE) link-check
	@echo "=== Quality gate: user documentation ==="; $(MAKE) docs-check
	@echo "=== Quality gate: build ==="; $(MAKE) build
	@echo "=== Quality gate: native tests ==="; $(MAKE) test
	@echo "=== Quality gate: SPARK proof + badges ==="; $(MAKE) prove
	@echo "=== Quality gate: fmt ==="; $(MAKE) fmt
	@echo "=== Quality gate: API docs ==="; $(MAKE) doc
	@echo "=== Quality gate: SBOM ==="; $(MAKE) sbom
	@echo "=== Quality gate: test counts in sync ==="; python3 tools/update-test-count.py --check
	@echo "=== Quality gate: proof metrics in sync ==="; python3 tools/update-proof-status.py --check
	@echo "=== Quality gate: description sync ==="; python3 tools/update-description.py --check
	@echo ""
	@echo "=== Quality gate passed: ascii, complexity, spark-off, changelog, action-parity, tools, version, doc-links, link, build, test, prove, doc, sbom, test-count, proof-status, description ==="

# Sync the crate description + long description from the canonical files
# (alire/description.txt + alire/long-description.txt) into every manifest.
# CHECK=1 verifies without writing (used by the quality gate).
description:
	@if [ "$(CHECK)" = "1" ]; then \
		python3 tools/update-description.py --check; \
	else \
		python3 tools/update-description.py; \
	fi

bump-version:
	@python3 tools/bump-version.py "$(VERSION)"

release:
	@python3 tools/release.py --version="$(VERSION)" $(if $(DRY_RUN),--dry-run,)
publish:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is not clean. Commit or stash changes first."; \
		exit 1; \
	fi; \
	alr publish

test-publish:
	@version=$$(git describe --tags --abbrev=0 2>/dev/null || \
		python3 tools/versions.py current); \
	echo "=== test-publish dry-run ==="; \
	echo "Version:  $$version"; \
	echo "Action:   alr publish (auto-detects GitHub, test deps excluded)"; \
	echo "Requires: GitHub PAT in GITHUB_TOKEN env var or gh auth token"; \
	echo "Docs:     https://github.com/alire-project/alire/blob/master/doc/publishing.md"; \
	echo "=== end dry-run ==="

clean:
	alr clean 2>/dev/null; rm -rf bin/ obj/ docs/badges/ docs/api/

e2e:
	pnpm --dir tests/e2e install
	pnpm --dir tests/e2e exec playwright install chromium
	pnpm --dir tests/e2e test
