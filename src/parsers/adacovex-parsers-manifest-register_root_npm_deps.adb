separate (Adacovex.Parsers.Manifest)
--  Register the project root's npm dependencies (the dependencies and
--  devDependencies sections of the root package.json) when the install
--  tree is absent. With node_modules present the vendored walk already
--  registers every installed package at its installed version, and the
--  installed tree is authoritative, so this procedure does nothing. The
--  declared set is read structurally (a JSON section parse, never a
--  substring match), and the resolved version comes from the root
--  importer blocks of pnpm-lock.yaml when the lockfile is there; the
--  registry resolver fills any gap the lockfile leaves (a version when
--  no lockfile exists, a licence, a website). A missing registry, an
--  offline machine, or an unknown package keeps the name-only entry --
--  no licence or version is ever guessed. A project that keeps
--  node_modules in the repository is unaffected.
--  @param Target_Dir  Project root.
--  @param Graph  Component graph to register into.
procedure Register_Root_Npm_Deps
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Directories;
   T         : constant String :=
     (if Target_Dir'Length > 1 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir);
   Deps      : Name_Vectors.Vector;
   Dev_Deps  : Name_Vectors.Vector;
   Lock      : constant String := T & "/pnpm-lock.yaml";
   Have_Lock : Boolean := False;

   --  Append every name in V to the graph under Sc, with its lockfile
   --  version when the lockfile has one and whatever the registry
   --  resolver can add otherwise.
   procedure Register (V : Name_Vectors.Vector; Sc : Types.Component_Scope) is
   begin
      for I in 1 .. Integer (V.Length) loop
         declare
            N     : constant String := V (I).Name (1 .. V (I).Len);
            Lic   : Types.Desc_Field;
            L_Ln  : Natural := 0;
            Vb    : Types.Desc_Field;
            V_Ln  : Natural := 0;
            Web   : Types.Path_Field;
            W_Ln  : Natural := 0;
            Local : constant String :=
              (if Have_Lock then Pnpm_Importer_Version (Lock, N) else "");
         begin
            Resolve_Ecosystem_Metadata
              (T,
               "npm",
               N,
               Local'Length > 0,
               False,
               Lic,
               L_Ln,
               Vb,
               V_Ln,
               Web,
               W_Ln);
            declare
               Ver   : constant String :=
                 (if Local'Length > 0
                  then Local
                  elsif V_Ln > 0
                  then Vb (1 .. V_Ln)
                  else "");
               Lic_S : constant String :=
                 (if L_Ln > 0 then Lic (1 .. L_Ln) else "");
               Web_S : constant String :=
                 (if W_Ln > 0 then Web (1 .. W_Ln) else "");
            begin
               Append_Dependency
                 (Graph,
                  N,
                  Ver,
                  Lic_S,
                  "npm package declared by the project (package.json)",
                  "pkg:npm/" & N & (if Ver'Length > 0 then "@" & Ver else ""),
                  1,
                  False,
                  Sc,
                  "JavaScript",
                  Web_S);
            end;
         end;
      end loop;
   end Register;
begin
   if Exists (T & "/node_modules") then
      return;
   end if;
   if not Exists (T & "/package.json") then
      return;
   end if;
   Have_Lock := Exists (Lock);
   Collect_Json_Section_Names (T & "/package.json", "dependencies", Deps);
   Collect_Json_Section_Names
     (T & "/package.json", "devDependencies", Dev_Deps);
   Register (Deps, Types.Scope_Base);
   Register (Dev_Deps, Types.Scope_Dev);
end Register_Root_Npm_Deps;
