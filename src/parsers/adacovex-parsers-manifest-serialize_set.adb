separate (Adacovex.Parsers.Manifest)
--  Serialize the referenced-tool set and its probe results to a cache blob.
--  Format: comma-separated tool names, then a '|' separator, then
--  comma-separated "name=version@fpdigest" probe pairs (both bounded by the
--  8192-char blob). The probe section lets a cache hit skip re-running
--  version probes and PATH lookups.
--  @return The blob text for Probes and Referenced.
function Serialize_Set return String is
   S : String (1 .. 8192);
   L : Natural := 0;

   procedure Add (Txt : String) is
   begin
      if L + Txt'Length <= S'Last then
         S (L + 1 .. L + Txt'Length) := Txt;
         L := L + Txt'Length;
      end if;
   end Add;
begin
   for I in 1 .. Integer (Referenced.Length) loop
      declare
         Nm : constant String :=
           Referenced (I).Name (1 .. Referenced (I).Len);
      begin
         if L > 0 then
            Add (",");
         end if;
         Add (Nm);
      end;
   end loop;
   Add ("|");
   for I in 1 .. Integer (Probes.Length) loop
      declare
         Nm : constant String := Probes (I).Name (1 .. Probes (I).NLen);
         Vr : constant String := Probes (I).Ver (1 .. Probes (I).VLen);
         Fd : constant String := Probes (I).Fp (1 .. Probes (I).FpLen);
      begin
         if L > 0 and then S (L) /= '|' then
            Add (",");
         end if;
         Add (Nm);
         Add ("=");
         Add (Vr);
         --  Binary-identity digest so a cache hit can re-validate
         --  each probe against the installed binary. Entries without
         --  one (never in a v2 blob) would fail validation on load.
         Add ("@");
         Add (Fd);
      end;
   end loop;
   return S (1 .. L);
end Serialize_Set;