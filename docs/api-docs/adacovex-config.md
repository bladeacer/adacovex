# Adacovex.Config

Command-line argument parser for adacovex.
Parses short and long option forms (--key=value and --key value)
and returns a populated CLI_Config record.
HLR-CLI: CLI argument parsing

> **Note:** All items in this package are public.

## Types

### type CLI_Config

```ada
type CLI_Config is record
Target_Path   : String (1 .. Types.Max_Path);
Target_Len    : Natural := 0;
Manifest_Path : String (1 .. Types.Max_Path);
Manifest_Len  : Natural := 0;
DAL_Target    : Types.DAL_Level := Types.DAL_C;
Serve_Mode    : Boolean := False;
Port          : Positive := 8080;
Emit_SVG      : Boolean := False;
SVG_Path      : String (1 .. Types.Max_Path);
SVG_Path_Len  : Natural := 0;
Emit_Markdown : Boolean := False;
MD_Path       : String (1 .. Types.Max_Path);
MD_Path_Len   : Natural := 0;
Verbose       : Boolean := False;
end record;
```

## Functions

### function Parse_CLI return Adacovex.Config.CLI_Config `[Post]`

**Returns:** Fully populated CLI_Config from parsed command-line arguments.

## Procedures

### procedure Print_Usage

**Returns:** Prints usage information to stdout.
