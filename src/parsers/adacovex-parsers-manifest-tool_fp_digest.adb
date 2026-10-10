separate (Adacovex.Parsers.Manifest)
--  SHA-256 of the fingerprint of the installed tool binary, "" when the
--  tool is not on PATH. The returned digest lets a cached probe result be
--  re-validated against the live binary.
--  @param Name  Executable name.
--  @return The digest of the installed binary, or "".
function Tool_Fp_Digest (Name : String) return String is
   Exe : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path (Name);
begin
   if Exe = null then
      return "";
   end if;
   declare
      D : constant String :=
        Adacovex.Cache.Hash_String (Adacovex.Cache.Tool_Fingerprint (Exe.all));
   begin
      GNAT.OS_Lib.Free (Exe);
      return D;
   end;
end Tool_Fp_Digest;
