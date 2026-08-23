.PHONY: help check build test prove doc clean run-self run-ada-crdt ascii-check spark-off-check fmt bump-version coverage-gate release publish test-publish _dev_cmd agents-tree sbom description proof-status test-count doc-links link-check changelog-check action-parity-check man

.DEFAULT_GOAL := help

help:
	@echo 'adacovex -- Ada Coverage and Verification Tool'
	@echo ''
	@echo 'Usage: make <target>'
	@echo '  check         Full quality gate (CI runs this before release): cheap'
	@echo '                static gates first (ascii, spark-off, changelog,'
	@echo '                version, doc-links), then build+test+prove+doc+sbom,'
	@echo '                then count-sync checks (test-count, proof-status,'
	@echo '                description) so stale metrics fail loudly'
	@echo '  build         Build project (adacovex + test_runner, covex alias);'
	@echo '                regenerates src/adacovex-version.ads from'
	@echo '                alire-dev.toml (or ADACOVEX_VERSION for releases)'
	@echo '  man           Install the man page into the local man database'
	@echo '                (~/.local/share/man, Linux/WSL) and refresh mandb'
	@echo '  test          Build and run native test suite'
	@echo '  prove         Run SPARK proofs (gnatprove via the prove subcommand,'
	@echo '                resolved from alire-dev.toml / PATH / cache / download)'
	@echo '                (also auto-regenerates SVG badges in docs/badges/)'
	@echo '  doc           Generate API docs via gnatdoc + rst2md (alire-dev.toml)'
	@echo '  fmt           Format Ada sources with gnatformat (alire-dev.toml)'
	@echo '  clean         Remove build artifacts'
	@echo '  run-self      Run against adacovex itself (default target: cwd)'
	@echo '                (auto-updates docs/badges/*.svg)'
	@echo '  run-ada-crdt  Run against ../Ada_CRDT (strict mode)'
	@echo '                (auto-updates ../Ada_CRDT/docs/badges/*.svg)'
	@echo '  sbom          Generate a proof-aware CycloneDX SBOM (sbom.json)'
	@echo '  description   Sync the crate description + long description from'
	@echo '                alire/description.txt + alire/long-description.txt'
	@echo '                into every manifest (tools/update-description.py;'
	@echo '                add CHECK=1 for a verify-only run)'
	@echo '  coverage-gate Compare docstring coverage between the latest two'
	@echo '                release tags (--coverage-delta in a worktree at'
	@echo '                the latest tag; verifies the release gate logic)'
	@echo '  agents-tree   Regenerate the AGENTS.md src/ architecture tree'
	@echo '                (tools/gen-agents-tree.py + tools/agents-tree.map)'
	@echo '  proof-status  Update the VC count + SPARK level in the docs from'
	@echo '                the current gnatprove.out (tools/update-proof-status.py)'
	@echo '  test-count    Update the test counts in the docs from'
	@echo '                docs/test_result.md (tools/update-test-count.py)'
	@echo '  doc-links     Regenerate the AGENTS.md Documentation block from'
	@echo '                tools/doc-links.map (tools/update-doc-links.py)'
	@echo '  link-check    Verify every markdown link in the repo resolves'
	@echo '                (tools/check-links.py)'
	@echo '  changelog-check Validate all docs/changelogs follow the canonical'
	@echo '                  format (tools/check-changelogs.py)'
	@echo '  bump-version  Bump version across alire.toml, alire-dev.toml,'
	@echo '                adacovex.ads, releases, index (VERSION=x.y.z)'
	@echo '  release       Tag, update releases+index, push. Use VERSION=x.y.z'
	@echo '                (Runs a docstring-coverage gate comparing the last'
	@echo '                 release against the current tree, then CI force-pushes'
	@echo '                 vMAJOR / vMAJOR.MINOR floating tags so @v1 / @v1.3'
	@echo '                 refs track the latest release. Release artifacts are'
	@echo '                 attested via actions/attest.)'
	@echo '  publish       Publish to Alire community index (run after make release)'
	@echo '  test-publish  Dry-run showing what make publish would do'
	@echo '  ascii-check   Verify all source files are pure ASCII'
	@echo '  spark-off-check  Fail if any SPARK_Mode (Off) appears outside the'
	@echo '                  Types.Implementation container package'
	@echo '  action-parity-check  Fail if the GitHub Action drifts from the base'
	@echo '                  CLI option set or the docs/ci-cd.md input table'
	@echo ''
	@echo 'check runs the same gates CI enforces before a release, cheap static'
	@echo '  gates first (ascii, spark-off, changelog, version, doc-links,
	@echo '  action-parity), then'
	@echo '  build + native tests + SPARK proof (Platinum, 720 VCs) + SVG badges'
	@echo '  + API docs + SBOM, then tree-wide count-sync checks (test-count,'
	@echo '  proof-status, description) that fail when any live file carries a'
	@echo '  stale metric. `make prove` / `make run-self` both emit badges, so'
	@echo '  check does not re-run them separately (no duplicate work).'
	@echo ''
	@echo 'Note: doc/fmt temporarily swap in alire-dev.toml for the duration'
	@echo '      of the command, then restore alire.toml and alire.lock untouched.'
	@echo ''
	@echo 'Prerequisites: alr (Alire), GNAT toolchain, Python 3 (for the'
	@echo '              tools/*.py dev scripts: version, description, test/'
	@echo '              proof doc sync, changelog check, agents-tree)'

