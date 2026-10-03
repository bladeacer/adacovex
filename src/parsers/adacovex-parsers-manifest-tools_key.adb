separate (Adacovex.Parsers.Manifest)
--  Input key for the referenced-tools cache. It combines the source-tree
--  content hash with the curated tool table and the version-probe
--  fallback chain.
--
--  Source_Tree_Hash covers every file the scan reads, so it alone
--  determines the referenced-tool set. The tool-table fingerprint
--  invalidates the key when the System_Tools constant changes within a
--  release. Names and categories are folded in (the stored version-probe
--  flag is gone: Probe_Version infers it at run time), so editing the table
--  self-invalidates the cache -- no hand-maintained "|tools-vN|" salt bump
--  to forget. (The 1.33-era control of that same risk relied on a
--  manually bumped salt; a forgotten bump served stale probe results within
--  a release.) The "|probe-fb:...|" token also separates this namespace
--  from the graph cache and the 1.27-era blob layout, while the flag chain
--  stays part of the digest.
--  @param Target_Dir  Project root directory.
--  @return "tools:" + SHA-256 digest, or "" when inputs are unhashable.
function Tools_Key (Target_Dir : String) return String is
   T    : constant String :=
     (if Target_Dir'Length > 1
        and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir);
   Comb : String (1 .. Types.Max_Path * 2);
   CLen : Natural := 0;
   procedure Add (S : String) is
   begin
      if S'Length > 0 and then CLen + S'Length <= Comb'Last then
         Comb (CLen + 1 .. CLen + S'Length) := S;
         CLen := CLen + S'Length;
      end if;
   end Add;
begin
   Add (Source_Tree_Hash (T));
   for I in System_Tools'Range loop
      Add (System_Tools (I).Name (1 .. System_Tools (I).Len));
      Add (":");
      Add (Tool_Category'Image (System_Tools (I).Cat));
      Add (";");
   end loop;
   --  The probe fallback chain lives in Probe_Version -- fold its flag
   --  order in so reordering the fallbacks also busts the cache.
   Add ("|probe-fb:--version,-v,version|namespace-v4|");
   if CLen = 0 then
      return "";
   end if;
   return "tools:" & Adacovex.Cache.Hash_String (Comb (1 .. CLen));
end Tools_Key;