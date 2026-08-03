.PHONY: help build test prove doc clean run-self run-ada-crdt \
        dev-setup prod-setup ascii-check fmt bump-version coverage-gate \
        release publish test-publish _dev_cmd agents-tree

.DEFAULT_GOAL := help

help:
	@echo 'adacovex -- Ada Coverage and Verification Tool'
	@echo ''
	@echo 'Usage: make <target>'
	@echo ''
	@echo '  build         Build project (adacovex + test_runner, covex alias)'
	@echo '  test          Build and run native test suite'
	@echo '  prove         Run SPARK proofs (gnatprove declared dependency)'
	@echo '  doc           Generate API docs via gnatdoc + rst2md (alire-dev.toml)'
	@echo '  fmt           Format Ada sources with gnatformat (alire-dev.toml)'
	@echo '  clean         Remove build artifacts'
	@echo '  run-self      Run against adacovex itself (default target: cwd)'
	@echo '  run-ada-crdt  Run against ../Ada_CRDT (strict mode)'
	@echo '  coverage-gate Compare docstring coverage between the latest two'
	@echo '                release tags (--coverage-delta in a worktree at'
	@echo '                the latest tag; verifies the release gate logic)'
	@echo '  agents-tree   Regenerate the AGENTS.md src/ architecture tree'
	@echo '                (tools/gen-agents-tree.py + tools/agents-tree.map)'
	@echo '  bump-version  Bump version across alire.toml, alire-dev.toml,'
	@echo '                adacovex.ads, releases, index (VERSION=x.y.z)'
	@echo '  release       Tag, update releases+index, push. Use VERSION=x.y.z'
	@echo '                (Runs a docstring-coverage gate comparing the last'
	@echo '                 release against the current tree, then CI force-pushes'
	@echo '                 vMAJOR / vMAJOR.MINOR floating tags so @v1 / @v1.3'
	@echo '                 refs track the latest release)'
	@echo '  publish       Publish to Alire community index (run after make release)'
	@echo '  test-publish  Dry-run showing what make publish would do'
	@echo '  ascii-check   Verify all source files are pure ASCII'
	@echo ''
	@echo 'Note: doc/fmt temporarily swap in alire-dev.toml for the duration'
	@echo '      of the command, then restore alire.toml and alire.lock untouched.'
	@echo ''
	@echo 'Prerequisites: alr (Alire), GNAT toolchain'

build:
	alr build
	ln -sf adacovex bin/covex

test: build
	./bin/test_runner

prove: build
	./bin/adacovex prove --target=. --no-svg

fmt:
	@$(MAKE) _dev_cmd CMD="alr exec -- gnatformat -P adacovex.gpr -U"

doc:
	@$(MAKE) _dev_cmd CMD='mkdir -p obj && \
	  alr exec -- gnatdoc -P adacovex.gpr --backend=rst \
	    --generate private --output-dir=obj/gnatdoc-rst && \
	  python3 tools/rst2md.py obj/gnatdoc-rst docs/api-docs && \
	  rm -f docs/api-docs/test_*.md docs/api-docs/adacovex-test_support.md && \
	  sed -i "/](test_[^)]*\.md)/d" docs/api-docs/index.md 2>/dev/null; \
	  sed -i "/](adacovex-test_support\.md)/d" docs/api-docs/index.md 2>/dev/null'

run-self: build
	./bin/adacovex --dal=C

run-ada-crdt: build
	./bin/adacovex --target=../Ada_CRDT --dal=C

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

agents-tree:
	@python3 tools/gen-agents-tree.py > /tmp/agents-tree.out && \
	python3 tools/apply-agents-tree.py /tmp/agents-tree.out && \
	rm -f /tmp/agents-tree.out

# Package the local gnatprove toolchain into the platform bundle that
# `covex prove` downloads into ~/.adacovex/toolchain/ when gnatprove is not
# on PATH or already cached.  Produces
# adacovex-toolchain-<os>-<arch>.tar.gz from the Alire gnatprove release
# (currently a GNAT distribution with gnatprove + solvers).  Attach it to a
# GitHub Release and the default toolchain URL
# (releases/latest/download/adacovex-toolchain-<os>-<arch>.tar.gz) resolves.
toolchain-asset:
	@set -e; \
	os=$$(uname -s | tr 'A-Z' 'a-z'); \
	arch=$$(uname -m); \
	case "$$arch" in x86_64|amd64) arch=x86_64;; aarch64|arm64) arch=aarch64;; *) echo "unsupported arch: $$arch" >&2; exit 1;; esac; \
	gnatprove_dir=$$(ls -d $$HOME/.local/share/alire/releases/gnatprove_*/ 2>/dev/null | head -1); \
	if [ -z "$$gnatprove_dir" ]; then \
		echo "ERROR: no gnatprove toolchain found under ~/.local/share/alire/releases/"; \
		echo "  Install it first: alr toolchain --select --install gnatprove"; \
		exit 1; \
	fi; \
	asset="adacovex-toolchain-$$os-$$arch.tar.gz"; \
	echo "Bundling gnatprove toolchain ($$gnatprove_dir) -> $$asset"; \
	tar -czf "$$asset" -C "$$gnatprove_dir" .; \
	echo "  Done: $$asset ($$(du -h "$$asset" | cut -f1))"; \
	echo "  Attach it to the release and 'covex prove' will auto-download it."

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

dev-setup:
	@echo 'dev-setup is no longer needed. prove/doc/fmt auto-swap alire-dev.toml'
	@echo 'safely and restore alire.toml afterwards. alire.toml always stays clean.'
	@exit 0

prod-setup:
	@echo 'prod-setup is no longer needed. alire.toml is never left with dev deps.'
	@exit 0

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
	sed -i 's/^   Version : constant String := "[^"]*"/   Version : constant String := "'$$version'"/' src/adacovex.ads; \
	echo "  src/adacovex.ads: Version = \"$$version\""; \
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
		echo "# adacovex $$version" > "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "Date: _$(shell date +%Y-%m-%d)_" >> "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "## Changes" >> "$$changelog"; \
		echo "" >> "$$changelog"; \
		echo "- Version bumped to $$version." >> "$$changelog"; \
		echo "  Created: $$changelog"; \
	else \
		sed -i 's/^version = ".*"/version = "'$$version'"/' "$$changelog" 2>/dev/null; \
		echo "  Updated: $$changelog"; \
	fi; \
	\
	echo "Done. Remember to:"; \
	echo "  - Update docs/changelogs/index.md"; \
	echo "  - Update AGENTS.md version references"; \
	echo "  - Commit: git commit -am \"Release $$version\" && git tag -a v$$version -m \"Release $$version\""

release:
	@if [ -n "$(VERSION)" ]; then \
		version="$(VERSION)"; \
		sed -i 's/^version = ".*"/version = "'$$version'"/' alire.toml; \
	else \
		version=$$(sed -n 's/^version = "\(.*\)"/\1/p' alire.toml); \
	fi; \
	echo "=== Generating proof artifacts ==="; \
	./bin/adacovex prove --target=. --no-svg; \
	echo "=== Building release binary (covex v$$version) ==="; \
	alr build --release; \
	echo "=== Validating self-assessment (DAL-C) ==="; \
	./bin/adacovex --target=. --dal=C --no-svg; \
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
	if git rev-parse "v$$version" >/dev/null 2>&1; then \
		git tag -d "v$$version" >/dev/null 2>&1 || true; \
		git push origin :refs/tags/"v$$version" >/dev/null 2>&1 || true; \
		echo "  Replaced existing tag v$$version"; \
	fi; \
	git add -A; \
	git commit -m "Release $$version" || true; \
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
