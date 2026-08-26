separate (Adacovex.Parsers.Manifest)
--  Probe a tool's version by running "<Tool> <Flag>" and extracting the
--  first whitespace-separated token that contains a digit from the
--  captured output (for example "2.55.0" from "git version 2.55.0",
--  "4.4.1" from "GNU Make 4.4.1").  Returns "" when the tool is missing,
--  when the probe fails, or when no digit token is found.  A tool that
--  does not understand its version flag then reports no version.
--  @param Tool  Executable name (must be on PATH).
--  @param Flag  Version-probe flag or subcommand.
--  @return The extracted version string, or "".
function Probe_Version (Tool : String; Flag : String) return String is
   Pid     : constant Integer := Pid_To_Integer (Current_Process_Id);
   Pid_Img : constant String := Integer'Image (Pid);
   Tmp     : constant String :=
     Adacovex.CPUs.Get_Temp_Directory
     & "/adacovex-ver-"
     & Pid_Img (2 .. Pid_Img'Last)
     & ".out";
   Buf     : String (1 .. 4096);
   BLen    : Natural := 0;
   F       : Ada.Text_IO.File_Type;
   Exe     : String_Access := Locate_Exec_On_Path (Tool);
   OK      : Boolean;
   Code    : Integer;
   Ver     : String (1 .. 40);
begin
   if Exe = null then
      return "";
   end if;
   Spawn
     (Exe.all, (1 => new String'(Flag)), Tmp, OK, Code, Err_To_Out => True);
   Free (Exe);
   if not OK or else Code /= 0 then
      return "";
   end if;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Tmp);
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (F);
         begin
            for I in Line'Range loop
               if BLen < Buf'Last then
                  BLen := BLen + 1;
                  Buf (BLen) := Line (I);
               end if;
            end loop;
            --  Keep the physical line break so tokens on separate lines
            --  do not run together (e.g. "4.4.1\nBuilt for ...").
            if BLen < Buf'Last then
               BLen := BLen + 1;
               Buf (BLen) := ASCII.LF;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (F);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
         return "";
   end;
   begin
      Ada.Directories.Delete_File (Tmp);
   exception
      when others =>
         null;
   end;

   --  First whitespace/newline-separated token containing a digit, with
   --  stray trailing punctuation (for example the ")" of "7.2.4)")
   --  trimmed.
   declare
      Last : constant Natural := Buf'First + BLen - 1;
      I    : Natural := Buf'First;

      function Is_Sep (C : Character) return Boolean is
      begin
         return C = ' ' or else C = ASCII.LF or else C = ASCII.CR;
      end Is_Sep;
   begin
      while I <= Last loop
         while I <= Last and then Is_Sep (Buf (I)) loop
            I := I + 1;
         end loop;
         declare
            Start     : constant Natural := I;
            Has_Digit : Boolean := False;
         begin
            while I <= Last and then not Is_Sep (Buf (I)) loop
               if Buf (I) in '0' .. '9' then
                  Has_Digit := True;
               end if;
               I := I + 1;
            end loop;
            if Has_Digit then
               declare
                  L : Natural := I - 1;
               begin
                  while L > Start
                    and then Buf (L) not in 'a' .. 'z'
                    and then Buf (L) not in 'A' .. 'Z'
                    and then Buf (L) not in '0' .. '9'
                    and then Buf (L) /= '.'
                    and then Buf (L) /= '-'
                  loop
                     L := L - 1;
                  end loop;
                  if L - Start + 1 <= Ver'Last then
                     for J in 1 .. L - Start + 1 loop
                        Ver (J) := Buf (Start + J - 1);
                     end loop;
                     return Ver (1 .. L - Start + 1);
                  end if;
               end;
            end if;
         end;
      end loop;
   end;
   return "";
end Probe_Version;
