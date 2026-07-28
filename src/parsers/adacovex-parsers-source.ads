with Adacovex.Types;

--  Ada source-file scanner.
--  Walks a project directory tree, reads every .ads file, extracts
--  subprogram declarations, HLR tags, and docstring annotations.
--  HLR-SCAN: Source scanning
--
--  Supported docstring annotations (placed immediately before a
--  subprogram declaration, no intervening blank lines):
--    @param Name  Description.       -- Document a formal parameter
--    @return Description.            -- Document a function return value
--    @field Description.             -- Document a record component
--    @formal Name  Description.      -- Document a generic formal
--
--  Conventions (following Ada_CRDT style):
--    Prefix:  --   (two dashes + two spaces)
--    Summary: Capitalized sentence ending with a period.
--    Alignment: Two spaces between tag name and description text.
--    Placement: Summary lines first, then tag lines, then declaration.

package Adacovex.Parsers.Source is
   pragma SPARK_Mode (On);

   --  Scan a single .ads file, extracting subprogram info and HLR tags.
   --  File_Path must name a readable .ads file. On success, Pkg is populated
   --  with subprogram declarations, docstring annotations, and HLR tag entries.
   --  @param File_Path  Path to .ads file.
   --  @param Pkg  Output package info.
   --  @param Success  True if file was successfully parsed.
   procedure Scan_Ads_File
     (File_Path : String; Pkg : out Types.Package_Info; Success : out Boolean)
   with
     Pre  => File_Path'Length > 0,
     Post => (if Success then Pkg.Name_Len > 0);

   --  Recursively scan all .ads files under Target_Dir.
   --  Walks the directory tree rooted at Target_Dir, parsing every .ads file
   --  found. Returns an array of up to Max_Packages package records.
   --  @param Target_Dir  Root directory to scan recursively.
   --  @param Packages  Output array of parsed packages.
   --  @param Pkg_Count  Number of packages found.
   procedure Scan_Project
     (Target_Dir : String;
      Packages   : out Types.Package_Array;
      Pkg_Count  : out Natural)
   with Pre => Target_Dir'Length > 0, Post => Pkg_Count <= Types.Max_Packages;

   --  Compute aggregate docstring-coverage metrics from scanned packages.
   --  Tallies documented vs. undocumented subprograms, parameters, and return
   --  values across all scanned packages.
   --  @param Packages  Array of scanned packages.
   --  @param Pkg_Count  Number of packages in array.
   --  @return Aggregate docstring-coverage metrics.
   function Compute_Docstring_Metrics
     (Packages : Types.Package_Array; Pkg_Count : Natural)
      return Types.Docstring_Metrics
   with
     Pre    => Pkg_Count <= Types.Max_Packages,
     Post   =>
       Compute_Docstring_Metrics'Result.Total_Subprograms <= 64 * Pkg_Count,
     Global => null;

end Adacovex.Parsers.Source;
