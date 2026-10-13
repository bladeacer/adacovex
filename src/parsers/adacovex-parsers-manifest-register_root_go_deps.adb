separate (Adacovex.Parsers.Manifest)
--  Register the modules the project root's go.mod declares. A direct
--  require becomes a base-scope component and a `// indirect` require a
--  transitive one, each at the version go.mod states and under a
--  pkg:golang/<module>@<version> purl. The parse is the structural
--  require-directive reader, never a substring match, so the contents of
--  a replace or exclude block and a commented-out line never register.
--  A module the vendored walk already registered is left alone: a Go
--  vendor tree answers for the whole tree with its modules.txt and the
--  licence files beside each module, so the installed tree stays
--  authoritative. No metadata is invented for a module that is only
--  declared: the Go toolchain reports no licence, a licence file beside
--  the root go.mod is the project's own licence rather than a
--  dependency's, and a website is never guessed. A test-named module
--  (github.com/stretchr/testify) takes Scope_Test, as everywhere else.
--  A missing go.mod collects nothing.
--  @param Target_Dir  Project root.
--  @param Graph  Component graph to register into.
procedure Register_Root_Go_Deps
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Directories;
   T        : constant String :=
     (if Target_Dir'Length > 1 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir);
   Direct   : Go_Module_Vectors.Vector;
   Indirect : Go_Module_Vectors.Vector;

   --  Append every module of V to the graph under Sc, unless the graph
   --  already holds the name (the vendored walk saw it first) or the
   --  path is empty after the Desc_Field cap.
   --  @param V  Modules to register.
   --  @param Sc  Scope for a module the file declares directly (or
   --    indirectly, for the indirect set); a test-named module upgrades
   --    it to Scope_Test.
   procedure Register
     (V : Go_Module_Vectors.Vector; Sc : Types.Component_Scope) is
   begin
      for I in 1 .. Integer (V.Length) loop
         declare
            N   : constant String := V (I).Path (1 .. V (I).PLen);
            Ver : constant String := V (I).Ver (1 .. V (I).VLen);
            S   : Types.Component_Scope := Sc;
         begin
            if N'Length = 0 or else Name_In_Graph (Graph, N) then
               null;
            else
               if Is_Test_Named (N) then
                  S := Types.Scope_Test;
               end if;
               Append_Dependency
                 (Graph,
                  N,
                  Ver,
                  "",
                  "Go module declared by the project (go.mod)",
                  "pkg:golang/"
                  & N
                  & (if Ver'Length > 0 then "@" & Ver else ""),
                  1,
                  False,
                  S,
                  "Go");
            end if;
         end;
      end loop;
   end Register;
begin
   if not Exists (T & "/go.mod") then
      return;
   end if;
   Collect_Go_Requires (T & "/go.mod", Direct, Indirect);
   Register (Direct, Types.Scope_Base);
   Register (Indirect, Types.Scope_Transitive);
end Register_Root_Go_Deps;
