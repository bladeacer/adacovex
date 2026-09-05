--  Cyclomatic complexity checker for Ada source files.
--  It scans a target directory for .ads/.adb files.  It computes per-file
--  and per-subprogram cyclomatic complexity.  It enforces configurable
--  LOC and complexity gates.  The implementation is native Ada with no
--  external dependencies.
--  HLR-COMPLEXITY: Cyclomatic complexity analysis
--
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Text_IO;

package Adacovex.Complexity is

   pragma SPARK_Mode (Off);

   Max_Message : constant := 256;

   type Subprogram_Info is record
      Name       : String (1 .. 128);
      Name_Len   : Natural := 0;
      Line       : Natural := 0;
      Complexity : Natural := 0;
      LOC        : Natural := 0;
   end record;

   package Subprogram_Vectors is new
     Ada.Containers.Vectors (Positive, Subprogram_Info);

   type File_Metrics is record
      Path          : String (1 .. 4096);
      Path_Len      : Natural := 0;
      LOC           : Natural := 0;
      Complexity    : Natural := 0;
      Total_Lines   : Natural := 0;
      Code_Lines    : Natural := 0;
      Comment_Lines : Natural := 0;
      Blank_Lines   : Natural := 0;
      Language      : String (1 .. 16);
      Language_Len  : Natural := 0;
      Subs          : Subprogram_Vectors.Vector;
   end record;

   package File_Vectors is new Ada.Containers.Vectors (Positive, File_Metrics);

   type Violation is record
      File_Path : String (1 .. 4096);
      File_Len  : Natural := 0;
      Message   : String (1 .. Max_Message);
      Msg_Len   : Natural := 0;
   end record;

   package Violation_Vectors is new
     Ada.Containers.Vectors (Positive, Violation);

   type Complexity_Result is record
      Files      : File_Vectors.Vector;
      Total_LOC  : Natural := 0;
      Violations : Violation_Vectors.Vector;
   end record;

   --  Scan Target_Dir for source files across supported languages.  Return
   --  per-file and per-subprogram cyclomatic complexity metrics.  Excludes is
   --  a comma-separated list of file extensions to skip (no leading dots),
   --  for example "md,rst".  Per-subprogram analysis is Ada-specific; the
   --  other languages contribute file-level LOC and decision counts.
   --  Skip_Paths is a comma-separated list of path fragments; any file
   --  whose full path contains one of them is skipped.  A file whose
   --  leading comment block carries the no-covex-complexity-scan marker
   --  (or no-covex-analysis) is skipped too -- see Adacovex.Opt_Outs.
   --  @brief Walk Target_Dir and compute complexity for every source file.
   --  @param Target_Dir  Project root directory to scan.
   --  @param Excludes  Comma-separated file extensions to skip.
   --  @param Skip_Paths  Comma-separated path fragments to skip.
   --  @return Aggregate complexity metrics for the scanned files.
   function Analyze_Project
     (Target_Dir : String; Excludes : String := ""; Skip_Paths : String := "")
      return Complexity_Result;

   --  Evaluate Result against the supplied thresholds.  Return the list of
   --  violations.  The list is empty when every gate passes.
   --  @brief Check Result against Max_File_LOC, Max_File_Pct, Max_Fn_Complexity, and Max_File_Complexity.
   function Check_Gates
     (Result              : Complexity_Result;
      Max_File_LOC        : Natural;
      Max_File_Pct        : Natural;
      Max_Fn_Complexity   : Natural;
      Max_File_Complexity : Natural) return Violation_Vectors.Vector;

   --  Emit a human-readable report to stdout.  When Check_Mode is True, the
   --  output shows only when Violations is not empty.  Otherwise every file
   --  and subprogram is printed.
   --  @brief Print a human-readable complexity report to stdout.
   procedure Print_Report
     (Result              : Complexity_Result;
      Check_Mode          : Boolean;
      Violations          : Violation_Vectors.Vector;
      Max_File_LOC        : Natural;
      Max_File_Pct        : Natural;
      Max_Fn_Complexity   : Natural;
      Max_File_Complexity : Natural);

end Adacovex.Complexity;
