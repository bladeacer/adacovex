# Adacovex.Parsers

Read one physical line from F into Line, reporting Last as usual.
When the physical line is longer than Line'Length, the trailing part is
drained (discarded) so the file is positioned at the next line,
Overflow is set True, and an error is reported to standard error naming
File_Path (with Line_Num when non-zero) and the buffer size.  Callers
must treat Overflow as an explicit parse failure rather than processing
the truncated content, which would silently produce partial results.
@param F  Open input file positioned at the line to read.
@param File_Path  Path of the file, used in the overflow error message.
@param Line_Num  Physical line number (1-based), or 0 to omit it.
@param Line  Output buffer receiving up to Line'Length characters.
@param Last  Index of the last valid character in Line.
@param Overflow  True when the physical line exceeded Line'Length.

> **Note:** All items in this package are public.

## Procedures

### procedure Read_Line (F : Ada.Text_IO.File_Type; File_Path : Standard.String; Line_Num : Standard.Natural; Line : Standard.String; Last : Standard.Natural; Overflow : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `F` | Open input file positioned at the line to read. |
| `File_Path` | Path of the file, used in the overflow error message. |
| `Last` | Index of the last valid character in Line. |
| `Line` | Output buffer receiving up to Line'Length characters. |
| `Line_Num` | Physical line number (1-based), or 0 to omit it. |
| `Overflow` | True when the physical line exceeded Line'Length. |
