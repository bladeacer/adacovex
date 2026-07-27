with Adacovex.Types;

--  Parser for DO-178C requirements documents.
--  Reads HLR.md and LLR.md markdown files, extracts HLR/LLR identifiers
--  and descriptions, and matches HLR tags found in source code.
--  HLR-COMPLIANCE: HLR/LLR parsing

package Adacovex.Parsers.DO178C is
   pragma SPARK_Mode (On);

   type HLR_Info is record
      Id   : String (1 .. Types.Max_Id_Str);
      Id_Len : Natural := 0;
      Desc : String (1 .. Types.Max_Desc_Str);
      D_Len : Natural := 0;
   end record;

   type HLR_Array is array (1 .. Types.Max_Hlrs) of HLR_Info;

   type LLR_Info is record
      Id      : String (1 .. Types.Max_Id_Str);
      Id_Len  : Natural := 0;
      HLR_Ref : String (1 .. Types.Max_Id_Str);
      HLR_Len : Natural := 0;
      Desc    : String (1 .. Types.Max_Desc_Str);
      D_Len   : Natural := 0;
   end record;

   type LLR_Array is array (1 .. Types.Max_Llrs) of LLR_Info;

   --  Parse an HLR.md file, extracting HLR entries and descriptions.
   --  Scans a Markdown file for lines matching "HLR_xxxx: Description",
   --  storing up to Max_Hlrs entries in the output array.
   procedure Parse_HLR_MD
     (File_Path : String;
      HLRs      : out HLR_Array;
      HLR_Count : out Natural;
      Success   : out Boolean)
     with Pre  => File_Path'Length > 0,
          Post => HLR_Count <= Types.Max_Hlrs;

   --  Parse an LLR.md file, extracting LLR_xxxx entries with HLR references.
   --  Scans a Markdown file for lines matching "LLR_xxxx: Description",
   --  including the HLR_xxxx reference, storing up to Max_Llrs entries.
   procedure Parse_LLR_MD
     (File_Path : String;
      LLRs      : out LLR_Array;
      LLR_Count : out Natural;
      Success   : out Boolean)
     with Pre  => File_Path'Length > 0,
          Post => LLR_Count <= Types.Max_Llrs;

   --  Check whether an HLR identifier appears as a source-code tag
   --  anywhere in the scanned package set.
   --  Searches the HLR_Tags array of every scanned package for a match.
   function Find_HLR_In_Source
     (HLR_Id   : String;
      Packages : Types.Package_Array;
      Pkg_Count: Natural) return Boolean
     with Pre  => HLR_Id'Length > 0
                  and then Pkg_Count <= Types.Max_Packages,
          Global => null;

end Adacovex.Parsers.DO178C;
