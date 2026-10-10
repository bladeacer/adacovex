with Ada.Text_IO;

separate (Adacovex.Parsers.Manifest)
--  Read a Go vendor manifest into the module-to-version table.
--
--  The file is the manifest `go mod vendor` writes beside the vendored tree.
--  It lists one module per stanza, the first line being "# <module path>
--  <version>" (for example "# golang.org/x/text v0.42.0"), followed by a
--  "## explicit" line and the vendored package paths. A line that starts
--  with "##" is metadata, not a module line, and is skipped.
--
--  This is the only offline, forge-independent source of a vendored Go
--  module's version. The module's own go.mod states the module path but
--  never its own version -- its require block lists that module's
--  dependencies, not the module itself. The registry is not consulted: the
--  module proxy protocol resolves through whichever proxy GOPROXY names
--  (public, private, or direct), so the answer never depends on the forge
--  the repository happens to live on.
--
--  The whole file is parsed in one pass, once per vendor root. Reading it
--  per component instead costs one open and one scan per component, which
--  is quadratic in the module count: a 100-module vendor tree paid 101
--  opens of a 300-line file.
--
--  A module path longer than the field is truncated to the field's length,
--  the same bounded-string rule every other parser field uses. Two distinct
--  module paths sharing a prefix longer than the field are not
--  distinguishable; no real module path is that long.
--  @param Path  Path to a vendor/modules.txt file.
--  @param Table  Filled with one entry per module line, in file order. An
--  unreadable or missing file leaves the table empty.
procedure Read_Go_Modules (Path : String; Table : out Go_Module_Vectors.Vector)
is
   use Ada.Strings;
   use Ada.Strings.Fixed;
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;
begin
   begin
      Open (F, In_File, Path);
   exception
      when others =>
         return;
   end;
   while not End_Of_File (F) loop
      Line_Num := Line_Num + 1;
      Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
      exit when Overflow;
      declare
         T : constant String := Trim (Line (1 .. Last), Both);
      begin
         --  "# <module> <version>": skip the "##" metadata lines and the
         --  package-path lines, which carry no leading '#'.
         if T'Length > 2
           and then T (T'First) = '#'
           and then T (T'First + 1) /= '#'
         then
            declare
               Rest : constant String :=
                 Trim (T (T'First + 1 .. T'Last), Both);
               Sp   : Natural := 0;
            begin
               for K in Rest'Range loop
                  if Rest (K) = ' ' then
                     Sp := K;
                     exit;
                  end if;
               end loop;
               if Sp > Rest'First and then Sp < Rest'Last then
                  declare
                     E    : Go_Module_Entry;
                     Ver  : constant String :=
                       Trim (Rest (Sp + 1 .. Rest'Last), Both);
                     MLen : Natural :=
                       (if Sp - Rest'First > Types.Max_Desc_Str
                        then Types.Max_Desc_Str
                        else Sp - Rest'First);
                     VLen : Natural :=
                       (if Ver'Length > Types.Max_Desc_Str
                        then Types.Max_Desc_Str
                        else Ver'Length);
                  begin
                     E.PLen := MLen;
                     E.Path (1 .. MLen) :=
                       Rest (Rest'First .. Rest'First + MLen - 1);
                     E.VLen := VLen;
                     E.Ver (1 .. VLen) :=
                       Ver (Ver'First .. Ver'First + VLen - 1);
                     Table.Append (E);
                  end;
               end if;
            end;
         end if;
      end;
   end loop;
   Close (F);
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
end Read_Go_Modules;
