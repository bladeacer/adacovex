with Ada.Text_IO;
--  SPDX-License-Identifier: Apache-2.0
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
        or else
        (TL >= 7 and then Trim (1 .. 7) = "function")
        or else
        (TL >= 6 and then Trim (1 .. 6) = "generic");
   end Is_Subprogram_Decl;

   function Has_HLR_Tag (Line : String; Tag : out String; Tag_Len : out Natural) return Boolean is
      In_Comment : Boolean := False;
      H_Start    : Natural := 0;
      H_End      : Natural := 0;
   begin
      Tag_Len := 0;
      for I in Line'Range loop
         if not In_Comment then
            if I < Line'Last - 1 and then Line (I) = '-' and then Line (I + 1) = '-' then
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
            if I < Line'Last - 1 and then Line (I) = '-' and then Line (I + 1) = '-' then
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
      Pkg       : out Types.Package_Info;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F  : File_Type;
      Line : String (1 .. Types.Max_Line);
      Last : Natural;
      Pkg_Name : Types.Name_Field;
      Pkg_NLen : Natural := 0;
      HLR_Buf  : String (1 .. Types.Max_Id_Str);
      HLR_Len  : Natural;
      DT_Type  : String (1 .. 64);
      DT_Len   : Natural;
      DT_Value : String (1 .. Types.Max_Desc_Str);
      DV_Len   : Natural;
      Subp_Idx : Natural := 0;
      In_Subp  : Boolean := False;
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

         if Has_HLR_Tag (Line (1 .. Last), HLR_Buf, HLR_Len) then
            if Subp_Idx = 0 then
               if Pkg.Total_HLR_Tags < Types.Max_Hlrs then
                  Pkg.Total_HLR_Tags := Pkg.Total_HLR_Tags + 1;
                  declare
                     TI : constant Natural := Pkg.Total_HLR_Tags;
                  begin
                     for I in 1 .. HLR_Len loop
                        Pkg.HLR_Tags (TI).Tag (I) := HLR_Buf (I);
                     end loop;
                     Pkg.HLR_Tags (TI).Len := HLR_Len;
                  end;
               end if;
            end if;
         end if;

         if Is_Subprogram_Decl (Line (1 .. Last)) then
            if Subp_Idx < Types.Max_Subprogs then
               Subp_Idx := Subp_Idx + 1;
               In_Subp := True;

               declare
                  Trim : String (1 .. Last);
                  TL   : Natural := 0;
                  In_SName : Boolean := False;
                  SName : String (1 .. Types.Max_Desc_Str);
                  SNLen : Natural := 0;
                  Skip : Natural := 0;
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
                        if I + 8 <= TL and then Trim (I .. I + 8) = "procedure" then
                           Skip := 8;
                        elsif I + 7 <= TL and then Trim (I .. I + 7) = "function" then
                           Skip := 7;
                        elsif I + 6 <= TL and then Trim (I .. I + 6) = "generic" then
                           Skip := 6;
                        elsif Trim (I) in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' then
                           In_SName := True;
                           SNLen := 1;
                           SName (SNLen) := Trim (I);
                        end if;
                     elsif Trim (I) in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' then
                        SNLen := SNLen + 1;
                        SName (SNLen) := Trim (I);
                     else
                        exit;
                     end if;
                  end loop;

                  Pkg.Subprogram_List (Subp_Idx).Name_Len := SNLen;
                  for J in 1 .. SNLen loop
                     Pkg.Subprogram_List (Subp_Idx).Name (J) := SName (J);
                  end loop;
               end;
            end if;
         end if;

         if Has_Docstring_Tag (Line (1 .. Last), DT_Type, DT_Len, DT_Value, DV_Len) then
            if Subp_Idx > 0 then
               if DT_Len >= 5 and then DT_Type (1 .. 5) = "param" then
                  Pkg.Subprogram_List (Subp_Idx).Has_Docstring := True;
                  Pkg.Subprogram_List (Subp_Idx).Doc_Param_Ct :=
                    Pkg.Subprogram_List (Subp_Idx).Doc_Param_Ct + 1;
               elsif DT_Len >= 6 and then DT_Type (1 .. 6) = "return" then
                  Pkg.Subprogram_List (Subp_Idx).Has_Docstring := True;
                  Pkg.Subprogram_List (Subp_Idx).Doc_Return := True;
               elsif DT_Len >= 5 and then DT_Type (1 .. 5) = "field" then
                  Pkg.Subprogram_List (Subp_Idx).Has_Docstring := True;
               elsif DT_Len >= 6 and then DT_Type (1 .. 6) = "formal" then
                  null;
               end if;
            end if;
         end if;
      end loop;

      Close (F);

      Pkg.Subprogram_Count := Subp_Idx;
      Success := True;
   end Scan_Ads_File;

   procedure Scan_Project
     (Target_Dir : String;
      Packages   : out Types.Package_Array;
      Pkg_Count  : out Natural)
   is
      Scan_Success : Boolean;

      procedure Search_Dir (Dir : String) is
         use Ada.Directories;
         Search : Search_Type;
         Ent    : Directory_Entry_Type;
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
                  if Name /= "." and Name /= ".." and Name /= ".git" and Name /= "obj" then
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
                     if Dot > 0 and then Name (Dot .. Name'Last) = ".ads" then
                        if Pkg_Count < Types.Max_Packages then
                           Pkg_Count := Pkg_Count + 1;
                           Scan_Ads_File (Path, Packages (Pkg_Count), OK);
                        end if;
                     end if;
                  end;
               end if;
            end;
         end loop;
         End_Search (Search);
      end Search_Dir;

   begin
      Pkg_Count := 0;
      Search_Dir (Target_Dir);
   end Scan_Project;

   function Compute_Docstring_Metrics
     (Packages  : Types.Package_Array;
      Pkg_Count : Natural) return Types.Docstring_Metrics
   is
      Metrics : Types.Docstring_Metrics;
   begin
      for P in 1 .. Pkg_Count loop
         for S in 1 .. Packages (P).Subprogram_Count loop
            Metrics.Total_Subprograms := Metrics.Total_Subprograms + 1;
            if Packages (P).Subprogram_List (S).Has_Docstring then
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
