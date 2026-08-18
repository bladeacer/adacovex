with Ada.Text_IO;
with Adacovex.Cache;

package body Adacovex.Parsers.DO178C is

   --  On-disk serialization for the parsed HLR/LLR vectors, so an unchanged
   --  requirements document is served from the result cache without
   --  re-parsing (HLR-CACHE: HLR/LLR parse caching).
   package HLR_Store is new Adacovex.Cache.Serialization (HLR_Vectors.Vector);
   package LLR_Store is new Adacovex.Cache.Serialization (LLR_Vectors.Vector);

   --  Cache key for an HLR.md file: "hlr:" + SHA-256 of its contents.
   --  Returns "" when the file cannot be read (nothing to cache).
   --  @param File_Path  Path to HLR.md markdown file.
   --  @return Cache key, or "" when the file is unreadable.
   function HLR_Key (File_Path : String) return String is
      H : constant String := Adacovex.Cache.Hash_File (File_Path);
   begin
      if H'Length > 0 then
         return "hlr:" & H;
      end if;
      return "";
   end HLR_Key;

   --  Cache key for an LLR.md file: "llr:" + SHA-256 of its contents.
   --  @param File_Path  Path to LLR.md markdown file.
   --  @return Cache key, or "" when the file is unreadable.
   function LLR_Key (File_Path : String) return String is
      H : constant String := Adacovex.Cache.Hash_File (File_Path);
   begin
      if H'Length > 0 then
         return "llr:" & H;
      end if;
      return "";
   end LLR_Key;

   procedure Parse_HLR_MD
     (File_Path : String;
      HLRs      : in out HLR_Vectors.Vector;
      Success   : out Boolean;
      Use_Cache : Boolean := False)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
   begin
      --  Serve a previously parsed (unchanged) HLR.md straight from the
      --  on-disk result cache instead of re-scanning the file.
      if Use_Cache then
         declare
            K     : constant String := HLR_Key (File_Path);
            Blob  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
            Blen  : Natural;
            Found : Boolean;
         begin
            if K'Length > 0 then
               Adacovex.Cache.Get_Cached (K, Blob, Blen, Found);
               if Found then
                  HLRs.Clear;
                  if HLR_Store.Deserialize (Blob (1 .. Blen), HLRs) then
                     Success := True;
                     return;
                  end if;
               end if;
            end if;
         end;
      end if;

      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      begin
         while not End_Of_File (F) loop
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, File_Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line is drained and
               --  reported by Read_Line; parsing stops so no partial HLR set
               --  is passed downstream.
               HLRs.Clear;
               Close (F);
               Success := False;
               return;
            end if;

            -- Look for lines matching "- HLR_XXX: description"
            if Last > 6 then
               declare
                  H_Start : Natural := 0;
                  H_End   : Natural := 0;
                  Colon   : Natural := 0;
               begin
                  for I in 1 .. Last - 3 loop
                     if Line (I) = 'H' and then Line (I .. I + 3) = "HLR-" then
                        H_Start := I;
                        exit;
                     end if;
                  end loop;

                  if H_Start > 0 then
                     for I in H_Start + 4 .. Last loop
                        if Line (I) = ' ' or else Line (I) = ':' then
                           H_End := I - 1;
                           if Line (I) = ':' then
                              Colon := I;
                           end if;
                           exit;
                        end if;
                     end loop;

                     if Colon = 0 then
                        for I in H_End + 1 .. Last loop
                           if Line (I) = ':' then
                              Colon := I;
                              exit;
                           end if;
                        end loop;
                     end if;

                     if H_End > H_Start + 3 then
                        HLRs.Append (HLR_Info'(others => <>));
                        declare
                           Elem : HLR_Info := HLRs (Positive (HLRs.Length));
                        begin
                           Elem.Id_Len :=
                             Natural'Min
                               (H_End - (H_Start + 4) + 1, Elem.Id'Length);
                           for I in H_Start + 4 .. H_Start + 3 + Elem.Id_Len
                           loop
                              Elem.Id (I - (H_Start + 4) + 1) := Line (I);
                           end loop;

                           if Colon > 0 and then Colon < Last then
                              declare
                                 D_Start : Natural := Colon + 1;
                              begin
                                 while D_Start <= Last
                                   and then Line (D_Start) = ' '
                                 loop
                                    D_Start := D_Start + 1;
                                 end loop;
                                 Elem.D_Len :=
                                   Natural'Min
                                     (Last - D_Start + 1, Elem.Desc'Length);
                                 for I in D_Start .. D_Start + Elem.D_Len - 1
                                 loop
                                    Elem.Desc (I - D_Start + 1) := Line (I);
                                 end loop;
                              end;
                           end if;
                           HLRs.Replace_Element (Positive (HLRs.Length), Elem);
                        end;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      exception
         when others =>
            Close (F);
            raise;
      end;

      Close (F);
      Success := True;

      --  Store the freshly parsed vector for the next run (only on success,
      --  so a partial/empty parse is never cached).
      if Use_Cache then
         declare
            K  : constant String := HLR_Key (File_Path);
            OK : Boolean;
         begin
            if K'Length > 0 then
               declare
                  S_Blob : constant String := HLR_Store.Serialize (HLRs);
               begin
                  if S_Blob'Length > 0 then
                     Adacovex.Cache.Put_Cached (K, S_Blob, OK);
                  end if;
               end;
            end if;
         end;
      end if;
   end Parse_HLR_MD;

   procedure Parse_LLR_MD
     (File_Path : String;
      LLRs      : in out LLR_Vectors.Vector;
      Success   : out Boolean;
      Use_Cache : Boolean := False)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
   begin
      --  Serve a previously parsed (unchanged) LLR.md straight from the
      --  on-disk result cache instead of re-scanning the file.
      if Use_Cache then
         declare
            K     : constant String := LLR_Key (File_Path);
            Blob  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
            Blen  : Natural;
            Found : Boolean;
         begin
            if K'Length > 0 then
               Adacovex.Cache.Get_Cached (K, Blob, Blen, Found);
               if Found then
                  LLRs.Clear;
                  if LLR_Store.Deserialize (Blob (1 .. Blen), LLRs) then
                     Success := True;
                     return;
                  end if;
               end if;
            end if;
         end;
      end if;

      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      begin
         while not End_Of_File (F) loop
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, File_Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line is drained and
               --  reported by Read_Line; parsing stops so no partial LLR set
               --  is passed downstream.
               LLRs.Clear;
               Close (F);
               Success := False;
               return;
            end if;

            -- Look for lines matching "- LLR_XXX: description [HLR_XXX]"
            if Last > 6 then
               declare
                  L_Start : Natural := 0;
                  L_End   : Natural := 0;
                  Colon   : Natural := 0;
                  H_Start : Natural := 0;
                  H_End   : Natural := 0;
               begin
                  for I in 1 .. Last - 3 loop
                     if Line (I) = 'L'
                       and then I + 3 <= Last
                       and then Line (I .. I + 3) = "LLR-"
                     then
                        L_Start := I;
                        exit;
                     end if;
                  end loop;

                  if L_Start = 0 then
                     for I in 1 .. Last - 3 loop
                        if Line (I) = 'L'
                          and then I + 3 <= Last
                          and then (Line (I .. I + 3) = "LLR-")
                        then
                           L_Start := I;
                           exit;
                        end if;
                     end loop;
                  end if;

                  if L_Start > 0 then
                     for I in L_Start + 4 .. Last loop
                        if Line (I) = ' ' or else Line (I) = ':' then
                           L_End := I - 1;
                           if Line (I) = ':' then
                              Colon := I;
                           end if;
                           exit;
                        end if;
                     end loop;

                     if Colon = 0 then
                        for I in L_End + 1 .. Last loop
                           if Line (I) = ':' then
                              Colon := I;
                              exit;
                           end if;
                        end loop;
                     end if;

                     if Colon > 0 then
                        for I in Colon + 1 .. Last - 3 loop
                           if Line (I) = 'H'
                             and then Line (I .. I + 3) = "HLR-"
                           then
                              H_Start := I;
                              for J in I + 4 .. Last loop
                                 if Line (J) = ' '
                                   or else Line (J) = ']'
                                   or else Line (J) = ')'
                                 then
                                    H_End := J - 1;
                                    exit;
                                 end if;
                              end loop;
                              exit;
                           end if;
                        end loop;
                     end if;

                     if L_End > L_Start + 3 then
                        LLRs.Append (LLR_Info'(others => <>));
                        declare
                           Elem : LLR_Info := LLRs (Positive (LLRs.Length));
                        begin
                           Elem.Id_Len :=
                             Natural'Min
                               (L_End - (L_Start + 4) + 1, Elem.Id'Length);
                           for I in L_Start + 4 .. L_Start + 3 + Elem.Id_Len
                           loop
                              Elem.Id (I - (L_Start + 4) + 1) := Line (I);
                           end loop;

                           if Colon > 0 and then Colon < Last then
                              declare
                                 D_Start : Natural := Colon + 1;
                                 D_End   : Natural := Last;
                              begin
                                 while D_Start <= Last
                                   and then Line (D_Start) = ' '
                                 loop
                                    D_Start := D_Start + 1;
                                 end loop;

                                 if H_Start > D_Start then
                                    D_End := H_Start - 1;
                                    while D_End > D_Start
                                      and then Line (D_End) = ' '
                                    loop
                                       D_End := D_End - 1;
                                    end loop;
                                 end if;

                                 Elem.D_Len :=
                                   Natural'Min
                                     (D_End - D_Start + 1, Elem.Desc'Length);
                                 for I in D_Start .. D_Start + Elem.D_Len - 1
                                 loop
                                    Elem.Desc (I - D_Start + 1) := Line (I);
                                 end loop;
                              end;
                           end if;

                           if H_Start > 0 and then H_End > H_Start + 3 then
                              Elem.HLR_Len :=
                                Natural'Min
                                  (H_End - (H_Start + 4) + 1,
                                   Elem.HLR_Ref'Length);
                              for I in
                                H_Start + 4 .. H_Start + 3 + Elem.HLR_Len
                              loop
                                 Elem.HLR_Ref (I - (H_Start + 4) + 1) :=
                                   Line (I);
                              end loop;
                           end if;
                           LLRs.Replace_Element (Positive (LLRs.Length), Elem);
                        end;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      exception
         when others =>
            Close (F);
            raise;
      end;

      Close (F);
      Success := True;

      --  Store the freshly parsed vector for the next run (only on success,
      --  so a partial/empty parse is never cached).
      if Use_Cache then
         declare
            K  : constant String := LLR_Key (File_Path);
            OK : Boolean;
         begin
            if K'Length > 0 then
               declare
                  S_Blob : constant String := LLR_Store.Serialize (LLRs);
               begin
                  if S_Blob'Length > 0 then
                     Adacovex.Cache.Put_Cached (K, S_Blob, OK);
                  end if;
               end;
            end if;
         end;
      end if;
   end Parse_LLR_MD;

   function Find_HLR_In_Source
     (HLR_Id : String; Packages : Types.Implementation.Package_Vectors.Vector)
      return Boolean is
   begin
      for P in 1 .. Integer (Packages.Length) loop
         for T in 1 .. Integer (Packages (P).HLR_Tags.Length) loop
            declare
               Tag_Len : constant Natural := Packages (P).HLR_Tags (T).Len;
               Match   : Boolean := True;
            begin
               if Tag_Len = HLR_Id'Length then
                  for I in 1 .. Tag_Len loop
                     if Packages (P).HLR_Tags (T).Tag (I)
                       /= HLR_Id (HLR_Id'First + I - 1)
                     then
                        Match := False;
                        exit;
                     end if;
                  end loop;
                  if Match then
                     return True;
                  end if;
               end if;
            end;
         end loop;
      end loop;
      return False;
   end Find_HLR_In_Source;

end Adacovex.Parsers.DO178C;
