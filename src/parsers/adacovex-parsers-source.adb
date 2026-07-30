with Ada.Text_IO;
with Ada.Directories;

package body Adacovex.Parsers.Source is

   function Is_Subprogram_Decl (Line : String) return Boolean is
      Trim : String (1 .. Line'Length);
      TL   : Natural := 0;
   begin
      for I in Line'Range loop
         if Line (I) /= ' ' then
            TL := TL + 1;
            Trim (TL) := Line (I);
         end if;
      end loop;
      return
        (TL >= 9 and then Trim (1 .. 9) = "procedure")
        or else (TL >= 8 and then Trim (1 .. 8) = "function")
        or else (TL >= 15 and then Trim (1 .. 15) = "genericprocedure")
        or else (TL >= 14 and then Trim (1 .. 14) = "genericfunction");
   end Is_Subprogram_Decl;

   function Has_HLR_Tag
     (Line : String; Tag : out String; Tag_Len : out Natural) return Boolean
   is
      In_Comment : Boolean := False;
      H_Start    : Natural := 0;
      H_End      : Natural := 0;
   begin
      Tag_Len := 0;
      for I in Line'Range loop
         if not In_Comment then
            if I < Line'Last - 1
              and then Line (I) = '-'
              and then Line (I + 1) = '-'
            then
               In_Comment := True;
            end if;
         else
            if Line (I) = '-' then
               null;
            elsif Line (I) = ' ' then
               null;
            else
               for J in I .. Line'Last - 3 loop
                  if Line (J) = 'H' and then Line (J .. J + 3) = "HLR-" then
                     H_Start := J;
                     exit;
                  end if;
               end loop;

               if H_Start > 0 then
                  for J in H_Start + 4 .. Line'Last loop
                     if Line (J) = ' ' or else Line (J) = ':' then
                        H_End := J - 1;
                        exit;
                     end if;
                     if J = Line'Last then
                        H_End := J;
                     end if;
                  end loop;

                  if H_End > H_Start + 3 then
                     Tag_Len := H_End - (H_Start + 4) + 1;
                     declare
                        Valid : Boolean := True;
                     begin
                        for CI in 1 .. Tag_Len loop
                           declare
                              C : constant Character :=
                                Line (H_Start + 4 + CI - 1);
                           begin
                              if C not in 'A' .. 'Z'
                                and then C not in '0' .. '9'
                                and then C /= '-'
                              then
                                 Valid := False;
                                 exit;
                              end if;
                           end;
                        end loop;
                        if not Valid then
                           return False;
                        end if;
                     end;
                     for J in 1 .. Tag_Len loop
                        Tag (J) := Line (H_Start + 4 + J - 1);
                     end loop;
                     return True;
                  end if;
               end if;
               return False;
            end if;
         end if;
      end loop;
      return False;
   end Has_HLR_Tag;

   function Has_Docstring_Tag
     (Line    : String;
      Dtype   : out String;
      Dtype_L : out Natural;
      Value   : out String;
      Val_L   : out Natural) return Boolean
   is
      In_Comment : Boolean := False;
      Start      : Natural := 0;
   begin
      Dtype_L := 0;
      Val_L := 0;
      for I in Line'Range loop
         if not In_Comment then
            if I < Line'Last - 1
              and then Line (I) = '-'
              and then Line (I + 1) = '-'
            then
               In_Comment := True;
            end if;
         else
            if Line (I) = '@' then
               Start := I + 1;
               for J in Start .. Line'Last loop
                  if Line (J) = ' ' then
                     Dtype_L := J - Start;
                     for K in 1 .. Dtype_L loop
                        Dtype (K) := Line (Start + K - 1);
                     end loop;
                     for K in J + 1 .. Line'Last loop
                        if Line (K) /= ' ' then
                           Val_L := Line'Last - K + 1;
                           for L in 1 .. Val_L loop
                              Value (L) := Line (K + L - 1);
                           end loop;
                           exit;
                        end if;
                     end loop;
                     return True;
                  end if;
                  if J = Line'Last then
                     Dtype_L := J - Start + 1;
                     for K in 1 .. Dtype_L loop
                        Dtype (K) := Line (Start + K - 1);
                     end loop;
                     return True;
                  end if;
               end loop;
            end if;
         end if;
      end loop;
      return False;
   end Has_Docstring_Tag;

   procedure Scan_Ads_File
     (File_Path : String;
      Pkg       : out Types.Implementation.Package_Info;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Pkg_Name : Types.Name_Field;
      Pkg_NLen : Natural := 0;
      HLR_Buf  : String (1 .. Types.Max_Id_Str);
      HLR_Len  : Natural;
      DT_Type  : String (1 .. 64);
      DT_Len   : Natural;
      DT_Value : String (1 .. Types.Max_Desc_Str);
      DV_Len   : Natural;
      Line_Num : Natural := 0;
      In_Subp  : Boolean := False;

      Pending_Has_Doc    : Boolean := False;
      Pending_Param_Ct   : Natural := 0;
      Pending_Has_Return : Boolean := False;

      procedure Flush_Pending is
      begin
         if Pending_Has_Doc and then Integer (Pkg.Subprograms.Length) > 0 then
            declare
               Idx : constant Positive := Positive (Pkg.Subprograms.Length);
            begin
               declare
                  Subp : Types.Subprogram_Info := Pkg.Subprograms (Idx);
               begin
                  Subp.Has_Docstring := True;
                  Subp.Doc_Param_Ct := Subp.Doc_Param_Ct + Pending_Param_Ct;
                  if Pending_Has_Return then
                     Subp.Doc_Return := True;
                  end if;
                  Pkg.Subprograms.Replace_Element (Idx, Subp);
               end;
            end;
            Pending_Has_Doc := False;
            Pending_Param_Ct := 0;
            Pending_Has_Return := False;
         end if;
      end Flush_Pending;
   begin
      Pkg := (others => <>);

      -- Extract package name from path
      declare
         Base : constant String := Ada.Directories.Simple_Name (File_Path);
      begin
         Pkg_NLen := 0;
         for I in Base'Range loop
            if Base (I) = '.' then
               exit;
            end if;
            Pkg_NLen := Pkg_NLen + 1;
            Pkg_Name (Pkg_NLen) := Base (I);
         end loop;
      end;

      Pkg.Name_Len := Pkg_NLen;
      for I in 1 .. Pkg_NLen loop
         Pkg.Name (I) := Pkg_Name (I);
      end loop;
      Pkg.Path_Len := File_Path'Length;
      for I in File_Path'Range loop
         Pkg.File_Path (I - File_Path'First + 1) := File_Path (I);
      end loop;

      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      while not End_Of_File (F) loop
         Get_Line (F, Line, Last);
         Line_Num := Line_Num + 1;
         if Last = Types.Max_Line then
            declare
               Drain : String (1 .. Types.Max_Line);
               DLast : Natural;
            begin
               loop
                  Get_Line (F, Drain, DLast);
                  exit when DLast < Types.Max_Line;
               end loop;
            end;
         end if;

         if Has_HLR_Tag (Line (1 .. Last), HLR_Buf, HLR_Len) then
            if not In_Subp then
               declare
                  Elem : Types.HLR_Tag_Entry;
               begin
                  for I in 1 .. HLR_Len loop
                     Elem.Tag (I) := HLR_Buf (I);
                  end loop;
                  Elem.Len := HLR_Len;
                  Pkg.HLR_Tags.Append (Elem);
               end;
            end if;
         end if;

         if Is_Subprogram_Decl (Line (1 .. Last)) then
            Pkg.Subprograms.Append
              (New_Item => Types.Subprogram_Info'(others => <>));
            declare
               Subp_Idx : constant Positive :=
                 Positive (Pkg.Subprograms.Length);
            begin
               Pkg.Subprograms (Subp_Idx).Line_Number := Line_Num;
               Flush_Pending;
               In_Subp := True;

               declare
                  Trim     : String (1 .. Last);
                  TL       : Natural := 0;
                  In_SName : Boolean := False;
                  SName    : String (1 .. Types.Max_Desc_Str);
                  SNLen    : Natural := 0;
                  Skip     : Natural := 0;
               begin
                  for I in 1 .. Last loop
                     if Line (I) /= ' ' then
                        TL := TL + 1;
                        Trim (TL) := Line (I);
                     end if;
                  end loop;

                  for I in 1 .. TL loop
                     if Skip > 0 then
                        Skip := Skip - 1;
                     elsif not In_SName then
                        if I + 8 <= TL and then Trim (I .. I + 8) = "procedure"
                        then
                           Skip := 8;
                        elsif I + 7 <= TL
                          and then Trim (I .. I + 7) = "function"
                        then
                           Skip := 7;
                        elsif I + 6 <= TL
                          and then Trim (I .. I + 6) = "generic"
                        then
                           Skip := 6;
                        elsif Trim (I)
                              in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_'
                        then
                           In_SName := True;
                           SNLen := 1;
                           SName (SNLen) := Trim (I);
                        end if;
                     elsif Trim (I)
                           in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_'
                     then
                        SNLen := SNLen + 1;
                        SName (SNLen) := Trim (I);
                     else
                        exit;
                     end if;
                  end loop;

                  Pkg.Subprograms (Subp_Idx).Name_Len := SNLen;
                  for J in 1 .. SNLen loop
                     Pkg.Subprograms (Subp_Idx).Name (J) := SName (J);
                  end loop;
               end;
            end;
         end if;

         if Has_Docstring_Tag
              (Line (1 .. Last), DT_Type, DT_Len, DT_Value, DV_Len)
         then
            if DT_Len >= 5 and then DT_Type (1 .. 5) = "param" then
               Pending_Has_Doc := True;
               Pending_Param_Ct := Pending_Param_Ct + 1;
            elsif DT_Len >= 6 and then DT_Type (1 .. 6) = "return" then
               Pending_Has_Doc := True;
               Pending_Has_Return := True;
            elsif DT_Len >= 5 and then DT_Type (1 .. 5) = "field" then
               Pending_Has_Doc := True;
            elsif DT_Len >= 6 and then DT_Type (1 .. 6) = "formal" then
               null;
            end if;
         elsif Last >= 5 then
            for P in 1 .. Last - 3 loop
               if Line (P) = '-'
                 and Line (P + 1) = '-'
                 and Line (P + 2) = ' '
                 and Line (P + 3) = ' '
               then
                  for C in P + 4 .. Last loop
                     if Line (C) /= ' ' then
                        Pending_Has_Doc := True;
                        exit;
                     end if;
                  end loop;
                  exit;
               end if;
            end loop;
         end if;
      end loop;

      Flush_Pending;

      Close (F);

      Success := True;
   end Scan_Ads_File;

   function Is_Skipped_Dir (Name : String; Skip_List : String) return Boolean
   is
      Start : Natural := Skip_List'First;
   begin
      if Name'Length = 0 or else Skip_List'Length = 0 then
         return False;
      end if;
      loop
         declare
            End_Pos : Natural := Start;
            Seg     : String (1 .. Types.Max_Filename);
            Seg_Len : Natural := 0;
         begin
            while End_Pos <= Skip_List'Last and then Skip_List (End_Pos) /= ','
            loop
               if Seg_Len < Types.Max_Filename then
                  Seg_Len := Seg_Len + 1;
                  Seg (Seg_Len) := Skip_List (End_Pos);
               end if;
               End_Pos := End_Pos + 1;
            end loop;
            if Seg_Len = Name'Length then
               declare
                  Match : Boolean := True;
               begin
                  for I in 1 .. Seg_Len loop
                     if Seg (I) /= Name (Name'First + I - 1) then
                        Match := False;
                        exit;
                     end if;
                  end loop;
                  if Match then
                     return True;
                  end if;
               end;
            end if;
            exit when End_Pos >= Skip_List'Last;
            Start := End_Pos + 1;
         end;
      end loop;
      return False;
   end Is_Skipped_Dir;

   procedure Scan_Project
     (Target_Dir : String;
      Skip_List  : String;
      Packages   : in out Types.Implementation.Package_Vectors.Vector)
   is
      procedure Search_Dir (Dir : String) is
         use Ada.Directories;
         Search : Search_Type;
         Ent    : Directory_Entry_Type;
         Pkg    : Types.Implementation.Package_Info;
         OK     : Boolean;
      begin
         Start_Search (Search, Dir, "");
         while More_Entries (Search) loop
            Get_Next_Entry (Search, Ent);
            declare
               Name : constant String := Simple_Name (Ent);
               Path : constant String := Full_Name (Ent);
            begin
               if Kind (Ent) = Directory then
                  if Name /= "."
                    and Name /= ".."
                    and Name /= ".git"
                    and Name /= "obj"
                    and Name /= "tests"
                    and Name /= "config"
                    and Name /= ".adacovex"
                    and not Is_Skipped_Dir (Name, Skip_List)
                  then
                     Search_Dir (Path);
                  end if;
               elsif Kind (Ent) = Ordinary_File then
                  declare
                     Dot : Natural := 0;
                  begin
                     for I in reverse Name'Range loop
                        if Name (I) = '.' then
                           Dot := I;
                           exit;
                        end if;
                     end loop;
                     if Dot > 0
                       and then Name (Dot .. Name'Last) = ".ads"
                       and then (Name'Length < 3
                                 or else Name (Name'First .. Name'First + 2)
                                         /= "b__")
                     then
                        Scan_Ads_File (Path, Pkg, OK);
                        if OK then
                           Packages.Append (Pkg);
                        end if;
                     end if;
                  end;
               end if;
            end;
         end loop;
         End_Search (Search);
      end Search_Dir;

   begin
      Search_Dir (Target_Dir);
   end Scan_Project;

   function Is_Prefix (Pre, S : String) return Boolean is
   begin
      if Pre'Length > S'Length then
         return False;
      end if;
      for I in Pre'Range loop
         if Pre (I) /= S (S'First + (I - Pre'First)) then
            return False;
         end if;
      end loop;
      return True;
   end Is_Prefix;

   function Relative_Path (Full_Path, Root : String) return String is
   begin
      if Is_Prefix (Root, Full_Path)
        and then Full_Path'Length > Root'Length + 1
        and then Full_Path (Root'Length + 1) = '/'
      then
         return Full_Path (Root'Length + 2 .. Full_Path'Last);
      end if;
      return "";
   end Relative_Path;

   procedure Apply_Patches
     (Target_Dir : String;
      Packages   : in out Types.Implementation.Package_Vectors.Vector)
   is
      Patch_Dir : constant String := Target_Dir & "/.adacovex/patches";
      OK        : Boolean;
   begin
      if not Ada.Directories.Exists (Patch_Dir) then
         return;
      end if;
      for P in 1 .. Integer (Packages.Length) loop
         declare
            Pkg_Path : String renames
              Packages (P).File_Path (1 .. Packages (P).Path_Len);
            Rel      : constant String := Relative_Path (Pkg_Path, Target_Dir);
            Tmp_Pkg  : Types.Implementation.Package_Info;
            Pkg_Copy : Types.Implementation.Package_Info := Packages (P);
         begin
            if Rel'Length > 0 then
               declare
                  Patch : constant String := Patch_Dir & "/" & Rel;
               begin
                  if Ada.Directories.Exists (Patch) then
                     Scan_Ads_File (Patch, Tmp_Pkg, OK);
                     if OK and then Integer (Tmp_Pkg.Subprograms.Length) > 0
                     then
                        for S in 1 .. Integer (Tmp_Pkg.Subprograms.Length) loop
                           for O in 1 .. Integer (Pkg_Copy.Subprograms.Length)
                           loop
                              if Tmp_Pkg.Subprograms (S).Name_Len
                                = Pkg_Copy.Subprograms (O).Name_Len
                              then
                                 declare
                                    Matches : Boolean := True;
                                 begin
                                    for C in
                                      1 .. Tmp_Pkg.Subprograms (S).Name_Len
                                    loop
                                       if Tmp_Pkg.Subprograms (S).Name (C)
                                         /= Pkg_Copy.Subprograms (O).Name (C)
                                       then
                                          Matches := False;
                                          exit;
                                       end if;
                                    end loop;
                                    if Matches
                                      and then not Pkg_Copy.Subprograms (O)
                                                     .Has_Docstring
                                    then
                                       if Tmp_Pkg.Subprograms (S).Has_Docstring
                                       then
                                          Pkg_Copy.Subprograms (O)
                                            .Has_Docstring :=
                                            True;
                                          Pkg_Copy.Subprograms (O)
                                            .Doc_Param_Ct :=
                                            Tmp_Pkg.Subprograms (S)
                                              .Doc_Param_Ct;
                                          Pkg_Copy.Subprograms (O)
                                            .Doc_Return :=
                                            Tmp_Pkg.Subprograms (S).Doc_Return;
                                       end if;
                                       exit;
                                    end if;
                                 end;
                              end if;
                           end loop;
                        end loop;
                        Packages.Replace_Element (P, Pkg_Copy);
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Apply_Patches;

   function Compute_Docstring_Metrics
     (Packages : Types.Implementation.Package_Vectors.Vector)
      return Types.Docstring_Metrics
   is
      Metrics : Types.Docstring_Metrics;
   begin
      for P in 1 .. Integer (Packages.Length) loop
         for S in 1 .. Integer (Packages (P).Subprograms.Length) loop
            Metrics.Total_Subprograms := Metrics.Total_Subprograms + 1;
            if Packages (P).Subprograms (S).Has_Docstring then
               Metrics.Documented_Subprogs := Metrics.Documented_Subprogs + 1;
            end if;
         end loop;
      end loop;

      if Metrics.Total_Subprograms > 0 then
         Metrics.Coverage_Pct :=
           (Metrics.Documented_Subprogs * 100) / Metrics.Total_Subprograms;
      end if;

      return Metrics;
   end Compute_Docstring_Metrics;

end Adacovex.Parsers.Source;
