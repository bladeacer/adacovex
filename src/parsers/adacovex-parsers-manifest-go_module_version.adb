separate (Adacovex.Parsers.Manifest)
--  Version of a Go module from the vendor manifest `go mod vendor` writes
--  beside the vendored tree. The file lists one module per stanza, the
--  first line being "# <module path> <version>" (for example
--  "# golang.org/x/text v0.42.0"), followed by a "## explicit" line and
--  the vendored package paths. A line that starts with "##" is metadata,
--  not a module line, and is skipped.
--
--  This is the only offline, forge-independent source of a vendored Go
--  module's version. The module's own go.mod states the module path but
--  never its own version -- its require block lists that module's
--  dependencies, not the module itself. The registry is not consulted: the
--  module proxy protocol resolves through whichever proxy GOPROXY names
--  (public, private, or direct), so the answer never depends on the forge
--  the repository happens to live on.
--  @param Path  Path to a vendor/modules.txt file.
--  @param Module  Module path to look for (for example
--  "golang.org/x/text").
--  @return The version token (for example "v0.42.0"), or "" when the file
--  is missing, unreadable, or lists no such module.
function Go_Module_Version (Path : String; Module : String) return String is
   use Ada.Strings;
   use Ada.Strings.Fixed;
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;
begin
   if Module'Length = 0 then
      return "";
   end if;
   begin
      Open (F, In_File, Path);
   exception
      when others =>
         return "";
   end;
   while not End_Of_File (F) loop
      Line_Num := Line_Num + 1;
      Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
      if Overflow then
         exit;
      end if;
      declare
         T : constant String := Trim (Line (1 .. Last), Both);
      begin
         --  "# <module> <version>": skip the "##" metadata lines and any
         --  package-path line, which carries no leading '#'.
         if T'Length > 2
           and then T (T'First) = '#'
           and then T (T'First + 1) /= '#'
         then
            declare
               Rest : constant String :=
                 Trim (T (T'First + 1 .. T'Last), Both);
            begin
               if Rest'Length > Module'Length
                 and then Rest (Rest'First .. Rest'First + Module'Length - 1)
                          = Module
                 and then Rest (Rest'First + Module'Length) = ' '
               then
                  declare
                     V : constant String :=
                       Trim
                         (Rest (Rest'First + Module'Length + 1 .. Rest'Last),
                          Both);
                  begin
                     if V'Length > 0 then
                        Close (F);
                        return V;
                     end if;
                  end;
               end if;
            end;
         end if;
      end;
   end loop;
   Close (F);
   return "";
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
      return "";
end Go_Module_Version;
