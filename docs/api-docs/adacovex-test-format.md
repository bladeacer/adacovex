# Supported Test Result Formats

adacovex can parse test results in several standard formats. Parsing is
additive and best-effort: every line is inspected for any recognized format,
so a file mixing styles (or wrapping a third-party runner's log) still
produces correct pass/fail totals.

## Markdown Table (native test runner)

The built-in `test_runner` executable produces output in this format:

```
  | Category                                |  Tests | Status   |
  |-----------------------------------------|--------|----------|
  | Types conversions                       |  21 | PASS     |
  | DAL compliance                          |  2 | PASS     |
  |-----------------------------------------|--------|----------|

  Passed: 23  Failed: 0
```

### Format rules

1. A table with columns: **Category**, **Tests**, **Status**
2. Columns separated by `|` characters
3. **Category** column: arbitrary text (the category/group name)
4. **Tests** column: a positive integer (number of tests in the category)
5. **Status** column: `PASS` or `FAIL`
6. A summary line containing `Passed:` and `Failed:` keywords followed by numbers

## TAP (Test Anything Protocol)

Each line is one test:

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

## Automake test-suite

```
PASS: basic
FAIL: edge case
SKIP: needs network
```

- `PASS:` increments passed; `FAIL:` increments failed; `SKIP:` is ignored.

## Maven Surefire

```
Tests run: 5, Failures: 1, Errors: 0, Skipped: 0, Time elapsed: 0.1 s
```

Failed = Failures + Errors; passed = Tests run - failed. The last summary line
wins.

## Unity

```
-----------------------
5 Tests 1 Failures 0 Ignored
OK
```

Failed = Failures; passed = Tests - Failures. The `N Failures` count may be
separated from the number by spaces.

## AUnit Format Compatibility

AUnit test runners that output Markdown format with the same column layout are
also supported (category names, per-category counts, PASS/FAIL status, and the
overall `Passed:` / `Failed:` summary line).

## Usage

The parser (`Adacovex.Parsers.Tests.Parse_Test_Result`) reads from a file;
`Parse_Test_Stdout` reads from standard input.

```bash
# Parse a test result file
adacovex --target=../Ada_CRDT

# The parser reads test_result.md from the target project
```
