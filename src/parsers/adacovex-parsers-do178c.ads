with Ada.Containers.Vectors;
with Adacovex.Types;

--  Parser for DO-178C requirements documents.
--  Reads HLR.md and LLR.md markdown files, extracts HLR/LLR identifiers
--  and descriptions, and matches HLR tags found in source code.
--  HLR-COMPLIANCE: HLR/LLR parsing

package Adacovex.Parsers.DO178C is

   type HLR_Info is record
      Id     : String (1 .. Types.Max_Id_Str);
      Id_Len : Natural := 0;
      Desc   : String (1 .. Types.Max_Desc_Str);
      D_Len  : Natural := 0;
   end record;

   package HLR_Vectors is new Ada.Containers.Vectors (Positive, HLR_Info);

   type LLR_Info is record
      Id      : String (1 .. Types.Max_Id_Str);
      Id_Len  : Natural := 0;
      HLR_Ref : String (1 .. Types.Max_Id_Str);
      HLR_Len : Natural := 0;
      Desc    : String (1 .. Types.Max_Desc_Str);
      D_Len   : Natural := 0;
   end record;

   package LLR_Vectors is new Ada.Containers.Vectors (Positive, LLR_Info);

   --  Parse an HLR.md file, extracting HLR entries and descriptions.
   --  Scans a Markdown file for lines matching "HLR_xxxx: Description",
   --  storing entries in the output vector.  With Use_Cache the parsed
   --  vector is keyed in the on-disk result cache by the file's content hash
   --  (SHA-256), so an unchanged HLR.md is served without re-parsing.
   --  @param File_Path  Path to HLR.md markdown file.
   --  @param HLRs  Output vector of HLR entries (appended to).
   --  @param Success  True if file was parsed successfully.
   --  @param Use_Cache  When True, serve/store the result in the on-disk
   --    result cache keyed by file content; when False, always re-parse.
   procedure Parse_HLR_MD
     (File_Path : String;
      HLRs      : in out HLR_Vectors.Vector;
      Success   : out Boolean;
      Use_Cache : Boolean := False)
   with Pre => File_Path'Length > 0;

   --  Parse an LLR.md file, extracting LLR_xxxx entries with HLR references.
   --  Scans a Markdown file for lines matching "LLR_xxxx: Description",
   --  including the HLR_xxxx reference, storing entries in the output vector.
   --  With Use_Cache the parsed vector is keyed in the on-disk result cache
   --  by the file's content hash (SHA-256).
   --  @param File_Path  Path to LLR.md markdown file.
   --  @param LLRs  Output vector of LLR entries (appended to).
   --  @param Success  True if file was parsed successfully.
   --  @param Use_Cache  When True, serve/store the result in the on-disk
   --    result cache keyed by file content; when False, always re-parse.
   procedure Parse_LLR_MD
     (File_Path : String;
      LLRs      : in out LLR_Vectors.Vector;
      Success   : out Boolean;
      Use_Cache : Boolean := False)
   with Pre => File_Path'Length > 0;

   --  Check whether an HLR identifier appears as a source-code tag
   --  anywhere in the scanned package set.
   --  Searches the HLR_Tags array of every scanned package for a match.
   --  @param HLR_Id  HLR identifier to search for.
   --  @param Packages  Vector of scanned packages.
   --  @return True if HLR_Id appears as a source-code tag in any package.
   function Find_HLR_In_Source
     (HLR_Id : String; Packages : Types.Implementation.Package_Vectors.Vector)
      return Boolean
   with Global => null;

end Adacovex.Parsers.DO178C;
