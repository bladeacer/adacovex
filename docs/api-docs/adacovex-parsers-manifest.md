# Adacovex.Parsers.Manifest

Parser for Alire manifest files and GNAT project (.gpr) files.
Resolves the project dependency graph from alire.lock (solved crates),
alire.toml / alire-dev.toml (root project metadata + base/dev dependency
scopes), and the root .gpr project file (with clauses). Every dependency
component carries a Component_Scope: base (declared in alire.toml), dev
(declared only in alire-dev.toml), transitive (resolved from the lock or a
GPR with clause but named in no manifest), or vendored (overlaid by a
.adacovex/patches/ docstring patch). The result is a component vector
suitable for SBOM generation.
HLR-MANIFEST: Manifest and dependency-graph parsing

> **Note:** All items in this package are public.

## Procedures

### procedure Build_Dependency_Graph (Target_Dir : Standard.String; Manifest_Path : Standard.String; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Success : Standard.Boolean; Use_Cache : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Graph` | Output dependency graph (index 1 = root project). |
| `Manifest_Path` | Path to the Alire manifest (alire.toml or dev). |
| `Success` | True if the manifest was readable and the root |
| `Target_Dir` | Project root directory. |
| `Use_Cache` | When True the resolved graph is keyed in the on-disk |
