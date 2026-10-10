separate (Adacovex.Parsers.Manifest)
--  Deserialize a cache blob into Referenced and Probes. The blob is split
--  on its '|' separator: names before it, probe pairs after it. A blob
--  written before the fingerprinted probe format carries no separator and
--  is read as a name list. A probe pair without '@' (a pre-fingerprint
--  blob) keeps an empty digest, which never validates -- the tool then
--  re-probes. A malformed pair is skipped rather than raising.
--  @param Blob  The stored blob text.
procedure Deserialize_Set (Blob : String) is
   Sep   : Natural := 0;
   Start : Natural := Blob'First;

   procedure Add_Name (Nm : String) is
   begin
      if Nm'Length > 0 then
         Add_Dep_Name (Referenced, Nm);
      end if;
   end Add_Name;
begin
   --  Split on the '|' separator: names before, probe pairs after.
   for I in Blob'First .. Blob'Last loop
      if Blob (I) = '|' then
         Sep := I;
         exit;
      end if;
   end loop;
   if Sep = 0 then
      --  Old-format blob (names only).
      Start := Blob'First;
      for I in Blob'First .. Blob'Last loop
         if Blob (I) = ',' then
            Add_Name (Blob (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      if Start <= Blob'Last then
         Add_Name (Blob (Start .. Blob'Last));
      end if;
      return;
   end if;

   --  Names section.
   Start := Blob'First;
   for I in Blob'First .. Sep - 1 loop
      if Blob (I) = ',' then
         Add_Name (Blob (Start .. I - 1));
         Start := I + 1;
      end if;
   end loop;
   if Start <= Sep - 1 then
      Add_Name (Blob (Start .. Sep - 1));
   end if;

   --  Probe section: parse "name=version@fpdigest" comma-separated
   --  pairs. A pair without '@' (pre-fingerprint blob) keeps an
   --  empty digest, which never validates -- the tool re-probes.
   Start := Sep + 1;
   for I in Sep + 1 .. Blob'Last loop
      if Blob (I) = ',' then
         declare
            Nm     : constant String := Blob (Start .. I - 1);
            Eq     : Natural := 0;
            At_Pos : Natural := 0;
         begin
            for J in Nm'Range loop
               if Nm (J) = '=' and then Eq = 0 then
                  Eq := J;
               elsif Nm (J) = '@' then
                  At_Pos := J;
                  exit;
               end if;
            end loop;
            if Eq > Nm'First then
               if At_Pos > Eq + 1 then
                  Add_Probe_Fp
                    (Nm (Nm'First .. Eq - 1),
                     Nm (Eq + 1 .. At_Pos - 1),
                     Nm (At_Pos + 1 .. Nm'Last));
               else
                  Add_Probe (Nm (Nm'First .. Eq - 1), Nm (Eq + 1 .. Nm'Last));
               end if;
            end if;
         end;
         Start := I + 1;
      end if;
   end loop;
   if Start <= Blob'Last then
      declare
         Nm     : constant String := Blob (Start .. Blob'Last);
         Eq     : Natural := 0;
         At_Pos : Natural := 0;
      begin
         for J in Nm'Range loop
            if Nm (J) = '=' and then Eq = 0 then
               Eq := J;
            elsif Nm (J) = '@' then
               At_Pos := J;
               exit;
            end if;
         end loop;
         if Eq > Nm'First then
            if At_Pos > Eq + 1 then
               Add_Probe_Fp
                 (Nm (Nm'First .. Eq - 1),
                  Nm (Eq + 1 .. At_Pos - 1),
                  Nm (At_Pos + 1 .. Nm'Last));
            else
               Add_Probe (Nm (Nm'First .. Eq - 1), Nm (Eq + 1 .. Nm'Last));
            end if;
         end if;
      end;
   end if;
end Deserialize_Set;
