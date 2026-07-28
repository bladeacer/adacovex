with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

package body Adacovex.Config is

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
      Dst_Len := Src'Length;
      for J in Src'Range loop
         Dst (J - Src'First + 1) := Src (J);
      end loop;
   end Set_String;

   function Parse_CLI return CLI_Config is
      Cfg   : CLI_Config;
      Count : constant Natural := Ada.Command_Line.Argument_Count;
      I     : Positive := 1;
   begin
      Cfg.Target_Len := 0;
      Cfg.Manifest_Len := 0;
      Cfg.SVG_Path_Len := 0;
      Cfg.MD_Path_Len := 0;

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
               end if;
            elsif Has_Prefix (A, "--manifest=") then
               Set_String
                 (Cfg.Manifest_Path,
                  Cfg.Manifest_Len,
                  A (A'First + 11 .. A'Last));
            elsif A = "--dal" then
               I := I + 1;
               if I <= Count then
                  Cfg.DAL_Target :=
                    Types.To_DAL (Ada.Command_Line.Argument (I));
               end if;
            elsif Has_Prefix (A, "--dal=") then
               Cfg.DAL_Target := Types.To_DAL (A (A'First + 6 .. A'Last));
            elsif A = "--serve" then
               Cfg.Serve_Mode := True;
            elsif A = "--port" then
               I := I + 1;
               if I <= Count then
                  Cfg.Port := Positive'Value (Ada.Command_Line.Argument (I));
               end if;
            elsif Has_Prefix (A, "--port=") then
               Cfg.Port := Positive'Value (A (A'First + 7 .. A'Last));
            elsif A = "--emit-svg" then
               I := I + 1;
               if I <= Count then
                  Cfg.Emit_SVG := True;
                  Set_String
                    (Cfg.SVG_Path,
                     Cfg.SVG_Path_Len,
                     Ada.Command_Line.Argument (I));
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
               end if;
            elsif Has_Prefix (A, "--emit-markdown=") then
               Cfg.Emit_Markdown := True;
               Set_String
                 (Cfg.MD_Path, Cfg.MD_Path_Len, A (A'First + 16 .. A'Last));
            elsif A = "--no-svg" then
               Cfg.No_SVG := True;
            elsif A = "--verbose" then
               Cfg.Verbose := True;
            elsif A = "--help" then
               Print_Usage;
            end if;
         end;
         I := I + 1;
      end loop;

      -- --no-svg overrides --emit-svg
      if Cfg.No_SVG then
         Cfg.Emit_SVG := False;
         Cfg.SVG_Path_Len := 0;
      end if;

      -- Default SVG output path if SVG is enabled but no path given
      if Cfg.Emit_SVG and then Cfg.SVG_Path_Len = 0 then
         Set_String (Cfg.SVG_Path, Cfg.SVG_Path_Len, "docs/badges");
      end if;

      -- Default target if not provided
      if Cfg.Target_Len = 0 then
         Set_String (Cfg.Target_Path, Cfg.Target_Len, "../Ada_CRDT");
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
               Set_String (Cfg.Target_Path, Cfg.Target_Len, AP);
            end;
         end if;
      end;

      -- Default manifest derived from target
      if Cfg.Manifest_Len = 0 then
         declare
            TDir : constant String := Cfg.Target_Path (1 .. Cfg.Target_Len);
         begin
            if Ada.Directories.Exists (TDir & "/alire-dev.toml") then
               Set_String
                 (Cfg.Manifest_Path,
                  Cfg.Manifest_Len,
                  TDir & "/alire-dev.toml");
            else
               Set_String
                 (Cfg.Manifest_Path, Cfg.Manifest_Len, TDir & "/alire.toml");
            end if;
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
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.Put_Line
        ("  --target=PATH         Target project path (default: ../Ada_CRDT)");
      Ada.Text_IO.Put_Line
        ("  --manifest=PATH       Target manifest file override");
      Ada.Text_IO.Put_Line
        ("  --dal=LEVEL           DAL level: A | B | C | D | E (default: C)");
      Ada.Text_IO.Put_Line
        ("  --serve               Start HTTP dashboard on :8080");
      Ada.Text_IO.Put_Line
        ("  --port=N              HTTP server port (default: 8080)");
      Ada.Text_IO.Put_Line
        ("  --emit-svg=PATH       Write SVG badges to directory (default: docs/badges)");
      Ada.Text_IO.Put_Line
        ("  --no-svg              Suppress automatic SVG output");
      Ada.Text_IO.Put_Line
        ("  --emit-markdown=PATH  Write VERIFICATION.md + TRACE.md");
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
