separate (Adacovex.Parsers.Manifest)
--  Record a probe result together with the identity digest of the binary
--  it was probed from. An existing entry for the tool keeps its version and
--  gains the digest; otherwise a new entry is appended.
--  @param Name  Tool name ("" is ignored).
--  @param Version  Version string reported by the probe.
--  @param Fp_Digest  SHA-256 of the fingerprint of the probed binary.
procedure Add_Probe_Fp (Name : String; Version : String; Fp_Digest : String) is
begin
   if Name'Length = 0 then
      return;
   end if;
   for I in 1 .. Integer (Probes.Length) loop
      if Probes (I).NLen = Name'Length
        and then Probes (I).Name (1 .. Name'Length) = Name
      then
         Probes (I).FpLen := Fp_Digest'Length;
         Probes (I).Fp (1 .. Fp_Digest'Length) := Fp_Digest;
         return;
      end if;
   end loop;
   declare
      P : Probe_Pair;
   begin
      P.NLen := Name'Length;
      P.Name (1 .. Name'Length) := Name (Name'First .. Name'Last);
      P.VLen := Version'Length;
      P.Ver (1 .. Version'Length) := Version (Version'First .. Version'Last);
      P.FpLen := Fp_Digest'Length;
      P.Fp (1 .. Fp_Digest'Length) := Fp_Digest;
      Probes.Append (P);
   end;
end Add_Probe_Fp;
