with Adacovex.Types;

--  Parser for Alire manifest files and GNAT project (.gpr) files.
--  Resolves the project dependency graph from alire.lock (solved crates),
--  alire.toml / alire-dev.toml (root project metadata and base or dev
--  dependency scopes), and the root .gpr project file (with clauses).
--  Every dependency component carries a Component_Scope.  The scopes are
--  base (declared in alire.toml), dev (declared only in alire-dev.toml),
--  transitive (resolved from the lock or a GPR with clause but named in no
--  manifest), or vendored (overlaid by a .adacovex/patches/ docstring
--  patch).  The result is a component vector suitable for SBOM generation.
--  Discover_System_Dev_Deps finds system-tool dev dependencies on top of
--  the manifest graph.  These are tools (python3, git, gnatprove, and
--  more) that the project's build or dev files reference and that are
--  installed on PATH.
--  HLR-MANIFEST: Manifest and dependency-graph parsing

package Adacovex.Parsers.Manifest is

   --  Build the dependency graph for a project rooted at Target_Dir.
   --  Read alire.toml / alire-dev.toml (root metadata), alire.lock
   --  (solved dependencies), and the root .gpr file (project name and
   --  with clauses).  The root component is stored at index 1.
   --  Dependency components reference their parent via the Parent field.
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
   --  Scan the project's dev-facing files.  These files are Makefiles,
   --  shell scripts, Python tools, Alire manifests, CI workflows, GNAT
   --  project files, and Ada sources.  Look for a curated set of known
   --  system binaries.  Append every tool that the files reference and that
   --  is actually installed on PATH to the graph.  Append it as a dev-scope
   --  dependency of the root.  Tools referenced nowhere in the project, or
   --  referenced but not installed, are not registered.  The SBOM lists only
   --  system tools that the project really interacts with and that are
   --  actually present.  Probe each registered tool's version by running
   --  "<Tool> --version" (or the tool-specific subcommand).  Extract the
   --  version token.  The SBOM then carries the installed version.  Tools
   --  whose probe fails report no version.
   --  @param Target_Dir  Project root directory to scan.
   --  @param Graph  Dependency graph to extend (root at index 1).
   procedure Discover_System_Dev_Deps
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector);

   --  Language name for a source file, derived from its extension.
   --  @param Name  File base name (for example "a.py").
   --  @return Language display name ("Python"), or "" for unknown.
   function Extension_Language (Name : String) return String;

end Adacovex.Parsers.Manifest;
