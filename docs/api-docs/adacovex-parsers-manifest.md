# Adacovex.Parsers.Manifest

Parser for Alire manifest files and GNAT project (.gpr) files.
Resolves the project dependency graph from alire.lock (solved crates),
alire.toml / alire-dev.toml (root project metadata and base or dev
dependency scopes), and the root .gpr project file (with clauses).
Every dependency component carries a Component_Scope.  The scopes are
base (declared in alire.toml), dev (declared only in alire-dev.toml),
transitive (resolved from the lock or a GPR with clause but named in no
manifest), or vendored (overlaid by a .adacovex/patches/ docstring
patch).  The result is a component vector suitable for SBOM generation.
Discover_System_Dev_Deps finds system-tool dev dependencies on top of
the manifest graph.  These are tools (python3, git, gnatprove, and
more) that the project's build or dev files reference and that are
installed on PATH.  Tools that are really language packages are never
registered as system tools: the root's Python requirements
(requirements*.txt, for example sphinx and myst-parser) are registered
as dev-scope pypi components resolved from the package registry
instead.
HLR-MANIFEST: Manifest and dependency-graph parsing

> **Note:** All items in this package are public.

## Functions

### function Extension_Language (Name : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Name` | File base name (for example "a.py"). |

**Returns:** Language display name ("Python"), or "" for unknown.

## Procedures

### procedure Build_Dependency_Graph (Target_Dir : Standard.String; Manifest_Path : Standard.String; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Success : Standard.Boolean; Use_Cache : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Graph` | Output dependency graph (index 1 = root project). |
| `Manifest_Path` | Path to the Alire manifest (alire.toml or dev). |
| `Success` | True if the manifest was readable and the root |
| `Target_Dir` | Project root directory. |
| `Use_Cache` | When True the resolved graph is keyed in the on-disk |

### procedure Discover_System_Dev_Deps (Target_Dir : Standard.String; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector)

| Parameter | Description |
|-----------|-------------|
| `Graph` | Dependency graph to extend (root at index 1). |
| `Target_Dir` | Project root directory to scan. |
