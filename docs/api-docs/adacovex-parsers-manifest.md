# Adacovex.Parsers.Manifest

Parser for Alire manifest files and GNAT project (.gpr) files.
Resolves the project dependency graph from alire.lock (solved crates),
alire.toml / alire-dev.toml (root project metadata), and the root .gpr
project file (with clauses). The result is a component vector suitable
for SBOM generation.
HLR-MANIFEST: Manifest and dependency-graph parsing

> **Note:** All items in this package are public.

## Procedures

### procedure Build_Dependency_Graph (Target_Dir : Standard.String; Manifest_Path : Standard.String; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Graph` | Output dependency graph (index 1 = root project). |
| `Manifest_Path` | Path to the Alire manifest (alire.toml or dev). |
| `Success` | True if the manifest was readable and the root |
| `Target_Dir` | Project root directory. |
