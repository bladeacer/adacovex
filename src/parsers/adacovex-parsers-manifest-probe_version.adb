separate (Adacovex.Parsers.Manifest)
--  Probe a tool's version by running "<Tool> <Flag>" and extracting the
--  first whitespace-separated token that contains a digit from the
--  captured output (for example "2.55.0" from "git version 2.55.0",
--  "4.4.1" from "GNU Make 4.4.1", "1.21.5" from "go version go1.21.5").
--  Returns "" when the tool is missing, when every probe fails, or when no
--  digit token is found.
--
--  A single flag is not robust across tools: go accepts only the
--  "version" subcommand, some tools only "-v", and most accept "--version".
--  The probe therefore tries the tool's configured flag first, then falls
--  back through "--version", "-v", and "version" in that order, and takes
--  the first successful run (a run whose output yields a version token).
--  A tool that understands none of the flags then reports no version.
--  @param Tool  Executable name (must be on PATH).
--  @param Flag  Version-probe flag or subcommand (the tool's configured
--    first choice, for example "version" for go).
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

   --  Run "<Tool> <Flag>" and return the extracted version, or "" when the
   --  run fails or no digit token is found.
   function Probe_One (One_Flag : String) return String is
      Ver      : String (1 .. 40);
      Ran_OK   : Boolean;
      Ran_Code : Integer;
   begin
      Spawn
        (Exe.all,
         (1 => new String'(One_Flag)),
         Tmp,
         Ran_OK,
         Ran_Code,
         Err_To_Out => True);
      if not Ran_OK or else Ran_Code /= 0 then
         return "";
      end if;
      BLen := 0;
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
      --  trimmed.  A leading "v" (node prints "v26.7.0") and a leading
      --  "go" (go prints "go1.21.5") are stripped so the version is the
      --  bare number.  go build tags ("go1.27.0-X:nodwarf5") are cut at
      --  the ':' separator.
      declare
         Last : constant Natural := Buf'First + BLen - 1;
         I    : Natural := Buf'First;

         function Is_Sep (C : Character) return Boolean is
         begin
            return C = ' ' or else C = ASCII.LF or else C = ASCII.CR;
         end Is_Sep;

         function Clean (S : String) return String is
            C_L : Natural := S'Length;
         begin
            if S'Length > 2
              and then S (S'First .. S'First + 1) = "go"
              and then S (S'First + 2) in '0' .. '9'
            then
               --  "go1.21.5..." -> "1.21.5..." (go's version token)
               C_L := C_L - 2;
               return S (S'First + 2 .. S'First + 2 + C_L - 1);
            end if;
            return S;
         end Clean;
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
                     declare
                        Raw   : constant String := Buf (Start .. L);
                        Cln   : constant String := Clean (Raw);
                        First : Natural := Cln'First;
                        CLast : Natural := Cln'Last;
                     begin
                        --  Cut a go build-tag suffix at ':' ("1.27.0-X").
                        if Tool = "go" then
                           for J in Cln'Range loop
                              if Cln (J) = ':' then
                                 CLast := J - 1;
                                 exit;
                              end if;
                           end loop;
                        end if;
                        --  Strip a leading "v" when followed by a digit
                        --  (node prints "v26.7.0").
                        if CLast - First + 1 > 1
                          and then Cln (First) = 'v'
                          and then Cln (First + 1) in '0' .. '9'
                        then
                           First := First + 1;
                        end if;
                        if CLast - First + 1 <= Ver'Last then
                           for J in 1 .. CLast - First + 1 loop
                              Ver (J) := Cln (First + J - 1);
                           end loop;
                           return Ver (1 .. CLast - First + 1);
                        end if;
                     end;
                  end;
               end if;
            end;
         end loop;
      end;
      return "";
   end Probe_One;

   --  Fallback flags tried in order after the configured flag: the common
   --  GNU-style long flag, the short flag, and the bare subcommand.  go
   --  understands only "version"; fossil and git-lfs also use "version".
   Fallbacks    : constant array (1 .. 3) of String (1 .. 16) :=
     ("--version       ", "-v              ", "version         ");
   Fallback_Len : constant array (1 .. 3) of Natural := (9, 2, 7);
begin
   if Exe = null then
      return "";
   end if;

   --  Configured flag first, then each fallback not already tried, in the
   --  order --version, -v, version.  The first successful run wins.
   declare
      One : constant String := Probe_One (Flag);
   begin
      if One'Length > 0 then
         Free (Exe);
         return One;
      end if;
      for K in Fallbacks'Range loop
         if Flag'Length /= Fallback_Len (K)
           or else Flag (Flag'First .. Flag'First + Flag'Length - 1)
                   /= Fallbacks (K) (1 .. Fallback_Len (K))
         then
            declare
               Alt : constant String :=
                 Probe_One (Fallbacks (K) (1 .. Fallback_Len (K)));
            begin
               if Alt'Length > 0 then
                  Free (Exe);
                  return Alt;
               end if;
            end;
         end if;
      end loop;
   end;

   Free (Exe);
   return "";
end Probe_Version;
