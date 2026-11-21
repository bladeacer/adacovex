with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

--  Per-unit proof cache identity for the `prove` subcommand.
--
--  A proof run used to have one cache entry for the whole project. This
--  package gives every proof unit its own entry. The entry key covers the
--  unit's resolved path, its content, the content of the units its `with`
--  clauses name (its dependency closure), the gnatprove options, and the
--  prover identity. A one-unit edit therefore invalidates that unit and the
--  units that depend on it, and every other unit entry stays a hit.
--
--  The whole-run proof entry remains the correctness gate: gnatprove proves
--  a project in one invocation, so a run whose unit keys all hit still
--  restores the cached artefacts through the whole-run entry. The unit
--  entries record which units a cached proof covers, and the `prove` output
--  reports the split ("N/M unit(s) hit"), so a partial edit is visible
--  instead of hidden behind one project-wide miss.
--
--  Identity uses the resolved absolute path, never the caller's spelling or
--  working directory: the same project reached as `.`, `..`, or an
--  absolute path produces the same unit keys.
--  HLR-PROVE: Per-unit proof cache

package Adacovex.Prove_Units is

   --  One proof unit and its cache key.
   type Unit_Entry is record
      --  Resolved absolute path of the unit source file.
      Path : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;

      --  Per-unit cache key (`proveunit:` plus a SHA-256 digest).
      Key : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   end record;

   --  Unbounded collection of proof units.
   package Unit_Vectors is new Ada.Containers.Vectors (Positive, Unit_Entry);

   --  Enumerate the proof inputs under Target_Dir and compute one cache key
   --  per unit. The walk uses the proof-input skip set (VCS metadata, build
   --  and proof outputs, installer and doc trees, vendored stores, and
   --  virtual environments) and the generated-bundle exclusion, so it sees
   --  exactly the files the proof-input hash sees. Paths are resolved once,
   --  so two spellings of one project produce one key set. Options and
   --  Prover_Id are folded into every key (the whole-run key already covers
   --  the project file).
   --  @param Target_Dir  Project root to walk.
   --  @param Options  gnatprove option string for the run.
   --  @param Prover_Id  Resolved prover identity.
   --  @param Units  Output unit list (cleared first).
   procedure Enumerate
     (Target_Dir : String;
      Options    : String;
      Prover_Id  : String;
      Units      : out Unit_Vectors.Vector);

   --  Count how many of the unit keys already exist in the result cache.
   --  @param Units  Units returned by Enumerate.
   --  @param Hits  Number of unit keys present in the cache.
   procedure Count_Hits (Units : Unit_Vectors.Vector; Hits : out Natural);

   --  Record a successful proof for every unit by storing its key marker.
   --  Called after gnatprove exits 0, so the next run can report which
   --  units the cached proof covers.
   --  @param Units  Units returned by Enumerate.
   --  @param Stored  Number of markers written.
   procedure Store (Units : Unit_Vectors.Vector; Stored : out Natural);

end Adacovex.Prove_Units;
