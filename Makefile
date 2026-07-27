.PHONY: help all build test prove fmt lint api-docs changelog \
        verify-report compliance ascii-check dev-setup prod-setup \
        bump-version release publish run-self run-self-serve run-self-badges \
        clean

.DEFAULT_GOAL := help

help:
	@echo 'adacovex — Ada Coverage & Verification Tool'
	@echo ''
	@echo 'Usage: make <target>'
	@echo ''
	@echo '  build         Build the project (alr build)'
	@echo '  test          Run tests'
	@echo '  prove         Run SPARK proofs (alr gnatprove)'
	@echo '  fmt           Format Ada sources with gnatformat'
	@echo '  lint          Check for build warnings'
	@echo '  api-docs      Generate Ada API docs (requires gnatdoc)'
	@echo '  changelog     Generate CHANGELOG from git log'
	@echo '  verify-report Regenerate VERIFICATION.md from gnatprove.out + test results'
	@echo '  compliance    HLR traceability check + verification report'
	@echo '  ascii-check   Enforce ASCII-only charset across source files'
	@echo '  dev-setup     Symlink alire-dev.toml over alire.toml for dev tools'
	@echo '  prod-setup    Restore clean publishing alire.toml'
	@echo '  bump-version  Bump version (VERSION=x.y.z)'
	@echo '  run-self      Dogfood: run against ../Ada_CRDT, DAL-C'
	@echo '  run-self-serve Dogfood with HTTP server on :8080'
	@echo '  run-self-badges Generate SVG badges + Markdown reports'
	@echo '  clean         Remove build artifacts'
	@echo '  help          Show this message'
	@echo ''
	@echo 'System: Alire (alr), GNAT/SPARK toolchain (managed by Alire)'

build:
	tmpfile=$$(mktemp); \
	alr build > $$tmpfile 2>&1; result=$$?; \
	grep -v "no .sframe will be created" $$tmpfile; \
	rm -f $$tmpfile; exit $$result

test: build
	alr run

prove:
	alr gnatprove

fmt:
	@echo "=== Formatting Ada sources with gnatformat ==="; \
	if ! grep -q 'gnatformat_bin' alire.toml 2>/dev/null; then \
		cp alire.toml alire.toml.fmtbak; \
		cp alire-dev.toml alire.toml; \
		restore=1; \
	else \
		restore=0; \
	fi; \
	alr exec -- gnatformat -P adacovex.gpr -U; \
	status=$$?; \
	if [ "$$restore" -eq 1 ]; then \
		mv alire.toml.fmtbak alire.toml; \
	fi; \
	exit $$status

lint:
	alr build 2>&1 | grep -iE "warning|error" || true

api-docs:
	@echo "=== Generating Ada API docs ==="; \
	alr exec -- gnatdoc -P adacovex.gpr --output-dir=docs/api --create-missing-dirs 2>/dev/null || \
	  echo "gnatdoc not available; run 'make dev-setup' first"

changelog:
	git log --oneline --format="%s" > CHANGELOG.tmp && \
	  echo "Changelog written to CHANGELOG.tmp" || \
	  echo "Not a git repository; update CHANGELOG.md manually"

