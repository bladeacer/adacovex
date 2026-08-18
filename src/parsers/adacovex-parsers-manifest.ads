with Adacovex.Types;

--  Parser for Alire manifest files and GNAT project (.gpr) files.
--  Resolves the project dependency graph from alire.lock (solved crates),
--  alire.toml / alire-dev.toml (root project metadata + base/dev dependency
--  scopes), and the root .gpr project file (with clauses). Every dependency
--  component carries a Component_Scope: base (declared in alire.toml), dev
--  (declared only in alire-dev.toml), transitive (resolved from the lock or a
--  GPR with clause but named in no manifest), or vendored (overlaid by a
--  .adacovex/patches/ docstring patch). The result is a component vector
--  suitable for SBOM generation.  System-tool dev dependencies (python3,
--  git, gnatprove, ...) that the project's build/dev files reference and
--  that are installed on PATH are discovered on top of the manifest graph by
--  Discover_System_Dev_Deps.
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
   --  @param Use_Cache  When True the resolved graph is keyed in the on-disk
   --    result cache by the combined content hash of the manifests, the
   --    lockfile, and every .gpr file, so an unchanged dependency set is
   --    served without re-parsing; when False it is always rebuilt.
   procedure Build_Dependency_Graph
     (Target_Dir    : String;
      Manifest_Path : String;
      Graph         : out Types.Implementation.Component_Vectors.Vector;
      Success       : out Boolean;
      Use_Cache     : Boolean := False)
   with Pre => Target_Dir'Length > 0;

   --  Discover system-tool dev dependencies referenced by the project.
   --  Scans the project's dev-facing files (Makefiles, shell scripts,
   --  Python tools, Alire manifests, CI workflows, GNAT project files, and
   --  Ada sources) for a curated set of known system binaries; every tool
   --  that the files reference AND that is actually installed on PATH is
   --  appended to the graph as a dev-scope dependency of the root.  Tools
   --  referenced nowhere in the project, or referenced but not installed,
   --  are not registered -- the SBOM only lists system tools the project
   --  really interacts with and that are actually present.  No versions are
   --  probed: asking dozens of tools for their version on every SBOM
   --  generation would spawn many subprocesses and make the output
   --  machine-dependent.
   --  @param Target_Dir  Project root directory to scan.
   --  @param Graph  Dependency graph to extend (root at index 1).
   procedure Discover_System_Dev_Deps
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector);

end Adacovex.Parsers.Manifest;
