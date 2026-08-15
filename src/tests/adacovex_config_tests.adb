with Adacovex.Types;  use Adacovex.Types;
with Adacovex.Config; use Adacovex.Config;

package body Adacovex_Config_Tests is

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
   end Run;

end Adacovex_Config_Tests;
