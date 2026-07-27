with Adacovex.Types;

--  Ada source-file scanner.
--  Walks a project directory tree, reads every .ads file, extracts
--  subprogram declarations, HLR tags, and docstring annotations.
--  HLR-SCAN: Source scanning

package Adacovex.Parsers.Source is
   pragma SPARK_Mode (On);

   --  Scan a single .ads file, extracting subprogram info and HLR tags.
   --  File_Path must name a readable .ads file. On success, Pkg is populated
   --  with subprogram declarations, docstring annotations, and HLR tag entries.
   procedure Scan_Ads_File
     (File_Path : String;
      Pkg       : out Types.Package_Info;
      Success   : out Boolean)
     with Pre  => File_Path'Length > 0,
          Post => (if Success then Pkg.Name_Len > 0);

   --  Recursively scan all .ads files under Target_Dir.
   --  Walks the directory tree rooted at Target_Dir, parsing every .ads file
   --  found. Returns an array of up to Max_Packages package records.
   procedure Scan_Project
     (Target_Dir : String;
      Packages   : out Types.Package_Array;
      Pkg_Count  : out Natural)
     with Pre  => Target_Dir'Length > 0,
          Post => Pkg_Count <= Types.Max_Packages;

   --  Compute aggregate docstring-coverage metrics from scanned packages.
   --  Tallies documented vs. undocumented subprograms, parameters, and return
   --  values across all scanned packages.
   function Compute_Docstring_Metrics
     (Packages  : Types.Package_Array;
      Pkg_Count : Natural) return Types.Docstring_Metrics
     with Pre  => Pkg_Count <= Types.Max_Packages,
          Post => Compute_Docstring_Metrics'Result.Total_Subprograms <= 64 * Pkg_Count,
          Global => null;

end Adacovex.Parsers.Source;