# Filter the benign ld 2.44 SFrame message ("error in ...(.sframe); no
# .sframe will be created") from the link step.  It is emitted by the Alire
# GNAT toolchain's bundled ld when it reads the .sframe section newer system
# binutils wrote into the glibc startup objects; the link still succeeds.  It
# is the only build output deliberately silenced -- compiler and gnatprove
# warnings stay fully visible.  See docs/architecture.md.
build:
	@python3 tools/gen-version.py; \
	python3 tools/gen-dashboard.py; \
	alr build > /tmp/alr-build.log 2>&1; rc=$$?; \
	sed -e '/\.sframe); no \.sframe will be created/d' /tmp/alr-build.log; \
	rm -f /tmp/alr-build.log; \
	if [ $$rc -eq 0 ]; then ln -sf adacovex bin/covex; fi; \
	exit $$rc

man: build
	./bin/adacovex man

test: build
	./bin/test_runner

# Self-assessment acceptance gates, defined once so prove/run-self/release stay
# in sync (and match .github/workflows/ci.yml + AGENTS.md "Dogfood target").
# --require-tests is the current native test-suite size (docs/test_result.md).
SELF_ASSESS_ARGS := --dal=C --standard=all --require-spark=Platinum --require-docstrings=100 --require-tests=879 --require-proof=100

prove: build
	SOURCE_DATE_EPOCH=$$(git show -s --format=%ct HEAD 2>/dev/null || echo 0) ./bin/adacovex prove --target=. $(SELF_ASSESS_ARGS) --emit-svg=docs/badges/

fmt:
	@$(MAKE) _dev_cmd CMD="alr exec -- gnatformat -P adacovex.gpr -U"; \
	python3 tools/gen-version.py; \
	python3 tools/gen-dashboard.py

doc:
	@$(MAKE) _dev_cmd CMD='mkdir -p obj && \
	  alr exec -- gnatdoc -P adacovex.gpr --backend=rst \
	    --generate private --output-dir=obj/gnatdoc-rst && \
	  python3 tools/rst2md.py obj/gnatdoc-rst docs/api-docs && \
	  rm -f docs/api-docs/test_*.md docs/api-docs/adacovex-test_support.md && \
	  sed -i "/](test_[^)]*\.md)/d" docs/api-docs/index.md 2>/dev/null; \
	  sed -i "/](adacovex-test_support\.md)/d" docs/api-docs/index.md 2>/dev/null'

