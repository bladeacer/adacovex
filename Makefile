.PHONY: all build test prove run-self clean

all: build

build:
	alr build

test:
	alr run

prove:
	alr gnatprove

run-self: build
	./bin/adacovex --target=../Ada_CRDT --dal=C

run-self-serve: build
	./bin/adacovex --target=../Ada_CRDT --dal=C --serve --port=8080

run-self-badges: build
	./bin/adacovex --target=../Ada_CRDT --dal=C --emit-svg=docs/badges/ --emit-markdown=docs/compliance/

clean:
	rm -rf bin/ obj/ docs/badges/
