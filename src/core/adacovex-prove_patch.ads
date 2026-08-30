--  Proof patches for vendored dependencies.
--
--  The docstring patch system (Adacovex.Parsers.Source.Apply_Patches)
--  overlays documentation onto vendored .ads files.  This package extends
--  the same ``.adacovex/patches/<relative-path>`` layout with SPARK proof
--  support.  A patch file can carry SPARK aspects.  The aspects are
--  SPARK_Mode on the package declaration and Pre, Post, or SPARK_Mode on
--  subprogram declarations.  The `prove` subcommand merges them into a copy
--  of the vendored spec.  When the patch carries one, it also merges the
--  vendored body.  GNATprove then analyses the vendored unit with the
--  patched contracts.  It does not modify the original vendored sources.
--  A .ads patch re-declares the spec with contracts.  A .adb patch opts
--  the body into the proof.  The body is analysed only when it declares
--  SPARK_Mode On itself.
--
--  The merge is textual and line-based.  The patched source is the original
--  with each patched subprogram declaration replaced by the patch's
--  declaration block.  The block carries the aspects.  A declaration
--  matches on name and normalised parameter profile.  An overload patches
--  its exact signature, never a same-named sibling.  The default `in` mode
--  is equivalent to a bare mode.  `in out` and `out` are distinct.  The
--  package declaration is given the patch's package-level aspect when
--  present.  Subprogram declarations terminate at the ';' of a spec
--  declaration or at the `is` of a body declaration.  A patched body
--  declaration is replaced without touching the body proper.
--
--  When the vendored body is SPARK-clean and opted in via a body patch,
--  GNATprove proves the patched contracts.  When it is not, for example
--  Ada.Text_IO callers, GNATprove skips the I/O bodies by design.  The
--  unit is then reported as out of proof scope.  A proof patch never drags
--  the target's proof level down.
--  HLR-PROVE: GNATprove runner and proof patches

with Adacovex.Types;

package Adacovex.Prove_Patch is

   --  True when the patch text carries SPARK proof aspects rather than
   --  docstrings only.  The aspects are any of the SPARK_Mode aspect, or a
   --  Pre, Post, or Global contract on a declaration.  It is used to decide
   --  whether a patch file participates in the proof overlay.
   --  @param Text  Patch file contents.
   --  @return True when the patch carries proof aspects.
   function Has_Proof (Text : String) return Boolean;

   --  Merge the SPARK aspects from a proof patch into a copy of the
   --  original vendored source (a spec or a body).
   --  The patched source is Original.  Every subprogram declaration that the
   --  patch re-declares with aspects is replaced by the patch's declaration
   --  block.  The package declaration is given the patch's package-level
   --  aspect when the patch carries one.  Subprograms that the patch does not
   --  re-declare with aspects stay untouched.  On success, OK is True and
   --  Merged (1 .. Merged_Len) is the patched source.  On failure, OK is
   --  False and the result is undefined.  Failure is when a patched
   --  subprogram has no match in the original, or the merged source is
   --  larger than the buffer.  The caller then skips the patch and reports.
   --  @param Original    Original vendored source text.
   --  @param Patch       Patch text (valid Ada .ads with docstrings and/or
   --                     SPARK aspects.  A body patch mirrors the .adb
   --                     declarations with stub bodies that are ignored).
   --  @param Merged      Buffer receiving the patched source.
   --  @param Merged_Len  Length of the patched source (0 on failure).
   --  @param OK          True when the merge succeeded.
   procedure Apply
     (Original   : String;
      Patch      : String;
      Merged     : out String;
      Merged_Len : out Natural;
      OK         : out Boolean);

   --  Count the patch files under <target>/.adacovex/patches/ that carry
   --  proof aspects (see Has_Proof).  A target with no proof patches is
   --  proved against its own tree exactly as before.  The patched-copy
   --  machinery engages only when this returns > 0.
   --  @param Target_Dir  Target project root.
   --  @return Number of proof-carrying patch files.
   function Count_Proof_Patches (Target_Dir : String) return Natural;

   --  Build the patched proof tree for a target with proof patches.
   --  It copies the target tree (excluding .git, obj, and .adacovex) into
   --  <target>/obj/adacovex-proof/.  It then overwrites each proof-patched
   --  spec and body with its merged form.  GNATprove then runs against a
   --  faithful replica whose vendored sources carry the patch contracts.
   --  The root project file of the copy is returned in Copy_GPR.  Run_Prove
   --  passes it to gnatprove and copies the resulting gnatprove.out back to
   --  <target>/obj/gnatprove/gnatprove.out.  The copy lives under the
   --  target's obj/ so it is excluded from scanning, manifest graphs, and the
   --  prove input hash.  Patches are hashed separately.
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
   --  It is folded into the prove result-cache key (Compute_Prove_Input_Hash)
   --  so a patch change re-proves instead of serving a stale proof.
   --  @param Target_Dir  Target project root.
   --  @return Hex digest of all patch file contents ("" when none).
   function Patches_Hash (Target_Dir : String) return String;

end Adacovex.Prove_Patch;
