.PHONY: all build test prove run-self run-self-serve run-self-badges clean lint

all: build

build:
	alr build

test:
	alr run

prove:
	alr gnatprove

lint:
	alr build -p 2>&1 | grep -i "warning\|error" || true

run-self: build
	./bin/adacovex --target=../Ada_CRDT --dal=C

run-self-serve: build
	./bin/adacovex --target=../Ada_CRDT --dal=C --serve --port=8080

run-self-badges: build
	mkdir -p docs/badges docs/compliance
	./bin/adacovex --target=../Ada_CRDT --dal=C --emit-svg=docs/badges/ --emit-markdown=docs/compliance/

clean:
	rm -rf bin/ obj/ docs/badges/ docs/compliance/
