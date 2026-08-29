with Adacovex.Types;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;

--  Command-line argument parser for adacovex.
--  Parses short and long option forms (--key=value and --key value)
--  and returns a populated CLI_Config record.
--  HLR-CLI: CLI argument parsing

package Adacovex.Config is

   type CLI_Config is record
      Target_Path     : String (1 .. Types.Max_Path);
      Target_Len      : Natural := 0;
      Manifest_Path   : String (1 .. Types.Max_Path);
      Manifest_Len    : Natural := 0;
      DAL_Target      : Types.DAL_Level := Types.DAL_C;
      Standard_Target : Types.Compliance_Standard := Types.DO_178C;

      --  True when --standard=all is given. The assessment runs once at the
      --  shared tier. It emits badges and reports for every compliance
      --  standard (DO-178C, ISO 26262, IEC 62304) instead of the selected
      --  one.
      Standard_All : Boolean := False;

      --  True when the user passes --standard, --asil, or --class
      --  explicitly. The sbom subcommand and the serve dashboard default to
      --  Standard_All when none is given. The SBOM carries the joined
      --  all-standards properties, and the dashboard renders every standard.
      --  An explicit standard flag narrows them to that single standard.
      Standard_Explicit : Boolean := False;
      Serve_Mode        : Boolean := False;
      Port              : Positive := 8080;

      --  Number of HTTP server task-pool workers for --serve (default: 4).
      --  --serve-workers=N raises or lowers how many concurrent requests the
      --  dashboard server handles.  Only relevant with --serve.
      Serve_Workers    : Positive := 4;
      Serve_Workers_Set : Boolean := False;

      --  Display timezone override (--tz / --timezone).  Empty means the
      --  operating system's timezone applies.  Accepted forms: a well-known
      --  IANA name ("Asia/Singapore") or a fixed UTC/GMT offset
      --  ("UTC+8", "GMT+8", "UTC+08", "GMT+08", "UTC+08:30").  See
      --  Adacovex.Timezones.  Consumed by `status` and the local
      --  date/time reports.
      Time_Zone      : String (1 .. Types.Max_Filename);
      Time_Zone_Len  : Natural := 0;

      --  Comma-separated file extensions to skip in `complexity` mode
      --  (--excludes=md,rst).  Only valid with the complexity subcommand.
      Complexity_Excludes : String (1 .. Types.Max_Filename);
      Excludes_Len        : Natural := 0;


      --  Dashboard colour theme for --serve (system/light/dark).  "system"
      --  follows the browser's prefers-color-scheme.  "light" and "dark"
      --  force a theme.  Relevant only with --serve.
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

      --  Result caching (see Adacovex.Cache).  Enabled by default.  The
      --  cache is keyed by the SHA-256 of each analysed input.  Unchanged
      --  code is served from disk instead of re-scanned, re-parsed, or
      --  re-proved.
      Cache_Enabled     : Boolean := True;
      Cache_Dir         : String (1 .. Types.Max_Path);
      Cache_Dir_Len     : Natural := 0;
      Cache_Max_Entries : Natural := 4096;

      CLI_Error : Boolean := False;

      --  True when an unknown flag or argument is rejected and no similar
      --  known flag is found to suggest (Suggest_Flags returned "").  The
      --  main program prints the full usage text to stdout after the error.
      --  A totally unrecognised token still lands the user on the flag list
      --  instead of a bare one-line error.
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

      --  True when the user gives `status --export[=PATH]`.  The status
      --  report is written as machine-readable JSON to PATH (or stdout when
      --  no path is supplied).  It replaces the human-readable text report.
      Status_Export          : Boolean := False;
      Status_Export_Path     : String (1 .. Types.Max_Path);
      Status_Export_Path_Len : Natural := 0;

      --  True when the user gives `status --metrics`.  The status report is
      --  printed as a compact key=value metrics summary (one per line).
      --  Shell scripts and CI can consume it without parsing prose.
      Status_Metrics       : Boolean := False;
      Completion_Mode      : Boolean := False;
      Completion_Shell     : String (1 .. Types.Max_Filename);
      Completion_Shell_Len : Natural := 0;
      SBOM_Mode            : Boolean := False;
      SBOM_Format          : Types.SBOM_Format_Kind := Types.CycloneDX_JSON;
      SBOM_Out             : String (1 .. Types.Max_Path);
      SBOM_Out_Len         : Natural := 0;
      No_SBOM              : Boolean := False;

      --  GNATprove invocation options (prove mode).  A value of -1 means
      --  "not configured".  --jobs auto-detects the core count.  The level,
      --  timeout, steps, and memlimit options are not passed to gnatprove.
      --  --jobs=0 forwards -j0 (all cores).  The prove subcommand applies
      --  its own --steps=10000 default when --steps is not passed (see
      --  Build_Option_String).  Proofs then get a reproducible budget
      --  instead of gnatprove's step-limit false negatives.
      Prove_Jobs           : Integer := -1;
      Prove_Level          : Integer := -1;
      Prove_Timeout        : Integer := -1;
      Prove_Steps          : Integer := -1;
      Prove_Memlimit       : Integer := -1;
      Prove_Force          : Boolean := False;
      Prove_No_Loop_Unroll : Boolean := False;
      Prove_No_Inlining    : Boolean := False;

      --  Quiet-by-default prove output.  Unless --verbose is given, the
      --  prove subcommand hides GNATprove's benign informational messages
      --  from stdout.  The hidden set is the default suppression set
      --  (loop-unrolling and inlining notices).  --verbose always wins over
      --  it and shows every message.  CI passes --verbose because CI output
      --  stays authoritative.  The default is True.  Local runs are quiet
      --  without any flag.
      Prove_Suppress_Warnings : Boolean := True;

      --  Comma-separated suppression-set names for --suppress-warnings=SETS
      --  (and --quiet, which is the default set).  Empty means the default
      --  set (unrolling-inlining).  A set name suppresses gnatprove info
      --  tags `[info-<SET>]` (or `[<SET>]`).  See
      --  Adacovex.Prove.Replay_Suppressed.
      Prove_Suppress_Sets : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;

      --  True when the user explicitly passes --quiet or --suppress-warnings.
      --  This differs from the quiet-by-default state.  Only the explicit
      --  form is a prove-mode flag for the "requires the prove subcommand"
      --  validation.  A plain local run never trips it.
      Prove_Suppress_Explicit : Boolean := False;

      --  CI threshold gates (default: all off).  When set, the assessment
      --  fails with exit code 1 and an explicit reason if the target does
      --  not meet the minimum required level.  These are extra gates on top
      --  of the DAL criteria.  A CI workflow pins these values to stop a
      --  regression from slipping through unnoticed.
      Require_SPARK          : Types.SPARK_Level := Types.Stone;
      Require_SPARK_Set      : Boolean := False;
      Require_Docstrings     : Natural := 0;  --  minimum docstring coverage %
      Require_Docstrings_Set : Boolean := False;
      Require_Tests          : Natural := 0;  --  minimum passing test count
      Require_Tests_Set      : Boolean := False;
      Require_Proof          : Natural := 0;  --  minimum proved-VC coverage %
      Require_Proof_Set      : Boolean := False;
   end record;

   --  Parse Ada.Command_Line arguments and return a fully populated config.
   --  The parser reads command-line arguments via Ada.Command_Line.
   --  Default values are used for any option not provided.  It resolves
   --  relative target paths to absolute paths.  It checks that the target's
   --  manifest file exists.
   --  @return Fully populated CLI_Config from parsed command-line arguments.
   function Parse_CLI return CLI_Config
   with
     Post =>
       Parse_CLI'Result.Target_Len <= Types.Max_Path
       and then Parse_CLI'Result.Manifest_Len <= Types.Max_Path
       and then Parse_CLI'Result.SVG_Path_Len <= Types.Max_Path
       and then Parse_CLI'Result.MD_Path_Len <= Types.Max_Path
       and then Parse_CLI'Result.Metrics_Path_Len <= Types.Max_Path
       and then Parse_CLI'Result.Compare_Base_Len <= Types.Max_Path
       and then Parse_CLI'Result.Coverage_Delta_Len <= Types.Max_Path
       and then Parse_CLI'Result.SBOM_Out_Len <= Types.Max_Path
       and then Parse_CLI'Result.Man_Dir_Len <= Types.Max_Path
       and then Parse_CLI'Result.Prove_Jobs in -1 .. 1024
       and then Parse_CLI'Result.Prove_Level in -1 .. 4
       and then Parse_CLI'Result.Prove_Timeout in -1 .. 3600
       and then Parse_CLI'Result.Prove_Steps in -1 .. 100_000_000
       and then Parse_CLI'Result.Prove_Memlimit in -1 .. 1_000_000
       and then Parse_CLI'Result.Require_Docstrings in 0 .. 100
       and then Parse_CLI'Result.Require_Proof in 0 .. 100
       and then Parse_CLI'Result.Help_Topic_Len <= Types.Max_Path;

   --  Add a directory name to the comma-separated skip list.
   --  The procedure appends Name to the Skip_Dirs field.  It inserts a ','
   --  separator if the list is non-empty.
   --  @param Cfg  Config record to modify.
   --  @param Name  Directory name to add to skip list.
   procedure Add_Skip_Dir (Cfg : in out CLI_Config; Name : String);

   --  All known CLI flag names, space-separated.  The "did you mean"
   --  suggestion walks the same list.  The shell-completion generator
   --  embeds the live flag set into the scripts it emits.
   --  @return Space-separated flag names (without leading dashes).
   function Flag_List return String
   with Post => Flag_List'Result'Length > 0, Global => null;

   --  Print usage help text to standard output.
   --  The procedure displays all CLI options, default values, and usage
   --  examples.
   --  @return Print usage information to stdout.
   procedure Print_Usage;

   --  Print contextual help for a single flag or subcommand.
   --  The procedure matches Topic case-insensitively, with or without the
   --  leading "--" (for example "serve", "--serve", "standard",
   --  "--standard").  It prints flag-specific detail (purpose, accepted
   --  values, related flags) for known topics.  It prints the full usage
   --  text for "help" itself.  For anything else it prints a short
   --  "unknown topic" notice followed by the full usage.
   --  @param Topic  Flag or subcommand name to explain.
   procedure Print_Topic_Help (Topic : String);

   --  Testable CLI-parser core.  Kept out of SPARK.  It operates on an
   --  unbounded string vector and reports parse errors to Standard_Error.
   --  Unit tests can drive flag precedence through Parse_Args without
   --  touching Ada.Command_Line.  Parse_CLI wraps Parse_Args with the real
   --  command line and then finalises filesystem defaults.
   package Testing is

      package Arg_Vectors is new
        Ada.Containers.Indefinite_Vectors (Positive, String);

      --  Parse an argument vector into Cfg.  The procedure applies each
      --  argument (--flag=value and --flag value forms) in order.  Flag
      --  precedence is last-write-wins per field.  --dal sets only the
      --  shared tier.  --asil and --class set both the standard and the
      --  tier.  --standard sets only the standard (or the "all" expansion).
      --  @param Args  Argument strings in command-line order.
      --  @param Cfg  Config record to populate (fields are overwritten in
      --              argument order).
       procedure Parse_Args
         (Args : Arg_Vectors.Vector; Cfg : in out CLI_Config);

       --  Parse an argument vector and apply every cross-flag validation
       --  (subcommand gating, --excludes/--serve-workers/--tz rules, derived
       --  defaults).  This is the testable core of Parse_CLI: the command-line
       --  reader builds the vector and delegates here, and the unit tests call
       --  it directly without touching Ada.Command_Line.
       --  @param Args  Argument strings in command-line order.
       --  @return Fully populated CLI_Config after validation.
       function Parse_All
         (Args : Arg_Vectors.Vector) return CLI_Config;

       --  Read the real Ada.Command_Line into an argument vector and delegate
       --  to Parse_Args.  Kept here (non-SPARK).  Parse_CLI's body stays free
       --  of access-type objects.
       --  @param Cfg  Config record to populate from the command line.
       procedure Parse_Command_Line (Cfg : out CLI_Config);
    end Testing;

end Adacovex.Config;
