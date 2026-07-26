with Adacovex.Types;

package Adacovex.Parsers.Source is

   procedure Scan_Ads_File
     (File_Path : String;
      Pkg       : out Types.Package_Info;
      Success   : out Boolean);

   procedure Scan_Project
     (Target_Dir : String;
      Packages   : out Types.Package_Array;
      Pkg_Count  : out Natural);

   function Compute_Docstring_Metrics
     (Packages  : Types.Package_Array;
      Pkg_Count : Natural) return Types.Docstring_Metrics;

end Adacovex.Parsers.Source;
