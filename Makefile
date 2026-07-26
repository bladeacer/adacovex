.PHONY: all build test prove fmt lint api-docs changelog run-self \
        run-self-serve run-self-badges clean

all: build

build:
	alr build

test:
	alr run

prove:
	alr gnatprove

fmt:
	gnatpp -P adacovex.gpr -rnb src/**/*.ads src/**/*.adb 2>/dev/null || \
	  echo "gnatpp not available; install Alire gnat_tools"

lint:
	alr build 2>&1 | grep -iE "warning|error" || true

api-docs:
	gnatdoc -P adacovex.gpr --output-dir=docs/api --create-missing-dirs \
	  2>/dev/null || echo "gnatdoc not available; install Alire gnat_tools"

changelog:
	git log --oneline --format="* %s" > CHANGELOG.tmp && \
	  echo "Changelog generated from git log" || \
	  echo "Not a git repository; update CHANGELOG.md manually"

run-self: build
	timeout 5 ./bin/adacovex --target=../Ada_CRDT --dal=C

run-self-serve: build
	timeout 5 ./bin/adacovex --target=../Ada_CRDT --dal=C --serve --port=8080

run-self-badges: build
	mkdir -p docs/badges docs/compliance
	timeout 5 ./bin/adacovex --target=../Ada_CRDT --dal=C \
	  --emit-svg=docs/badges/ \
	  --emit-markdown=docs/compliance/

clean:
	rm -rf bin/ obj/ docs/badges/ docs/compliance/ docs/api/
