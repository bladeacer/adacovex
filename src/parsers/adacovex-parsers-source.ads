with Adacovex.Types;

--  Ada source-file scanner.
--  Walks a project directory tree, reads every .ads file, extracts
--  subprogram declarations, HLR tags, and docstring annotations.

package Adacovex.Parsers.Source is

   --  Scan a single .ads file, extracting subprogram info and HLR tags.
   procedure Scan_Ads_File
     (File_Path : String;
      Pkg       : out Types.Package_Info;
      Success   : out Boolean);

   --  Recursively scan all .ads files under Target_Dir.
   procedure Scan_Project
     (Target_Dir : String;
      Packages   : out Types.Package_Array;
      Pkg_Count  : out Natural);

   --  Compute aggregate docstring-coverage metrics from scanned packages.
   function Compute_Docstring_Metrics
     (Packages  : Types.Package_Array;
      Pkg_Count : Natural) return Types.Docstring_Metrics;

end Adacovex.Parsers.Source;
