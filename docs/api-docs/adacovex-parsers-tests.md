# Adacovex.Parsers.Tests

Parse a Markdown-format test result file for pass/fail counts.
Reads category counts from a pre-formatted test summary Markdown file.
@param File_Path  Path to test result Markdown file.
@param Summary  Output test summary record.
@param Success  True if file was parsed successfully.

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