run-self: build
	SOURCE_DATE_EPOCH=$$(git show -s --format=%ct HEAD 2>/dev/null || echo 0) ./bin/adacovex $(SELF_ASSESS_ARGS) --emit-svg=docs/badges/

run-ada-crdt: build
	SOURCE_DATE_EPOCH=$$(git -C ../Ada_CRDT show -s --format=%ct HEAD 2>/dev/null || echo 0) ./bin/adacovex --target=../Ada_CRDT --dal=C

sbom: build
	SOURCE_DATE_EPOCH=$$(git show -s --format=%ct HEAD 2>/dev/null || echo 0) ./bin/adacovex sbom --target=. --dal=C

coverage-gate: build
	@tags=$$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$'); \
	latest=$$(echo "$$tags" | head -1); \
	prev=$$(echo "$$tags" | sed -n '2p'); \
	if [ -z "$$latest" ] || [ -z "$$prev" ]; then \
		echo "  Need at least two release tags to compare."; \
		exit 1; \
	fi; \
	echo "=== Coverage delta gate: $$prev (base) vs $$latest (current) ==="; \
	tmp=$$(mktemp -d); \
	if ! git worktree add --detach "$$tmp" "$$latest" >/dev/null 2>&1; then \
		echo "  ERROR: could not check out $$latest"; \
		rm -rf "$$tmp"; \
		exit 1; \
	fi; \
	( cd "$$tmp" && "$(CURDIR)/bin/adacovex" --target=. --coverage-delta="$$prev" ); \
	rc=$$?; \
	git worktree remove --force "$$tmp" >/dev/null 2>&1; \
	rmdir "$$tmp" 2>/dev/null || true; \
	exit $$rc

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

changelog-check:
	@python3 tools/check-changelogs.py

