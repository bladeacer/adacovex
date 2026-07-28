# Supported Test Result Format

adacovex can parse test results in Markdown table format. Both native
test-runner output and AUnit-formatted results are supported.

## Native Test Runner Format

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

The parser (`Adacovex.Parsers.Tests.Parse_Test_Result`) reads from a file.
`Parse_Test_Stdout` reads from standard input.

## AUnit Format Compatibility

AUnit test runners that output Markdown format with the same column layout
are also supported. The parser reads:
- Category names
- Per-category test counts
- Per-category PASS/FAIL status
- Overall passed/failed totals from the "Passed:" / "Failed:" summary line

## Usage

```bash
# Parse a test result file
adacovex --target=../Ada_CRDT

# The parser reads test_result.md from the target project
```
