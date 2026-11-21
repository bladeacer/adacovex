# Adacovex.Prove_Units

Per-unit proof cache identity for the ``prove`` subcommand.

A proof run used to have one cache entry for the whole project. This
package gives every proof unit its own entry. The entry key covers the
unit's resolved path, its content, the content of the units its ``with``
clauses name (its dependency closure), the gnatprove options, and the
prover identity. A one-unit edit therefore invalidates that unit and the
units that depend on it, and every other unit entry stays a hit.

The whole-run proof entry remains the correctness gate: gnatprove proves
a project in one invocation, so a run whose unit keys all hit still
restores the cached artefacts through the whole-run entry. The unit
entries record which units a cached proof covers, and the ``prove`` output
reports the split ("N/M unit(s) hit"), so a partial edit is visible
instead of hidden behind one project-wide miss.

Identity uses the resolved absolute path, never the caller's spelling or
working directory: the same project reached as ``.``, ``..``, or an
absolute path produces the same unit keys.
HLR-PROVE: Per-unit proof cache

> **Note:** All items in this package are public.

## Types

### type Unit_Entry

```ada
type Unit_Entry is record
Path : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Key : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
end record;
```

> One proof unit and its cache key.

## Procedures

### procedure Count_Hits (Units : Adacovex.Prove_Units.Unit_Vectors.Vector; Hits : Standard.Natural)

> Count how many of the unit keys already exist in the result cache.

| Parameter | Description |
|-----------|-------------|
| `Hits` | Number of unit keys present in the cache. |
| `Units` | Units returned by Enumerate. |

### procedure Enumerate (Target_Dir : Standard.String; Options : Standard.String; Prover_Id : Standard.String; Units : Adacovex.Prove_Units.Unit_Vectors.Vector)

> Enumerate the proof inputs under Target_Dir and compute one cache key per unit. The walk uses the proof-input skip set (VCS metadata, build and proof outputs, installer and doc trees, vendored stores, and virtual environments) and the generated-bundle exclusion, so it sees exactly the files the proof-input hash sees. Paths are resolved once, so two spellings of one project produce one key set. Options and Prover_Id are folded into every key (the whole-run key already covers the project file).

| Parameter | Description |
|-----------|-------------|
| `Options` | gnatprove option string for the run. |
| `Prover_Id` | Resolved prover identity. |
| `Target_Dir` | Project root to walk. |
| `Units` | Output unit list (cleared first). |

### procedure Store (Units : Adacovex.Prove_Units.Unit_Vectors.Vector; Stored : Standard.Natural)

> Record a successful proof for every unit by storing its key marker. Called after gnatprove exits 0, so the next run can report which units the cached proof covers.

| Parameter | Description |
|-----------|-------------|
| `Stored` | Number of markers written. |
| `Units` | Units returned by Enumerate. |