# --- Verification report from build artifacts ---
verify-report:
	@echo "=== Generating Verification Report ==="; \
	prove_out="obj/gnatprove/gnatprove.out"; \
	test_result="../Ada_CRDT/test_result.md"; \
	verif_file="docs/compliance/VERIFICATION.md"; \
	\
	if [ ! -f "$$prove_out" ]; then \
		echo "  WARNING: $$prove_out not found"; \
		echo "  Using placeholder values."; \
		total="0"; proved="0"; unproved="0"; \
		rt_total="0"; rt_proved="0"; \
		flow_deps="0"; \
	else \
		total=$$(awk 'BEGIN{FS="  +"}/^Total /{print $$2+0}' "$$prove_out"); \
		proved=$$(awk 'BEGIN{FS="  +"}/^Total /{print $$4+0}' "$$prove_out"); \
		unproved=$$(awk 'BEGIN{FS="  +"}/^Total /{print $$6+0}' "$$prove_out"); \
		rt_total=$$(awk 'BEGIN{FS="  +"}/^Run-time Checks /{print $$2+0}' "$$prove_out"); \
		rt_proved=$$(awk 'BEGIN{FS="  +"}/^Run-time Checks /{print $$4+0}' "$$prove_out"); \
		flow_deps=$$(awk 'BEGIN{FS="  +"}/^Flow Dependencies /{print $$2+0}' "$$prove_out"); \
	fi; \
	\
	if [ -f "$$test_result" ]; then \
		test_total=$$(grep 'Passed:' "$$test_result" | awk '{print $$2}'); \
		test_failed=$$(grep 'Passed:' "$$test_result" | awk '{print $$4}'); \
	else \
		test_total="?"; test_failed="?"; \
	fi; \
	\
	hlr_count=$$(grep -rn -- '--.*HLR-' src | sed 's/.*HLR-\([A-Z0-9-]*\).*/\1/' | sort -u | wc -l); \
	\
	echo "# adacovex Verification Report" > "$$verif_file"; \
	echo "" >> "$$verif_file"; \
	echo "## SPARK Proof Results" >> "$$verif_file"; \
	echo "" >> "$$verif_file"; \
	echo "| Metric | Count |" >> "$$verif_file"; \
	echo "|--------|-------|" >> "$$verif_file"; \
	echo "| Total checks | $$total |" >> "$$verif_file"; \
	echo "| Proved | $$proved |" >> "$$verif_file"; \
	echo "| Unproved | $$unproved |" >> "$$verif_file"; \
	echo "| Flow Dependencies | $$flow_deps |" >> "$$verif_file"; \
	echo "| Run-time Checks | $$rt_total ($$rt_proved proved) |" >> "$$verif_file"; \
	echo "" >> "$$verif_file"; \
	echo "## Test Results" >> "$$verif_file"; \
	echo "" >> "$$verif_file"; \
	echo "**Total: $$test_total passed, $$test_failed failed.**" >> "$$verif_file"; \
	echo "" >> "$$verif_file"; \
	echo "## HLR Traceability" >> "$$verif_file"; \
	echo "" >> "$$verif_file"; \
	echo "- **HLRs**: $$hlr_count high-level requirements, all traced to source" >> "$$verif_file"; \
	echo "" >> "$$verif_file"; \
	echo "  Generated: $$verif_file"

# --- DO-178C compliance check ---
compliance:
	@echo "=== DO-178C Traceability Verification ==="; \
	errors=0; \
	srcdir=src; \
	hlr_file="docs/HLR.md"; \
	llr_file="docs/LLR.md"; \
	trace_file="docs/compliance/TRACE.md"; \
	\
	echo "--- HLR tag scan ---"; \
	source_hlrs=$$(grep -rn -- '--.*HLR-' $$srcdir | sed 's/.*HLR-\([A-Z0-9-]*\).*/\1/' | sort -u); \
	src_count=$$(echo "$$source_hlrs" | wc -l); \
	echo "HLR tags found in source: $$src_count"; \
	for hlr in $$source_hlrs; do \
		found=$$(grep -rl -- "--.*HLR-$$hlr" $$srcdir 2>/dev/null); \
		if [ -z "$$found" ]; then \
			echo "  MISSING: HLR-$$hlr -- no source file has this tag"; \
			errors=$$((errors + 1)); \
		else \
			echo "  HLR-$$hlr -> $$(echo $$found | tr ' ' ',')"; \
		fi; \
	done; \
	\
	if [ -f "$$hlr_file" ]; then \
		echo ""; \
		echo "--- HLR.md coverage ---"; \
		doc_hlrs=$$(sed -n 's/.*HLR-\([A-Z0-9-]*\).*/\1/p' "$$hlr_file" | sort -u); \
		for hlr in $$source_hlrs; do \
			if ! echo "$$doc_hlrs" | grep -q "$$hlr"; then \
				echo "  MISSING in HLR.md: HLR-$$hlr"; \
				errors=$$((errors + 1)); \
			fi; \
		done; \
		for hlr in $$doc_hlrs; do \
			if ! echo "$$source_hlrs" | grep -q "$$hlr"; then \
				echo "  STALE in HLR.md: HLR-$$hlr (not in source)"; \
				errors=$$((errors + 1)); \
			fi; \
		done; \
		if [ $$errors -eq 0 ]; then echo "  All HLRs in source match HLR.md."; \
		fi; \
	else \
		echo "  MISSING: $$hlr_file"; \
		errors=$$((errors + 1)); \
	fi; \
	\
	for f in "$$llr_file" "$$trace_file"; do \
		if [ -f "$$f" ]; then echo "  $$f -- present"; \
		else echo "  $$f -- MISSING"; errors=$$((errors + 1)); fi; \
	done; \
	\
	echo ""; \
	if [ "$$errors" -eq 0 ]; then \
		echo "All compliance checks passed."; \
	else \
		echo "$$errors compliance issue(s) found."; \
		exit 1; \
	fi

