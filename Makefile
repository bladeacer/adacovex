.PHONY: help build test prove doc clean run-self run-ada-crdt \
        dev-setup prod-setup ascii-check fmt _dev_cmd

.DEFAULT_GOAL := help

help:
	@echo 'adacovex -- Ada Coverage and Verification Tool'
	@echo ''
	@echo 'Usage: make <target>'
	@echo ''
	@echo '  build         Build project (adacovex_main + test_runner)'
	@echo '  test          Build and run native test suite'
	@echo '  prove         Run SPARK proofs (swaps alire-dev.toml)'
	@echo '  doc           Generate API docs via gnatdoc + rst2md'
	@echo '  fmt           Format Ada sources with gnatformat'
	@echo '  clean         Remove build artifacts'
	@echo '  run-self      Run against adacovex itself (--target=.)'
	@echo '  run-ada-crdt  Run against ../Ada_CRDT'
	@echo '  ascii-check   Verify all source files are pure ASCII'
	@echo '  dev-setup     Copy alire-dev.toml over alire.toml'
	@echo '  prod-setup    Restore clean publishing alire.toml'
	@echo ''
	@echo 'Prerequisites: alr (Alire), GNAT toolchain'

build:
	alr build

test: build
	./bin/test_runner

prove:
	@$(MAKE) _dev_cmd CMD="alr gnatprove"

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
	./bin/adacovex_main --target=. --dal=C

run-ada-crdt: build
	./bin/adacovex_main --target=../Ada_CRDT --dal=C

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
	cp alire.toml alire.toml.bak && cp alire-dev.toml alire.toml

prod-setup:
	mv alire.toml.bak alire.toml 2>/dev/null || git checkout alire.toml

clean:
	alr clean 2>/dev/null; rm -rf bin/ obj/ docs/badges/ docs/compliance/ docs/api/

_dev_cmd:
	@if ! grep -q 'gnatformat_bin' alire.toml 2>/dev/null; then \
	  cp alire.toml alire.toml.bak && cp alire-dev.toml alire.toml; \
	  restore=1; \
	else restore=0; fi; \
	$(CMD); status=$$?; \
	if [ "$$restore" -eq 1 ]; then mv alire.toml.bak alire.toml; fi; \
	exit $$status
