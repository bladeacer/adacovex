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
Target_Path     : String (1 .. Types.Max_Path);
Target_Len      : Natural := 0;
Manifest_Path   : String (1 .. Types.Max_Path);
Manifest_Len    : Natural := 0;
DAL_Target      : Types.DAL_Level := Types.DAL_C;
Standard_Target : Types.Compliance_Standard := Types.DO_178C;
Standard_All : Boolean := False;
Standard_Explicit : Boolean := False;
Serve_Mode        : Boolean := False;
Port              : Positive := 8080;
Serve_Workers     : Positive := 4;
Serve_Workers_Set : Boolean := False;
Time_Zone     : String (1 .. Types.Max_Filename);
Time_Zone_Len : Natural := 0;
Complexity_Excludes : String (1 .. Types.Max_Filename);
Excludes_Len        : Natural := 0;
Theme            : Types.Dashboard_Theme := Types.System_Theme;
No_SVG           : Boolean := False;
Emit_SVG         : Boolean := True;
SVG_Path         : String (1 .. Types.Max_Path);
SVG_Path_Len     : Natural := 0;
Emit_Markdown    : Boolean := False;
MD_Path          : String (1 .. Types.Max_Path);
MD_Path_Len      : Natural := 0;
Emit_Metrics     : Boolean := False;
Metrics_Path     : String (1 .. Types.Max_Path);
Metrics_Path_Len : Natural := 0;
Verbose          : Boolean := False;
Strict_Mode      : Boolean := True;
Cache_Enabled     : Boolean := True;
Cache_Dir         : String (1 .. Types.Max_Path);
Cache_Dir_Len     : Natural := 0;
Cache_Max_Entries : Natural := 4096;
CLI_Error : Boolean := False;
Unknown_No_Suggest : Boolean := False;
Help_Requested     : Boolean := False;
Help_Topic         : String (1 .. Types.Max_Path);
Help_Topic_Len     : Natural := 0;
Version_Requested  : Boolean := False;
Man_Mode           : Boolean := False;
Man_Check          : Boolean := False;
Man_Force          : Boolean := False;
Man_Dir            : String (1 .. Types.Max_Path);
Man_Dir_Len        : Natural := 0;
Skip_Dir_Ct        : Natural := 0;
Skip_Dirs          : Types.Name_Field;
Compare_Base       : String (1 .. Types.Max_Path);
Compare_Base_Len   : Natural := 0;
Coverage_Delta     : String (1 .. Types.Max_Path);
Coverage_Delta_Len : Natural := 0;
Prove_Mode         : Boolean := False;
Complexity_Mode    : Boolean := False;
Status_Mode        : Boolean := False;
Status_Export          : Boolean := False;
Status_Export_Path     : String (1 .. Types.Max_Path);
Status_Export_Path_Len : Natural := 0;
Status_Metrics       : Boolean := False;
Completion_Mode      : Boolean := False;
Completion_Shell     : String (1 .. Types.Max_Filename);
Completion_Shell_Len : Natural := 0;
SBOM_Mode            : Boolean := False;
SBOM_Format          : Types.SBOM_Format_Kind := Types.CycloneDX_JSON;
SBOM_Out             : String (1 .. Types.Max_Path);
SBOM_Out_Len         : Natural := 0;
No_SBOM              : Boolean := False;
Prove_Jobs           : Integer := -1;
Prove_Level          : Integer := -1;
Prove_Timeout        : Integer := -1;
Prove_Steps          : Integer := -1;
Prove_Memlimit       : Integer := -1;
Prove_Force          : Boolean := False;
Prove_No_Loop_Unroll : Boolean := False;
Prove_No_Inlining    : Boolean := False;
Prove_Suppress_Warnings : Boolean := True;
Prove_Suppress_Sets : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Prove_Suppress_Explicit : Boolean := False;
Require_SPARK          : Types.SPARK_Level := Types.Stone;
Require_SPARK_Set      : Boolean := False;
Require_Docstrings     : Natural := 0;
Require_Docstrings_Set : Boolean := False;
Require_Tests          : Natural := 0;
Require_Tests_Set      : Boolean := False;
Require_Proof          : Natural := 0;
Require_Proof_Set      : Boolean := False;
end record;
```

## Functions

### function Flag_List return Standard.String `[Post]` `[Global]`

**Returns:** Space-separated flag names (without leading dashes).

### function Parse_CLI return Adacovex.Config.CLI_Config `[Post]`

**Returns:** Fully populated CLI_Config from parsed command-line arguments.

## Procedures

### procedure Add_Skip_Dir (Cfg : Adacovex.Config.CLI_Config; Name : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Config record to modify. |
| `Name` | Directory name to add to skip list. |

### procedure Print_Topic_Help (Topic : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Topic` | Flag or subcommand name to explain. |

### procedure Print_Usage

**Returns:** Print usage information to stdout.
