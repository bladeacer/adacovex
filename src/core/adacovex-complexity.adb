with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Characters.Handling;
with Adacovex.Parsers;
with Adacovex.Types;

package body Adacovex.Complexity is

   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;
   use Ada.Characters.Handling;
   use type Ada.Containers.Count_Type;

   function Strip_Comments (Line : String) return String is
      Out_Buf : Unbounded_String;
      In_Str  : Boolean := False;
   begin
      for I in Line'Range loop
         declare
            C : constant Character := Line (I);
         begin
            if In_Str then
               Append (Out_Buf, C);
               if C = '"' then
                  In_Str := False;
               end if;
            elsif C = '"' then
               In_Str := True;
               Append (Out_Buf, C);
            elsif I < Line'Last and then C = '-' and then Line (I + 1) = '-'
            then
               exit;
            else
               Append (Out_Buf, C);
            end if;
         end;
      end loop;
      return To_String (Out_Buf);
   end Strip_Comments;

   function CI_Starts_With (S : String; Prefix : String) return Boolean is
   begin
      if Prefix'Length > S'Length then
         return False;
      end if;
      for I in Prefix'Range loop
         declare
            C1 : constant Character :=
              To_Lower (S (S'First + (I - Prefix'First)));
            C2 : constant Character := To_Lower (Prefix (I));
         begin
            if C1 /= C2 then
               return False;
            end if;
         end;
      end loop;
      return True;
   end CI_Starts_With;

   function Trim (S : String) return String is
      F, L : Natural := S'First;
   begin
      while F <= S'Last loop
         exit when
           S (F) /= ' '
           and then S (F) /= ASCII.HT
           and then S (F) /= ASCII.CR
           and then S (F) /= ASCII.LF;
         F := F + 1;
      end loop;
      L := S'Last;
      while L >= F loop
         exit when
           S (L) /= ' '
           and then S (L) /= ASCII.HT
           and then S (L) /= ASCII.CR
           and then S (L) /= ASCII.LF;
         L := L - 1;
      end loop;
      if F > L then
         return "";
      end if;
      return S (F .. L);
   end Trim;

   function Count_Decisions (Line : String) return Natural is
      S    : constant String := Strip_Comments (Line);
      N    : Natural := 0;
      I    : Natural := S'First;
      Prev : String (1 .. 16) := (others => ' ');
      PLen : Natural := 0;
      T    : String (1 .. 64);
      TL   : Natural := 0;
   begin
      while I <= S'Last loop
         while I <= S'Last loop
            exit when
              S (I) in 'a' .. 'z'
              or else S (I) in 'A' .. 'Z'
              or else S (I) in '0' .. '9'
              or else S (I) = '_';
            I := I + 1;
         end loop;
         if I > S'Last then
            exit;
         end if;
         TL := 0;
         while I <= S'Last loop
            exit when
              not (S (I) in 'a' .. 'z'
                   or else S (I) in 'A' .. 'Z'
                   or else S (I) in '0' .. '9'
                   or else S (I) = '_');
            if TL < T'Last then
               TL := TL + 1;
               T (TL) := To_Lower (S (I));
            end if;
            I := I + 1;
         end loop;
         if TL = 2 and then T (1 .. 2) = "if" then
            N := N + 1;
         elsif TL = 5 and then T (1 .. 5) = "elsif" then
            N := N + 1;
         elsif TL = 4 and then T (1 .. 4) = "case" then
            N := N + 1;
         elsif TL = 5 and then T (1 .. 5) = "while" then
            N := N + 1;
         elsif TL = 3 and then T (1 .. 3) = "for" then
            N := N + 1;
         elsif TL = 4 and then T (1 .. 4) = "exit" then
            N := N + 1;
         elsif TL = 4 and then T (1 .. 4) = "when" then
            N := N + 1;
         elsif TL = 3
           and then T (1 .. 3) = "and"
           and then PLen = 4
           and then Prev (1 .. 4) = "then"
         then
            N := N + 1;
         elsif TL = 2
           and then T (1 .. 2) = "or"
           and then PLen = 4
           and then Prev (1 .. 4) = "else"
         then
            N := N + 1;
         end if;
         if TL <= Prev'Last then
            Prev (1 .. TL) := T (1 .. TL);
            PLen := TL;
         else
            Prev := (others => ' ');
            PLen := 0;
         end if;
      end loop;
      return N;
   end Count_Decisions;

   function Forbidden_End (S : String) return Boolean is
      L : String (1 .. 7) := (others => ' ');
      N : Natural := 0;
   begin
      for I in S'Range loop
         exit when N = 7;
         N := N + 1;
         L (N) := To_Lower (S (I));
      end loop;
      return
        (N >= 2 and then L (1 .. 2) = "if")
        or else (N >= 4 and then L (1 .. 4) = "loop")
        or else (N >= 4 and then L (1 .. 4) = "case")
        or else (N >= 6 and then L (1 .. 6) = "select")
        or else (N >= 6 and then L (1 .. 6) = "return")
        or else (N >= 7 and then L (1 .. 7) = "declare")
        or else (N >= 5 and then L (1 .. 5) = "block");
   end Forbidden_End;

   procedure Detect_Package
     (S : String; Pkg : out Boolean; Name : out String; Name_Len : out Natural)
   is
      I : Natural := S'First;
   begin
      Pkg := False;
      Name_Len := 0;
      Name := (others => ' ');
      if not CI_Starts_With (S, "package") then
         return;
      end if;
      I := I + 7;
      while I <= S'Last and then S (I) = ' ' loop
         I := I + 1;
      end loop;
      if I > S'Last then
         return;
      end if;
      if CI_Starts_With (S (I .. S'Last), "body") then
         I := I + 4;
         while I <= S'Last and then S (I) = ' ' loop
            I := I + 1;
         end loop;
      end if;
      if I > S'Last then
         return;
      end if;
      declare
         Start : Natural := I;
      begin
         while I <= S'Last loop
            exit when
              not (S (I) in 'a' .. 'z'
                   or else S (I) in 'A' .. 'Z'
                   or else S (I) in '0' .. '9'
                   or else S (I) = '.'
                   or else S (I) = '_');
            I := I + 1;
         end loop;
         if I > Start then
            Name_Len := I - Start;
            Name (1 .. Name_Len) := S (Start .. I - 1);
         else
            return;
         end if;
      end;
      while I <= S'Last and then S (I) = ' ' loop
         I := I + 1;
      end loop;
      if CI_Starts_With (S (I .. S'Last), "is") then
         Pkg := True;
      end if;
   end Detect_Package;

   procedure Detect_Header
     (S : String; Hdr : out Boolean; Name : out String; Name_Len : out Natural)
   is
      I : Natural := S'First;
   begin
      Hdr := False;
      Name_Len := 0;
      Name := (others => ' ');
      if S'Length < 5 then
         return;
      end if;
      if S (S'First) /= ' '
        or else S (S'First + 1) /= ' '
        or else S (S'First + 2) /= ' '
      then
         return;
      end if;
      if S (S'First + 3) = ' ' then
         return;
      end if;
      I := S'First + 3;
      if CI_Starts_With (S (I .. S'Last), "overriding") then
         I := I + 10;
         while I <= S'Last and then S (I) = ' ' loop
            I := I + 1;
         end loop;
      end if;
      if I > S'Last then
         return;
      end if;
      declare
         Is_Proc : constant Boolean :=
           CI_Starts_With (S (I .. S'Last), "procedure");
         Is_Func : constant Boolean :=
           CI_Starts_With (S (I .. S'Last), "function");
      begin
         if not (Is_Proc or Is_Func) then
            return;
         end if;
         if Is_Proc then
            I := I + 9;
         else
            I := I + 8;
         end if;
         while I <= S'Last and then S (I) = ' ' loop
            I := I + 1;
         end loop;
         if I > S'Last then
            return;
         end if;
         declare
            Start : Natural := I;
         begin
            while I <= S'Last loop
               exit when
                 not (S (I) in 'a' .. 'z'
                      or else S (I) in 'A' .. 'Z'
                      or else S (I) in '0' .. '9'
                      or else S (I) = '_');
               I := I + 1;
            end loop;
            if I > Start then
               Name_Len := I - Start;
               Name (1 .. Name_Len) := S (Start .. I - 1);
               Hdr := True;
            end if;
         end;
      end;
   end Detect_Header;

   procedure Detect_End
     (S               : String;
      Is_End, Is_Bare : out Boolean;
      Name            : out String;
      Name_Len        : out Natural)
   is
      I : Natural := S'First;
   begin
      Is_End := False;
      Is_Bare := False;
      Name_Len := 0;
      Name := (others => ' ');
      if S'Length < 3 or else not CI_Starts_With (S, "end") then
         return;
      end if;
      I := I + 3;
      while I <= S'Last and then S (I) = ' ' loop
         I := I + 1;
      end loop;
      if I > S'Last then
         Is_End := True;
         Is_Bare := True;
         return;
      end if;
      if Forbidden_End (S (I .. S'Last)) then
         return;
      end if;
      declare
         Start : Natural := I;
      begin
         while I <= S'Last loop
            exit when
              not (S (I) in 'a' .. 'z'
                   or else S (I) in 'A' .. 'Z'
                   or else S (I) in '0' .. '9'
                   or else S (I) = '.'
                   or else S (I) = '_');
            I := I + 1;
         end loop;
         if I > Start then
            Name_Len := I - Start;
            Name (1 .. Name_Len) := S (Start .. I - 1);
            while I <= S'Last and then S (I) = ' ' loop
               I := I + 1;
            end loop;
            if I > S'Last then
               Is_End := True;
               return;
            end if;
            if S (I) = ';' then
               I := I + 1;
               while I <= S'Last and then S (I) = ' ' loop
                  I := I + 1;
               end loop;
               if I > S'Last then
                  Is_End := True;
                  return;
               end if;
            end if;
            return;
         elsif S (I) = ';' then
            I := I + 1;
            while I <= S'Last and then S (I) = ' ' loop
               I := I + 1;
            end loop;
            if I > S'Last then
               Is_End := True;
               Is_Bare := True;
               return;
            end if;
         end if;
      end;
   end Detect_End;

   function Scan_Source_Files (Target_Dir : String) return File_Vectors.Vector
   is
      use Ada.Directories;
      Result : File_Vectors.Vector;

      Abs_Target : constant String :=
        (if Exists (Target_Dir) then Full_Name (Target_Dir) else Target_Dir);

      procedure Walk (Dir : String) is
         Search : Search_Type;
         Ent    : Directory_Entry_Type;
      begin
         Start_Search (Search, Dir, "");
         while More_Entries (Search) loop
            Get_Next_Entry (Search, Ent);
            declare
               N : constant String := Simple_Name (Ent);
            begin
               if N = "." or else N = ".." then
                  null;
               elsif Kind (Ent) = Directory then
                  if N /= ".git"
                    and then N /= ".alire"
                    and then N /= "obj"
                    and then N /= "tests"
                  then
                     Walk (Full_Name (Ent));
                  end if;
               elsif Kind (Ent) = Ordinary_File then
                  if N'Length > 4 then
                     declare
                        Ext : constant String := N (N'Last - 3 .. N'Last);
                     begin
                        if Ext = ".ads" or else Ext = ".adb" then
                           if N /= "adacovex_version_info.ads"
                             and then N /= "adacovex-dashboard_template.ads"
                           then
                              declare
                                 Item : File_Metrics;
                                 Full : constant String := Full_Name (Ent);
                              begin
                                 Item.Path_Len := Full'Length;
                                 Item.Path (1 .. Item.Path_Len) := Full;
                                 Result.Append (Item);
                              end;
                           end if;
                        end if;
                     end;
                  end if;
               end if;
            end;
         end loop;
         End_Search (Search);
      exception
         when others =>
            End_Search (Search);
      end Walk;

   begin
      if Exists (Abs_Target & "/src") then
         Walk (Abs_Target & "/src");
      end if;
      return Result;
   end Scan_Source_Files;

   function Analyze_File (Path : String) return File_Metrics is
      use Ada.Text_IO;

      Line    : String (1 .. Types.Max_Line);
      Last    : Natural;
      Line_No : Natural := 0;
      LOC     : Natural := 0;
      F       : File_Type;

      type Block_Kind is (Pkg_Block, Sub_Block);
      type Stack_Entry is record
         Kind     : Block_Kind;
         Name     : String (1 .. 128);
         Name_Len : Natural := 0;
      end record;
      Stack : array (1 .. 64) of Stack_Entry;
      Depth : Natural := 0;

      Cur    : Subprogram_Info;
      Cur_On : Boolean := False;

      procedure Flush (Subs : in out Subprogram_Vectors.Vector) is
      begin
         if Cur_On then
            Cur.Name_Len := Cur.Name_Len;
            Subs.Append (Cur);
            Cur_On := False;
         end if;
      end Flush;

      procedure Push_Block (K : Block_Kind; N : String; L : Natural) is
      begin
         if Depth < Stack'Last then
            Depth := Depth + 1;
            Stack (Depth).Kind := K;
            Stack (Depth).Name (1 .. L) := N (1 .. L);
            Stack (Depth).Name_Len := L;
         end if;
      end Push_Block;

      procedure Pop_Block is
      begin
         if Depth > 0 then
            Depth := Depth - 1;
         end if;
      end Pop_Block;

      Result : File_Metrics;

   begin
      Result.Path_Len := Path'Length;
      Result.Path (1 .. Result.Path_Len) := Path;

      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return Result;
      end;

      while not End_Of_File (F) loop
         declare
            Raw       : String (1 .. Types.Max_Line);
            Last_Raw  : Natural;
            Ovl       : Boolean;
            Raw_S     : String (1 .. Types.Max_Line);
            RL        : Natural := 0;
            Decisions : Natural;
            Pkg_Found : Boolean;
            Hdr_Found : Boolean;
            End_Found : Boolean;
            Bare_End  : Boolean;
            Pkg_Name  : String (1 .. 128);
            Pkg_Len   : Natural := 0;
            Hdr_Name  : String (1 .. 128);
            Hdr_Len   : Natural := 0;
            End_Name  : String (1 .. 128);
            End_Len   : Natural := 0;
            Clean     : String (1 .. Types.Max_Line);
            CLen      : Natural := 0;
         begin
            Line_No := Line_No + 1;
            Adacovex.Parsers.Read_Line (F, Path, Line_No, Raw, Last_Raw, Ovl);
            if Ovl then
               goto Next_Line;
            end if;
            RL := Last_Raw;
            Raw_S (1 .. RL) := Raw (1 .. Last_Raw);
            declare
               procedure Do_Strip is
                  Tmp  : String (1 .. Types.Max_Line);
                  TLen : Natural := 0;
               begin
                  for I in 1 .. RL loop
                     if TLen < Tmp'Last then
                        TLen := TLen + 1;
                        Tmp (TLen) := Raw_S (I);
                     end if;
                  end loop;
                  declare
                     S : constant String :=
                       Trim (Strip_Comments (Tmp (1 .. TLen)));
                  begin
                     CLen := S'Length;
                     Clean (1 .. CLen) := S;
                  end;
               end Do_Strip;
            begin
               Do_Strip;
            end;
            if CLen = 0 then
               goto Next_Line;
            end if;
            if Clean (Clean'First) = '-' and then Clean (Clean'First + 1) = '-'
            then
               goto Next_Line;
            end if;
            LOC := LOC + 1;
            Decisions := Count_Decisions (Raw_S (1 .. RL));
            Detect_Package
              (Clean (Clean'First .. Clean'First + CLen - 1),
               Pkg_Found,
               Pkg_Name,
               Pkg_Len);
            Detect_Header (Raw_S (1 .. RL), Hdr_Found, Hdr_Name, Hdr_Len);
            Detect_End
              (Clean (Clean'First .. Clean'First + CLen - 1),
               End_Found,
               Bare_End,
               End_Name,
               End_Len);
            if Pkg_Found then
               Push_Block (Pkg_Block, Pkg_Name (1 .. Pkg_Len), Pkg_Len);
            elsif Hdr_Found then
               if Cur_On then
                  Flush (Result.Subs);
               end if;
               declare
                  Nm : constant String := Hdr_Name (1 .. Hdr_Len);
               begin
                  Cur.Name (1 .. Nm'Length) := Nm;
                  Cur.Name_Len := Nm'Length;
                  Cur.Line := Line_No;
                  Cur.Complexity := Decisions;
                  Cur.LOC := 1;
                  Cur_On := True;
                  Push_Block (Sub_Block, Nm, Nm'Length);
               end;
            elsif End_Found then
               if Depth = 0 then
                  if Cur_On then
                     Flush (Result.Subs);
                  end if;
               else
                  declare
                     Top_Name : constant String :=
                       Stack (Depth).Name (1 .. Stack (Depth).Name_Len);
                     Top_Kind : constant Block_Kind := Stack (Depth).Kind;
                  begin
                     if End_Len > 0
                       and then End_Len = Top_Name'Length
                       and then End_Name (1 .. End_Len) = Top_Name
                     then
                        Pop_Block;
                        if Top_Kind = Sub_Block then
                           Flush (Result.Subs);
                        end if;
                     elsif End_Len = 0
                       and then Top_Kind = Sub_Block
                       and then Depth = 1
                     then
                        Pop_Block;
                        Flush (Result.Subs);
                     end if;
                  end;
               end if;
            else
               if Cur_On
                 and then Depth > 0
                 and then Stack (Depth).Kind = Sub_Block
               then
                  Cur.Complexity := Cur.Complexity + Decisions;
                  Cur.LOC := Cur.LOC + 1;
               end if;
            end if;
            <<Next_Line>>
            null;
         end;
      end loop;

      if Cur_On then
         Flush (Result.Subs);
      end if;

      Close (F);

      Result.LOC := LOC;
      for S of Result.Subs loop
         Result.Complexity := Result.Complexity + S.Complexity;
      end loop;

      return Result;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end;

   function Analyze_Project (Target_Dir : String) return Complexity_Result is
      Files : constant File_Vectors.Vector := Scan_Source_Files (Target_Dir);
      Res   : Complexity_Result;
   begin
      for I in 1 .. Integer (Files.Length) loop
         declare
            FM : constant File_Metrics :=
              Analyze_File (Files (I).Path (1 .. Files (I).Path_Len));
         begin
            Res.Files.Append (FM);
            Res.Total_LOC := Res.Total_LOC + FM.LOC;
         end;
      end loop;
      return Res;
   end Analyze_Project;

   function Check_Gates
     (Result              : Complexity_Result;
      Max_File_LOC        : Natural;
      Max_File_Pct        : Natural;
      Max_Fn_Complexity   : Natural;
      Max_File_Complexity : Natural) return Violation_Vectors.Vector
   is
      V : Violation_Vectors.Vector;
   begin
      for I in 1 .. Integer (Result.Files.Length) loop
         declare
            FM  : File_Metrics renames Result.Files (I);
            Pct : Natural := 0;
         begin
            if Result.Total_LOC > 0 then
               Pct := (FM.LOC * 100) / Result.Total_LOC;
            end if;
            for S of FM.Subs loop
               if S.Complexity > Max_Fn_Complexity then
                  declare
                     Suffix : constant String :=
                       " '"
                       & S.Name (1 .. S.Name_Len)
                       & "' cyclomatic "
                       & Trim (Natural'Image (S.Complexity))
                       & " > "
                       & Trim (Natural'Image (Max_Fn_Complexity));
                     M      : Violation;
                  begin
                     M.File_Len := FM.Path_Len;
                     M.File_Path (1 .. M.File_Len) :=
                       FM.Path (1 .. FM.Path_Len);
                     M.Message (1 .. Suffix'Length) := Suffix;
                     M.Msg_Len := Suffix'Length;
                     V.Append (M);
                  end;
               end if;
            end loop;
            if FM.LOC > Max_File_LOC then
               declare
                  Suffix : constant String :=
                    " LOC "
                    & Trim (Natural'Image (FM.LOC))
                    & " > "
                    & Trim (Natural'Image (Max_File_LOC));
                  M      : Violation;
               begin
                  M.File_Len := FM.Path_Len;
                  M.File_Path (1 .. M.File_Len) := FM.Path (1 .. FM.Path_Len);
                  M.Message (1 .. Suffix'Length) := Suffix;
                  M.Msg_Len := Suffix'Length;
                  V.Append (M);
               end;
            end if;
            if Pct > Max_File_Pct then
               declare
                  Suffix : constant String :=
                    " "
                    & Trim (Natural'Image (Pct))
                    & "% of codebase > "
                    & Trim (Natural'Image (Max_File_Pct))
                    & "%";
                  M      : Violation;
               begin
                  M.File_Len := FM.Path_Len;
                  M.File_Path (1 .. M.File_Len) := FM.Path (1 .. FM.Path_Len);
                  M.Message (1 .. Suffix'Length) := Suffix;
                  M.Msg_Len := Suffix'Length;
                  V.Append (M);
               end;
            end if;
            if FM.Complexity > Max_File_Complexity then
               declare
                  Suffix : constant String :=
                    " total cyclomatic "
                    & Trim (Natural'Image (FM.Complexity))
                    & " > "
                    & Trim (Natural'Image (Max_File_Complexity));
                  M      : Violation;
               begin
                  M.File_Len := FM.Path_Len;
                  M.File_Path (1 .. M.File_Len) := FM.Path (1 .. FM.Path_Len);
                  M.Message (1 .. Suffix'Length) := Suffix;
                  M.Msg_Len := Suffix'Length;
                  V.Append (M);
               end;
            end if;
         end;
      end loop;
      return V;
   end Check_Gates;

   procedure Print_Report
     (Result              : Complexity_Result;
      Check_Mode          : Boolean;
      Violations          : Violation_Vectors.Vector;
      Max_File_LOC        : Natural;
      Max_File_Pct        : Natural;
      Max_Fn_Complexity   : Natural;
      Max_File_Complexity : Natural)
   is
      pragma
        Unreferenced
          (Max_File_LOC, Max_File_Pct, Max_Fn_Complexity, Max_File_Complexity);
      Marker : String (1 .. 40) := (others => ' ');
      MLen   : Natural := 0;
   begin
      Ada.Text_IO.Put_Line ("file" & (58 - 4 => ' ') & " loc     %   cx");
      for I in 1 .. Integer (Result.Files.Length) loop
         declare
            FM    : File_Metrics renames Result.Files (I);
            Pct   : Natural := 0;
            Start : Natural := 1;
         begin
            if Result.Total_LOC > 0 then
               Pct := (FM.LOC * 100) / Result.Total_LOC;
            end if;
            MLen := 0;
            for S of FM.Subs loop
               if S.Complexity > Max_Fn_Complexity then
                  Marker (1 .. 26) := "  <-- function too complex";
                  MLen := 26;
                  exit;
               end if;
            end loop;
            if FM.LOC > Max_File_LOC then
               Marker (1 .. 14) := "  <-- too long";
               MLen := 14;
            end if;
            if Pct > Max_File_Pct then
               Marker (1 .. 14) := "  <-- dominant";
               MLen := 14;
            end if;
            if FM.Complexity > Max_File_Complexity then
               Marker (1 .. 16) := "  <-- god object";
               MLen := 16;
            end if;
            if FM.Path_Len > 58 then
               Start := FM.Path_Len - 57;
            end if;
            Ada.Text_IO.Put (FM.Path (Start .. FM.Path_Len));
            for J in FM.Path_Len - Start + 1 .. 58 loop
               Ada.Text_IO.Put (' ');
            end loop;
            Ada.Text_IO.Put (Natural'Image (FM.LOC));
            Ada.Text_IO.Put (' ');
            Ada.Text_IO.Put (Natural'Image (Pct));
            Ada.Text_IO.Put ('%');
            Ada.Text_IO.Put (' ');
            Ada.Text_IO.Put (Natural'Image (FM.Complexity));
            if MLen > 0 then
               Ada.Text_IO.Put (Marker (1 .. MLen));
            end if;
            Ada.Text_IO.New_Line;
         end;
      end loop;
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line
        ("total LOC (src): " & Trim (Natural'Image (Result.Total_LOC)));
      Ada.Text_IO.Put_Line
        ("files analyzed: "
         & Trim (Natural'Image (Integer (Result.Files.Length))));
      Ada.Text_IO.New_Line;
      if Check_Mode then
         if Integer (Violations.Length) > 0 then
            Ada.Text_IO.Put_Line
              ("  Complexity/LOC gate FAILED ("
               & Trim (Natural'Image (Integer (Violations.Length)))
               & " violation(s))");
            for I in 1 .. Integer (Violations.Length) loop
               Ada.Text_IO.Put_Line
                 ("  - "
                  & Violations (I).File_Path (1 .. Violations (I).File_Len)
                  & Violations (I).Message (1 .. Violations (I).Msg_Len));
            end loop;
         else
            Ada.Text_IO.Put_Line ("  Complexity/LOC gate passed.");
         end if;
      end if;
   end Print_Report;

end Adacovex.Complexity;
