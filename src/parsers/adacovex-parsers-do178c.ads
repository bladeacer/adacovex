with Adacovex.Types;

package Adacovex.Parsers.DO178C is

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

   procedure Parse_HLR_MD
     (File_Path : String;
      HLRs      : out HLR_Array;
      HLR_Count : out Natural;
      Success   : out Boolean);

   procedure Parse_LLR_MD
     (File_Path : String;
      LLRs      : out LLR_Array;
      LLR_Count : out Natural;
      Success   : out Boolean);

   function Find_HLR_In_Source
     (HLR_Id   : String;
      Packages : Types.Package_Array;
      Pkg_Count: Natural) return Boolean;

end Adacovex.Parsers.DO178C;
