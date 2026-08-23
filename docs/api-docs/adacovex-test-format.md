# Supported Test Result Formats

adacovex can parse test results in several standard formats. Parsing is
additive and best-effort: every line is inspected for any recognized format,
so a file mixing styles (or wrapping a third-party runner's log) still
produces correct pass/fail totals.

Every format contributes to the same three outputs:

- **totals** -- `Total_Passed` / `Total_Failed`, reported as
  `tests: N passed, M failed` and consumed by the DAL "Tests passing"
  criterion;
- **per-category metrics** -- `Categories` (name, count, status), consumed
  by the dashboard's Tests chart and the `--emit-metrics` export;
- the summary lines below.

## Markdown Table (native test runner)

The built-in `test_runner` executable produces this format, and any
Markdown table with the same shape is accepted:

```
  | Category            |  Tests | Status   |
  |---------------------|--------|----------|
  | Types conversions   |  67 | PASS     |
  | Server routing      |  25 | PASS     |
  | DAL compliance      |   2 | FAIL     |
  |-----------------------------------------|--------|----------|

  Passed: 92  Failed: 2
```

### Format rules

1. Columns separated by `|`. The header row and `|---|` separator rows are
   ignored (they have no numeric count cell).
2. **Two row layouts are accepted** (the count cell is detected by its
   digits in either):
   - with a leading index cell: `| - | Category | N | PASS |`
     (the AUnit-report style),
   - plain: `| Category | N | PASS |` (the native `test_runner` style).
3. **Category** cell: arbitrary text (leading/trailing spaces are trimmed).
4. **Tests** cell: a positive integer, optionally space-padded to the
   column width (`| 67 |`). Header and separator rows have no such cell.
5. **Status** cell: `PASS` (anything else counts as `FAIL`).
6. Each row ADDITIONALLY adds its count to the totals.
7. A summary line containing `Passed:` and `Failed:` followed by numbers
   **overrides** the totals (the last such line wins). This is the footer
   of the native `test_result.md`, so files with both rows and a footer
   report the footer's totals.

## TAP (Test Anything Protocol)

The protocol used by Perl's `prove`/`Test::Harness` toolchain (also emitted
by many dynamic-language test frameworks):

```
1..5
ok 1 - add works
not ok 2 - remove edge case
ok 3 - merge works
ok - unnamed pass
not ok - unnamed fail
```

- `ok ...` lines increment the passed counter.
- `not ok ...` lines increment the failed counter.
- The `1..N` plan line and anything else are ignored.

## Automake test-suite

The `PASS:`/`FAIL:`/`SKIP:` lines emitted by GNU Automake's `make check`
(`testsuite.log` / `test-suite.log` style):

```
PASS: basic
FAIL: edge case
SKIP: needs network
```

- `PASS:` increments passed; `FAIL:` increments failed; `SKIP:` is ignored.

## Maven Surefire

The summary line of Maven's Surefire JUnit runner ("Tests run:" line from
the console/log output):

```
Tests run: 5, Failures: 1, Errors: 0, Skipped: 0, Time elapsed: 0.1 s
```

Failed = Failures + Errors; passed = Tests run - failed. The last summary
line wins.

## Unity

The summary line of the [Unity](https://github.com/ThrowTheSwitch/Unity) C
test framework:

```
-----------------------
5 Tests 1 Failures 0 Ignored
OK
```

Failed = Failures; passed = Tests - Failures. The `N Failures` count may be
separated from the number by spaces.

## AUnit (Ada)

AdaCore's AUnit runner output -- either its tabular report (the indexed
`| N | Category | Count | PASS |` layout with a leading index or `-` cell,
including the optional `Passed:`/`Failed:` footer) or a Markdown table with
the same columns. Both are handled by the generic Markdown-table parser
above; AUnit report lines that match TAP/Automake patterns are additionally
accepted.

## Usage

The parser (`Adacovex.Parsers.Tests.Parse_Test_Result`) reads from a file;
`Parse_Test_Stdout` reads from standard input. When no explicit file is
given, `Parse_Test_Result_From_Project` auto-discovers the test summary in
the target project, trying conventional file names (`test_result.md`,
`test_results.md`, `test-result.md`, `test_report.md`, `test_output.md`,
`.txt`/`.log` variants, and `docs/` mirrors) in order.

```bash
# Parse a test result file
adacovex --target=../Ada_CRDT

# The parser auto-discovers test_result.md (or any conventional variant) from the target project
```

## See also

- [Target projects](../target-projects.md) -- the test-summary file
  auto-discovery rules and missing-data behavior
- [Test parser API](adacovex-parsers-tests.md) -- `Adacovex.Parsers.Tests`
- [DAL Levels](adacovex-dal-levels.md) -- how the passing-tests criterion
  feeds the compliance assessment