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
Serve_Watch     : Boolean := True;
Serve_Watch_Set : Boolean := False;
Time_Zone     : String (1 .. Types.Max_Filename);
Time_Zone_Len : Natural := 0;
Complexity_Excludes : String (1 .. Types.Max_Filename);
Excludes_Len        : Natural := 0;
Complexity_Skip_Paths : String (1 .. Types.Max_Path);
Skip_Paths_Len        : Natural := 0;
Theme         : Types.Dashboard_Theme := Types.System_Theme;
No_SVG        : Boolean := False;
Emit_SVG      : Boolean := True;
SVG_Path      : String (1 .. Types.Max_Path);
SVG_Path_Len  : Natural := 0;
Emit_Markdown : Boolean := False;
MD_Path       : String (1 .. Types.Max_Path);
MD_Path_Len   : Natural := 0;
No_Markdown      : Boolean := False;
Emit_Metrics     : Boolean := False;
Metrics_Path     : String (1 .. Types.Max_Path);
Metrics_Path_Len : Natural := 0;
Verbose          : Boolean := False;
Strict_Mode      : Boolean := True;
Cache_Enabled     : Boolean := True;
Cache_Dir         : String (1 .. Types.Max_Path);
Cache_Dir_Len     : Natural := 0;
Cache_Max_Entries : Natural := 4096;
Cache_Expiry_Days : Natural := 7;
Cache_Expiry_Set  : Boolean := False;
Cache_Clear : Boolean := False;
CLI_Error : Boolean := False;
Unknown_No_Suggest : Boolean := False;
Help_Requested    : Boolean := False;
Help_Topic        : String (1 .. Types.Max_Path);
Help_Topic_Len    : Natural := 0;
Version_Requested : Boolean := False;
Man_Mode          : Boolean := False;
Bare_Invocation : Boolean := False;
Init_Mode : Boolean := False;
Tldr_Mode : Boolean := False;
Man_Check : Boolean := False;
Man_Force : Boolean := False;
Man_Dir             : String (1 .. Types.Max_Path);
Man_Dir_Len         : Natural := 0;
Skip_Dir_Ct         : Natural := 0;
Skip_Dirs           : Types.Name_Field;
Compare_Base        : String (1 .. Types.Max_Path);
Compare_Base_Len    : Natural := 0;
Coverage_Delta      : String (1 .. Types.Max_Path);
Coverage_Delta_Len  : Natural := 0;
Prove_Mode          : Boolean := False;
Complexity_Mode     : Boolean := False;
Status_Mode         : Boolean := False;
Spark_Coverage_Mode : Boolean := False;
Spark_Group       : Types.Spark_Group_Kind := Types.Group_File;
Spark_Metric      : Types.Spark_Metric_Kind := Types.Metric_Statements;
Spark_Report      : Types.Spark_Report_Kind := Types.Spark_Text;
Spark_Min         : Natural := 0;
Spark_Require     : Natural := 0;
Spark_Require_Set : Boolean := False;
Spark_Gate_Metric : Types.Spark_Metric_Kind := Types.Metric_Statements;
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
Prove_Counterexamples : Boolean := True;
Prove_Counterexamples_Explicit : Boolean := False;
Prove_Suppress_Warnings : Boolean := True;
Prove_Suppress_Sets : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Prove_Suppress_Explicit : Boolean := False;
Prove_Show_Coverage : Boolean := True;
Prove_Coverage_Explicit : Boolean := False;
Prove_Diagnostics_Json : Boolean := False;
Prove_Diagnostics_Explicit : Boolean := False;
Prove_Args : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
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

> Every option one run is configured with, as the parser fills it.

### type Config_Settings

```ada
type Config_Settings is record
Coverage       : Boolean := True;
Coverage_Set   : Boolean := False;
Scaffold       : Boolean := True;
Scaffold_Set   : Boolean := False;
Jobs           : Integer := -1;
Level          : Integer := -1;
Timeout        : Integer := -1;
Steps          : Integer := -1;
Memlimit       : Integer := -1;
Excludes       : String (1 .. Types.Max_Filename);
Excludes_Len   : Natural := 0;
Skip_Paths     : String (1 .. Types.Max_Path);
Skip_Paths_Len : Natural := 0;
Expiry_Days    : Integer := -1;
end record;
```

