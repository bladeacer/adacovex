--  Proof patches for vendored dependencies.
--
--  The docstring patch system (Adacovex.Parsers.Source.Apply_Patches)
--  overlays documentation onto vendored .ads files.  This package extends
--  the same .adacovex/patches/<relative-path> layout with SPARK proof
--  support: a patch file may carry SPARK aspects (SPARK_Mode on the package
--  declaration, Pre/Post/SPARK_Mode on subprogram declarations), and the
--  `prove` subcommand merges them into a copy of the vendored spec so
--  GNATprove analyzes the vendored unit with the patched contracts --
--  without modifying the original vendored sources.
--   --  The merge is textual and line-based: the patched spec is the original
--  spec with each patched subprogram declaration (matched on name AND
--  normalized parameter profile, so an overload patches its exact
--  signature -- never a same-named sibling) replaced by the patch's
--  declaration block (which carries the aspects), and the package
--  declaration given the patch's package-level aspect when present.
--
--  Where the vendored body is SPARK-clean, GNATprove proves the patched
--  contracts; where it is not (e.g. Ada.Text_IO callers), GNATprove skips
--  the bodies by design and the unit is reported as out of proof scope --
--  it never drags the target's proof level down.
--  HLR-PROVE: GNATprove runner and proof patches

with Adacovex.Types;

package Adacovex.Prove_Patch is

   --  True when the patch text carries SPARK proof aspects rather than
   --  docstrings only: any of the SPARK_Mode aspect, or a Pre/Post/Global
   --  contract on a declaration.  Used to decide whether a patch file
   --  participates in the proof overlay.
   --  @param Text  Patch file contents.
   --  @return True when the patch carries proof aspects.
   function Has_Proof (Text : String) return Boolean;

   --  Merge the SPARK aspects from a proof patch into a copy of the
   --  original spec.
   --  The patched spec is Original with every subprogram declaration that
   --  the patch re-declares with aspects replaced by the patch's
   --  declaration block, and the package declaration given the patch's
   --  package-level aspect when the patch carries one.  Subprograms the
   --  patch does not re-declare with aspects are left untouched.  On
   --  success OK is True and Merged (1 .. Merged_Len) is the patched spec;
   --  on failure (a patched subprogram has no match in the original, or
   --  the merged spec would overflow the buffer) OK is False and the
   --  result is undefined -- the caller skips the patch and reports.
   --  @param Original    Original vendored spec text.
   --  @param Patch       Patch text (valid Ada .ads with docstrings and/or
   --                     SPARK aspects).
   --  @param Merged      Buffer receiving the patched spec.
   --  @param Merged_Len  Length of the patched spec (0 on failure).
   --  @param OK          True when the merge succeeded.
   procedure Apply
     (Original   : String;
      Patch      : String;
      Merged     : out String;
      Merged_Len : out Natural;
      OK         : out Boolean);

   --  Count the patch files under <target>/.adacovex/patches/ that carry
   --  proof aspects (see Has_Proof).  A target with no proof patches is
   --  proved against its own tree exactly as before -- the patched-copy
   --  machinery engages only when this returns > 0.
   --  @param Target_Dir  Target project root.
   --  @return Number of proof-carrying patch files.
   function Count_Proof_Patches (Target_Dir : String) return Natural;

   --  Build the patched proof tree for a target with proof patches.
   --  Copies the target tree (excluding .git, obj, and .adacovex) into
   --  <target>/obj/adacovex-proof/, then overwrites each proof-patched
   --  spec with its merged form, so GNATprove runs against a faithful
   --  replica whose vendored specs carry the patch contracts.  The root
   --  project file of the copy is returned in Copy_GPR -- Run_Prove
   --  passes it to gnatprove and copies the resulting gnatprove.out back
   --  to <target>/obj/gnatprove/gnatprove.out.  The copy lives under the
   --  target's obj/ so it is excluded from scanning, manifest graphs, and
   --  the prove input hash (patches are hashed separately).
   --  @param Target_Dir  Target project root.
   --  @param Root_GPR    Absolute path of the root project file.
   --  @param Copy_Dir    Directory of the patched proof tree.
   --  @param Copy_Len    Length of Copy_Dir.
   --  @param Copy_GPR    Absolute path of the copy's root project file.
   --  @param GPR_Len     Length of Copy_GPR.
   --  @param Success     True when the tree was built (a merge failure
   --                     reports to standard error and skips that patch).
   procedure Build_Patched_Copy
     (Target_Dir : String;
      Root_GPR   : String;
      Copy_Dir   : out String;
      Copy_Len   : out Natural;
      Copy_GPR   : out String;
      GPR_Len    : out Natural;
      Success    : out Boolean);

   --  SHA-256 fold of every file under <target>/.adacovex/patches/.
   --  Folded into the prove result-cache key (Compute_Prove_Input_Hash)
   --  so a patch change re-proves instead of serving a stale proof.
   --  @param Target_Dir  Target project root.
   --  @return Hex digest of all patch file contents ("" when none).
   function Patches_Hash (Target_Dir : String) return String;

end Adacovex.Prove_Patch;
