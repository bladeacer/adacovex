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
      Path       : String (1 .. 4096);
      Path_Len   : Natural := 0;
      LOC        : Natural := 0;
      Complexity : Natural := 0;
      Subs       : Subprogram_Vectors.Vector;
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

   --  Scan Target_Dir for Ada source files and return per-file and per-
   --  subprogram cyclomatic complexity metrics.
   function Analyze_Project (Target_Dir : String) return Complexity_Result;

   --  Evaluate Result against the supplied thresholds and return the list of
   --  violations (empty when every gate passes).
   function Check_Gates
     (Result              : Complexity_Result;
      Max_File_LOC        : Natural;
      Max_File_Pct        : Natural;
      Max_Fn_Complexity   : Natural;
      Max_File_Complexity : Natural) return Violation_Vectors.Vector;

   --  Emit a human-readable report to stdout.  When Check_Mode is True the
   --  output is gated on Violations being non-empty; otherwise every file
   --  and subprogram is always printed.
   procedure Print_Report
     (Result              : Complexity_Result;
      Check_Mode          : Boolean;
      Violations          : Violation_Vectors.Vector;
      Max_File_LOC        : Natural;
      Max_File_Pct        : Natural;
      Max_Fn_Complexity   : Natural;
      Max_File_Complexity : Natural);

end Adacovex.Complexity;
