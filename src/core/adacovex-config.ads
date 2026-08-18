with Adacovex.Types;
with Ada.Containers.Indefinite_Vectors;

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

      --  True when --standard=all is given: run the assessment once at the
      --  shared tier and emit badges/reports for every compliance standard
      --  (DO-178C, ISO 26262, IEC 62304) instead of just the selected one.
      Standard_All : Boolean := False;

      --  True when --standard / --asil / --class was passed explicitly.
      --  The sbom subcommand and the serve dashboard default to Standard_All
      --  when none of these is given (the SBOM carries the joined
      --  all-standards properties and the dashboard renders every standard);
      --  an explicit standard flag narrows them to that single standard.
      Standard_Explicit : Boolean := False;
      Serve_Mode        : Boolean := False;
      Port              : Positive := 8080;

      --  Dashboard color theme for --serve (system/light/dark).  "system"
      --  follows the browser's prefers-color-scheme; light/dark force a
      --  theme.  Only relevant with --serve.
      Theme         : Types.Dashboard_Theme := Types.System_Theme;
      No_SVG        : Boolean := False;
      Emit_SVG      : Boolean := True;
      SVG_Path      : String (1 .. Types.Max_Path);
      SVG_Path_Len  : Natural := 0;
      Emit_Markdown : Boolean := False;
      MD_Path       : String (1 .. Types.Max_Path);
      MD_Path_Len   : Natural := 0;
      Verbose       : Boolean := False;
      Strict_Mode   : Boolean := True;

      --  Result caching (see Adacovex.Cache).  Enabled by default; the cache
      --  is keyed by the SHA-256 of each analyzed input, so unchanged code
      --  is served from disk instead of re-scanned / re-parsed / re-proved.
      Cache_Enabled     : Boolean := True;
      Cache_Dir         : String (1 .. Types.Max_Path);
      Cache_Dir_Len     : Natural := 0;
      Cache_Max_Entries : Natural := 4096;

      CLI_Error : Boolean := False;

      --  True when an unknown flag/argument was rejected AND no similar
      --  known flag was found to suggest (Suggest_Flags returned "").  The
      --  main program prints the full usage text to stdout after the error
      --  in this case, so a totally unrecognized token still lands the user
      --  on the flag list instead of a bare one-line error.
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
      Status_Mode        : Boolean := False;
      SBOM_Mode          : Boolean := False;
      SBOM_Format        : Types.SBOM_Format_Kind := Types.CycloneDX_JSON;
      SBOM_Out           : String (1 .. Types.Max_Path);
      SBOM_Out_Len       : Natural := 0;
      No_SBOM            : Boolean := False;

      --  GNATprove invocation options (prove mode).  A value of -1 means
      --  "not configured": --jobs auto-detects the core count, and the
      --  level/timeout/steps/memlimit options are not passed to gnatprove.
      --  --jobs=0 forwards -j0 (all cores).  The prove subcommand applies
      --  its own --steps=10000 default when --steps is not passed (see
      --  Build_Option_String), so proofs get a reproducible budget instead
      --  of gnatprove's step-limit false negatives.
      Prove_Jobs           : Integer := -1;
      Prove_Level          : Integer := -1;
      Prove_Timeout        : Integer := -1;
      Prove_Steps          : Integer := -1;
      Prove_Memlimit       : Integer := -1;
      Prove_Force          : Boolean := False;
      Prove_No_Loop_Unroll : Boolean := False;
      Prove_No_Inlining    : Boolean := False;

      --  CI threshold gates (default: all off).  When set, the assessment
      --  fails loudly (exit code 1 with an explicit reason) if the target
      --  does not meet the minimum required level.  These are extra gates on
      --  top of the DAL criteria -- exactly the values a CI workflow wants to
      --  pin so a regression cannot slip through unnoticed.
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
   --  Reads command-line arguments via Ada.Command_Line; default values are
   --  used for any option not provided.  Resolves relative target paths to
   --  absolute and checks that the target's manifest file exists.
   --  @return Fully populated CLI_Config from parsed command-line arguments.
   function Parse_CLI return CLI_Config
   with
     Post =>
       Parse_CLI'Result.Target_Len <= Types.Max_Path
       and then Parse_CLI'Result.Manifest_Len <= Types.Max_Path
       and then Parse_CLI'Result.SVG_Path_Len <= Types.Max_Path
       and then Parse_CLI'Result.MD_Path_Len <= Types.Max_Path
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
   --  Appends Name to the Skip_Dirs field, inserting ',' separator if
   --  the list is non-empty.
   --  @param Cfg  Config record to modify.
   --  @param Name  Directory name to add to skip list.
   procedure Add_Skip_Dir (Cfg : in out CLI_Config; Name : String);

   --  Print usage help text to standard output.
   --  Displays all CLI options, default values, and usage examples.
   --  @return Prints usage information to stdout.
   procedure Print_Usage;

   --  Print contextual help for a single flag or subcommand.
   --  Topic is matched case-insensitively, with or without the leading
   --  "--" (e.g. "serve", "--serve", "standard", "--standard").  Prints
   --  flag-specific detail (purpose, accepted values, related flags) for
   --  known topics, the full usage text for "help" itself, and a short
   --  "unknown topic" notice followed by the full usage for anything else.
   --  @param Topic  Flag or subcommand name to explain.
   procedure Print_Topic_Help (Topic : String);

   --  Testable CLI-parser core.  Kept out of SPARK (it operates on an
   --  unbounded string vector and reports parse errors to Standard_Error),
   --  so unit tests can drive flag precedence through Parse_Args without
   --  touching Ada.Command_Line.  Parse_CLI wraps Parse_Args with the real
   --  command line and then finalizes filesystem defaults.
   package Testing is

      package Arg_Vectors is new
        Ada.Containers.Indefinite_Vectors (Positive, String);

      --  Parse an argument vector into Cfg, applying each argument
      --  (--flag=value and --flag value forms) in order.  Flag precedence is
      --  last-write-wins per field: --dal sets only the shared tier,
      --  --asil/--class set both the standard and the tier, and --standard
      --  sets only the standard (or the "all" expansion).
      --  @param Args  Argument strings in command-line order.
      --  @param Cfg  Config record to populate (fields are overwritten in
      --              argument order).
      procedure Parse_Args
        (Args : Arg_Vectors.Vector; Cfg : in out CLI_Config);

      --  Read the real Ada.Command_Line into an argument vector and delegate
      --  to Parse_Args.  Kept here (non-SPARK) so Parse_CLI's body stays
      --  free of access-type objects.
      --  @param Cfg  Config record to populate from the command line.
      procedure Parse_Command_Line (Cfg : out CLI_Config);
   end Testing;

end Adacovex.Config;
