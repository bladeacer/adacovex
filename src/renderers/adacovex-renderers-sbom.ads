with Ada.Text_IO;
with Adacovex.Types;

--  Proof-aware software bill of materials (SBOM) generator.
--  Produces CycloneDX 1.5 JSON and SPDX 2.3 JSON documents from the
--  dependency graph resolved by Adacovex.Parsers.Manifest.  Only the root
--  component -- the project adacovex actually assessed -- carries the
--  adacovex:proof_level (Gold | Platinum) and adacovex:dal_target
--  (DAL-A through DAL-D) properties.  Dependency components report
--  adacovex:proof_level = "Not proved": adacovex only proves the target
--  itself, never third-party dependencies.  Every dependency component also
--  carries an adacovex:dep_scope property ("base" | "dev" | "transitive" |
--  "vendored") distinguishing publishing (alire.toml), development-only
--  (alire-dev.toml), transitive, and patched-vendored packages.
--  HLR-SBOM: SBOM generation

package Adacovex.Renderers.SBOM is

   --  Map an assessed SPARK level to the binary proof-level property value.
   --  Reports the honest assessed level (Stone..Platinum) verbatim rather than
   --  collapsing to a coarse "Gold"/"Platinum" tier, so SBOM consumers never
   --  overstate the assurance state (e.g. Silver with unproved VCs is
   --  reported as "Silver", never "Gold").
   --  @param Level  Assessed SPARK level.
   --  @return "Stone", "Bronze", "Silver", "Gold", or "Platinum".
   function Proof_Level_Property (Level : Types.SPARK_Level) return String
   with
     SPARK_Mode => On,
     Post       =>
       Proof_Level_Property'Result = "Stone"
       or else Proof_Level_Property'Result = "Bronze"
       or else Proof_Level_Property'Result = "Silver"
       or else Proof_Level_Property'Result = "Gold"
       or else Proof_Level_Property'Result = "Platinum",
     Global     => null;

   --  Map a DAL level to the dal_target property value ("DAL-A".."DAL-D").
   --  Returns an empty string for DAL-E, which has no safety effect and is
   --  therefore not asserted in the SBOM.
   --  @param Level  Target DAL level.
   --  @return "DAL-A".."DAL-D", or "" for DAL-E.
   function DAL_Property_Value (Level : Types.DAL_Level) return String
   with
     SPARK_Mode => On,
     Post       => DAL_Property_Value'Result'Length <= 5,
     Global     => null;

   --  Map a dependency scope to the adacovex:dep_scope property value
   --  ("base", "dev", "transitive", or "vendored").  Base dependencies are
   --  declared in the publishing alire.toml, dev dependencies only in
   --  alire-dev.toml, transitive ones in neither manifest, and vendored
   --  packages are overlaid by a .adacovex/patches/ docstring patch.
   --  @param Scope  Component dependency scope.
   --  @return "base" (4), "dev" (3), "transitive" (10), or "vendored" (8).
   function Scope_Property (Scope : Types.Component_Scope) return String
   with
     SPARK_Mode => On,
     Post       => Scope_Property'Result'Length in 3 .. 10,
     Global     => null;

   --  Write an SBOM in the requested format to Out_Path.
   --  Creates any missing parent directories and overwrites Out_Path.
   --  @param Format  SBOM format (CycloneDX_JSON or SPDX_JSON).
   --  @param Out_Path  Filesystem path to write the SBOM to.
   --  @param Graph  Dependency graph (index 1 = root component).
   --  @param Proof_Level  adacovex:proof_level property value.
   --  @param DAL_Target  adacovex:dal_target property value.
   --  @param Success  True if the SBOM was written successfully.
   procedure Write_SBOM
     (Format      : Types.SBOM_Format_Kind;
      Out_Path    : String;
      Graph       : Types.Implementation.Component_Vectors.Vector;
      Proof_Level : String;
      DAL_Target  : String;
      Success     : out Boolean)
   with Pre => Out_Path'Length > 0;

   --  Write a CycloneDX 1.5 JSON SBOM to an already-open file.
   --  @param F  Output file to write the JSON document to.
   --  @param Graph  Dependency graph (index 1 = root component).
   --  @param Proof_Level  adacovex:proof_level property value.
   --  @param DAL_Target  adacovex:dal_target property value.
   procedure Write_CycloneDX_To
     (F           : in out Ada.Text_IO.File_Type;
      Graph       : Types.Implementation.Component_Vectors.Vector;
      Proof_Level : String;
      DAL_Target  : String);

   --  Write an SPDX 2.3 JSON SBOM to an already-open file.
   --  @param F  Output file to write the JSON document to.
   --  @param Graph  Dependency graph (index 1 = root component).
   --  @param Proof_Level  adacovex:proof_level property value.
   --  @param DAL_Target  adacovex:dal_target property value.
   procedure Write_SPDX_To
     (F           : in out Ada.Text_IO.File_Type;
      Graph       : Types.Implementation.Component_Vectors.Vector;
      Proof_Level : String;
      DAL_Target  : String);

   --  Write a human-readable Markdown SBOM to an already-open file.
   --  Renders a compliance table of every component with its version,
   --  license, PURL, proof level, and DAL target properties.
   --  @param F  Output file to write the Markdown document to.
   --  @param Graph  Dependency graph (index 1 = root component).
   --  @param Proof_Level  adacovex:proof_level property value.
   --  @param DAL_Target  adacovex:dal_target property value.
   procedure Write_Markdown_To
     (F           : in out Ada.Text_IO.File_Type;
      Graph       : Types.Implementation.Component_Vectors.Vector;
      Proof_Level : String;
      DAL_Target  : String);

end Adacovex.Renderers.SBOM;