ascii-check:
	@echo "=== ASCII Charset Verification ==="; \
	error=0; \
	for ext in ads adb md py toml gpr; do \
	  files=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./alire/*" -not -path "./obj/*" 2>/dev/null); \
	  for f in $$files; do \
	    if LC_ALL=C grep -q '[^ -~	]' "$$f" 2>/dev/null; then \
	      echo "  NON-ASCII: $$f"; \
	      error=$$((error + 1)); \
	    fi; \
	  done; \
	done; \
	if [ $$error -eq 0 ]; then echo "All source files are pure ASCII."; \
	else echo "$$error file(s) contain non-ASCII characters."; exit 1; fi

# Quality gate: no `SPARK_Mode (Off)` may appear anywhere in src/ except the
# Types.Implementation container package -- SPARK forbids instantiating the
# non-formal Ada.Containers in SPARK_Mode On code, so that package is the one
# required exception (see AGENTS.md "SPARK proof discipline").
spark-off-check:
	@echo "=== SPARK_Mode Off verification ==="; \
	off=$$(grep -rn --include='*.ads' --include='*.adb' -E 'pragma SPARK_Mode \(Off\)|SPARK_Mode => Off' src/ 2>/dev/null | grep -v '^src/core/adacovex-types.ads:' || true); \
	if [ -n "$$off" ]; then \
	  echo "  SPARK_Mode (Off) found outside src/core/adacovex-types.ads:"; \
	  echo "$$off"; \
	  echo "  Only Types.Implementation may be SPARK_Mode Off (non-formal"; \
	  echo "  Ada.Containers are illegal in SPARK_Mode On code)."; \
	  exit 1; \
	fi; \
	echo "  no SPARK_Mode (Off) outside src/core/adacovex-types.ads"

# Quality gate: everything CI enforces before a release.  Cheap static
# gates run first so a formatting / sync problem fails before the expensive
# build+prove; the count-sync checks then verify test/proof metrics stayed
# in sync across the whole tree after `make test` / `make prove` refreshed
# them (both prove and run-self emit docs/badges/*.svg, so badges are
# produced exactly once here).
check:
	@echo "=== Quality gate: ASCII ==="; $(MAKE) ascii-check
	@echo "=== Quality gate: SPARK_Mode Off ==="; $(MAKE) spark-off-check
	@echo "=== Quality gate: changelog format ==="; $(MAKE) changelog-check
	@echo "=== Quality gate: action/CLI/docs parity ==="; $(MAKE) action-parity-check
	@echo "=== Quality gate: version source ==="; python3 tools/gen-version.py --check
	@echo "=== Quality gate: doc links ==="; python3 tools/update-doc-links.py --check
	@echo "=== Quality gate: markdown links ==="; $(MAKE) link-check
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
	@echo "=== Quality gate passed: ascii, spark-off, changelog, action-parity, version, doc-links, link, build, test, prove, doc, sbom, test-count, proof-status, description ==="

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
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make bump-version VERSION=x.y.z"; \
		exit 1; \
	fi; \
	version="$(VERSION)"; \
	if ! echo "$$version" | grep -q '^[0-9]\+\.[0-9]\+\.[0-9]\+$$'; then \
		echo "Error: version must be in x.y.z format (got: $$version)"; \
		exit 1; \
	fi; \
	echo "Bumping version to $$version..."; \
	sed -i 's/^version = ".*"/version = "'$$version'"/' alire.toml; \
	echo "  alire.toml: version = \"$$version\""; \
	sed -i 's/^version = ".*"/version = "'$$version'"/' alire-dev.toml; \
	echo "  alire-dev.toml: version = \"$$version\""; \
	python3 tools/gen-version.py; \
	echo "  src/adacovex-version.ads: Version = \"$$version\" (generated)"; \
	\
	release_file="alire/releases/covex-$$version.toml"; \
	if [ ! -f "$$release_file" ]; then \
		sed 's/^version = ".*"/version = "'$$version'"/' alire/releases/covex-0.0.0.toml > "$$release_file"; \
		echo "  Created: $$release_file"; \
	else \
		sed -i 's/^version = ".*"/version = "'$$version'"/' "$$release_file"; \
		echo "  Updated: $$release_file"; \
	fi; \
	\
	index_file="index/ad/covex/covex-$$version.toml"; \
	if [ ! -f "$$index_file" ]; then \
		sed 's/^version = ".*"/version = "'$$version'"/' index/ad/covex/covex-0.1.0-dev.toml > "$$index_file"; \
		echo "  Created: $$index_file"; \
	else \
		sed -i 's/^version = ".*"/version = "'$$version'"/' "$$index_file"; \
		echo "  Updated: $$index_file"; \
	fi; \
	\
	changelog="docs/changelogs/adacovex-$$version.md"; \
	if [ ! -f "$$changelog" ]; then \
		prev=$$(ls docs/changelogs/adacovex-*.md 2>/dev/null | \
			sed -n 's/.*adacovex-\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)\.md/\1/p' | \
			sort -t. -k1,1n -k2,2n -k3,3n | tail -1); \
		if [ -z "$$prev" ]; then prev="0.0.0"; fi; \
		echo "# adacovex $$version" > "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "Date: _$(shell date +%Y-%m-%d)_" >> "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "Version bumped $$prev -> $$version." >> "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "## Changes" >> "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "### C1: <Title>" >> "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "## Test Suite" >> "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "## Proof Results" >> "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "## Traceability" >> "$$changelog"; \
		echo "  Created: $$changelog (fill in the ### C1: subsection)"; \
	else \
		sed -i 's/^version = ".*"/version = "'$$version'"/' "$$changelog" 2>/dev/null; \
		echo "  Updated: $$changelog"; \
	fi; \
	\
	python3 tools/update-description.py; \
	echo "  descriptions synced to all manifests"; \
	echo "Done. Version bumped to $$version."; \
	echo "Next: run 'make release VERSION=$$version' to build, prove, validate,"; \
	echo "bundle, commit, and tag the release (or 'make publish' to submit to the"; \
	echo "Alire community index once the tag is pushed)."

release:
	@if [ -n "$(VERSION)" ]; then \
		version="$(VERSION)"; \
		sed -i 's/^version = ".*"/version = "'$$version'"/' alire.toml; \
	else \
		version=$$(sed -n 's/^version = "\(.*\)"/\1/p' alire.toml); \
	fi; \
	echo "=== Generating proof artifacts ==="; \
	SOURCE_DATE_EPOCH=$$(git show -s --format=%ct HEAD 2>/dev/null || echo 0) ./bin/adacovex prove --target=. $(SELF_ASSESS_ARGS) --emit-svg=docs/badges/; \
	echo "=== Building release binary (covex v$$version) ==="; \
	ADACOVEX_VERSION="$$version" python3 tools/gen-version.py; \
	alr build --release; \
	echo "=== Validating self-assessment (DAL-C) ==="; \
	SOURCE_DATE_EPOCH=$$(git show -s --format=%ct HEAD 2>/dev/null || echo 0) ./bin/adacovex --target=. $(SELF_ASSESS_ARGS) --emit-svg=docs/badges/; \
	echo "=== Docstring coverage gate (last release vs current) ==="; \
	prev_tag=$$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | grep -v "^v$$version$$" | head -1); \
	if [ -z "$$prev_tag" ]; then \
		echo "  No previous release found; skipping coverage gate"; \
	else \
		echo "  Comparing docstring coverage against $$prev_tag"; \
		./bin/adacovex --target=. --coverage-delta="$$prev_tag"; \
		if [ $$? -ne 0 ]; then \
			echo "  ERROR: docstring coverage regressed vs $$prev_tag; aborting release"; \
			exit 1; \
		fi; \
	fi; \
	echo "=== Changelogs (last release to v$$version) ==="; \
	prev_num=""; \
	if [ -n "$$prev_tag" ]; then prev_num="$${prev_tag#v}"; \
	else \
		prev_num=$$(ls alire/releases/covex-*.toml 2>/dev/null | \
			sed -n 's/.*covex-\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)\.toml/\1/p' | \
			grep -v "^$$version$$" | sort -V | tail -1); \
	fi; \
	for f in docs/changelogs/adacovex-*.md; do \
		cv=$$(basename "$$f" .md | sed 's/^adacovex-//'); \
		if [ -n "$$prev_num" ]; then \
			if [ "$$(printf '%s\n%s\n' "$$cv" "$$prev_num" | sort -V | head -1)" = "$$cv" ]; then continue; fi; \
		fi; \
		if [ "$$(printf '%s\n%s\n' "$$cv" "$$version" | sort -V | tail -1)" != "$$version" ]; then continue; fi; \
		printf '%s\n' "$$cv"; \
	done | sort -V -r | while read cv; do \
		echo "  - docs/changelogs/adacovex-$$cv.md"; \
	done; \
	echo "=== Bundling release artifacts ==="; \
	rm -rf dist; \
	mkdir -p dist; \
	cp bin/adacovex dist/adacovex; \
	ln -s adacovex dist/covex; \
	cp install.sh dist/install.sh; \
	chmod +x dist/install.sh; \
	cp LICENSE dist/LICENSE; \
	cp docs/THIRD_PARTY_NOTICES.md dist/THIRD_PARTY_NOTICES.md; \
	tar -czf "adacovex-v$$version.tar.gz" -C dist .; \
	tar -czf "adacovex-action-v$$version.tar.gz" -C . action.yml; \
	echo "  Bundled: adacovex-v$$version.tar.gz, adacovex-action-v$$version.tar.gz"; \
	echo "=== Attesting release artifacts (actions/attest) ==="; \
	if command -v gh >/dev/null 2>&1; then \
		if [ -n "$$GITHUB_TOKEN" ]; then \
			gh attest "adacovex-v$$version.tar.gz" "adacovex-action-v$$version.tar.gz" \
				--repo "$${GITHUB_REPOSITORY:-bladeacer/adacovex}" && \
			echo "  Attestations created locally."; \
		else \
			echo "  gh found but GITHUB_TOKEN is not set; skipping local attestation."; \
			echo "  (CI attests these artifacts with OIDC on the v$$version tag push.)"; \
		fi; \
	else \
		echo "  gh not installed; skipping local attestation."; \
		echo "  (CI attests these artifacts with OIDC on the v$$version tag push.)"; \
	fi; \
	commit=$$(git rev-parse HEAD); \
	index_file="index/ad/covex/covex-$$version.toml"; \
	if [ ! -f "$$index_file" ]; then \
		sed 's/^version = ".*"/version = "'$$version'"/' index/ad/covex/covex-0.1.0-dev.toml > "$$index_file"; \
	fi; \
	sed -i 's/^version = ".*"/version = "'$$version'"/' "$$index_file"; \
	release_file="alire/releases/covex-$$version.toml"; \
	if [ ! -f "$$release_file" ]; then \
		sed 's/^version = ".*"/version = "'$$version'"/' alire/releases/covex-0.0.0.toml > "$$release_file"; \
	fi; \
	sed -i 's/^version = ".*"/version = "'$$version'"/' "$$release_file"; \
	python3 tools/update-description.py; \
	echo "  descriptions synced to all manifests"; \
	if git rev-parse "v$$version" >/dev/null 2>&1; then \
		git tag -d "v$$version" >/dev/null 2>&1 || true; \
		git push origin :refs/tags/"v$$version" >/dev/null 2>&1 || true; \
		echo "  Replaced existing tag v$$version"; \
	fi; \
	git add -A; \
	git commit -m "chore: Release $$version" || true; \
	git tag -a "v$$version" -m "Release $$version"; \
	echo "Tagged v$$version at $$commit"; \
	git push origin HEAD && git push origin "v$$version"; \
	echo "Pushed commit and tag v$$version"; \
	echo ""; \
	echo "Next: run 'make publish' to submit to Alire community index."

publish:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is not clean. Commit or stash changes first."; \
		exit 1; \
	fi; \
	alr publish

test-publish:
	@version=$$(git describe --tags --abbrev=0 2>/dev/null || \
		sed -n 's/^version = "\(.*\)"/\1/p' alire.toml); \
	echo "=== test-publish dry-run ==="; \
	echo "Version:  $$version"; \
	echo "Action:   alr publish (auto-detects GitHub, test deps excluded)"; \
	echo "Requires: GitHub PAT in GITHUB_TOKEN env var or gh auth token"; \
	echo "Docs:     https://github.com/alire-project/alire/blob/master/doc/publishing.md"; \
	echo "=== end dry-run ==="

clean:
	alr clean 2>/dev/null; rm -rf bin/ obj/ docs/badges/ docs/api/

_dev_cmd:
	@tmp=$$(mktemp -d); \
	cp alire.toml "$$tmp/alire.toml" && cp alire-dev.toml alire.toml; \
	if [ -d alire ]; then cp -r alire "$$tmp/alire"; fi; \
	restore() { \
	  [ -f "$$tmp/alire.toml" ] && mv -f "$$tmp/alire.toml" alire.toml 2>/dev/null; \
	  if [ -d "$$tmp/alire" ]; then \
	    rm -rf alire; \
	    mv -f "$$tmp/alire" alire; \
	  fi; \
	  rmdir "$$tmp" 2>/dev/null || true; \
	}; \
	trap restore EXIT INT TERM; \
	$(CMD); status=$$?; \
	trap - EXIT INT TERM; \
	restore; \
	exit $$status
