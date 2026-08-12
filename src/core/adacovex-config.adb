with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

package body Adacovex.Config is

   use type Types.SBOM_Format_Kind;

   function Has_Prefix (S : String; Prefix : String) return Boolean is
   begin
      if S'Length < Prefix'Length then
         return False;
      end if;
      for I in Prefix'Range loop
         if S (S'First + (I - Prefix'First)) /= Prefix (I) then
            return False;
         end if;
      end loop;
      return True;
   end Has_Prefix;

   procedure Set_String (Dst : out String; Dst_Len : out Natural; Src : String)
   is
   begin
      --  Clamp to the fixed destination buffer so an overlong CLI argument
      --  never raises Constraint_Error; Dst_Len reflects the clamped length.
      Dst_Len := Natural'Min (Src'Length, Dst'Length);
      for J in Src'First .. Src'First + Dst_Len - 1 loop
         Dst (J - Src'First + 1) := Src (J);
      end loop;
   end Set_String;

   procedure Add_Skip_Dir (Cfg : in out CLI_Config; Name : String) is
   begin
      if Cfg.Skip_Dir_Ct > 0 then
         if Cfg.Skip_Dir_Ct < Types.Max_Filename then
            Cfg.Skip_Dir_Ct := Cfg.Skip_Dir_Ct + 1;
            Cfg.Skip_Dirs (Cfg.Skip_Dir_Ct) := ',';
         end if;
      end if;
      if Cfg.Skip_Dir_Ct < Types.Max_Filename then
         for I in Name'Range loop
            exit when Cfg.Skip_Dir_Ct >= Types.Max_Filename;
            Cfg.Skip_Dir_Ct := Cfg.Skip_Dir_Ct + 1;
            Cfg.Skip_Dirs (Cfg.Skip_Dir_Ct) := Name (I);
         end loop;
      end if;
   end Add_Skip_Dir;

   procedure Set_Error (Cfg : in out CLI_Config; Msg : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "Error: " & Msg);
      Cfg.CLI_Error := True;
   end Set_Error;

   function Is_Valid_DAL (S : String) return Boolean is
   begin
      return S'Length = 1 and then (S (S'First) in 'A' .. 'E' | 'a' .. 'e');
   end Is_Valid_DAL;

   --  Parse an integer prove option into a config field, validating its
   --  range.  On a bad value or out-of-range value the config is flagged as
   --  an error and Field is left untouched.
   procedure Set_Prove_Int
     (Cfg   : in out CLI_Config;
      Field : out Integer;
      Val   : String;
      Min   : Integer;
      Max   : Integer;
      Flag  : String) is
   begin
      begin
         Field := Integer'Value (Val);
      exception
         when Constraint_Error =>
            Set_Error (Cfg, Flag & " must be an integer (got: " & Val & ")");
            return;
      end;
      if Field < Min or Field > Max then
         Set_Error
           (Cfg,
            Flag
            & " must be in"
            & Integer'Image (Min)
            & ".."
            & Integer'Image (Max)
            & " (got: "
            & Val
            & ")");
      end if;
   end Set_Prove_Int;

   function Parse_CLI return CLI_Config is
      Cfg   : CLI_Config;
      Count : constant Natural := Ada.Command_Line.Argument_Count;
      I     : Positive := 1;
   begin
      Cfg.Target_Len := 0;
      Cfg.Manifest_Len := 0;
      Cfg.SVG_Path_Len := 0;
      Cfg.MD_Path_Len := 0;
      Cfg.Skip_Dir_Ct := 0;
      Cfg.Compare_Base_Len := 0;
      Cfg.Coverage_Delta_Len := 0;
      Cfg.SBOM_Out_Len := 0;

      while I <= Count loop
         declare
            A : constant String := Ada.Command_Line.Argument (I);
         begin
            if A = "--target" then
               I := I + 1;
               if I <= Count then
                  Set_String
                    (Cfg.Target_Path,
                     Cfg.Target_Len,
                     Ada.Command_Line.Argument (I));
               else
                  Set_Error (Cfg, "--target requires a path argument");
               end if;
            elsif Has_Prefix (A, "--target=") then
               Set_String
                 (Cfg.Target_Path, Cfg.Target_Len, A (A'First + 9 .. A'Last));
            elsif A = "--manifest" then
               I := I + 1;
               if I <= Count then
                  Set_String
                    (Cfg.Manifest_Path,
                     Cfg.Manifest_Len,
                     Ada.Command_Line.Argument (I));
               else
                  Set_Error (Cfg, "--manifest requires a path argument");
               end if;
            elsif Has_Prefix (A, "--manifest=") then
               Set_String
                 (Cfg.Manifest_Path,
                  Cfg.Manifest_Len,
                  A (A'First + 11 .. A'Last));
            elsif A = "--dal" then
               I := I + 1;
               if I <= Count then
                  declare
                     Val : constant String := Ada.Command_Line.Argument (I);
                  begin
                     if Is_Valid_DAL (Val) then
                        Cfg.DAL_Target := Types.To_DAL (Val);
                     else
                        Set_Error
                          (Cfg,
                           "--dal must be A, B, C, D, or E (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               else
                  Set_Error (Cfg, "--dal requires a level argument (A-E)");
               end if;
            elsif Has_Prefix (A, "--dal=") then
               declare
                  Val : constant String := A (A'First + 6 .. A'Last);
               begin
                  if Is_Valid_DAL (Val) then
                     Cfg.DAL_Target := Types.To_DAL (Val);
                  else
                     Set_Error
                       (Cfg,
                        "--dal must be A, B, C, D, or E (got: " & Val & ")");
                  end if;
               end;
            elsif A = "--serve" then
               Cfg.Serve_Mode := True;
            elsif A = "--port" then
               I := I + 1;
               if I <= Count then
                  begin
                     Cfg.Port :=
                       Positive'Value (Ada.Command_Line.Argument (I));
                  exception
                     when Constraint_Error =>
                        Set_Error
                          (Cfg,
                           "--port must be a positive integer (got: "
                           & Ada.Command_Line.Argument (I)
                           & ")");
                  end;
               else
                  Set_Error (Cfg, "--port requires an integer argument");
               end if;
            elsif Has_Prefix (A, "--port=") then
               begin
                  Cfg.Port := Positive'Value (A (A'First + 7 .. A'Last));
               exception
                  when Constraint_Error =>
                     Set_Error
                       (Cfg,
                        "--port must be a positive integer (got: "
                        & A (A'First + 7 .. A'Last)
                        & ")");
               end;
            elsif A = "--emit-svg" then
               I := I + 1;
               if I <= Count then
                  Cfg.Emit_SVG := True;
                  Set_String
                    (Cfg.SVG_Path,
                     Cfg.SVG_Path_Len,
                     Ada.Command_Line.Argument (I));
               else
                  Set_Error (Cfg, "--emit-svg requires a directory argument");
               end if;
            elsif Has_Prefix (A, "--emit-svg=") then
               Cfg.Emit_SVG := True;
               Set_String
                 (Cfg.SVG_Path, Cfg.SVG_Path_Len, A (A'First + 11 .. A'Last));
            elsif A = "--emit-markdown" then
               I := I + 1;
               if I <= Count then
                  Cfg.Emit_Markdown := True;
                  Set_String
                    (Cfg.MD_Path,
                     Cfg.MD_Path_Len,
                     Ada.Command_Line.Argument (I));
               else
                  Set_Error
                    (Cfg, "--emit-markdown requires a directory argument");
               end if;
            elsif Has_Prefix (A, "--emit-markdown=") then
               Cfg.Emit_Markdown := True;
               Set_String
                 (Cfg.MD_Path, Cfg.MD_Path_Len, A (A'First + 16 .. A'Last));
            elsif A = "--no-svg" then
               Cfg.No_SVG := True;
            elsif A = "--verbose" then
               Cfg.Verbose := True;
            elsif A = "--relaxed" then
               Cfg.Strict_Mode := False;
            elsif A = "--skip-dir" then
               I := I + 1;
               if I <= Count then
                  Add_Skip_Dir (Cfg, Ada.Command_Line.Argument (I));
               else
                  Set_Error (Cfg, "--skip-dir requires a directory name");
               end if;
            elsif Has_Prefix (A, "--skip-dir=") then
               Add_Skip_Dir (Cfg, A (A'First + 10 .. A'Last));
            elsif A = "--compare-base" then
               I := I + 1;
               if I <= Count then
                  Set_String
                    (Cfg.Compare_Base,
                     Cfg.Compare_Base_Len,
                     Ada.Command_Line.Argument (I));
               else
                  Set_Error
                    (Cfg, "--compare-base requires a branch/commit argument");
               end if;
            elsif Has_Prefix (A, "--compare-base=") then
               Set_String
                 (Cfg.Compare_Base,
                  Cfg.Compare_Base_Len,
                  A (A'First + 15 .. A'Last));
            elsif A = "--coverage-delta" then
               I := I + 1;
               if I <= Count then
                  Set_String
                    (Cfg.Coverage_Delta,
                     Cfg.Coverage_Delta_Len,
                     Ada.Command_Line.Argument (I));
               else
                  Set_Error
                    (Cfg,
                     "--coverage-delta requires a branch/commit argument");
               end if;
            elsif Has_Prefix (A, "--coverage-delta=") then
               Set_String
                 (Cfg.Coverage_Delta,
                  Cfg.Coverage_Delta_Len,
                  A (A'First + 17 .. A'Last));
            elsif A = "sbom" then
               Cfg.SBOM_Mode := True;
            elsif A = "prove" then
               Cfg.Prove_Mode := True;
            elsif A = "--no-sbom" then
               Cfg.No_SBOM := True;
            elsif A = "--sbom-format" then
               I := I + 1;
               if I <= Count then
                  declare
                     Val : constant String := Ada.Command_Line.Argument (I);
                  begin
                     if Val = "cyclonedx-json" then
                        Cfg.SBOM_Format := Types.CycloneDX_JSON;
                     elsif Val = "spdx-json" then
                        Cfg.SBOM_Format := Types.SPDX_JSON;
                     elsif Val = "md" then
                        Cfg.SBOM_Format := Types.Markdown;
                     else
                        Set_Error
                          (Cfg,
                           "--sbom-format must be cyclonedx-json, spdx-json, "
                           & "or md (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               else
                  Set_Error (Cfg, "--sbom-format requires a format argument");
               end if;
            elsif Has_Prefix (A, "--sbom-format=") then
               declare
                  Val : constant String := A (A'First + 14 .. A'Last);
               begin
                  if Val = "cyclonedx-json" then
                     Cfg.SBOM_Format := Types.CycloneDX_JSON;
                  elsif Val = "spdx-json" then
                     Cfg.SBOM_Format := Types.SPDX_JSON;
                  elsif Val = "md" then
                     Cfg.SBOM_Format := Types.Markdown;
                  else
                     Set_Error
                       (Cfg,
                        "--sbom-format must be cyclonedx-json, spdx-json, "
                        & "or md (got: "
                        & Val
                        & ")");
                  end if;
               end;
            elsif A = "--format" then
               I := I + 1;
               if I <= Count then
                  declare
                     Val : constant String := Ada.Command_Line.Argument (I);
                  begin
                     if Val = "cyclonedx-json" then
                        Cfg.SBOM_Format := Types.CycloneDX_JSON;
                     elsif Val = "spdx-json" then
                        Cfg.SBOM_Format := Types.SPDX_JSON;
                     elsif Val = "md" then
                        Cfg.SBOM_Format := Types.Markdown;
                     else
                        Set_Error
                          (Cfg,
                           "--format must be cyclonedx-json, spdx-json, or "
                           & "md (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               else
                  Set_Error (Cfg, "--format requires a format argument");
               end if;
            elsif Has_Prefix (A, "--format=") then
               declare
                  Val : constant String := A (A'First + 9 .. A'Last);
               begin
                  if Val = "cyclonedx-json" then
                     Cfg.SBOM_Format := Types.CycloneDX_JSON;
                  elsif Val = "spdx-json" then
                     Cfg.SBOM_Format := Types.SPDX_JSON;
                  elsif Val = "md" then
                     Cfg.SBOM_Format := Types.Markdown;
                  else
                     Set_Error
                       (Cfg,
                        "--format must be cyclonedx-json, spdx-json, or "
                        & "md (got: "
                        & Val
                        & ")");
                  end if;
               end;
            elsif A = "--out" then
               I := I + 1;
               if I <= Count then
                  Set_String
                    (Cfg.SBOM_Out,
                     Cfg.SBOM_Out_Len,
                     Ada.Command_Line.Argument (I));
               else
                  Set_Error (Cfg, "--out requires a path argument");
               end if;
            elsif Has_Prefix (A, "--out=") then
               Set_String
                 (Cfg.SBOM_Out, Cfg.SBOM_Out_Len, A (A'First + 6 .. A'Last));
            elsif A = "--jobs" or A = "-j" then
               I := I + 1;
               if I <= Count then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Jobs,
                     Ada.Command_Line.Argument (I),
                     -1,
                     1024,
                     "--jobs");
               else
                  Set_Error (Cfg, "--jobs requires an integer argument");
               end if;
            elsif Has_Prefix (A, "--jobs=") then
               Set_Prove_Int
                 (Cfg,
                  Cfg.Prove_Jobs,
                  A (A'First + 7 .. A'Last),
                  -1,
                  1024,
                  "--jobs");
            elsif Has_Prefix (A, "-j") and then A'Length > 2 then
               --  Combined short form: -j12
               Set_Prove_Int
                 (Cfg,
                  Cfg.Prove_Jobs,
                  A (A'First + 2 .. A'Last),
                  -1,
                  1024,
                  "-j");
            elsif A = "--level" then
               I := I + 1;
               if I <= Count then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Level,
                     Ada.Command_Line.Argument (I),
                     0,
                     4,
                     "--level");
               else
                  Set_Error (Cfg, "--level requires an integer argument");
               end if;
            elsif Has_Prefix (A, "--level=") then
               Set_Prove_Int
                 (Cfg,
                  Cfg.Prove_Level,
                  A (A'First + 8 .. A'Last),
                  0,
                  4,
                  "--level");
            elsif A = "--timeout" then
               I := I + 1;
               if I <= Count then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Timeout,
                     Ada.Command_Line.Argument (I),
                     1,
                     3600,
                     "--timeout");
               else
                  Set_Error (Cfg, "--timeout requires an integer argument");
               end if;
            elsif Has_Prefix (A, "--timeout=") then
               Set_Prove_Int
                 (Cfg,
                  Cfg.Prove_Timeout,
                  A (A'First + 10 .. A'Last),
                  1,
                  3600,
                  "--timeout");
            elsif A = "--steps" then
               I := I + 1;
               if I <= Count then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Steps,
                     Ada.Command_Line.Argument (I),
                     1,
                     100_000_000,
                     "--steps");
               else
                  Set_Error (Cfg, "--steps requires an integer argument");
               end if;
            elsif Has_Prefix (A, "--steps=") then
               Set_Prove_Int
                 (Cfg,
                  Cfg.Prove_Steps,
                  A (A'First + 8 .. A'Last),
                  1,
                  100_000_000,
                  "--steps");
            elsif A = "--memlimit" then
               I := I + 1;
               if I <= Count then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Memlimit,
                     Ada.Command_Line.Argument (I),
                     1,
                     1_000_000,
                     "--memlimit");
               else
                  Set_Error (Cfg, "--memlimit requires an integer argument");
               end if;
            elsif Has_Prefix (A, "--memlimit=") then
               Set_Prove_Int
                 (Cfg,
                  Cfg.Prove_Memlimit,
                  A (A'First + 11 .. A'Last),
                  1,
                  1_000_000,
                  "--memlimit");
            elsif A = "--force" then
               Cfg.Prove_Force := True;
            elsif A = "--no-loop-unrolling" then
               Cfg.Prove_No_Loop_Unroll := True;
            elsif A = "--no-inlining" then
               Cfg.Prove_No_Inlining := True;
            elsif A = "--help" then
               Cfg.Help_Requested := True;
               Print_Usage;
            end if;
         end;
         I := I + 1;
      end loop;

      -- Default skip dirs (used in relaxed mode; .git/obj always skipped)
      if Cfg.Skip_Dir_Ct = 0 then
         Set_String (Cfg.Skip_Dirs, Cfg.Skip_Dir_Ct, "demo,deps,examples");
      end if;

      -- --no-svg overrides --emit-svg
      if Cfg.No_SVG then
         Cfg.Emit_SVG := False;
         Cfg.SVG_Path_Len := 0;
      end if;

      -- Differential modes are mutually exclusive
      if Cfg.Compare_Base_Len > 0 and then Cfg.Coverage_Delta_Len > 0 then
         Set_Error
           (Cfg, "--compare-base and --coverage-delta are mutually exclusive");
      end if;

      -- SBOM mode is exclusive with the differential modes
      if Cfg.SBOM_Mode
        and then (Cfg.Compare_Base_Len > 0 or Cfg.Coverage_Delta_Len > 0)
      then
         Set_Error
           (Cfg,
            "sbom cannot be combined with --compare-base/--coverage-delta");
      end if;

      -- Prove mode is exclusive with the differential modes and sbom mode
      if Cfg.Prove_Mode
        and then (Cfg.Compare_Base_Len > 0
                  or Cfg.Coverage_Delta_Len > 0
                  or Cfg.SBOM_Mode)
      then
         Set_Error
           (Cfg,
            "prove cannot be combined with --compare-base, --coverage-delta, "
            & "or sbom");
      end if;

      -- GNATprove options only make sense in prove mode.
      if not Cfg.Prove_Mode
        and then (Cfg.Prove_Jobs >= 0
                  or Cfg.Prove_Level >= 0
                  or Cfg.Prove_Timeout >= 0
                  or Cfg.Prove_Steps >= 0
                  or Cfg.Prove_Memlimit >= 0
                  or Cfg.Prove_Force
                  or Cfg.Prove_No_Loop_Unroll
                  or Cfg.Prove_No_Inlining)
      then
         Set_Error
           (Cfg,
            "prove options (--jobs, --level, --timeout, --steps, --memlimit, "
            & "--force, --no-loop-unrolling, --no-inlining) require the prove "
            & "subcommand");
      end if;

      -- Automatic SBOM at the end of every assessment is skipped only in the
      -- single-purpose modes (differential, coverage gate, sbom) or when
      -- --no-sbom is passed. Prove mode runs gnatprove and then falls through
      -- to the normal assessment, so the automatic SBOM still applies.
      if Cfg.SBOM_Mode
        or Cfg.Compare_Base_Len > 0
        or Cfg.Coverage_Delta_Len > 0
      then
         Cfg.No_SBOM := True;
      end if;

      -- Default target if not provided: current working directory
      if Cfg.Target_Len = 0 then
         Set_String
           (Cfg.Target_Path,
            Cfg.Target_Len,
            Ada.Directories.Current_Directory);
      end if;

      -- Resolve target path to absolute, then derive default manifest
      declare
         Raw : constant String := Cfg.Target_Path (1 .. Cfg.Target_Len);
      begin
         if Raw'Length > 0 and then Raw (Raw'First) /= '/' then
            declare
               CD : constant String := Ada.Directories.Current_Directory;
               AP : constant String := CD & "/" & Raw;
            begin
               -- Normalize a trailing "/." (e.g. "--target=.") to the
               -- plain directory so display paths stay clean.
               if AP'Length >= 2 and then AP (AP'Last - 1 .. AP'Last) = "/."
               then
                  Set_String (Cfg.Target_Path, Cfg.Target_Len, CD);
               else
                  Set_String (Cfg.Target_Path, Cfg.Target_Len, AP);
               end if;
            end;
         end if;
      end;

      -- Default SVG output path: project-scoped (relative to resolved target)
      if Cfg.Emit_SVG and then Cfg.SVG_Path_Len = 0 then
         Set_String
           (Cfg.SVG_Path,
            Cfg.SVG_Path_Len,
            Cfg.Target_Path (1 .. Cfg.Target_Len) & "/docs/badges");
      end if;

      -- Default manifest derived from target
      if Cfg.Manifest_Len = 0 then
         declare
            TDir : constant String := Cfg.Target_Path (1 .. Cfg.Target_Len);
         begin
            if Ada.Directories.Exists (TDir & "/alire.toml") then
               Set_String
                 (Cfg.Manifest_Path, Cfg.Manifest_Len, TDir & "/alire.toml");
            else
               Set_String
                 (Cfg.Manifest_Path,
                  Cfg.Manifest_Len,
                  TDir & "/alire-dev.toml");
            end if;
         end;
      end if;

      -- Default SBOM output path: project-scoped, format-aware.  Applies to
      -- both the explicit `adacovex sbom` subcommand and the automatic SBOM
      -- generation that runs at the end of every normal assessment (unless
      -- disabled with --no-sbom).
      if Cfg.SBOM_Out_Len = 0 then
         declare
            TDir : constant String := Cfg.Target_Path (1 .. Cfg.Target_Len);
         begin
            case Cfg.SBOM_Format is
               when Types.SPDX_JSON =>
                  Set_String
                    (Cfg.SBOM_Out, Cfg.SBOM_Out_Len, TDir & "/sbom.spdx.json");

               when Types.Markdown  =>
                  Set_String
                    (Cfg.SBOM_Out,
                     Cfg.SBOM_Out_Len,
                     TDir & "/docs/compliance/SBOM.md");

               when others          =>
                  Set_String
                    (Cfg.SBOM_Out, Cfg.SBOM_Out_Len, TDir & "/sbom.json");
            end case;
         end;
      end if;

      return Cfg;
   end Parse_CLI;

   procedure Print_Usage is
   begin
      Ada.Text_IO.Put_Line
        ("adacovex v"
         & Adacovex.Version
         & " -- Ada/SPARK Coverage, Proof & DO-178C Compliance Tool");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Usage: adacovex [options]");
      Ada.Text_IO.Put_Line ("       adacovex sbom --format=FMT --out=PATH");
      Ada.Text_IO.Put_Line ("       adacovex prove --target=PATH");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.Put_Line
        ("  --target=PATH         Target project path (default: current directory)");
      Ada.Text_IO.Put_Line
        ("  --manifest=PATH       Target manifest file override");
      Ada.Text_IO.Put_Line
        ("  --dal=LEVEL           DAL level: A | B | C | D | E (default: C)");
      Ada.Text_IO.Put_Line
        ("  --serve               Start HTTP dashboard on :8080");
      Ada.Text_IO.Put_Line
        ("  --port=N              HTTP server port (default: 8080)");
      Ada.Text_IO.Put_Line
        ("  --emit-svg=PATH       Write SVG badges to directory (default: <target>/docs/badges)");
      Ada.Text_IO.Put_Line
        ("  --no-svg              Suppress automatic SVG output");
      Ada.Text_IO.Put_Line
        ("  --emit-markdown=PATH  Write VERIFICATION.md + TRACE.md");
      Ada.Text_IO.Put_Line
        ("  --skip-dir=NAME       Add directory name to skip list (repeatable)");
      Ada.Text_IO.Put_Line
        ("  --relaxed             Disable strict mode (skip dirs, no patches); strict is default");
      Ada.Text_IO.Put_Line
        ("  --compare-base=REF    Differential mode: compare against a git base");
      Ada.Text_IO.Put_Line
        ("                        (branch or commit) and report VC/DAL delta");
      Ada.Text_IO.Put_Line
        ("  --coverage-delta=REF  Docstring coverage gate: exit non-zero if");
      Ada.Text_IO.Put_Line
        ("                        current docstring coverage is below the base");
      Ada.Text_IO.Put_Line
        ("  prove --target=PATH   Run GNATprove on the target project, then");
      Ada.Text_IO.Put_Line
        ("                        assess it (bundled gnatprove resolution,");
      Ada.Text_IO.Put_Line
        ("                        no alire.toml required in the target)");
      Ada.Text_IO.Put_Line
        ("  --jobs=N, -j N        GNATprove parallelism (default: auto-detect");
      Ada.Text_IO.Put_Line
        ("                        CPU count; 0 = all cores; e.g. -j12)");
      Ada.Text_IO.Put_Line
        ("  --level=N             GNATprove proof effort 0-4 (default: tool default)");
      Ada.Text_IO.Put_Line
        ("  --timeout=N           Per-check prover timeout in seconds");
      Ada.Text_IO.Put_Line
        ("  --steps=N             Max proof steps (reproducible)");
      Ada.Text_IO.Put_Line
        ("  --memlimit=N          Prover memory limit in MB");
      Ada.Text_IO.Put_Line
        ("  --force               Force full gnatprove reanalysis (-f)");
      Ada.Text_IO.Put_Line
        ("  --no-loop-unrolling   Disable automatic loop unrolling");
      Ada.Text_IO.Put_Line
        ("  --no-inlining         Disable contextual analysis inlining");
      Ada.Text_IO.Put_Line
        ("  sbom --format=FMT     Generate a proof-aware SBOM (FMT: cyclonedx-json");
      Ada.Text_IO.Put_Line
        ("                        | spdx-json | md; default: cyclonedx-json)");
      Ada.Text_IO.Put_Line
        ("  sbom --out=PATH       SBOM output path (default: <target>/sbom.json");
      Ada.Text_IO.Put_Line
        ("                        or <target>/sbom.spdx.json, or");
      Ada.Text_IO.Put_Line
        ("                        <target>/docs/compliance/SBOM.md for md)");
      Ada.Text_IO.Put_Line
        ("  --no-sbom             Skip the automatic SBOM generated at the end");
      Ada.Text_IO.Put_Line
        ("                        of every assessment (generated by default)");
      Ada.Text_IO.Put_Line
        ("  --sbom-format=FMT     Format for the automatic SBOM (cyclonedx-json");
      Ada.Text_IO.Put_Line
        ("                        | spdx-json | md; default: cyclonedx-json)");
      Ada.Text_IO.Put_Line ("  --verbose             Verbose diagnostics");
      Ada.Text_IO.Put_Line
        ("  --help                Show this message and exit");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line
        ("Outputs: ANSI terminal report, SVG badges, Markdown reports,");
      Ada.Text_IO.Put_Line
        ("         HTML dashboard (--serve), JSON API (GET /api/metrics)");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line
        ("Zero-dependency Ada/SPARK tool for DO-178C DAL A-E assessment");
   end Print_Usage;

end Adacovex.Config;
