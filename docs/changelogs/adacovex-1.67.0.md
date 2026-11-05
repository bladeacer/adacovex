# adacovex 1.67.0

Date: _2026-11-05_

Version bumped 1.66.0 -> 1.67.0.

## Changes

### C1: The API reference names every subprogram parameter

Many generated API pages listed a parameter with an empty Description cell.
The reader saw a table row that named a parameter and then said nothing about
it. The cause was twofold. Some source docstrings never carried an `@param`
line for the parameter, and the converter that builds the pages dropped the
docstrings that did exist.

The docstrings now document every parameter of the affected subprograms:
`Adacovex.Cache.Get_Meta`, `Adacovex.Complexity.Check_Gates` and
`Adacovex.Complexity.Print_Report`, `Adacovex.CPUs.Run_Capture`,
`Adacovex.Prove.Run_Prove`, the five `Adacovex.Types.To_String` overloads that
had none, and the four SPARK coverage and dashboard renderers in
`Adacovex.Renderers.HTML`. Each of the 26 test categories also documents its
`Run` procedure and its `R` parameter, so the per-category page states what
the category covers.

The generated `Adacovex.Docs_Template` unit now carries the same annotations.
`tools/gen-docs.py` emits the offline manual specification, so it emits the
`@param` and `@return` lines for `Body_Bytes`, `Base85_Decode`, `Content`, and
`Find` from one place.

Every page that lost a description now shows it. The converter changes that
made that possible are recorded under H1.

## Fixes

### H1: rst2md keeps the docstrings it already has

`tools/rst2md.py` builds the API pages from the gnatdoc RST output and the Ada
specs. Four defects hid docstrings that the source already carried.

The `record_depth` counter rose on a multi-line `type X is` declaration and
never fell, because an enumeration has no `end record`. Every subprogram after
the first enumeration in a spec lost its annotation block, so its whole
parameter table rendered empty. The counter now treats a `type X is` header as
a type body that closes on its terminating semicolon, and a `record` line that
follows the header still opens a record.

Annotation tags also leaked across blocks. A file header that shows the
supported `@param` form put an example tag on the first subprogram of the
file, which changed the annotation key and hid the real tags. A blank line or
any other code line now ends the block, so tags belong only to the declaration
they sit against.

`find_ads` skipped `src/tests/`, so the per-category test pages never found
their spec and every `Run` parameter stayed blank. The lookup now searches the
test tree too. Private-section subprograms were recorded as private items but
their annotation blocks were discarded; they are kept now, so the private
section renders its parameter tables.

The tools suite pins the first two defects: a multi-line enumeration followed
by a documented function, and a header example tag followed by a documented
procedure.

## Test Suite

- 2127/2127 native tests passing across 29 categories. The native suite is
  unchanged: this release adds no executable Ada statement.
- `tools/tests.py` grows to 202 checks with the two new `rst2md` regression
  checks (the type-body counter and the header-tag leak).

## Proof Results

- gnatprove 16.1.0: SPARK Gold, 1054/1054 VCs proved across 75 analyzed
  units, 0 unproved, and 0 justified. No proof surface changed: the work adds
  comments to specs and test packages, and it edits two Python tools (see
  `docs/proof/16.1.0-ledger.md`).

## Traceability

No new HLR record enters this release. The changed packages keep their
existing tags:

- `-- HLR-CACHE` (`adacovex-cache`): the `Get_Meta` parameter block;
- `-- HLR-COMPLEXITY` (`adacovex-complexity`): the gate and report parameter
  blocks;
- `-- HLR-CPU` (`adacovex-cpus`): the `Run_Capture` parameter block;
- `-- HLR-PROVE` (`adacovex-prove`): the `Run_Prove` target parameter;
- `-- HLR-RENDER-HTML` (`adacovex-renderers-html`): the dashboard and SPARK
  coverage renderer parameter blocks;
- `-- HLR-SCAN` (`adacovex-parsers-source`): the scanner docstrings the
  converter now keeps;
- `-- HLR-ARCH` (`tools/rst2md.py`, `tools/gen-docs.py`): the converter
  fixes, the test-package lookup, and the generated manual annotations.
