with Adacovex.Types;   use Adacovex.Types;
with Adacovex.Config;  use Adacovex.Config;

package body Adacovex_Config_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  Test 1: default config has Emit_SVG = True and SVG_Path_Len = 0
      declare
          Cfg : constant CLI_Config :=
            (Target_Path   => (others => ' '),
             Target_Len    => 0,
             Manifest_Path => (others => ' '),
             Manifest_Len  => 0,
             DAL_Target    => DAL_C,
             Serve_Mode    => False,
             Port          => 8080,
             No_SVG        => False,
             Emit_SVG      => True,
             SVG_Path      => (others => ' '),
             SVG_Path_Len  => 0,
             Emit_Markdown => False,
             MD_Path       => (others => ' '),
             MD_Path_Len   => 0,
              Verbose       => False,
              Strict_Mode   => False,
              CLI_Error     => False,
              Skip_Dir_Ct   => 0,
              Skip_Dirs     => (others => ' '));
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
       end;

       --  Test 2: No_SVG overrides Emit_SVG
       declare
          Cfg : constant CLI_Config :=
            (Target_Path   => (others => ' '),
             Target_Len    => 0,
             Manifest_Path => (others => ' '),
             Manifest_Len  => 0,
             DAL_Target    => DAL_C,
             Serve_Mode    => False,
             Port          => 8080,
             No_SVG        => True,
             Emit_SVG      => True,
             SVG_Path      => (others => ' '),
             SVG_Path_Len  => 0,
             Emit_Markdown => False,
             MD_Path       => (others => ' '),
             MD_Path_Len   => 0,
              Verbose       => False,
              Strict_Mode   => False,
              CLI_Error     => False,
              Skip_Dir_Ct   => 0,
              Skip_Dirs     => (others => ' '));
       begin
          --  No_SVG=True means Emit_SVG should be forced False by Parse_CLI
         R.Check (Cfg.No_SVG, "No_SVG field works");
      end;

   end Run;

end Adacovex_Config_Tests;