ascii-check:
	@echo "=== ASCII Charset Verification ==="; \
	extensions="ads adb md toml gpr yaml yml"; \
	error=0; \
	for ext in $$extensions; do \
		files=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./alire/*" -not -path "./obj/*" 2>/dev/null); \
		for f in $$files; do \
			if LC_ALL=C grep -q '[^ -~	]' "$$f" 2>/dev/null; then \
				echo "  NON-ASCII: $$f"; \
				error=$$((error + 1)); \
			fi; \
		done; \
	done; \
	if [ $$error -eq 0 ]; then \
		echo "All source files are pure ASCII."; \
	else \
		echo "$$error file(s) contain non-ASCII characters."; \
		exit 1; \
	fi

dev-setup:
	@echo "Symlinking alire-dev.toml over alire.toml for development tools..."; \
	cp alire.toml alire.toml.bak; \
	cp alire-dev.toml alire.toml; \
	echo "Done. Run 'make prod-setup' to restore the clean publishing manifest."

prod-setup:
	@echo "Restoring clean publishing manifest..."; \
	mv alire.toml.bak alire.toml 2>/dev/null || git checkout alire.toml; \
	echo "alire.toml restored."

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
	sed -i 's/^version = ".*"/version = "'$$version'"/' alire.toml; \
	sed -i 's/^version = ".*"/version = "'$$version'"/' alire-dev.toml; \
	echo "Version bumped to $$version"

release:
	@if [ -n "$(VERSION)" ]; then \
		version="$(VERSION)"; \
		sed -i 's/^version = ".*"/version = "'$$version'"/' alire.toml; \
		sed -i 's/^version = ".*"/version = "'$$version'"/' alire-dev.toml; \
	else \
		version=$$(sed -n 's/^version = "\(.*\)"/\1/p' alire.toml); \
	fi; \
	commit=$$(git rev-parse HEAD); \
	git add -A; \
	git commit -m "Release $$version" || true; \
	git tag -a "v$$version" -m "Release $$version"; \
	echo "Tagged v$$version at $$commit"; \
	echo "Next: git push origin HEAD && git push origin v$$version"

publish:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is not clean. Commit or stash changes first."; \
		exit 1; \
	fi; \
	alr publish

run-self: build
	timeout 10 ./bin/adacovex_main --target=../Ada_CRDT --dal=C

run-self-serve: build
	timeout 5 ./bin/adacovex_main --target=../Ada_CRDT --dal=C --serve --port=8080

run-self-badges: build
	mkdir -p docs/badges docs/compliance
	timeout 10 ./bin/adacovex_main --target=../Ada_CRDT --dal=C \
	  --emit-svg=docs/badges/ \
	  --emit-markdown=docs/compliance/

clean:
	alr clean 2>/dev/null; \
	rm -rf bin/ obj/ docs/badges/ docs/compliance/ docs/api/
