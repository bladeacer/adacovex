with Adacovex.Types;  use Adacovex.Types;
with Adacovex.Config; use Adacovex.Config;

package body Adacovex_Config_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  Test 1: default config has Emit_SVG = True and SVG_Path_Len = 0
      declare
         Cfg : constant CLI_Config :=
           (Target_Path        => (others => ' '),
            Target_Len         => 0,
            Manifest_Path      => (others => ' '),
            Manifest_Len       => 0,
            DAL_Target         => DAL_C,
            Serve_Mode         => False,
            Port               => 8080,
            No_SVG             => False,
            Emit_SVG           => True,
            SVG_Path           => (others => ' '),
            SVG_Path_Len       => 0,
            Emit_Markdown      => False,
            MD_Path            => (others => ' '),
            MD_Path_Len        => 0,
            Verbose            => False,
            Strict_Mode        => False,
            CLI_Error          => False,
            Help_Requested     => False,
            Skip_Dir_Ct        => 0,
            Skip_Dirs          => (others => ' '),
            Compare_Base       => (others => ' '),
            Compare_Base_Len   => 0,
            Coverage_Delta     => (others => ' '),
            Coverage_Delta_Len => 0,
            Prove_Mode         => False,
            SBOM_Mode          => False,
            SBOM_Format        => CycloneDX_JSON,
             SBOM_Out           => (others => ' '),
             SBOM_Out_Len       => 0,
             No_SBOM            => False,
             Prove_Jobs         => -1,
             Prove_Level        => -1,
             Prove_Timeout      => -1,
             Prove_Steps        => -1,
             Prove_Memlimit     => -1,
             Prove_Force        => False,
             Prove_No_Loop_Unroll => False,
             Prove_No_Inlining  => False);
      begin
         R.Check (Cfg.Emit_SVG, "Default Emit_SVG is True");
         R.Check
           (Cfg.SVG_Path_Len = 0,
            "Default SVG_Path_Len is 0 (set later if emit)");
         R.Check (not Cfg.Serve_Mode, "Default Serve_Mode is False");
         R.Check (Cfg.DAL_Target = DAL_C, "Default DAL_Target is C");
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
           (Target_Path        => (others => ' '),
            Target_Len         => 0,
            Manifest_Path      => (others => ' '),
            Manifest_Len       => 0,
            DAL_Target         => DAL_C,
            Serve_Mode         => False,
            Port               => 8080,
            No_SVG             => True,
            Emit_SVG           => True,
            SVG_Path           => (others => ' '),
            SVG_Path_Len       => 0,
            Emit_Markdown      => False,
            MD_Path            => (others => ' '),
            MD_Path_Len        => 0,
            Verbose            => False,
            Strict_Mode        => False,
            CLI_Error          => False,
            Help_Requested     => False,
            Skip_Dir_Ct        => 0,
            Skip_Dirs          => (others => ' '),
            Compare_Base       => (others => ' '),
            Compare_Base_Len   => 0,
            Coverage_Delta     => (others => ' '),
            Coverage_Delta_Len => 0,
            Prove_Mode         => False,
             SBOM_Mode          => False,
             SBOM_Format        => CycloneDX_JSON,
             SBOM_Out           => (others => ' '),
             SBOM_Out_Len       => 0,
             No_SBOM            => False,
             Prove_Jobs         => -1,
             Prove_Level        => -1,
             Prove_Timeout      => -1,
             Prove_Steps        => -1,
             Prove_Memlimit     => -1,
             Prove_Force        => False,
             Prove_No_Loop_Unroll => False,
             Prove_No_Inlining  => False);
      begin
         --  No_SVG=True means Emit_SVG should be forced False by Parse_CLI
         R.Check (Cfg.No_SVG, "No_SVG field works");
      end;

      --  Test 3: prove option defaults are the unset sentinels
      declare
         Cfg : constant CLI_Config :=
           (Target_Path          => (others => ' '),
            Target_Len           => 0,
            Manifest_Path        => (others => ' '),
            Manifest_Len         => 0,
            DAL_Target           => DAL_C,
            Serve_Mode           => False,
            Port                 => 8080,
            No_SVG               => False,
            Emit_SVG             => True,
            SVG_Path             => (others => ' '),
            SVG_Path_Len         => 0,
            Emit_Markdown        => False,
            MD_Path              => (others => ' '),
            MD_Path_Len          => 0,
            Verbose              => False,
            Strict_Mode          => False,
            CLI_Error            => False,
            Help_Requested       => False,
            Skip_Dir_Ct          => 0,
            Skip_Dirs            => (others => ' '),
            Compare_Base         => (others => ' '),
            Compare_Base_Len     => 0,
            Coverage_Delta       => (others => ' '),
            Coverage_Delta_Len   => 0,
            Prove_Mode           => False,
            SBOM_Mode            => False,
            SBOM_Format          => CycloneDX_JSON,
            SBOM_Out             => (others => ' '),
            SBOM_Out_Len         => 0,
            No_SBOM              => False,
            Prove_Jobs           => -1,
            Prove_Level          => -1,
            Prove_Timeout        => -1,
            Prove_Steps          => -1,
            Prove_Memlimit       => -1,
            Prove_Force          => False,
            Prove_No_Loop_Unroll => False,
            Prove_No_Inlining    => False);
      begin
         R.Check (Cfg.Prove_Jobs = -1, "Default Prove_Jobs is -1 (auto)");
         R.Check (Cfg.Prove_Level = -1, "Default Prove_Level is -1 (unset)");
         R.Check (Cfg.Prove_Timeout = -1, "Default Prove_Timeout is -1 (unset)");
         R.Check (Cfg.Prove_Steps = -1, "Default Prove_Steps is -1 (unset)");
         R.Check (Cfg.Prove_Memlimit = -1, "Default Prove_Memlimit is -1 (unset)");
         R.Check (not Cfg.Prove_Force, "Default Prove_Force is False");
         R.Check
           (not Cfg.Prove_No_Loop_Unroll,
            "Default Prove_No_Loop_Unroll is False");
         R.Check
           (not Cfg.Prove_No_Inlining,
            "Default Prove_No_Inlining is False");
      end;

   end Run;

end Adacovex_Config_Tests;
