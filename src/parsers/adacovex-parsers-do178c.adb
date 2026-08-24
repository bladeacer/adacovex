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

   --  Find one requirement entry ("HLR-XXXX: ..." / "LLR-XXXX: ... [...]")
   --  on a markdown line and return the offsets of its parts.
   --  The Marker prefix ("HLR-" or "LLR-") is located on the line.  The
   --  id runs to the first space or colon.  The optional HLR reference after
   --  the description is detected as "HLR-xxxx" followed by a closer.
   --  All outputs are 0 when the part is absent.  Id_Start is more than 0 if
   --  and only if the marker was found.
   function Find_Entry
     (Line     : String;
      Last     : Natural;
      Marker   : String;
      Id_Start : out Natural;
      Id_End   : out Natural;
      Colon    : out Natural;
      H_Start  : out Natural;
      H_End    : out Natural) return Boolean
   is
      M_First : constant Natural := Line'First;
   begin
      Id_Start := 0;
      Id_End := 0;
      Colon := 0;
      H_Start := 0;
      H_End := 0;

      --  Find the marker prefix anywhere on the line.
      if Marker'Length = 0 then
         return False;
      end if;
      for I in M_First .. Last - 3 loop
         if Line (I .. I + 3) = Marker then
            Id_Start := I;
            exit;
         end if;
      end loop;
      if Id_Start = 0 then
         return False;
      end if;

      --  Id runs until a space or colon.
      for I in Id_Start + 4 .. Last loop
         if Line (I) = ' ' or else Line (I) = ':' then
            Id_End := I - 1;
            if Line (I) = ':' then
               Colon := I;
            end if;
            exit;
         end if;
      end loop;
      if Id_End = 0 then
         Id_End := Last;
      end if;

      --  Optional HLR reference after the colon ("[HLR-xxx]" / "(HLR-xxx)").
      if Colon > 0 then
         for I in Colon + 1 .. Last - 3 loop
            if Line (I) = 'H' and then Line (I .. I + 3) = "HLR-" then
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

      return True;
   end Find_Entry;

   --  Copy a fixed-width field from a line into the caller's buffer,
   --  clamping the length to the buffer size (never overruns).
   procedure Copy_Field
     (Line    : String;
      From    : Natural;
      To      : Natural;
      Dst     : out String;
      Dst_Len : out Natural) is
   begin
      Dst_Len := 0;
      if From = 0 or else To < From or else To > Line'Last then
         return;
      end if;
      Dst_Len := Natural'Min (To - From + 1, Dst'Length);
      for I in 1 .. Dst_Len loop
         Dst (I) := Line (From + I - 1);
      end loop;
   end Copy_Field;

   --  Extract one line's parsed entry and append it to an HLR vector.
   --  Id is the "HLR-xxx" token.  The description follows the colon.
   procedure Parse_HLR_Line
     (Line : String; Last : Natural; HLRs : in out HLR_Vectors.Vector)
   is
      Id_S, Id_E, Colon, H_S, H_E : Natural;
   begin
      if not Find_Entry (Line, Last, "HLR-", Id_S, Id_E, Colon, H_S, H_E) then
         return;
      end if;
      if Id_E <= Id_S + 3 then
         return;  --  empty id

      end if;
      HLRs.Append (HLR_Info'(others => <>));
      declare
         Elem : HLR_Info := HLRs (HLRs.Last_Index);
      begin
         Copy_Field (Line, Id_S + 4, Id_E, Elem.Id, Elem.Id_Len);
         if Colon > 0 and then Colon < Last then
            declare
               D_Start : Natural := Colon + 1;
            begin
               while D_Start <= Last and then Line (D_Start) = ' ' loop
                  D_Start := D_Start + 1;
               end loop;
               Copy_Field (Line, D_Start, Last, Elem.Desc, Elem.D_Len);
            end;
         end if;
         HLRs.Replace_Element (HLRs.Last_Index, Elem);
      end;
   end Parse_HLR_Line;

   --  Extract one parsed LLR entry.  The description runs up to the optional
   --  HLR reference.  The HLR reference is copied into HLR_Ref.
   procedure Parse_LLR_Line
     (Line : String; Last : Natural; LLRs : in out LLR_Vectors.Vector)
   is
      Id_S, Id_E, Colon, H_S, H_E : Natural;
   begin
      if not Find_Entry (Line, Last, "LLR-", Id_S, Id_E, Colon, H_S, H_E) then
         return;
      end if;
      if Id_E <= Id_S + 3 then
         return;
      end if;
      LLRs.Append (LLR_Info'(others => <>));
      declare
         Elem : LLR_Info := LLRs (LLRs.Last_Index);
      begin
         Copy_Field (Line, Id_S + 4, Id_E, Elem.Id, Elem.Id_Len);
         if Colon > 0 and then Colon < Last then
            declare
               D_Start : Natural := Colon + 1;
               D_End   : Natural := Last;
            begin
               while D_Start <= Last and then Line (D_Start) = ' ' loop
                  D_Start := D_Start + 1;
               end loop;
               if H_S > D_Start then
                  D_End := H_S - 1;
                  while D_End > D_Start and then Line (D_End) = ' ' loop
                     D_End := D_End - 1;
                  end loop;
               end if;
               Copy_Field (Line, D_Start, D_End, Elem.Desc, Elem.D_Len);
            end;
         end if;
         if H_S > 0 and then H_E > H_S + 3 then
            Copy_Field (Line, H_S + 4, H_E, Elem.HLR_Ref, Elem.HLR_Len);
         end if;
         LLRs.Replace_Element (LLRs.Last_Index, Elem);
      end;
   end Parse_LLR_Line;

   --  Iterate the lines of an open markdown file and feed each one to the
   --  shared line parser.  The HLR and LLR parsers share one file-reading
   --  skeleton.  Each parser keeps its own entry type.  A line longer than
   --  Max_Line is drained and reported by Read_Line.  Parsing stops.  No
   --  partial entry set is passed downstream.
   generic
      type Item_Type is private;
      type Item_Vector is private;
      with
        procedure Add_Line
          (Line : String; Last : Natural; Items : in out Item_Vector);
      with procedure Clear_Items (Items : in out Item_Vector);
   procedure Scan_Markdown_Lines
     (Src_File  : in out Ada.Text_IO.File_Type;
      File_Path : String;
      Items     : in out Item_Vector);

   procedure Scan_Markdown_Lines
     (Src_File  : in out Ada.Text_IO.File_Type;
      File_Path : String;
      Items     : in out Item_Vector)
   is
      use Ada.Text_IO;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
   begin
      while not End_Of_File (Src_File) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line
           (Src_File, File_Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            Clear_Items (Items);
            raise Constraint_Error;  --  caught by caller; marks failure

         end if;
         if Last > 6 then
            Add_Line (Line (1 .. Last), Last, Items);
         end if;
      end loop;
   end Scan_Markdown_Lines;

   procedure Clear_HLRs (Items : in out HLR_Vectors.Vector) is
   begin
      Items.Clear;
   end Clear_HLRs;

   procedure Clear_LLRs (Items : in out LLR_Vectors.Vector) is
   begin
      Items.Clear;
   end Clear_LLRs;

   --  Ada 2012: instantiate the generic over the two vector kinds.
   procedure Scan_HLR is new
     Scan_Markdown_Lines
       (Item_Type   => HLR_Info,
        Item_Vector => HLR_Vectors.Vector,
        Add_Line    => Parse_HLR_Line,
        Clear_Items => Clear_HLRs);
   procedure Scan_LLR is new
     Scan_Markdown_Lines
       (Item_Type   => LLR_Info,
        Item_Vector => LLR_Vectors.Vector,
        Add_Line    => Parse_LLR_Line,
        Clear_Items => Clear_LLRs);

   procedure Parse_And_Cache_HLR
     (File_Path : String;
      HLRs      : in out HLR_Vectors.Vector;
      Success   : out Boolean;
      Use_Cache : Boolean := False)
   is
      use Ada.Text_IO;
      F : File_Type;
   begin
      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      begin
         Scan_HLR (F, File_Path, HLRs);
         Close (F);
         Success := True;
      exception
         when others =>
            Close (F);
            HLRs.Clear;
            Success := False;
      end;

      if Success and then Use_Cache then
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
   end Parse_And_Cache_HLR;

   procedure Parse_And_Cache_LLR
     (File_Path : String;
      LLRs      : in out LLR_Vectors.Vector;
      Success   : out Boolean;
      Use_Cache : Boolean := False)
   is
      use Ada.Text_IO;
      F : File_Type;
   begin
      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      begin
         Scan_LLR (F, File_Path, LLRs);
         Close (F);
         Success := True;
      exception
         when others =>
            Close (F);
            LLRs.Clear;
            Success := False;
      end;

      if Success and then Use_Cache then
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
   end Parse_And_Cache_LLR;

   procedure Parse_HLR_MD
     (File_Path : String;
      HLRs      : in out HLR_Vectors.Vector;
      Success   : out Boolean;
      Use_Cache : Boolean := False) is
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

      Parse_And_Cache_HLR (File_Path, HLRs, Success, Use_Cache);
   end Parse_HLR_MD;

   procedure Parse_LLR_MD
     (File_Path : String;
      LLRs      : in out LLR_Vectors.Vector;
      Success   : out Boolean;
      Use_Cache : Boolean := False) is
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

      Parse_And_Cache_LLR (File_Path, LLRs, Success, Use_Cache);
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
