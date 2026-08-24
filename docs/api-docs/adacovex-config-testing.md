# Adacovex.Config.Testing

Testable CLI-parser core.  Kept out of SPARK.  It operates on an
unbounded string vector and reports parse errors to Standard_Error.
Unit tests can drive flag precedence through Parse_Args without
touching Ada.Command_Line.  Parse_CLI wraps Parse_Args with the real
command line and then finalises filesystem defaults.

> **Note:** All items in this package are public.

## Procedures

### procedure Parse_Args (Args : Adacovex.Config.Testing.Arg_Vectors.Vector; Cfg : Adacovex.Config.CLI_Config)

| Parameter | Description |
|-----------|-------------|
| `Args` | Argument strings in command-line order. |
| `Cfg` | Config record to populate (fields are overwritten in |

### procedure Parse_Command_Line (Cfg : Adacovex.Config.CLI_Config)

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Config record to populate from the command line. |
