with Adacovex.Types;

--  Parser for Alire manifest files and GNAT project (.gpr) files.
--  Resolves the project dependency graph from alire.lock (solved crates),
--  alire.toml / alire-dev.toml (root project metadata), and the root .gpr
--  project file (with clauses). The result is a component vector suitable
--  for SBOM generation.
--  HLR-MANIFEST: Manifest and dependency-graph parsing

package Adacovex.Parsers.Manifest is

   --  Build the dependency graph for a project rooted at Target_Dir.
   --  Reads alire.toml / alire-dev.toml (root metadata), alire.lock
   --  (solved dependencies), and the root .gpr file (project name and
   --  with clauses). The root component is stored at index 1; dependency
   --  components reference their parent via the Parent field.
   --  @param Target_Dir  Project root directory.
   --  @param Manifest_Path  Path to the Alire manifest (alire.toml or dev).
   --  @param Graph  Output dependency graph (index 1 = root project).
   --  @param Success  True if the manifest was readable and the root
   --    component was resolved.
   procedure Build_Dependency_Graph
     (Target_Dir    : String;
      Manifest_Path : String;
      Graph         : out Types.Implementation.Component_Vectors.Vector;
      Success       : out Boolean)
   with Pre => Target_Dir'Length > 0;

end Adacovex.Parsers.Manifest;
