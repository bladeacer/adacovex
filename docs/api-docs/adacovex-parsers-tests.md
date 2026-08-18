# Adacovex.Parsers.Tests

Parser for test-run results.
Reads a Markdown-format test summary file or parses raw stdout
to produce a structured Test_Summary.
HLR-TEST: Test result parsing

Recognized formats (all additive, best-effort):
Markdown table      | Category | Tests | PASS/FAIL | rows
Summary line        "Passed: N  Failed: M"
TAP                 "ok N - name" / "not ok N - name"
Automake suite      "PASS: name" / "FAIL: name"
Maven Surefire      "Tests run: N, Failures: M, Errors: E"
Unity               "N Tests M Failures [K Ignored]"

**See also:** [Test Result Formats](adacovex-test-format.md)

> **Note:** All items in this package are public.

## Functions

### function Find_Test_Result (Target_Dir : Standard.String) return Standard.String `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Root directory to inspect. |

**Returns:** Path to a discovered test-result file, or "".

### function Starts_With (S : Standard.String; Pre : Standard.String) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Pre` | Required prefix. |
| `S` | Candidate string. |

**Returns:** True when S'Length >= Pre'Length and the first Pre'Length

## Procedures

### procedure Parse_Test_Result (File_Path : Standard.String; Summary : Adacovex.Types.Implementation.Test_Summary; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to test result Markdown file. |
| `Success` | True if file was parsed successfully. |
| `Summary` | Output test summary record. |

### procedure Parse_Test_Result_From_Project (Target_Dir : Standard.String; Summary : Adacovex.Types.Implementation.Test_Summary; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Success` | True if a test result file was found and parsed. |
| `Summary` | Output test summary record. |
| `Target_Dir` | Target project root directory. |
