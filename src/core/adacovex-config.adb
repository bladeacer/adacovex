with Ada.Command_Line;
--  SPDX-License-Identifier: Apache-2.0
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

   function Parse_CLI return CLI_Config is
      Cfg   : CLI_Config;
      Count : constant Natural := Ada.Command_Line.Argument_Count;
      I     : Positive := 1;
   begin
      Cfg.Target_Len := 0;
      Cfg.SVG_Path_Len := 0;
      Cfg.MD_Path_Len := 0;

      while I <= Count loop
         declare
            A : constant String := Ada.Command_Line.Argument (I);
         begin
            if A = "--target" then
               I := I + 1;
               if I <= Count then
                  declare
                     V : constant String := Ada.Command_Line.Argument (I);
                  begin
                     Cfg.Target_Len := V'Length;
                     for J in V'Range loop
                        Cfg.Target_Path (J - V'First + 1) := V (J);
                     end loop;
                  end;
               end if;
            elsif Has_Prefix (A, "--target=") then
               declare
                  V : constant String := A (A'First + 9 .. A'Last);
               begin
                  Cfg.Target_Len := V'Length;
                  for J in V'Range loop
                     Cfg.Target_Path (J - V'First + 1) := V (J);
                  end loop;
               end;
            elsif A = "--dal" then
               I := I + 1;
               if I <= Count then
                  Cfg.DAL_Target := Types.To_DAL (Ada.Command_Line.Argument (I));
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
                  declare
                     V : constant String := Ada.Command_Line.Argument (I);
                  begin
                     Cfg.Emit_SVG := True;
                     Cfg.SVG_Path_Len := V'Length;
                     for J in V'Range loop
                        Cfg.SVG_Path (J - V'First + 1) := V (J);
                     end loop;
                  end;
               end if;
            elsif Has_Prefix (A, "--emit-svg=") then
               declare
                  V : constant String := A (A'First + 11 .. A'Last);
               begin
                  Cfg.Emit_SVG := True;
                  Cfg.SVG_Path_Len := V'Length;
                  for J in V'Range loop
                     Cfg.SVG_Path (J - V'First + 1) := V (J);
                  end loop;
               end;
            elsif A = "--emit-markdown" then
               I := I + 1;
               if I <= Count then
                  declare
                     V : constant String := Ada.Command_Line.Argument (I);
                  begin
                     Cfg.Emit_Markdown := True;
                     Cfg.MD_Path_Len := V'Length;
                     for J in V'Range loop
                        Cfg.MD_Path (J - V'First + 1) := V (J);
                     end loop;
                  end;
               end if;
             elsif Has_Prefix (A, "--emit-markdown=") then
                declare
                   Eq : Natural := 0;
                begin
                   for I in A'Range loop
                      if A (I) = '=' then
                         Eq := I;
                         exit;
                      end if;
                   end loop;
                   if Eq > 0 and Eq < A'Last then
                      Cfg.Emit_Markdown := True;
                      Cfg.MD_Path_Len := A'Last - Eq;
                      for J in Eq + 1 .. A'Last loop
                         Cfg.MD_Path (J - Eq) := A (J);
                      end loop;
                   end if;
                end;
            elsif A = "--verbose" then
               Cfg.Verbose := True;
            elsif A = "--help" then
               Print_Usage;
            end if;
         end;
         I := I + 1;
      end loop;

      if Cfg.Target_Len = 0 then
         declare
            D : constant String := "../Ada_CRDT";
         begin
            Cfg.Target_Len := D'Length;
            for J in D'Range loop
               Cfg.Target_Path (J - D'First + 1) := D (J);
            end loop;
         end;
      end if;

      return Cfg;
   end Parse_CLI;

   procedure Print_Usage is
   begin
      Ada.Text_IO.Put_Line ("adacovex - Ada Coverage & Verification Tool");
      Ada.Text_IO.Put_Line ("Usage:");
      Ada.Text_IO.Put_Line ("  adacovex [options]");
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.Put_Line ("  --target=PATH       Target project path (default: ../Ada_CRDT)");
      Ada.Text_IO.Put_Line ("  --dal=LEVEL         Target DAL level: A, B, C, D, E (default: C)");
      Ada.Text_IO.Put_Line ("  --serve             Start HTTP dashboard server");
      Ada.Text_IO.Put_Line ("  --port=N            Server port (default: 8080)");
      Ada.Text_IO.Put_Line ("  --emit-svg=PATH     Emit SVG badges to directory");
      Ada.Text_IO.Put_Line ("  --emit-markdown=PATH Emit Markdown reports to directory");
      Ada.Text_IO.Put_Line ("  --verbose           Verbose output");
      Ada.Text_IO.Put_Line ("  --help              Show this help");
   end Print_Usage;

end Adacovex.Config;
