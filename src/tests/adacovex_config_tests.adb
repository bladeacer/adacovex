with Adacovex.Types;  use Adacovex.Types;
with Adacovex.Config; use Adacovex.Config;
with Adacovex.Completion;
with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Environment_Variables;

package body Adacovex_Config_Tests is

   procedure Add (A : in out Testing.Arg_Vectors.Vector; S : String) is
   begin
      Testing.Arg_Vectors.Append (A, S);
   end Add;

   --  Run the parser over Args and check the resolved standard/tier/all
   --  fields against the expected precedence outcome.
   procedure Check_Args
     (Args    : Testing.Arg_Vectors.Vector;
      R       : in out Adacovex.Test_Support.Runner'Class;
      Std     : Compliance_Standard;
      Tier    : DAL_Level;
      All_Std : Boolean;
      Msg     : String)
   is
      Cfg : CLI_Config;
   begin
      Testing.Parse_Args (Args, Cfg);
      R.Check (Cfg.Standard_Target = Std, Msg & ": standard");
      R.Check (Cfg.DAL_Target = Tier, Msg & ": tier");
      R.Check (Cfg.Standard_All = All_Std, Msg & ": all-standards");
   end Check_Args;

   --  True when two parsed configs carry the same user-visible option state.
   --  Only the option fields are compared: the fixed path buffers past their
   --  length are uninitialised, so a plain record equality would read
   --  garbage.
   function Same_Options (A, B : CLI_Config) return Boolean is
   begin
      return
        A.DAL_Target = B.DAL_Target
        and then A.Standard_Target = B.Standard_Target
        and then A.Standard_All = B.Standard_All
        and then A.Standard_Explicit = B.Standard_Explicit
        and then A.Serve_Mode = B.Serve_Mode
        and then A.Port = B.Port
        and then A.Serve_Workers = B.Serve_Workers
        and then A.Serve_Workers_Set = B.Serve_Workers_Set
        and then A.Theme = B.Theme
        and then A.No_SVG = B.No_SVG
        and then A.Emit_SVG = B.Emit_SVG
        and then A.Emit_Markdown = B.Emit_Markdown
        and then A.No_Markdown = B.No_Markdown
        and then A.Verbose = B.Verbose
        and then A.Strict_Mode = B.Strict_Mode
        and then A.Cache_Enabled = B.Cache_Enabled
        and then A.Cache_Max_Entries = B.Cache_Max_Entries
        and then A.Skip_Dir_Ct = B.Skip_Dir_Ct
        and then A.Prove_Mode = B.Prove_Mode
        and then A.Prove_Level = B.Prove_Level
        and then A.Prove_Jobs = B.Prove_Jobs
        and then A.Prove_Timeout = B.Prove_Timeout
        and then A.Prove_Steps = B.Prove_Steps
        and then A.Prove_Memlimit = B.Prove_Memlimit
        and then A.Prove_Force = B.Prove_Force
        and then A.Prove_No_Loop_Unroll = B.Prove_No_Loop_Unroll
        and then A.Prove_No_Inlining = B.Prove_No_Inlining
        and then A.Prove_Suppress_Warnings = B.Prove_Suppress_Warnings
        and then A.Prove_Suppress_Explicit = B.Prove_Suppress_Explicit
        and then A.Require_SPARK = B.Require_SPARK
        and then A.Require_SPARK_Set = B.Require_SPARK_Set
        and then A.Require_Docstrings = B.Require_Docstrings
        and then A.Require_Docstrings_Set = B.Require_Docstrings_Set
        and then A.Require_Tests = B.Require_Tests
        and then A.Require_Tests_Set = B.Require_Tests_Set
        and then A.Require_Proof = B.Require_Proof
        and then A.Require_Proof_Set = B.Require_Proof_Set
        and then A.CLI_Error = B.CLI_Error
        and then A.Target_Len = B.Target_Len
        and then A.Manifest_Len = B.Manifest_Len
        and then A.SVG_Path_Len = B.SVG_Path_Len
        and then A.MD_Path_Len = B.MD_Path_Len
        and then A.Compare_Base_Len = B.Compare_Base_Len
        and then A.Coverage_Delta_Len = B.Coverage_Delta_Len;
   end Same_Options;

   --  Parse two argument lists with Parse_All and assert the alias produces
   --  the same option state as its canonical long spelling.
   procedure Check_Equivalent
     (Alias     : Testing.Arg_Vectors.Vector;
      Canonical : Testing.Arg_Vectors.Vector;
      R         : in out Adacovex.Test_Support.Runner'Class;
      Msg       : String)
   is
      A : CLI_Config;
      B : CLI_Config;
   begin
      A := Testing.Parse_All (Alias);
      B := Testing.Parse_All (Canonical);
      R.Check (not A.CLI_Error and then not B.CLI_Error, Msg & ": parses");
      R.Check (Same_Options (A, B), Msg & ": same option state");
   end Check_Equivalent;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  Test 1: default config has Emit_SVG = True and SVG_Path_Len = 0.
      --  Uses `others => <>` so newly added fields with defaults need no
      --  explicit mention; a non-defaulted field would fail to compile.
      declare
         Cfg : constant CLI_Config :=
           (Emit_SVG       => True,
            SVG_Path_Len   => 0,
            Serve_Mode     => False,
            DAL_Target     => DAL_C,
            Port           => 8080,
            Verbose        => False,
            Emit_Markdown  => False,
            Help_Requested => False,
            Strict_Mode    => False,
            others         => <>);
      begin
         R.Check (Cfg.Emit_SVG, "Default Emit_SVG is True");
         R.Check
           (Cfg.SVG_Path_Len = 0,
            "Default SVG_Path_Len is 0 (set later if emit)");
         R.Check (not Cfg.Serve_Mode, "Default Serve_Mode is False");
         R.Check (Cfg.DAL_Target = DAL_C, "Default DAL_Target is C");
         R.Check
           (Cfg.Standard_Target = DO_178C,
            "Default Standard_Target is DO_178C");
         R.Check
           (not Cfg.Standard_All,
            "Default Standard_All is False (single-standard mode)");
         R.Check (Cfg.Port = 8080, "Default Port is 8080");
         R.Check (not Cfg.Verbose, "Default Verbose is False");
         R.Check (not Cfg.Emit_Markdown, "Default Emit_Markdown is False");
         R.Check (not Cfg.Help_Requested, "Default Help_Requested is False");
         R.Check
           (Cfg.Compare_Base_Len = 0,
            "Default Compare_Base_Len is 0 (--compare-base not set)");
         R.Check
           (Cfg.Coverage_Delta_Len = 0,
            "Default Coverage_Delta_Len is 0 (--coverage-delta not set)");
      end;

      --  Test 2: No_SVG overrides Emit_SVG
      declare
         Cfg : constant CLI_Config :=
           (No_SVG => True, Emit_SVG => True, others => <>);
      begin
         --  No_SVG=True means Emit_SVG should be forced False by Parse_CLI
         R.Check (Cfg.No_SVG, "No_SVG field works");
      end;

      --  Test 3: prove option defaults are the unset sentinels
      declare
         Cfg : constant CLI_Config := (others => <>);
      begin
         R.Check (Cfg.Prove_Jobs = -1, "Default Prove_Jobs is -1 (auto)");
         R.Check (Cfg.Prove_Level = -1, "Default Prove_Level is -1 (unset)");
         R.Check
           (Cfg.Prove_Timeout = -1, "Default Prove_Timeout is -1 (unset)");
         R.Check (Cfg.Prove_Steps = -1, "Default Prove_Steps is -1 (unset)");
         R.Check
           (Cfg.Prove_Memlimit = -1, "Default Prove_Memlimit is -1 (unset)");
         R.Check (not Cfg.Prove_Force, "Default Prove_Force is False");
         R.Check
           (not Cfg.Prove_No_Loop_Unroll,
            "Default Prove_No_Loop_Unroll is False");
         R.Check
           (not Cfg.Prove_No_Inlining, "Default Prove_No_Inlining is False");
         --  Quiet is the default for local runs: suppression is on and the
         --  set list is empty (the default set), without any flag.
         R.Check
           (Cfg.Prove_Suppress_Warnings,
            "Default Prove_Suppress_Warnings is True (quiet by default)");
         R.Check
           (Ada.Strings.Unbounded.Length (Cfg.Prove_Suppress_Sets) = 0,
            "Default Prove_Suppress_Sets is empty (default set)");
         R.Check
           (not Cfg.Prove_Suppress_Explicit,
            "Default Prove_Suppress_Explicit is False (not a prove-mode flag)");
      end;

      --  --quiet parses as an explicit prove-mode flag selecting the
      --  default suppression set (the "outside prove mode is an error"
      --  validation runs in Parse_CLI, which the Parse_Args unit tests do
      --  not reach).
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "--quiet");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Prove_Suppress_Warnings,
            "prove --quiet keeps Prove_Suppress_Warnings on");
         R.Check
           (Ada.Strings.Unbounded.Length (Cfg.Prove_Suppress_Sets) = 0,
            "prove --quiet selects the default set (empty set list)");
         R.Check
           (Cfg.Prove_Suppress_Explicit,
            "prove --quiet sets Prove_Suppress_Explicit");
         R.Check (not Cfg.CLI_Error, "prove --quiet is not an error");
      end;

      --  --suppress-warnings (bare) is an alias of --quiet, and
      --  --suppress-warnings=SETS carries a comma-separated custom set list.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "--suppress-warnings");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Prove_Suppress_Warnings,
            "prove --suppress-warnings sets Prove_Suppress_Warnings");
         R.Check
           (Ada.Strings.Unbounded.Length (Cfg.Prove_Suppress_Sets) = 0,
            "prove --suppress-warnings selects the default set");
         R.Check
           (Cfg.Prove_Suppress_Explicit,
            "prove --suppress-warnings sets Prove_Suppress_Explicit");
         R.Check
           (not Cfg.CLI_Error, "prove --suppress-warnings is not an error");
      end;

      --  --suppress-warnings=xyz,abc carries a custom comma-separated set
      --  list verbatim.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "--suppress-warnings=xyz,abc");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Prove_Suppress_Warnings,
            "prove --suppress-warnings=xyz,abc keeps suppression on");
         R.Check
           (Ada.Strings.Unbounded.To_String (Cfg.Prove_Suppress_Sets)
            = "xyz,abc",
            "prove --suppress-warnings=xyz,abc stores the set list verbatim");
         R.Check
           (Cfg.Prove_Suppress_Explicit,
            "prove --suppress-warnings=xyz,abc sets Prove_Suppress_Explicit");
         R.Check
           (not Cfg.CLI_Error,
            "prove --suppress-warnings=xyz,abc is not an error");
      end;

      --  Test 4: CI threshold defaults are "not set" (gates off)
      declare
         Cfg : constant CLI_Config := (others => <>);
      begin
         R.Check
           (not Cfg.Require_SPARK_Set,
            "Default Require_SPARK_Set is False (gate off)");
         R.Check
           (Cfg.Require_SPARK = Stone,
            "Default Require_SPARK is Stone (lowest)");
         R.Check
           (not Cfg.Require_Docstrings_Set,
            "Default Require_Docstrings_Set is False (gate off)");
         R.Check
           (Cfg.Require_Docstrings = 0, "Default Require_Docstrings is 0 (%)");
         R.Check
           (not Cfg.Require_Tests_Set,
            "Default Require_Tests_Set is False (gate off)");
         R.Check (Cfg.Require_Tests = 0, "Default Require_Tests is 0");
         R.Check
           (not Cfg.Require_Proof_Set,
            "Default Require_Proof_Set is False (gate off)");
         R.Check (Cfg.Require_Proof = 0, "Default Require_Proof is 0 (%)");
      end;

      --  Test 5: the prove-option / threshold fields can be set on a
      --  populated record (a field that loses its default stops compiling).
      declare
         Cfg : CLI_Config := (Prove_Jobs => 12, others => <>);
      begin
         Cfg.Require_SPARK := Gold;
         Cfg.Require_SPARK_Set := True;
         Cfg.Require_Docstrings := 80;
         Cfg.Require_Tests := 300;
         Cfg.Require_Proof := 90;
         R.Check
           (Cfg.Require_SPARK = Gold and Cfg.Require_SPARK_Set,
            "Require_SPARK can be set");
         R.Check
           (Cfg.Require_Docstrings = 80, "Require_Docstrings can be set");
         R.Check (Cfg.Require_Tests = 300, "Require_Tests can be set");
         R.Check (Cfg.Require_Proof = 90, "Require_Proof can be set");
         R.Check (Cfg.Prove_Jobs = 12, "Prove_Jobs can be set");
      end;

      --  Flag precedence (1.10.0): dedicated level flags set both the
      --  standard and the shared tier; --dal sets only the tier; --standard
      --  sets only the standard (or the "all" expansion).  Sequential
      --  application is last-write-wins per field.
      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--asil=B");
         Check_Args (A, R, ISO_26262, DAL_C, False, "--asil=B alone");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--class=A");
         Check_Args (A, R, IEC_62304, DAL_C, False, "--class=A alone");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--standard=iso26262");
         Add (A, "--dal=C");
         Check_Args
           (A, R, ISO_26262, DAL_C, False, "--standard=iso26262 --dal=C");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--dal=A");
         Add (A, "--standard=iso26262");
         Check_Args
           (A, R, ISO_26262, DAL_A, False, "--dal=A --standard=iso26262");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--standard=do178c");
         Add (A, "--asil=B");
         Check_Args
           (A,
            R,
            ISO_26262,
            DAL_C,
            False,
            "--asil=B after --standard overrides standard");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--asil=B");
         Add (A, "--standard=do178c");
         Check_Args
           (A,
            R,
            DO_178C,
            DAL_C,
            False,
            "--standard=do178c after --asil=B overrides standard");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--class=C");
         Add (A, "--asil=B");
         Check_Args
           (A,
            R,
            ISO_26262,
            DAL_C,
            False,
            "--asil=B after --class=C overrides standard and tier");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--asil=B");
         Add (A, "--class=C");
         Check_Args
           (A,
            R,
            IEC_62304,
            DAL_A,
            False,
            "--class=C after --asil=B overrides standard and tier");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--standard=all");
         Check_Args (A, R, DO_178C, DAL_C, True, "--standard=all alone");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--asil=B");
         Add (A, "--standard=all");
         Check_Args
           (A,
            R,
            DO_178C,
            DAL_C,
            True,
            "--standard=all after --asil=B keeps tier, enables all");
      end;

      --  --version is a standalone banner flag.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--version");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Version_Requested, "--version sets Version_Requested");
         R.Check (not Cfg.CLI_Error, "--version alone is not an error");
         R.Check (not Cfg.Help_Requested, "--version does not imply --help");
      end;

      --  man subcommand: install mode by default.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "man");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Man_Mode, "man sets Man_Mode");
         R.Check
           (not Cfg.Man_Check, "man without --check installs (no check)");
         R.Check (Cfg.Man_Dir_Len = 0, "man without --dir uses the default");
      end;

      --  man --check --dir=PATH: check mode with an explicit man root.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "man");
         Add (A, "--check");
         Add (A, "--dir=/tmp/x");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Man_Mode, "man --check sets Man_Mode");
         R.Check (Cfg.Man_Check, "--check sets Man_Check");
         R.Check (Cfg.Man_Dir_Len = 6, "--dir=/tmp/x sets Man_Dir_Len");
         R.Check
           (Cfg.Man_Dir (1 .. Cfg.Man_Dir_Len) = "/tmp/x",
            "--dir=/tmp/x stores the man root");
      end;

      --  man --dir PATH (space-separated form) also parses.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "man");
         Add (A, "--dir");
         Add (A, "/tmp/y");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Man_Dir (1 .. Cfg.Man_Dir_Len) = "/tmp/y",
            "--dir PATH space-separated form parses");
      end;

      --  sbom subcommand defaults to ALL standards (joined DO-178C / ISO
      --  26262 / IEC 62304 properties) unless a standard flag narrows it.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "sbom");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.SBOM_Mode, "sbom sets SBOM_Mode");
         R.Check (Cfg.Standard_All, "sbom defaults to all standards");
         R.Check (not Cfg.CLI_Error, "bare sbom is not an error");
      end;

      --  sbom --standard=NAME narrows to that single standard.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "sbom");
         Add (A, "--standard=iso26262");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.SBOM_Mode, "sbom --standard sets SBOM_Mode");
         R.Check
           (Cfg.Standard_Target = ISO_26262,
            "sbom --standard=iso26262 selects ISO 26262");
         R.Check
           (not Cfg.Standard_All,
            "sbom --standard=NAME disables all-standards");
      end;

      --  sbom --asil=LEVEL selects the standard and level together.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "sbom");
         Add (A, "--asil=B");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Standard_Target = ISO_26262,
            "sbom --asil=B selects ISO 26262");
         R.Check
           (not Cfg.Standard_All, "sbom --asil=LEVEL disables all-standards");
         R.Check (Cfg.DAL_Target = DAL_C, "sbom --asil=B maps to DAL-C tier");
      end;

      --  sbom --standard=all stays all-standards (explicit form).
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "sbom");
         Add (A, "--standard=all");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.SBOM_Mode, "sbom --standard=all sets SBOM_Mode");
         R.Check (Cfg.Standard_All, "sbom --standard=all keeps all standards");
      end;

      --  serve defaults to ALL standards (the dashboard renders every
      --  standard's compliance level) unless a standard flag narrows it.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Serve_Mode, "serve sets Serve_Mode");
         R.Check (Cfg.Standard_All, "serve defaults to all standards");
         R.Check (not Cfg.CLI_Error, "bare serve is not an error");
      end;

      --  serve --standard=NAME narrows to that single standard.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Add (A, "--standard=iso26262");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Serve_Mode, "serve --standard sets Serve_Mode");
         R.Check
           (Cfg.Standard_Target = ISO_26262,
            "serve --standard=iso26262 selects ISO 26262");
         R.Check
           (not Cfg.Standard_All,
            "serve --standard=NAME disables all-standards");
      end;

      --  serve --asil=LEVEL selects the standard and level together.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Add (A, "--asil=B");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Standard_Target = ISO_26262,
            "serve --asil=B selects ISO 26262");
         R.Check
           (not Cfg.Standard_All, "serve --asil=LEVEL disables all-standards");
         R.Check (Cfg.DAL_Target = DAL_C, "serve --asil=B maps to DAL-C tier");
      end;

      --  serve --standard=all stays all-standards (explicit form).
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Add (A, "--standard=all");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Serve_Mode, "serve --standard=all sets Serve_Mode");
         R.Check
           (Cfg.Standard_All, "serve --standard=all keeps all standards");
      end;

      --  --theme defaults to system and accepts light/dark/system.
      declare
         Cfg : CLI_Config := (others => <>);
      begin
         R.Check
           (Cfg.Theme = System_Theme,
            "Default Theme is system (follows prefers-color-scheme)");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--theme=dark");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Theme = Dark_Theme, "--theme=dark parses");
         R.Check (not Cfg.CLI_Error, "--theme=dark is not an error");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--theme");
         Add (A, "light");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Theme = Light_Theme, "--theme light space form parses");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--theme=neon");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.CLI_Error, "--theme=neon is an error");
      end;

      --  Contextual help: the help keyword sets Help_Requested, and a
      --  neighboring flag/subcommand is captured as the help topic.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "help");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Help_Requested, "bare help sets Help_Requested");
         R.Check
           (Cfg.Help_Topic_Len = 0, "bare help has no topic (full usage)");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "help");
         Add (A, "--serve");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Help_Requested, "help --serve sets Help_Requested");
         R.Check
           (Cfg.Help_Topic (1 .. Cfg.Help_Topic_Len) = "--serve",
            "help --serve captures the topic");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Add (A, "help");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Help_Requested, "--serve help sets Help_Requested");
         R.Check
           (Cfg.Help_Topic (1 .. Cfg.Help_Topic_Len) = "--serve",
            "--serve help captures the preceding flag");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "help");
         Add (A, "serve");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Help_Topic (1 .. Cfg.Help_Topic_Len) = "serve",
            "help serve captures bare topic word");
      end;

      --  Newly documented flags resolve as help topics too (e.g. the
      --  render/cache/verbosity flags beyond the core standard set).
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "help");
         Add (A, "--emit-svg");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Help_Topic (1 .. Cfg.Help_Topic_Len) = "--emit-svg",
            "help --emit-svg captures the topic");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--verbose");
         Add (A, "help");
         Testing.Parse_Args (A, Cfg);
         R.Check
           (Cfg.Help_Topic (1 .. Cfg.Help_Topic_Len) = "--verbose",
            "--verbose help captures the preceding flag");
      end;

      --  --help still sets Help_Requested (full usage printed by the caller).
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--help");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Help_Requested, "--help sets Help_Requested");
      end;

      --  Unknown flags are rejected loudly instead of silently running an
      --  assessment, and a close flag is suggested ("did you mean").
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--stnadard=all");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.CLI_Error, "unknown option sets CLI_Error");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--comparebse");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.CLI_Error, "unknown option with a typo sets CLI_Error");
      end;

      --  Unknown bare words (typo'd subcommands) are rejected too.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "proove");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.CLI_Error, "unknown bare-word argument sets CLI_Error");
      end;

      --  Unknown_No_Suggest: set (True) when the unknown token has no
      --  close-enough known flag, so the main program prints --help.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--zzz-flag");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.CLI_Error, "unknown --zzz-flag sets CLI_Error");
         R.Check
           (Cfg.Unknown_No_Suggest,
            "unknown flag with no similar match sets Unknown_No_Suggest");
      end;

      --  A near-miss unknown flag (suggestion produced) leaves
      --  Unknown_No_Suggest False so no full usage dump is printed.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Add (A, "--verbos");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.CLI_Error, "--verbos sets CLI_Error");
         R.Check
           (not Cfg.Unknown_No_Suggest,
            "near-miss flag (suggested) leaves Unknown_No_Suggest False");
      end;

      --  Bare-word unknown tokens with no match also set the flag.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "frobnicate");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.CLI_Error, "unknown bare word sets CLI_Error");
         R.Check
           (Cfg.Unknown_No_Suggest,
            "unknown bare word with no match sets Unknown_No_Suggest");
      end;

      --  --force with the man subcommand is the man --force override flag
      --  (not a prove-mode error).
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "man");
         Add (A, "--force");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Man_Mode, "man --force sets Man_Mode");
         R.Check (Cfg.Man_Force, "--force sets Man_Force");
         R.Check (not Cfg.CLI_Error, "man --force is not a CLI error");
      end;

      --  completion subcommand: bare form defaults to bash, an explicit
      --  shell argument is consumed, and --completion=zsh works too.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "completion");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Completion_Mode, "completion sets Completion_Mode");
         R.Check
           (Cfg.Completion_Shell_Len = 0,
            "bare completion defaults the shell (bash)");
         R.Check (not Cfg.CLI_Error, "completion alone is not a CLI error");
      end;
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "completion");
         Add (A, "zsh");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Completion_Mode, "completion zsh sets Completion_Mode");
         R.Check
           (Cfg.Completion_Shell_Len = 3
            and then Cfg.Completion_Shell (1 .. 3) = "zsh",
            "completion zsh picks the zsh shell");
      end;
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--completion=fish");
         Testing.Parse_Args (A, Cfg);
         R.Check (Cfg.Completion_Mode, "--completion=fish sets mode");
         R.Check
           (Cfg.Completion_Shell_Len = 4
            and then Cfg.Completion_Shell (1 .. 4) = "fish",
            "--completion=fish picks fish");
      end;

      --  Completion scripts carry the live flag list (Flag_List is the
      --  same Known_Flags the suggestion walker uses) and one script per
      --  supported shell is generated.
      declare
         B : constant String :=
           Adacovex.Completion.Generate ("bash", Flag_List);
         F : constant String :=
           Adacovex.Completion.Generate ("FISH", Flag_List);
         Z : constant String :=
           Adacovex.Completion.Generate ("zsh", Flag_List);
         P : constant String :=
           Adacovex.Completion.Generate ("pwsh", Flag_List);
         U : constant String :=
           Adacovex.Completion.Generate ("tcsh", Flag_List);
      begin
         R.Check (B'Length > 100, "bash script is non-trivial");
         R.Check
           (Ada.Strings.Fixed.Index (B, "target") > 0
            and then Ada.Strings.Fixed.Index (B, "compgen -W") > 0,
            "bash script embeds live flags");
         R.Check
           (Ada.Strings.Fixed.Index (F, "complete -c adacovex") > 0,
            "fish script uses fish syntax");
         R.Check
           (Ada.Strings.Fixed.Index (Z, "#compdef") > 0,
            "zsh script starts with compdef");
         R.Check
           (Ada.Strings.Fixed.Index (P, "Register-ArgumentCompleter") > 0,
            "pwsh script registers a completer");
         R.Check
           (Ada.Strings.Fixed.Index (U, "_adacovex_complete") > 0,
            "unknown shell falls back to bash");
      end;

      --  --excludes only works with the complexity subcommand; it is
      --  rejected loudly on its own so a silent no-op is impossible.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--excludes=md,rst");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.CLI_Error, "--excludes without complexity is an error");
      end;

      --  --excludes with the complexity subcommand is accepted and stored.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "complexity");
         Add (A, "--excludes=md,rst");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "complexity --excludes is not an error");
         R.Check (Cfg.Complexity_Mode, "complexity subcommand sets mode");
         R.Check
           (Cfg.Excludes_Len > 0
            and then Cfg.Complexity_Excludes (1 .. Cfg.Excludes_Len)
                     = "md,rst",
            "--excludes value is stored");
      end;

      --  --excludes with a space-separated value and no subcommand: error.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--excludes");
         Add (A, "md");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.CLI_Error,
            "--excludes without complexity (space form) is an error");
      end;

      --  --serve-workers only works with --serve; reject a silent no-op.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve-workers=8");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.CLI_Error, "--serve-workers without --serve is an error");
      end;

      --  --serve-workers with --serve is accepted and stored.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Add (A, "--serve-workers=8");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "serve --serve-workers is not an error");
         R.Check (Cfg.Serve_Workers = 8, "--serve-workers=8 is stored");
         R.Check
           (Cfg.Serve_Workers_Set, "--serve-workers marks the field as set");
      end;

      --  --serve-workers rejects a non-positive value.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Add (A, "--serve-workers=0");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.CLI_Error, "--serve-workers=0 is rejected (must be positive)");
      end;

      --  --serve-workers with a non-numeric value is rejected.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--serve");
         Add (A, "--serve-workers=many");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.CLI_Error,
            "--serve-workers=many is rejected (must be an integer)");
      end;

      --  --tz / --timezone validate their value loudly.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "status");
         Add (A, "--tz=Not/AZone");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.CLI_Error, "--tz with an unknown zone is an error");
      end;

      --  --tz accepts a named IANA zone.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "status");
         Add (A, "--tz=Asia/Singapore");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "--tz=Asia/Singapore is accepted");
         R.Check
           (Cfg.Time_Zone_Len > 0
            and then Cfg.Time_Zone (1 .. Cfg.Time_Zone_Len) = "Asia/Singapore",
            "--tz value is stored");
      end;

      --  --tz accepts a fixed UTC/GMT offset in every supported form.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "status");
         Add (A, "--timezone=UTC+08:30");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "--timezone=UTC+08:30 is accepted");
      end;

      --  --timezone is the long form of --tz and is accepted.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "status");
         Add (A, "--timezone=GMT+8");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "--timezone=GMT+8 is accepted");
      end;

      --  --skip-path only works with the complexity subcommand.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--skip-path=docs/api-docs");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.CLI_Error, "--skip-path without complexity is an error");
      end;

      --  complexity --skip-path is accepted and stored (repeatable).
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "complexity");
         Add (A, "--skip-path=docs/api-docs");
         Add (A, "--skip-path");
         Add (A, "generated");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "complexity --skip-path is not an error");
         R.Check
           (Cfg.Skip_Paths_Len > 0
            and then Cfg.Complexity_Skip_Paths (1 .. Cfg.Skip_Paths_Len)
                     = "docs/api-docs,generated",
            "--skip-path values accumulate comma-separated");
      end;

      --  --args only works with the prove subcommand.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--args=--prover=cvc5");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.CLI_Error, "--args without prove is an error");
      end;

      --  prove --args is accepted and accumulates across repeats.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "--args=--prover=cvc5 --timeout=5");
         Add (A, "--args");
         Add (A, "--report=all");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "prove --args is not an error");
         R.Check
           (Ada.Strings.Unbounded.To_String (Cfg.Prove_Args)
            = "--prover=cvc5 --timeout=5 --report=all",
            "prove --args accumulates space-joined raw gnatprove flags");
      end;

      --  --target=~/... expands the tilde to HOME before the cwd-join, so
      --  the resolved target starts with HOME (never "$CWD/~/...").
      declare
         Cfg  : CLI_Config;
         A    : Testing.Arg_Vectors.Vector;
         Home : constant String :=
           (if Ada.Environment_Variables.Exists ("HOME")
            then Ada.Environment_Variables.Value ("HOME")
            else "/tmp");
      begin
         Add (A, "--target=~/some-project");
         Cfg := Testing.Parse_All (A);
         declare
            Resolved : constant String :=
              Cfg.Target_Path (1 .. Cfg.Target_Len);
         begin
            R.Check
              (Cfg.Target_Len >= Home'Length
               and then Cfg.Target_Path (1 .. Home'Length) = Home,
               "--target=~/some-project expands to HOME/some-project");
            R.Check
              (Resolved'Length >= 13
               and then Resolved (Resolved'Last - 12 .. Resolved'Last)
                        = "/some-project",
               "tilde-expanded target keeps the path tail");
         end;
      end;

      --  --target=~ alone resolves to the home directory itself.
      declare
         Cfg  : CLI_Config;
         A    : Testing.Arg_Vectors.Vector;
         Home : constant String :=
           (if Ada.Environment_Variables.Exists ("HOME")
            then Ada.Environment_Variables.Value ("HOME")
            else "/tmp");
      begin
         Add (A, "--target=~");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.Target_Path (1 .. Cfg.Target_Len) = Home,
            "--target=~ resolves to the home directory");
      end;

      --  A ~name form (another user's home) is left untouched: only the
      --  shell can resolve it, and adacovex must not mangle it into
      --  "$HOME/name".  It still gets the cwd-join (unchanged behaviour).
      declare
         Cfg  : CLI_Config;
         A    : Testing.Arg_Vectors.Vector;
         Home : constant String :=
           (if Ada.Environment_Variables.Exists ("HOME")
            then Ada.Environment_Variables.Value ("HOME")
            else "/tmp");
      begin
         Add (A, "--target=~other/code");
         Cfg := Testing.Parse_All (A);
         declare
            Resolved : constant String :=
              Cfg.Target_Path (1 .. Cfg.Target_Len);
         begin
            --  The untouched tilde path still gets the cwd-join, so the
            --  resolved value ends with the literal "~other/code" tail
            --  (a tilde at a NON-leading position is an ordinary
            --  character) instead of HOME's prefix + "/code".
            R.Check
              (Resolved'Length >= 11
               and then Resolved (Resolved'Last - 10 .. Resolved'Last)
                        = "~other/code",
               "--target=~other/code is not home-expanded");
         end;
      end;
      --  Short-flag and alias shorthands resolve to their canonical flags:
      --  -t / -t=PATH for --target, -m for --manifest.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-t");
         Add (A, ".");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "-t . parses");
         R.Check (Cfg.Target_Len > 0, "-t sets the target path");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-t=.");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "-t=. parses");
         R.Check (Cfg.Target_Len > 0, "-t=. sets the target path");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-m=my.toml");
         Cfg := Testing.Parse_All (A);
         R.Check
           (not Cfg.CLI_Error
            and then Cfg.Manifest_Len > 0
            and then Cfg.Manifest_Path (1 .. Cfg.Manifest_Len) = "my.toml",
            "-m=my.toml sets the manifest path");
      end;

      --  Bare serve / cache / relaxed words and the -s / -c shorts.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "serve");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.Serve_Mode, "bare serve starts serve mode");
         R.Check (not Cfg.CLI_Error, "bare serve is not an error");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-s");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.Serve_Mode, "-s starts serve mode");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-c");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.Cache_Enabled, "-c keeps the cache on");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "relaxed");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.Strict_Mode, "bare relaxed disables strict mode");
      end;

      --  --strict re-enables strict mode after a bare relaxed.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "relaxed");
         Add (A, "--strict");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.Strict_Mode, "--strict re-enables strict mode");
      end;

      --  -p / -pN set the port (with --serve).
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "serve");
         Add (A, "-p");
         Add (A, "9090");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "serve -p 9090 parses");
         R.Check (Cfg.Port = 9090, "-p N sets the port");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "serve");
         Add (A, "-p9091");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.Port = 9091, "glued -pN sets the port");
      end;

      --  --workers is an alias of --serve-workers.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "serve");
         Add (A, "--workers=6");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "serve --workers=6 parses");
         R.Check (Cfg.Serve_Workers = 6, "--workers sets the worker count");
         R.Check (Cfg.Serve_Workers_Set, "--workers marks the field as set");
      end;

      --  -l is the GNATprove proof level only.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "-l");
         Add (A, "2");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "prove -l 2 parses");
         R.Check (Cfg.Prove_Level = 2, "-l sets the proof level");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-l3");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.CLI_Error,
            "glued -l3 outside prove mode is a prove-option error");
      end;

      --  -r is the require-proof gate shorthand.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-r=100");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "-r=100 parses");
         R.Check
           (Cfg.Require_Proof_Set and then Cfg.Require_Proof = 100,
            "-r sets the require-proof gate");
      end;

      --  --spark / --docstrs / --tests alias the require-* gates.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--spark=Gold");
         Add (A, "--docstrs=90");
         Add (A, "--tests=500");
         Cfg := Testing.Parse_All (A);
         R.Check (not Cfg.CLI_Error, "require-gate aliases parse");
         R.Check
           (Cfg.Require_SPARK_Set and then Cfg.Require_SPARK = Gold,
            "--spark sets the SPARK gate");
         R.Check
           (Cfg.Require_Docstrings_Set and then Cfg.Require_Docstrings = 90,
            "--docstrs sets the docstring gate");
         R.Check
           (Cfg.Require_Tests_Set and then Cfg.Require_Tests = 500,
            "--tests sets the test gate");
      end;

      --  --diff / --base / -b are compare-base aliases; -d is a
      --  coverage-delta alias.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--diff=main");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.Compare_Base_Len > 0
            and then Cfg.Compare_Base (1 .. Cfg.Compare_Base_Len) = "main",
            "--diff sets the compare-base ref");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--base");
         Add (A, "v1.0.0");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.Compare_Base_Len > 0
            and then Cfg.Compare_Base (1 .. Cfg.Compare_Base_Len) = "v1.0.0",
            "--base REF sets the compare-base ref");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-d=main");
         Cfg := Testing.Parse_All (A);
         R.Check
           (Cfg.Coverage_Delta_Len > 0
            and then Cfg.Coverage_Delta (1 .. Cfg.Coverage_Delta_Len) = "main",
            "-d sets the coverage-delta ref");
      end;

      --  --svg-path / --emit-md / --no-md.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--svg-path=out/badges");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.Emit_SVG, "--svg-path enables SVG output");
         R.Check
           (Cfg.SVG_Path_Len > 0
            and then Cfg.SVG_Path (1 .. Cfg.SVG_Path_Len) = "out/badges",
            "--svg-path sets the badge directory");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--emit-md");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.Emit_Markdown, "bare --emit-md enables Markdown output");
         R.Check
           (Cfg.MD_Path_Len > 4
            and then Cfg.MD_Path (Cfg.MD_Path_Len - 4 .. Cfg.MD_Path_Len)
                     = "/docs",
            "bare --emit-md uses the default <target>/docs directory");
      end;

      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--emit-md=out/md");
         Add (A, "--no-md");
         Cfg := Testing.Parse_All (A);
         R.Check
           (not Cfg.Emit_Markdown, "--no-md overrides --emit-md with a path");
         R.Check (Cfg.MD_Path_Len = 0, "--no-md clears the Markdown path");
      end;

      --  --standard=NAME also accepts a combined standard + tier token.
      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--standard=dal-a");
         Check_Args (A, R, DO_178C, DAL_A, False, "--standard=dal-a");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--standard=asil-b");
         Check_Args (A, R, ISO_26262, DAL_C, False, "--standard=asil-b");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--standard=class-c");
         Check_Args (A, R, IEC_62304, DAL_A, False, "--standard=class-c");
      end;

      declare
         A : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--standard=ASIL-QM");
         Check_Args (A, R, ISO_26262, DAL_E, False, "--standard=ASIL-QM");
      end;

      --  An unknown --standard value is rejected loudly.
      declare
         Cfg : CLI_Config;
         A   : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--standard=bogus");
         Cfg := Testing.Parse_All (A);
         R.Check (Cfg.CLI_Error, "--standard with an unknown value errors");
      end;

      --  Shorthand / alias equivalence: every alias produces exactly the
      --  same parsed option state as its canonical long spelling.
      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-t=.");
         Add (C, "--target=.");
         Check_Equivalent (A, C, R, "-t == --target");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-m=x.toml");
         Add (C, "--manifest=x.toml");
         Check_Equivalent (A, C, R, "-m == --manifest");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "serve");
         Add (C, "--serve");
         Check_Equivalent (A, C, R, "bare serve == --serve");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-s");
         Add (C, "--serve");
         Check_Equivalent (A, C, R, "-s == --serve");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-c");
         Add (C, "--cache");
         Check_Equivalent (A, C, R, "-c == --cache");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "relaxed");
         Add (C, "--relaxed");
         Check_Equivalent (A, C, R, "bare relaxed == --relaxed");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--strict");
         Check_Equivalent (A, C, R, "--strict == the strict default");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "serve");
         Add (A, "-p");
         Add (A, "9090");
         Add (C, "serve");
         Add (C, "--port=9090");
         Check_Equivalent (A, C, R, "-p N == --port=N");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "serve");
         Add (A, "-p9091");
         Add (C, "serve");
         Add (C, "--port=9091");
         Check_Equivalent (A, C, R, "glued -pN == --port=N");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "serve");
         Add (A, "--workers=6");
         Add (C, "serve");
         Add (C, "--serve-workers=6");
         Check_Equivalent (A, C, R, "--workers == --serve-workers");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "-l");
         Add (A, "2");
         Add (C, "prove");
         Add (C, "--level=2");
         Check_Equivalent (A, C, R, "-l N == --level=N");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "-l3");
         Add (C, "prove");
         Add (C, "--level=3");
         Check_Equivalent (A, C, R, "glued -lN == --level=N");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "-j");
         Add (A, "4");
         Add (C, "prove");
         Add (C, "--jobs=4");
         Check_Equivalent (A, C, R, "-j N == --jobs=N");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "prove");
         Add (A, "-j4");
         Add (C, "prove");
         Add (C, "--jobs=4");
         Check_Equivalent (A, C, R, "glued -jN == --jobs=N");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-r");
         Add (A, "100");
         Add (C, "--require-proof=100");
         Check_Equivalent (A, C, R, "-r N == --require-proof=N");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-r=100");
         Add (C, "--require-proof=100");
         Check_Equivalent (A, C, R, "-r=N == --require-proof=N");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--spark=Gold");
         Add (C, "--require-spark=Gold");
         Check_Equivalent (A, C, R, "--spark == --require-spark");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--docstrs=90");
         Add (C, "--require-docstrings=90");
         Check_Equivalent (A, C, R, "--docstrs == --require-docstrings");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--tests=500");
         Add (C, "--require-tests=500");
         Check_Equivalent (A, C, R, "--tests == --require-tests");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--diff=main");
         Add (C, "--compare-base=main");
         Check_Equivalent (A, C, R, "--diff == --compare-base");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--base");
         Add (A, "main");
         Add (C, "--compare-base=main");
         Check_Equivalent (A, C, R, "--base REF == --compare-base=REF");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-b");
         Add (A, "main");
         Add (C, "--compare-base=main");
         Check_Equivalent (A, C, R, "-b REF == --compare-base=REF");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "-d=main");
         Add (C, "--coverage-delta=main");
         Check_Equivalent (A, C, R, "-d == --coverage-delta");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--delta=main");
         Add (C, "--coverage-delta=main");
         Check_Equivalent (A, C, R, "--delta == --coverage-delta");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--svg-path=out/b");
         Add (C, "--emit-svg=out/b");
         Check_Equivalent (A, C, R, "--svg-path == --emit-svg");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--md-path=out/m");
         Add (C, "--emit-markdown=out/m");
         Check_Equivalent (A, C, R, "--md-path == --emit-markdown");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--emit-md=out/m");
         Add (C, "--emit-markdown=out/m");
         Check_Equivalent (A, C, R, "--emit-md == --emit-markdown");
      end;

      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--emit-md");
         Add (C, "--emit-markdown");
         Check_Equivalent (A, C, R, "bare --emit-md == bare --emit-markdown");
      end;

      --  --no-md wins over an emit form, whether or not a path is present.
      declare
         A, C : Testing.Arg_Vectors.Vector;
      begin
         Add (A, "--emit-md=out/m");
         Add (A, "--no-md");
         Add (C, "--no-md");
         Check_Equivalent (A, C, R, "--no-md overrides --emit-md");
      end;

      --  Every shorthand / alias spelling is advertised to the shell
      --  completion scripts and the "did you mean" walker, which share the
      --  Flag_List table.
      declare
         Names  : constant String :=
           "workers svg-path md-path emit-md no-md strict diff base delta "
           & "spark docstrs tests";
         Padded : constant String := " " & Flag_List & " ";
         Start  : Natural := Names'First;
         Fin    : Natural;
      begin
         while Start <= Names'Last loop
            Fin := Start;
            while Fin <= Names'Last and then Names (Fin) /= ' ' loop
               Fin := Fin + 1;
            end loop;
            R.Check
              (Ada.Strings.Fixed.Index
                 (Padded, " " & Names (Start .. Fin - 1) & " ")
               > 0,
               Names (Start .. Fin - 1) & " is advertised in Flag_List");
            exit when Fin > Names'Last;
            Start := Fin + 1;
         end loop;
      end;
   end Run;

end Adacovex_Config_Tests;
