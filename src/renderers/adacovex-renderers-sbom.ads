with Ada.Text_IO;
with Adacovex.Types;

--  Proof-aware software bill of materials (SBOM) generator.
--  Produces CycloneDX 1.5 JSON and SPDX 2.3 JSON documents from the
--  dependency graph resolved by Adacovex.Parsers.Manifest.  Only the root
--  component -- the project adacovex actually assessed -- carries the
--  adacovex:proof_level (Stone..Platinum), adacovex:standard
--  ("DO-178C" | "ISO 26262" | "IEC 62304"), adacovex:dal_target
--  (DAL-A through DAL-D), and adacovex:level (the standard-specific label
--  "DAL-C" | "ASIL B" | "Class A") properties.  Dependency components
--  report adacovex:proof_level = "Not proved": adacovex only proves the
--  target itself, never third-party dependencies.  Every dependency
--  component also carries an adacovex:dep_scope property ("base" | "dev" |
--  "transitive" | "vendored") distinguishing publishing (alire.toml),
--  development-only (alire-dev.toml), transitive, and patched-vendored
--  packages.
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
     Post       => Proof_Level_Property'Result = Types.To_String (Level),
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

   --  Standard-specific level label for the root component's adacovex:level
   --  property ("DAL-C", "ASIL B", "Class A", ...).  Returns an empty
   --  string for the no-safety-effect tier (DAL-E), matching
   --  DAL_Property_Value's omission of DAL-E.
   --  @param Standard  Compliance standard labelling the level.
   --  @param Level  Shared rigor tier.
   --  @return The standard-specific level label, or "" for DAL-E.
   function Level_Property
     (Standard : Types.Compliance_Standard; Level : Types.DAL_Level)
      return String
   with SPARK_Mode => On, Global => null;

   --  Comma-joined standard names for the "all standards" SBOM property:
   --  "DO-178C, ISO 26262, IEC 62304".  Used for adacovex:standard when
   --  --standard=all runs one assessment against every standard.
   --  @return The comma-joined standard names.
   function All_Standards_Property return String
   with
     SPARK_Mode => On,
     Post       => All_Standards_Property'Result'Length > 0,
     Global     => null;

   --  Slash-joined standard-specific level labels for the "all standards"
   --  SBOM property, e.g. "DAL-C / ASIL B / Class A".  Each standard's
   --  native label is used so an ISO 26262 / IEC 62304 reader sees "ASIL B"
   --  / "Class A" without decoding the shared tier.
   --  @param Level  Shared rigor tier.
   --  @return The slash-joined level labels for all three standards.
   function All_Levels_Property (Level : Types.DAL_Level) return String;

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

   --  Escape a string for inclusion in a JSON document.  Backslash, quote
   --  and control characters are escaped so the emitted JSON is always
   --  well-formed, even for manifest strings containing embedded quotes.
   --  The output buffer is bounded at six bytes per input byte (the widest
   --  escape, "\u00xx").  Source length is capped at Max_Esc_Src so the 6x
   --  output bound stays provably within Natural.
   --  @param S  String to escape.
   --  @return The escaped JSON string.
   function Escape_JSON (S : String) return String
   with
     SPARK_Mode => On,
     Pre        => S'Length <= Max_Esc_Src,
     Post       => Escape_JSON'Result'Length <= 6 * S'Length,
     Global     => null;

   --  Maximum source length Escape_JSON accepts.  Kept well below
   --  Natural'Last / 6 so the 6x output buffer bound is provable with
   --  constant-coefficient arithmetic (no division-floor reasoning needed).
   --  SBOM field values (names, licenses, descriptions, PURLs) are far
   --  smaller than this cap.
   Max_Esc_Src : constant := 200_000;

   --  Decimal string of a non-negative integer.  A fixed 10-character buffer
   --  holds any Natural (up to 2,147,483,647, ten digits); the loop invariant
   --  proves the write cursor never underflows the buffer.
   --  @param N  Non-negative integer to format.
   --  @return The decimal string, 1-10 characters, no leading zeros.
   function I2S (N : Natural) return String
   with
     SPARK_Mode => On,
     Post       =>
       I2S'Result'First in 1 .. 10
       and I2S'Result'Last in 1 .. 10
       and I2S'Result'Length in 1 .. 10,
     Global     => null;

   --  Two-digit-padded decimal string of a non-negative integer (single
   --  digits are prefixed with a zero).
   --  @param N  Non-negative integer to format.
   --  @return Two-or-more-digit zero-padded decimal string.
   function Pad2 (N : Natural) return String
   with
     SPARK_Mode => On,
     Post       =>
       Pad2'Result'First in 1 .. 10
       and Pad2'Result'Last in 1 .. 11
       and Pad2'Result'Length in 1 .. 11,
     Global     => null;

   --  ISO 8601 UTC timestamp (YYYY-MM-DDTHH:MM:SS) from a Unix epoch second
   --  count, computed with pure integer arithmetic (Howard Hinnant's
   --  civil-from-days algorithm) so the result is identical on every machine
   --  and timezone.
   --  @param Epoch_Sec  Unix epoch seconds since 1970-01-01T00:00:00Z.
   --  @return The fixed-length ISO 8601 timestamp string.
   function ISO_From_Epoch (Epoch_Sec : Natural) return String
   with SPARK_Mode => On, Global => null;

   --  Write an SBOM in the requested format to Out_Path.
   --  Creates any missing parent directories and overwrites Out_Path.
   --  @param Format  SBOM format (CycloneDX_JSON, SPDX_JSON, or Markdown).
   --  @param Out_Path  Filesystem path to write the SBOM to.
   --  @param Graph  Dependency graph (index 1 = root component).
   --  @param Proof_Level  adacovex:proof_level property value.
   --  @param Standard  Compliance standard labelling the root assessment.
   --  @param DAL_Target  Shared rigor tier for adacovex:dal_target/level.
   --  @param Standard_All  True when --standard=all: emit the joined
   --    standard names and level labels for every standard instead of the
   --    single selected standard.
   --  @param Success  True if the SBOM was written successfully.
   procedure Write_SBOM
     (Format       : Types.SBOM_Format_Kind;
      Out_Path     : String;
      Graph        : Types.Implementation.Component_Vectors.Vector;
      Proof_Level  : String;
      Standard     : Types.Compliance_Standard;
      DAL_Target   : Types.DAL_Level;
      Standard_All : Boolean;
      Success      : out Boolean)
   with Pre => Out_Path'Length > 0;

   --  Write a CycloneDX 1.5 JSON SBOM to an already-open file.
   --  @param F  Output file to write the JSON document to.
   --  @param Graph  Dependency graph (index 1 = root component).
   --  @param Proof_Level  adacovex:proof_level property value.
   --  @param Standard  Compliance standard labelling the root assessment.
   --  @param DAL_Target  Shared rigor tier for adacovex:dal_target/level.
   --  @param Standard_All  True when --standard=all: emit the joined
   --    standard names and level labels for every standard.
   procedure Write_CycloneDX_To
     (F            : in out Ada.Text_IO.File_Type;
      Graph        : Types.Implementation.Component_Vectors.Vector;
      Proof_Level  : String;
      Standard     : Types.Compliance_Standard;
      DAL_Target   : Types.DAL_Level;
      Standard_All : Boolean);

   --  Write an SPDX 2.3 JSON SBOM to an already-open file.
   --  @param F  Output file to write the JSON document to.
   --  @param Graph  Dependency graph (index 1 = root component).
   --  @param Proof_Level  adacovex:proof_level property value.
   --  @param Standard  Compliance standard labelling the root assessment.
   --  @param DAL_Target  Shared rigor tier for adacovex:dal_target/level.
   --  @param Standard_All  True when --standard=all: emit the joined
   --    standard names and level labels for every standard.
   procedure Write_SPDX_To
     (F            : in out Ada.Text_IO.File_Type;
      Graph        : Types.Implementation.Component_Vectors.Vector;
      Proof_Level  : String;
      Standard     : Types.Compliance_Standard;
      DAL_Target   : Types.DAL_Level;
      Standard_All : Boolean);

   --  Write a human-readable Markdown SBOM to an already-open file.
   --  Renders a compliance table of every component with its version,
   --  license, PURL, proof level, standard, and DAL target properties.
   --  @param F  Output file to write the Markdown document to.
   --  @param Graph  Dependency graph (index 1 = root component).
   --  @param Proof_Level  adacovex:proof_level property value.
   --  @param Standard  Compliance standard labelling the root assessment.
   --  @param DAL_Target  Shared rigor tier for adacovex:dal_target/level.
   --  @param Standard_All  True when --standard=all: emit the joined
   --    standard names and level labels for every standard.
   procedure Write_Markdown_To
     (F            : in out Ada.Text_IO.File_Type;
      Graph        : Types.Implementation.Component_Vectors.Vector;
      Proof_Level  : String;
      Standard     : Types.Compliance_Standard;
      DAL_Target   : Types.DAL_Level;
      Standard_All : Boolean);

end Adacovex.Renderers.SBOM;