> The values one configuration file supplies. A key that the file does not mention keeps its "set" flag False (or its -1 / 0 sentinel), so it never overwrites a built-in default or another file. `[prove] jobs`, `level`, `timeout`, `steps`, and `memlimit` take an integer; `[prove] coverage` takes true or false; `[complexity] excludes` and `skip-path` take a comma-separated string; `[cache] expiry-days` takes a non-negative integer (0 means never expire). `[init] scaffold` takes true or false; only the global file reads it, and it turns the `init` subcommand off for every project on the machine.

### type Scaffold_Status

```ada
type Scaffold_Status is
(Scaffold_Created,
Scaffold_Exists,
Scaffold_Failed);
```

> What `adacovex init` did with the project file.

## Functions

### function Flag_List return Standard.String `[Post]` `[Global]`

> All known CLI flag names, space-separated. The "did you mean" suggestion walks the same list. The shell-completion generator embeds the live flag set into the scripts it emits.

**Returns:** Space-separated flag names (without leading dashes).

### function Merge_Settings (Base : Adacovex.Config.Config_Settings; Override : Adacovex.Config.Config_Settings) return Adacovex.Config.Config_Settings

> Merge two settings sets key by key: every key Override supplies wins, and every key it does not supply keeps the value Base carries. Call it with the global file as Base and the project file as Override, so the project file wins over the global one while the command line still wins over the merged result.

| Parameter | Description |
|-----------|-------------|
| `Base` | Settings from the lower-priority file. |
| `Override` | Settings from the higher-priority file. |

**Returns:** The merged settings.

### function Parse_CLI return Adacovex.Config.CLI_Config `[Post]`

> Parse Ada.Command_Line arguments and return a fully populated config. The parser reads command-line arguments via Ada.Command_Line. Default values are used for any option not provided. It resolves relative target paths to absolute paths. It checks that the target's manifest file exists.

**Returns:** Fully populated CLI_Config from parsed command-line arguments.

### function Read_Settings (Path : Standard.String) return Adacovex.Config.Config_Settings

> Read one `adacovex.toml`. A missing or unreadable file returns the defaults (every key unset). An unknown key, an unknown section, a comment, and a bare `#` after a value are all ignored, so a file is safe to extend. Values may be quoted; an integer that is not an integer is ignored rather than failing the run.

| Parameter | Description |
|-----------|-------------|
| `Path` | Configuration file to read. |

**Returns:** The settings the file supplies.

### function Write_Sample_Project_File (Target_Dir : Standard.String; Force : Standard.Boolean) return Adacovex.Config.Scaffold_Status

> Write the sample project configuration into Target_Dir. The sample states the default of every supported key and links to the deployed manual. An existing file is left untouched unless Force is True, so a project's own settings are never lost by accident.

| Parameter | Description |
|-----------|-------------|
| `Force` | Overwrite an existing file. |
| `Target_Dir` | Directory that receives adacovex.toml. |

**Returns:** Created, Exists (left alone), or Failed.

## Procedures

### procedure Add_Skip_Dir (Cfg : Adacovex.Config.CLI_Config; Name : Standard.String)

> Add a directory name to the comma-separated skip list. The procedure appends Name to the Skip_Dirs field. It inserts a ',' separator if the list is non-empty.

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Config record to modify. |
| `Name` | Directory name to add to skip list. |

### procedure Apply_Settings (Cfg : Adacovex.Config.CLI_Config; Settings : Adacovex.Config.Config_Settings)

> Apply Settings to Cfg, key by key, only where the command line left the field unset: a prove integer below zero, an empty excludes or skip-path list, and a coverage state that --coverage or --no-coverage did not choose. Apply the global file first and the project file second, so the project wins over the global file while the command line wins over both.

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Parsed configuration to fill in. |
| `Settings` | Values read from one configuration file. |

### procedure Print_Topic_Help (Topic : Standard.String)

> Print contextual help for a single flag or subcommand. The procedure matches Topic case-insensitively, with or without the leading "--" (for example "serve", "--serve", "standard", "--standard"). It prints flag-specific detail (purpose, accepted values, related flags) for known topics. It prints the full usage text for "help" itself. For anything else it prints a short "unknown topic" notice followed by the full usage.

| Parameter | Description |
|-----------|-------------|
| `Topic` | Flag or subcommand name to explain. |

### procedure Print_Usage

> Print usage help text to standard output. The procedure displays all CLI options, default values, and usage examples.

**Returns:** Print usage information to stdout.
