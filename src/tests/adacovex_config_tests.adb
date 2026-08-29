with Adacovex.Types;  use Adacovex.Types;
with Adacovex.Config; use Adacovex.Config;
with Adacovex.Completion;
with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;

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
   end Run;

end Adacovex_Config_Tests;
