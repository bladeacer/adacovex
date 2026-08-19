with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Adacovex.Cache;

package body Adacovex.Prove_Patch is

   use Ada.Strings.Fixed;

   --  Maximum number of subprogram declarations a patch may re-declare
   --  with aspects, and the fixed buffer bound for the merged spec and for
   --  reading vendored sources.  Patch files mirror single .ads files, so
   --  these bounds are generous; an oversized patch or spec fails loudly
   --  (the patch is skipped and reported) rather than truncating.
   Max_Patch_Subprogs : constant := 64;

   --  A subprogram parameter profile ("(A : in T; B : in U)" normalized) is
   --  at most a few hundred characters; a small dedicated buffer keeps the
   --  refs array -- 64 entries of Name + Profile -- comfortably on the
   --  stack.  A profile longer than this fails the match loudly (the
   --  patch entry stays unmatched and Apply reports it).
   Max_Profile : constant := 512;

   type Subprog_Ref is record
      Name             : String (1 .. Types.Max_Id_Str);
      Name_Len         : Natural := 0;
      Profile          : String (1 .. Max_Profile);
      Profile_Len      : Natural := 0;
      Profile_Too_Long : Boolean := False;
      Start_Pos        : Natural := 0;
      End_Pos          : Natural := 0;
      Used             : Boolean := False;
   end record;

   type Subprog_Refs is array (1 .. Max_Patch_Subprogs) of Subprog_Ref;

   function Has_Proof (Text : String) return Boolean is
   begin
      return
        Index (Text, "SPARK_Mode") > 0
        or else Index (Text, "Pre =>") > 0
        or else Index (Text, "Post =>") > 0
        or else Index (Text, "Global =>") > 0;
   end Has_Proof;

   --  Bounds of the line of Text starting at Pos (without the trailing LF
   --  or CR): Line_First .. Line_Last, with Next_Pos the start of the
   --  following line (Text'Last + 1 past the final line).
   procedure Next_Line_Bounds
     (Text       : String;
      Pos        : Natural;
      Line_First : out Natural;
      Line_Last  : out Natural;
      Next_Pos   : out Natural)
   is
      P : Natural := Pos;
   begin
      Line_First := Pos;
      if Pos > Text'Last then
         Line_Last := Pos - 1;
         Next_Pos := Pos;
         return;
      end if;
      while P <= Text'Last and then Text (P) /= ASCII.LF loop
         P := P + 1;
      end loop;
      Line_Last := P - 1;
      if Line_Last >= Line_First and then Text (Line_Last) = ASCII.CR then
         Line_Last := Line_Last - 1;
      end if;
      if P <= Text'Last then
         Next_Pos := P + 1;
      else
         Next_Pos := Text'Last + 1;
      end if;
   end Next_Line_Bounds;

   --  True when Line declares a subprogram of the given Name: a line that
   --  starts (after an optional overriding prefix) with "procedure" /
   --  "function", followed by the exact Name and a non-identifier
   --  character (or end of line), so "Move_Cursor" never matches
   --  "Move_Cursor_To".  Same name-matching rule as Apply_Patches.
   function Decl_Name_At (Line : String; Name : String) return Boolean is
      T : constant String := Trim (Line, Ada.Strings.Both);
      P : Natural := T'First;
   begin
      if T'Length >= 15 and then T (T'First .. T'First + 14) = "not overriding"
      then
         P := T'First + 15;
      elsif T'Length >= 10 and then T (T'First .. T'First + 9) = "overriding"
      then
         P := T'First + 10;
      end if;
      while P <= T'Last and then T (P) = ' ' loop
         P := P + 1;
      end loop;
      if T'Last - P + 1 >= 10 and then T (P .. P + 9) = "procedure " then
         P := P + 10;
      elsif T'Last - P + 1 >= 9 and then T (P .. P + 8) = "function " then
         P := P + 9;
      else
         return False;
      end if;
      if T'Last - P + 1 < Name'Length then
         return False;
      end if;
      for I in Name'Range loop
         if T (P + (I - Name'First)) /= Name (I) then
            return False;
         end if;
      end loop;
      if P + Name'Length <= T'Last then
         declare
            C : constant Character := T (P + Name'Length);
         begin
            return
              not (C in 'a' .. 'z'
                   or else C in 'A' .. 'Z'
                   or else C in '0' .. '9'
                   or else C = '_');
         end;
      end if;
      return True;
   end Decl_Name_At;

   --  Normalized parameter profile of the declaration whose span starts at
   --  Start and ends at Span_End: the text from the first '(' after the
   --  subprogram name through its matching ')', with all whitespace
   --  removed.  A parameterless declaration yields "".  Scans only within
   --  the declaration span so a parameterless Reset never picks up the
   --  parentheses of a later sibling declaration.  Used to match a patch
   --  entry to the exact overload it re-declares -- a patched
   --  two-argument Scroll_Screen replaces the two-argument original,
   --  never a same-named sibling.
   function Param_Profile
     (Text : String; Start : Natural; Span_End : Natural) return String
   is
      Open  : Natural := 0;
      Depth : Natural := 0;
      Close : Natural := 0;
   begin
      for I in Start .. Span_End loop
         if Text (I) = '(' then
            Open := I;
            exit;
         end if;
      end loop;
      if Open = 0 then
         return "";
      end if;
      for I in Open .. Span_End loop
         if Text (I) = '(' then
            Depth := Depth + 1;
         elsif Text (I) = ')' then
            if Depth = 1 then
               Close := I;
               exit;
            end if;
            Depth := Depth - 1;
         end if;
      end loop;
      if Close = 0 then
         return "";
      end if;
      declare
         Res : String (1 .. (Close - Open - 1));
         N   : Natural := 0;
      begin
         for I in Open + 1 .. Close - 1 loop
            if Text (I) /= ' '
              and then Text (I) /= ASCII.CR
              and then Text (I) /= ASCII.LF
              and then Text (I) /= ASCII.HT
            then
               N := N + 1;
               Res (N) := Text (I);
            end if;
         end loop;
         return Res (1 .. N);
      end;
   end Param_Profile;

   --  True when the profile of the original declaration at Line_Start
   --  (span ending at Span_End) equals Ref's profile (same parameter
   --  list, whitespace-insensitive).
   function Ref_Profile_Matches
     (Original   : String;
      Line_Start : Natural;
      Span_End   : Natural;
      Ref        : Subprog_Ref) return Boolean
   is
      O : constant String := Param_Profile (Original, Line_Start, Span_End);
   begin
      if Ref.Profile_Too_Long then
         return False;
      end if;
      if O'Length /= Ref.Profile_Len then
         return False;
      end if;
      for I in 1 .. O'Length loop
         if O (I) /= Ref.Profile (I) then
            return False;
         end if;
      end loop;
      return True;
   end Ref_Profile_Matches;

   --  True when Line starts a subprogram declaration (any name) -- used to
   --  pre-scan the patch for declarations that carry aspects.
   function Is_Subprog_Decl (Line : String) return Boolean is
      T : constant String := Trim (Line, Ada.Strings.Both);
      P : Natural := T'First;
   begin
      if T'Length >= 15 and then T (T'First .. T'First + 14) = "not overriding"
      then
         P := T'First + 15;
      elsif T'Length >= 10 and then T (T'First .. T'First + 9) = "overriding"
      then
         P := T'First + 10;
      end if;
      while P <= T'Last and then T (P) = ' ' loop
         P := P + 1;
      end loop;
      return
        (T'Last - P + 1 >= 10 and then T (P .. P + 9) = "procedure ")
        or else (T'Last - P + 1 >= 9 and then T (P .. P + 8) = "function ");
   end Is_Subprog_Decl;

   --  Identifier of the subprogram declared by Line (the token after
   --  "procedure"/"function").  Only valid when Is_Subprog_Decl is True.
   procedure Subprog_Name
     (Line : String; Name : out String; Name_Len : out Natural)
   is
      T : constant String := Trim (Line, Ada.Strings.Both);
      P : Natural := T'First;
      S : Natural;
      E : Natural;
   begin
      Name_Len := 0;
      if T'Length >= 15 and then T (T'First .. T'First + 14) = "not overriding"
      then
         P := T'First + 15;
      elsif T'Length >= 10 and then T (T'First .. T'First + 9) = "overriding"
      then
         P := T'First + 10;
      end if;
      while P <= T'Last and then T (P) = ' ' loop
         P := P + 1;
      end loop;
      if T'Last - P + 1 >= 10 and then T (P .. P + 9) = "procedure " then
         P := P + 10;
      elsif T'Last - P + 1 >= 9 and then T (P .. P + 8) = "function " then
         P := P + 9;
      else
         return;
      end if;
      S := P;
      E := P;
      while E <= T'Last
        and then (T (E) in 'a' .. 'z'
                  or else T (E) in 'A' .. 'Z'
                  or else T (E) in '0' .. '9'
                  or else T (E) = '_')
      loop
         E := E + 1;
      end loop;
      E := E - 1;
      if E >= S then
         Name_Len := Natural'Min (E - S + 1, Name'Length);
         for I in 1 .. Name_Len loop
            Name (I) := T (S + I - 1);
         end loop;
      end if;
   end Subprog_Name;

   --  Position of the last character of the line that terminates the
   --  declaration starting at Start: the first line (at paren depth 0)
   --  whose trimmed text ends with ';'.  Aspect clauses and multi-line
   --  parameter lists stay inside the span because their parentheses
   --  balance before the final ';'.  The span text is therefore
   --  Text (Start .. Decl_Span_End), with no trailing line terminator.
   function Decl_Span_End (Text : String; Start : Natural) return Natural is
      Pos    : Natural := Start;
      Depth  : Integer := 0;
      L1, L2 : Natural;
      Next   : Natural;
   begin
      loop
         Next_Line_Bounds (Text, Pos, L1, L2, Next);
         if L2 < L1 then
            --  Reached end of text without a terminator: the span ends at
            --  the last character.
            return Text'Last;
         end if;
         declare
            Line : constant String := Text (L1 .. L2);
         begin
            for I in Line'Range loop
               if Line (I) = '(' then
                  Depth := Depth + 1;
               elsif Line (I) = ')' and then Depth > 0 then
                  Depth := Depth - 1;
               end if;
            end loop;
            declare
               T : constant String := Trim (Line, Ada.Strings.Both);
            begin
               if Depth = 0 and then T'Length > 0 and then T (T'Last) = ';'
               then
                  return L2;
               end if;
            end;
         end;
         Pos := Next;
      end loop;
   end Decl_Span_End;

   --  True when Line is the package declaration line ("package <Name> is",
   --  with or without an existing aspect clause).
   function Is_Package_Decl (Line : String) return Boolean is
      T : constant String := Trim (Line, Ada.Strings.Both);
   begin
      return
        T'Length >= 9
        and then T (T'First .. T'First + 7) = "package "
        and then Index (T, " is") > 0;
   end Is_Package_Decl;

   --  Append S and a line terminator to Dst at cursor C; OK False when the
   --  fixed buffer would overflow (fail loudly, never truncate).
   procedure Emit_Line
     (Dst : in out String; C : in out Natural; S : String; OK : in out Boolean)
   is
   begin
      if C + S'Length + 1 > Dst'Last then
         OK := False;
         return;
      end if;
      for I in S'Range loop
         C := C + 1;
         Dst (C) := S (I);
      end loop;
      C := C + 1;
      Dst (C) := ASCII.LF;
      OK := True;
   end Emit_Line;

   procedure Apply
     (Original   : String;
      Patch      : String;
      Merged     : out String;
      Merged_Len : out Natural;
      OK         : out Boolean)
   is
      Refs       : Subprog_Refs;
      Ref_Ct     : Natural := 0;
      Pkg_Aspect : String (1 .. Types.Max_Line);
      Pkg_Len    : Natural := 0;
      Pos        : Natural := Patch'First;
      L1, L2, Nx : Natural;
      C          : Natural := 0;
   begin
      Merged_Len := 0;
      OK := False;

      --  Pre-scan the patch: the package-level aspect (if any) and every
      --  subprogram declaration that carries an aspect clause.
      while Pos <= Patch'Last loop
         Next_Line_Bounds (Patch, Pos, L1, L2, Nx);
         declare
            Line : constant String := Patch (L1 .. L2);
         begin
            if Is_Package_Decl (Line) and then Index (Line, "with") > 0 then
               declare
                  W : constant Natural := Index (Line, "with");
                  I : Natural := W + 4;
               begin
                  --  The aspect text runs from "with" to the "is" word.
                  while I + 2 <= Line'Last
                    and then not (Line (I) = ' '
                                  and then Line (I + 1) = 'i'
                                  and then Line (I + 2) = 's')
                  loop
                     I := I + 1;
                  end loop;
                  if I + 2 <= Line'Last then
                     Pkg_Len := Natural'Min (I - W, Pkg_Aspect'Length);
                     for J in 1 .. Pkg_Len loop
                        Pkg_Aspect (J) := Line (W + J - 1);
                     end loop;
                  end if;
               end;
            elsif Is_Subprog_Decl (Line) then
               if Ref_Ct < Max_Patch_Subprogs then
                  Ref_Ct := Ref_Ct + 1;
                  Subprog_Name
                    (Line, Refs (Ref_Ct).Name, Refs (Ref_Ct).Name_Len);
                  Refs (Ref_Ct).Start_Pos := L1;
                  Refs (Ref_Ct).End_Pos := Decl_Span_End (Patch, L1);
                  declare
                     Prof : constant String :=
                       Param_Profile (Patch, L1, Refs (Ref_Ct).End_Pos);
                  begin
                     if Prof'Length > Refs (Ref_Ct).Profile'Length then
                        --  Over-long parameter list: the ref can never
                        --  match, so Apply's unused-ref check reports it.
                        Refs (Ref_Ct).Profile_Too_Long := True;
                     else
                        Refs (Ref_Ct).Profile_Len := Prof'Length;
                        for J in 1 .. Prof'Length loop
                           Refs (Ref_Ct).Profile (J) := Prof (J);
                        end loop;
                     end if;
                  end;
                  --  Only subprograms re-declared WITH aspects are patched;
                  --  a docstring-only mirror entry leaves the original
                  --  declaration untouched.
                  if Index
                       (Patch
                          (Refs (Ref_Ct).Start_Pos
                           .. Refs (Ref_Ct).End_Pos - 1),
                        "with")
                    = 0
                  then
                     Ref_Ct := Ref_Ct - 1;
                  end if;
               end if;
            end if;
         end;
         Pos := Nx;
      end loop;

      if Pkg_Len = 0 and then Ref_Ct = 0 then
         --  No proof aspects anywhere: the merge is the original unchanged.
         if Original'Length > Merged'Last then
            return;
         end if;
         for I in Original'Range loop
            C := C + 1;
            Merged (C) := Original (I);
         end loop;
         Merged_Len := C;
         OK := True;
         return;
      end if;

      --  Walk the original spec, replacing patched declarations and
      --  splicing the package-level aspect.
      Pos := Original'First;
      while Pos <= Original'Last loop
         Next_Line_Bounds (Original, Pos, L1, L2, Nx);
         declare
            Line    : constant String := Original (L1 .. L2);
            Emitted : Boolean := False;
            New_Pos : Natural := Nx;
         begin
            if Pkg_Len > 0
              and then Is_Package_Decl (Line)
              and then Index (Line, "with") = 0
            then
               declare
                  Ipos : Natural := Line'First;
               begin
                  --  Locate the "is" word in the original package line.
                  while Ipos + 2 <= Line'Last
                    and then not (Line (Ipos) = ' '
                                  and then Line (Ipos + 1) = 'i'
                                  and then Line (Ipos + 2) = 's')
                  loop
                     Ipos := Ipos + 1;
                  end loop;
                  if Ipos + 2 <= Line'Last then
                     Emit_Line
                       (Merged,
                        C,
                        Line (Line'First .. Ipos - 1)
                        & " "
                        & Pkg_Aspect (1 .. Pkg_Len)
                        & " "
                        & Line (Ipos + 1 .. Line'Last),
                        OK);
                     if OK then
                        Emitted := True;
                     end if;
                  end if;
               end;
            end if;

            if not Emitted then
               for R in 1 .. Ref_Ct loop
                  if not Refs (R).Used
                    and then Decl_Name_At
                               (Line, Refs (R).Name (1 .. Refs (R).Name_Len))
                    and then Ref_Profile_Matches
                               (Original,
                                L1,
                                Decl_Span_End (Original, L1),
                                Refs (R))
                  then
                     Emit_Line
                       (Merged,
                        C,
                        Patch (Refs (R).Start_Pos .. Refs (R).End_Pos),
                        OK);
                     if OK then
                        Refs (R).Used := True;
                        New_Pos := Decl_Span_End (Original, L1);
                        if New_Pos < Original'Last
                          and then Original (New_Pos + 1) = ASCII.LF
                        then
                           New_Pos := New_Pos + 2;
                        else
                           New_Pos := New_Pos + 1;
                        end if;
                        Emitted := True;
                     end if;
                     exit;
                  end if;
               end loop;
            end if;

            if not Emitted then
               Emit_Line (Merged, C, Line, OK);
            end if;
            if not OK then
               return;
            end if;
            Pos := New_Pos;
         end;
      end loop;

      --  Every patched subprogram must have matched a declaration in the
      --  original; a stray patch entry fails loudly instead of silently
      --  dropping the contract.
      for R in 1 .. Ref_Ct loop
         if not Refs (R).Used then
            OK := False;
            return;
         end if;
      end loop;

      Merged_Len := C;
      OK := True;
   end Apply;

   --  Read a text file into Buf (with trailing LF after each line).
   --  Fails loudly when the file exceeds the buffer.
   procedure Read_Text_File
     (Path : String; Buf : out String; Len : out Natural; OK : out Boolean)
   is
      use Ada.Text_IO;
      F : File_Type;
      C : Natural := 0;
   begin
      Len := 0;
      OK := False;
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            L : constant String := Get_Line (F);
         begin
            if C + L'Length + 1 > Buf'Last then
               Close (F);
               return;
            end if;
            for I in L'Range loop
               C := C + 1;
               Buf (C) := L (I);
            end loop;
            C := C + 1;
            Buf (C) := ASCII.LF;
         end;
      end loop;
      Close (F);
      Len := C;
      OK := True;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Read_Text_File;

   --  Byte-exact file copy via Stream_IO.
   procedure Copy_File (Src : String; Dst : String; OK : out Boolean) is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      In_F, Out_F : File_Type;
      Buf         : Stream_Element_Array (1 .. 65_536);
      Last        : Stream_Element_Offset;
   begin
      OK := False;
      Open (In_F, In_File, Src);
      Create (Out_F, Out_File, Dst);
      loop
         Read (In_F, Buf, Last);
         exit when Last < Buf'First;
         Write (Out_F, Buf (Buf'First .. Last));
      end loop;
      Close (Out_F);
      Close (In_F);
      OK := True;
   exception
      when others =>
         if Is_Open (In_F) then
            Close (In_F);
         end if;
         if Is_Open (Out_F) then
            Close (Out_F);
         end if;
   end Copy_File;

   --  Recursively delete a directory tree.
   procedure Delete_Tree (Dir : String) is
      use Ada.Directories;
      Srch : Search_Type;
      Ent  : Directory_Entry_Type;
   begin
      if not Exists (Dir) then
         return;
      end if;
      Start_Search (Srch, Dir, "");
      while More_Entries (Srch) loop
         Get_Next_Entry (Srch, Ent);
         declare
            N : constant String := Simple_Name (Ent);
         begin
            if N /= "." and then N /= ".." then
               if Kind (Ent) = Directory then
                  Delete_Tree (Full_Name (Ent));
               else
                  Delete_File (Full_Name (Ent));
               end if;
            end if;
         end;
      end loop;
      End_Search (Srch);
      Delete_Directory (Dir);
   exception
      when others =>
         null;
   end Delete_Tree;

   --  Copy a directory tree, skipping .git / obj / .adacovex at any depth
   --  (the same always-excluded set the scanner and proof hash use).
   procedure Copy_Tree (Src : String; Dst : String; Skipped : in out Natural)
   is
      use Ada.Directories;

      function Skip (Name : String) return Boolean is
      begin
         return Name = ".git" or else Name = "obj" or else Name = ".adacovex";
      end Skip;

      Srch : Search_Type;
      Ent  : Directory_Entry_Type;
      OK   : Boolean;
   begin
      if not Exists (Src) or else Kind (Src) /= Directory then
         return;
      end if;
      Create_Path (Dst);
      Start_Search (Srch, Src, "");
      while More_Entries (Srch) loop
         Get_Next_Entry (Srch, Ent);
         declare
            N : constant String := Simple_Name (Ent);
         begin
            if N /= "." and then N /= ".." and then not Skip (N) then
               if Kind (Ent) = Directory then
                  Copy_Tree (Full_Name (Ent), Dst & "/" & N, Skipped);
               else
                  Copy_File (Full_Name (Ent), Dst & "/" & N, OK);
                  if not OK then
                     Skipped := Skipped + 1;
                  end if;
               end if;
            end if;
         end;
      end loop;
      End_Search (Srch);
   exception
      when others =>
         null;
   end Copy_Tree;

   --  Relative path of File under Root ("" when File is not under Root).
   function Relative_Path (File, Root : String) return String is
   begin
      if File'Length > Root'Length + 1
        and then File (File'First .. File'First + Root'Length - 1) = Root
        and then File (File'First + Root'Length) = '/'
      then
         return File (File'First + Root'Length + 1 .. File'Last);
      end if;
      return "";
   end Relative_Path;

   --  Walk <root>/.adacovex/patches/ recursively; apply Proc to each file
   --  (Full path and its path relative to the patches root).  The base
   --  root stays fixed across recursion so nested patch files report paths
   --  like "demo/deps/vt100/vt100.ads" rather than the basename only --
   --  the merge engine resolves the original source via that relative path.
   procedure Walk_Patches
     (Root : String; Proc : access procedure (File, Rel : String))
   is
      use Ada.Directories;
      Base : constant String := Root;

      procedure Walk (Dir : String) is
         Srch : Search_Type;
         Ent  : Directory_Entry_Type;
      begin
         Start_Search (Srch, Dir, "");
         while More_Entries (Srch) loop
            Get_Next_Entry (Srch, Ent);
            declare
               N : constant String := Simple_Name (Ent);
            begin
               if N /= "." and then N /= ".." then
                  if Kind (Ent) = Directory then
                     Walk (Full_Name (Ent));
                  else
                     Proc.all
                       (Full_Name (Ent),
                        Relative_Path (Full_Name (Ent), Base));
                  end if;
               end if;
            end;
         end loop;
         End_Search (Srch);
      end Walk;
   begin
      if not Exists (Root) then
         return;
      end if;
      Walk (Root);
   exception
      when others =>
         null;
   end Walk_Patches;

   function Count_Proof_Patches (Target_Dir : String) return Natural is
      Root    : constant String := Target_Dir & "/.adacovex/patches";
      Count   : Natural := 0;
      Buf     : String (1 .. Types.Max_Line);
      Len     : Natural := 0;
      Is_File : Boolean;

      procedure Consider (File : String; Rel : String) is
         pragma Unreferenced (Rel);
      begin
         if File'Length >= 4
           and then File (File'Last - 3 .. File'Last) = ".ads"
         then
            Read_Text_File (File, Buf, Len, Is_File);
            if Is_File and then Has_Proof (Buf (1 .. Len)) then
               Count := Count + 1;
            end if;
         end if;
      end Consider;
   begin
      Walk_Patches (Root, Consider'Access);
      return Count;
   end Count_Proof_Patches;

   function Patches_Hash (Target_Dir : String) return String is
      Root : constant String := Target_Dir & "/.adacovex/patches";
      Comb : String (1 .. 64) := (others => ' ');
      Has  : Boolean := False;

      procedure Fold (File : String; Rel : String) is
         pragma Unreferenced (Rel);
      begin
         Comb :=
           Adacovex.Cache.Hash_String (Comb & Adacovex.Cache.Hash_File (File));
         Has := True;
      end Fold;
   begin
      Walk_Patches (Root, Fold'Access);
      if Has then
         return Comb;
      end if;
      return "";
   end Patches_Hash;

   procedure Build_Patched_Copy
     (Target_Dir : String;
      Root_GPR   : String;
      Copy_Dir   : out String;
      Copy_Len   : out Natural;
      Copy_GPR   : out String;
      GPR_Len    : out Natural;
      Success    : out Boolean)
   is
      use Ada.Directories;
      Dst      : constant String := Target_Dir & "/obj/adacovex-proof";
      Skipped  : Natural := 0;
      Base     : String (1 .. Types.Max_Filename);
      Base_Len : Natural := 0;
      I        : Natural := Root_GPR'Last;
   begin
      Copy_Len := 0;
      GPR_Len := 0;
      Success := False;

      --  Rebuild the patched tree from scratch so stale merged specs from a
      --  previous patch set can never leak into a run.
      Delete_Tree (Dst);
      Copy_Tree (Target_Dir, Dst, Skipped);

      --  Apply the proof patches: overwrite each proof-carrying spec in the
      --  copy with its merged form.
      declare
         P_Root : constant String := Target_Dir & "/.adacovex/patches";
         OBuf   : String (1 .. Types.Max_Line);
         OLen   : Natural := 0;
         PBuf   : String (1 .. Types.Max_Line);
         PLen   : Natural := 0;
         MBuf   : String (1 .. Types.Max_Line);
         MLen   : Natural := 0;
         R1, R2 : Boolean;

         procedure Merge_One (File : String; Rel : String) is
            Orig : constant String := Target_Dir & "/" & Rel;
            DstF : constant String := Dst & "/" & Rel;
         begin
            if File'Length < 4
              or else File (File'Last - 3 .. File'Last) /= ".ads"
            then
               return;
            end if;
            Read_Text_File (File, PBuf, PLen, R1);
            if not R1 or else not Has_Proof (PBuf (1 .. PLen)) then
               return;
            end if;
            if not Exists (Orig) then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "  ERROR: proof patch '"
                  & Rel
                  & "' has no matching source file under the target;"
                  & " patch skipped");
               return;
            end if;
            Read_Text_File (Orig, OBuf, OLen, R1);
            if not R1 then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "  ERROR: could not read '"
                  & Rel
                  & "' for proof patching; patch skipped");
               return;
            end if;
            Apply (OBuf (1 .. OLen), PBuf (1 .. PLen), MBuf, MLen, R2);
            if not R2 then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "  ERROR: proof patch '"
                  & Rel
                  & "' could not be merged into the vendored spec"
                  & " (unmatched subprogram or oversized file); patch"
                  & " skipped");
               return;
            end if;
            declare
               F          : Ada.Text_IO.File_Type;
               Last_Slash : Natural := 0;
            begin
               --  Create the patch's parent directory inside the copy
               --  (matching the original's sub-tree layout).
               for J in Rel'Range loop
                  if Rel (J) = '/' then
                     Last_Slash := J;
                  end if;
               end loop;
               if Last_Slash > 0 then
                  Create_Path (Dst & "/" & Rel (Rel'First .. Last_Slash - 1));
               else
                  Create_Path (Dst);
               end if;
               Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, DstF);
               for J in 1 .. MLen loop
                  Ada.Text_IO.Put (F, MBuf (J));
               end loop;
               Ada.Text_IO.Close (F);
            exception
               when others =>
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "  ERROR: could not write patched spec '" & DstF & "'");
            end;
         end Merge_One;

      begin
         Walk_Patches (P_Root, Merge_One'Access);
      end;

      --  Root project file of the copy: same file name as the original
      --  root project (the copy preserves the tree layout).
      while I >= Root_GPR'First and then Root_GPR (I) /= '/' loop
         I := I - 1;
      end loop;
      if I < Root_GPR'First then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  ERROR: root project path has no directory component: "
            & Root_GPR);
         return;
      end if;
      Base_Len := Root_GPR'Last - I;
      for J in 1 .. Base_Len loop
         Base (J) := Root_GPR (I + J);
      end loop;

      Copy_Len := Dst'Length;
      for J in 1 .. Copy_Len loop
         Copy_Dir (J) := Dst (Dst'First + J - 1);
      end loop;
      GPR_Len := Dst'Length + 1 + Base_Len;
      for J in 1 .. Dst'Length loop
         Copy_GPR (J) := Dst (Dst'First + J - 1);
      end loop;
      Copy_GPR (Dst'Length + 1) := '/';
      for J in 1 .. Base_Len loop
         Copy_GPR (Dst'Length + 1 + J) := Base (J);
      end loop;

      Success := True;
   end Build_Patched_Copy;

end Adacovex.Prove_Patch;
