# Adacovex.Config.Testing

Testable CLI-parser core. Kept out of SPARK. It operates on an
unbounded string vector and reports parse errors to Standard_Error.
Unit tests can drive flag precedence through Parse_Args without
touching Ada.Command_Line. Parse_CLI wraps Parse_Args with the real
command line and then finalises filesystem defaults.

> **Note:** All items in this package are public.

## Functions

### function Parse_All (Args : Adacovex.Config.Testing.Arg_Vectors.Vector) return Adacovex.Config.CLI_Config

> Parse an argument vector and apply every cross-flag validation (subcommand gating, --excludes/--serve-workers/--tz rules, derived defaults). This is the testable core of Parse_CLI: the command-line reader builds the vector and delegates here, and the unit tests call it directly without touching Ada.Command_Line.

| Parameter | Description |
|-----------|-------------|
| `Args` | Argument strings in command-line order. |

**Returns:** Fully populated CLI_Config after validation.

## Procedures

### procedure Parse_Args (Args : Adacovex.Config.Testing.Arg_Vectors.Vector; Cfg : Adacovex.Config.CLI_Config)

> Parse an argument vector into Cfg. The procedure applies each argument (--flag=value and --flag value forms) in order. Flag precedence is last-write-wins per field. --dal sets only the shared tier. --asil and --class set both the standard and the tier. --standard sets only the standard (or the "all" expansion).

| Parameter | Description |
|-----------|-------------|
| `Args` | Argument strings in command-line order. |
| `Cfg` | Config record to populate (fields are overwritten in argument order). |

### procedure Parse_Command_Line (Cfg : Adacovex.Config.CLI_Config)

> Read the real Ada.Command_Line into an argument vector and delegate to Parse_Args. Kept here (non-SPARK). Parse_CLI's body stays free of access-type objects.

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Config record to populate from the command line. |
