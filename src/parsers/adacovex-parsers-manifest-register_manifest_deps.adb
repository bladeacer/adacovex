separate (Adacovex.Parsers.Manifest)
--  Register manifest-declared dependencies that no GPR with-clause or
--  lockfile resolved (or fill in missing metadata on entries that were).
--  These are base deps from the publishing manifest (alire.toml) and dev
--  deps from alire-dev.toml.  Append_Dependency adds a name-only
--  "pkg:alire/<name>" purl when the crate is not already in the graph.
--  For every manifest-declared crate, `alr show` supplies the licence and
--  source repository URL from Alire's local index -- filling them onto a
--  freshly appended entry or an existing lockfile/GPR one whose source
--  could not otherwise be resolved.  No garbage links are produced: a
--  URL is only ever taken from the release metadata, never guessed.
procedure Register_Manifest_Deps
  (Graph      : in out Types.Implementation.Component_Vectors.Vector;
   Base_Names : Name_Vectors.Vector;
   Dev_Names  : Name_Vectors.Vector)
is
   --  Fill missing licence/website/version on an existing graph entry.
   procedure Enrich_Existing
     (Name    : String;
      Lic     : Types.Desc_Field;
      Lic_Len : Natural;
      Web     : Types.Path_Field;
      Web_Len : Natural;
      Ver     : Types.Desc_Field;
      Ver_Len : Natural) is
   begin
      for I in 1 .. Integer (Graph.Length) loop
         if Graph (I).Name_Len = Name'Length
           and then Graph (I).Name (1 .. Name'Length) = Name
         then
            declare
               C : Types.Implementation.Component_Info := Graph (I);
            begin
               if Lic_Len > 0 and C.License_Len = 0 then
                  for J in 1 .. Lic_Len loop
                     C.License (J) := Lic (J);
                  end loop;
                  C.License_Len := Lic_Len;
               end if;
               if Web_Len > 0 and C.Website_Len = 0 then
                  for J in 1 .. Web_Len loop
                     C.Website (J) := Web (J);
                  end loop;
                  C.Website_Len := Web_Len;
               end if;
               if Ver_Len > 0 and C.Version_Len = 0 then
                  for J in 1 .. Ver_Len loop
                     C.Version (J) := Ver (J);
                  end loop;
                  C.Version_Len := Ver_Len;
               end if;
               Graph (I) := C;
            end;
            exit;
         end if;
      end loop;
   end Enrich_Existing;

   procedure Register
     (Names : Name_Vectors.Vector; Scope : Types.Component_Scope) is
   begin
      for I in 1 .. Integer (Names.Length) loop
         declare
            Name    : constant String := Names (I).Name (1 .. Names (I).Len);
            Lic     : Types.Desc_Field;
            Lic_Len : Natural := 0;
            Web     : Types.Path_Field;
            Web_Len : Natural := 0;
            Ver     : Types.Desc_Field;
            Ver_Len : Natural := 0;
            Lic_S   : String (1 .. Types.Max_Desc_Str);
            Lic_SL  : Natural := 0;
            Web_S   : String (1 .. Types.Max_Path);
            Web_SL  : Natural := 0;
            Ver_S   : String (1 .. Types.Max_Desc_Str);
            Ver_SL  : Natural := 0;
         begin
            --  Ask the local index for the crate's licence, version and
            --  source URL (`alr show` answers without network access).
            --  The unified registry resolver tables alire alongside the
            --  other ecosystems.  When the crate is not in the graph yet,
            --  bundle them into the new entry; otherwise patch them onto
            --  the existing one so lockfile-resolved dev deps still carry
            --  real release metadata and a real source link.
            Resolve_Ecosystem_Metadata
              ("alire", Name, Lic, Lic_Len, Ver, Ver_Len, Web, Web_Len);
            if Lic_Len > 0 then
               Lic_SL := Lic_Len;
               for J in 1 .. Lic_Len loop
                  Lic_S (J) := Lic (J);
               end loop;
            end if;
            if Web_Len > 0 then
               Web_SL := Web_Len;
               for J in 1 .. Web_Len loop
                  Web_S (J) := Web (J);
               end loop;
            end if;
            if Ver_Len > 0 then
               Ver_SL := Ver_Len;
               for J in 1 .. Ver_Len loop
                  Ver_S (J) := Ver (J);
               end loop;
            end if;
            if Name_In_Graph (Graph, Name) then
               Enrich_Existing
                 (Name, Lic, Lic_Len, Web, Web_Len, Ver, Ver_Len);
            else
               Append_Dependency
                 (Graph,
                  Name,
                  (if Ver_SL > 0 then Ver_S (1 .. Ver_SL) else ""),
                  (if Lic_SL > 0 then Lic_S (1 .. Lic_SL) else ""),
                  "",
                  "pkg:alire/" & Name,
                  1,
                  False,
                  Scope,
                  "Ada",
                  (if Web_SL > 0 then Web_S (1 .. Web_SL) else ""));
            end if;
         end;
      end loop;
   end Register;
begin
   Register (Base_Names, Types.Scope_Base);
   Register (Dev_Names, Types.Scope_Dev);
end Register_Manifest_Deps;
