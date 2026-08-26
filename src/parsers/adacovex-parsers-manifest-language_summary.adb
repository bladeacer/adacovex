separate (Adacovex.Parsers.Manifest)
--  Rank a detected language counter vector.  The primary language is
--  first.  The primary language is the ecosystem manifest's language (for
--  example Rust for Cargo.toml).  The remaining languages follow by file
--  count descending.  Ties follow by name ascending.  Join up to 3 with
--  " - ".  Mixed-language sources list the top ~3 languages.  This keeps
--  "Ada; C; C++" style labels bounded.
--  @param Langs  Detected language counters (must be sorted into rank).
--  @param Primary  Ecosystem language, or "" to rank by file count only.
--  @return Joined language summary (for example "Ada; C; C++").
function Language_Summary
  (Langs : Lang_Vectors.Vector; Primary : String) return String
is
   Vec   : Lang_Vectors.Vector := Langs;
   Buf   : String (1 .. 128);
   BLen  : Natural := 0;
   Taken : Natural := 0;
   J     : Integer := 0;
   I     : Integer := 0;

   procedure Add_One (L : String) is
   begin
      if BLen + L'Length + 2 > Buf'Last then
         return;
      end if;
      if BLen > 0 then
         Buf (BLen + 1 .. BLen + 2) := "; ";
         BLen := BLen + 2;
      end if;
      Buf (BLen + 1 .. BLen + L'Length) := L;
      BLen := BLen + L'Length;
   end Add_One;
begin
   --  Bubble sort the counter vector (small): file count descending.
   --  Ties keep their detection order (the walk is deterministic).
   --  The primary language is added first regardless of its file count,
   --  then the remaining top languages up to 3 labels total.
   I := Integer (Vec.Length);
   while I > 1 loop
      J := 2;
      while J <= I loop
         if Vec (J).Ct > Vec (J - 1).Ct then
            declare
               T : Lang_Item := Vec (J);
            begin
               Vec (J) := Vec (J - 1);
               Vec (J - 1) := T;
            end;
         end if;
         J := J + 1;
      end loop;
      I := I - 1;
   end loop;

   if Primary'Length > 0 then
      Add_One (Primary);
      Taken := 1;
   end if;
   for I in 1 .. Integer (Vec.Length) loop
      exit when Taken >= 3;
      if Primary'Length = 0
        or else Vec (I).Len /= Primary'Length
        or else Vec (I).Name (1 .. Vec (I).Len) /= Primary
      then
         Add_One (Vec (I).Name (1 .. Vec (I).Len));
         Taken := Taken + 1;
      end if;
   end loop;
   return Buf (1 .. BLen);
end Language_Summary;
