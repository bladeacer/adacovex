with Ada.Text_IO;
with Adacovex.Types;

--  Proof-aware software bill of materials (SBOM) generator.
--  Produces CycloneDX 1.5 JSON and SPDX 2.3 JSON documents from the
--  dependency graph resolved by Adacovex.Parsers.Manifest.  Every
--  component is extended with the adacovex proof-aware properties
--  adacovex:proof_level (Gold | Platinum) and adacovex:dal_target
--  (DAL-A through DAL-D).
--  HLR-SBOM: SBOM generation

package Adacovex.Renderers.SBOM is

   --  Map an assessed SPARK level to the binary proof-level property value.
   --  "Platinum" when the assessment reached Platinum (all VCs proved),
   --  otherwise "Gold", the formal-verification tier the build is verified
   --  against.  adacovex SBOMs distinguish these two proof-aware tiers.
   --  @param Level  Assessed SPARK level.
   --  @return "Gold" or "Platinum".
   function Proof_Level_Property (Level : Types.SPARK_Level) return String
   with
     SPARK_Mode => On,
     Post       =>
       Proof_Level_Property'Result = "Gold"
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
