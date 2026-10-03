separate (Adacovex.Parsers.Manifest)
--  Record a probe result for a referenced tool (deduplicated). The first
--  result for a tool name wins: a later probe of the same tool never
--  overwrites an earlier entry.
--  @param Name  Tool name ("" is ignored).
--  @param Version  Version string reported by the probe.
procedure Add_Probe (Name : String; Version : String) is
begin
   if Name'Length = 0 then
      return;
   end if;
   for I in 1 .. Integer (Probes.Length) loop
      if Probes (I).NLen = Name'Length
        and then Probes (I).Name (1 .. Name'Length) = Name
      then
         return;
      end if;
   end loop;
   declare
      P : Probe_Pair;
   begin
      P.NLen := Name'Length;
      P.Name (1 .. Name'Length) := Name (Name'First .. Name'Last);
      P.VLen := Version'Length;
      P.Ver (1 .. Version'Length) :=
        Version (Version'First .. Version'Last);
      Probes.Append (P);
   end;
end Add_Probe;