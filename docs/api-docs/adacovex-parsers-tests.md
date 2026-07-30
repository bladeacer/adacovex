# Adacovex.Parsers.Tests

Parser for AUnit test-run results.
Reads a Markdown-format test summary file or parses raw stdout
to produce a structured Test_Summary.
HLR-TEST: Test result parsing

> **Note:** All items in this package are public.

## Procedures

### procedure Parse_Test_Result (File_Path : Standard.String; Summary : Adacovex.Types.Test_Summary; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to test result Markdown file. |
| `Success` | True if file was parsed successfully. |
| `Summary` | Output test summary record. |

### procedure Parse_Test_Stdout (Summary : Adacovex.Types.Test_Summary)

| Parameter | Description |
|-----------|-------------|
| `Summary` | Output test summary from piped stdout. |
