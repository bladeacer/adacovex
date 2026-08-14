with Adacovex.Types;

--  Command-line argument parser for adacovex.
--  Parses short and long option forms (--key=value and --key value)
--  and returns a populated CLI_Config record.
--  HLR-CLI: CLI argument parsing

package Adacovex.Config is
   pragma SPARK_Mode (On);

   type CLI_Config is record
      Target_Path   : String (1 .. Types.Max_Path);
      Target_Len    : Natural := 0;
      Manifest_Path : String (1 .. Types.Max_Path);
      Manifest_Len  : Natural := 0;
      DAL_Target    : Types.DAL_Level := Types.DAL_C;
      Serve_Mode    : Boolean := False;
      Port          : Positive := 8080;
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

      CLI_Error          : Boolean := False;
      Help_Requested     : Boolean := False;
      Skip_Dir_Ct        : Natural := 0;
      Skip_Dirs          : Types.Name_Field;
      Compare_Base       : String (1 .. Types.Max_Path);
      Compare_Base_Len   : Natural := 0;
      Coverage_Delta     : String (1 .. Types.Max_Path);
      Coverage_Delta_Len : Natural := 0;
      Prove_Mode         : Boolean := False;
      SBOM_Mode          : Boolean := False;
      SBOM_Format        : Types.SBOM_Format_Kind := Types.CycloneDX_JSON;
      SBOM_Out           : String (1 .. Types.Max_Path);
      SBOM_Out_Len       : Natural := 0;
      No_SBOM            : Boolean := False;

      --  GNATprove invocation options (prove mode).  A value of -1 means
      --  "not configured": --jobs auto-detects the core count, and the
      --  level/timeout/steps/memlimit options are not passed to gnatprove.
      --  --jobs=0 forwards -j0 (all cores).
      Prove_Jobs           : Integer := -1;
      Prove_Level          : Integer := -1;
      Prove_Timeout        : Integer := -1;
      Prove_Steps          : Integer := -1;
      Prove_Memlimit       : Integer := -1;
      Prove_Force          : Boolean := False;
      Prove_No_Loop_Unroll : Boolean := False;
      Prove_No_Inlining    : Boolean := False;

      --  GNATprove version pin for the prove subcommand.  Empty means
      --  "latest": Resolve_GNATprove follows normal resolution priority
      --  (manifest-declared version first).  When set, the named gnatprove
      --  version is deployed via `alr -n get gnatprove=<version>` and run
      --  directly, overriding any manifest pin (the CLI pin is authoritative
      --  -- "latest" otherwise -- and the version is folded into the proof
      --  result-cache identity so proofs from different provers never mix).
      --  Recommended for mission-critical / reproducible CI: pin the exact
      --  version (e.g. --gnatprove-version=16.1.0), because a gnatprove
      --  upgrade can change which VCs are discharged.
      GNATprove_Version     : String (1 .. Types.Max_Id_Str);
      GNATprove_Version_Len : Natural := 0;

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
       and then Parse_CLI'Result.Prove_Jobs in -1 .. 1024
       and then Parse_CLI'Result.Prove_Level in -1 .. 4
       and then Parse_CLI'Result.Prove_Timeout in -1 .. 3600
       and then Parse_CLI'Result.Prove_Steps in -1 .. 100_000_000
       and then Parse_CLI'Result.Prove_Memlimit in -1 .. 1_000_000
       and then Parse_CLI'Result.GNATprove_Version_Len <= Types.Max_Id_Str
       and then Parse_CLI'Result.Require_Docstrings in 0 .. 100
       and then Parse_CLI'Result.Require_Proof in 0 .. 100;

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

end Adacovex.Config;
