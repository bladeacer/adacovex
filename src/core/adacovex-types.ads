--  All domain types used across the adacovex tool chain.
--  Every type is bounded at compile time; no heap allocation is used.

package Adacovex.Types is

   Max_Hlrs      : constant := 64;
   Max_Llrs      : constant := 64;
   Max_Packages  : constant := 64;
   Max_Subprogs  : constant := 64;
   Max_Params    : constant := 8;
   Max_Path      : constant := 256;
   Max_Line      : constant := 512;
   Max_Id_Str    : constant := 64;
   Max_Desc_Str  : constant := 128;
   Max_Filename  : constant := 64;
   Max_VC_Count  : constant := 128;
   Max_Badge_Path: constant := 128;
   Max_Metrics   : constant := 32;

   subtype HLR_Index is Positive range 1 .. Max_Hlrs;
   subtype LLR_Index is Positive range 1 .. Max_Llrs;

   subtype Desc_Field is String (1 .. Max_Desc_Str);
   subtype Name_Field is String (1 .. Max_Filename);
   subtype Path_Field is String (1 .. Max_Path);

   type HLR_Tag_Entry is record
      Tag : String (1 .. Max_Id_Str);
      Len : Natural := 0;
   end record;

   type HLR_Tag_Array is array (1 .. Max_Hlrs) of HLR_Tag_Entry;

   type SPARK_Level is (Stone, Bronze, Silver, Gold, Platinum);

   type DAL_Level is (DAL_A, DAL_B, DAL_C, DAL_D, DAL_E);

   type DAL_Status is (Achieved, Unmet);

   type Test_Status is (Pass, Fail);

   type Subprogram_Info is record
      Name          : Desc_Field;
      Name_Len      : Natural := 0;
      Has_Docstring : Boolean := False;
      Param_Count   : Natural := 0;
      Doc_Param_Ct  : Natural := 0;
      Has_Return    : Boolean := False;
      Doc_Return    : Boolean := False;
   end record;

   type Subprogram_Array is array (1 .. Max_Subprogs) of Subprogram_Info;

   type Package_Info is record
      Name             : Name_Field;
      Name_Len         : Natural := 0;
      File_Path        : Path_Field;
      Path_Len         : Natural := 0;
      Subprogram_List  : Subprogram_Array;
      Subprogram_Count : Natural := 0;
      Total_HLR_Tags   : Natural := 0;
      HLR_Tags         : HLR_Tag_Array;
   end record;

   type Package_Array is array (1 .. Max_Packages) of Package_Info;

   type VC_Info is record
      Unit       : Desc_Field;
      Unit_Len   : Natural := 0;
      Check_Type : Desc_Field;
      Check_Len  : Natural := 0;
      Status     : Desc_Field;
      Stat_Len   : Natural := 0;
   end record;

   type VC_Vector is array (1 .. Max_VC_Count) of VC_Info;

   type Proof_Summary is record
      Total_VCs        : Natural := 0;
      Proved_VCs       : Natural := 0;
      Flow_Checks      : Natural := 0;
      Flow_Proved      : Natural := 0;
      Runtime_Checks   : Natural := 0;
      Runtime_Proved   : Natural := 0;
      Assertions       : Natural := 0;
      Assert_Proved    : Natural := 0;
      Functional_Ct    : Natural := 0;
      Functional_Proved: Natural := 0;
      Termination_Ct   : Natural := 0;
      Termination_Proved: Natural := 0;
      Justified        : Natural := 0;
      Unproved         : Natural := 0;
      Level            : SPARK_Level := Stone;
      Units_Analyzed   : Natural := 0;
      Units_Skipped    : Natural := 0;
   end record;

   type Test_Metrics is record
      Category   : Desc_Field;
      Cat_Len    : Natural := 0;
      Test_Count : Natural := 0;
      Status     : Test_Status := Pass;
   end record;

   type Test_Metrics_Array is array (1 .. 32) of Test_Metrics;

   type Test_Summary is record
      Categories     : Test_Metrics_Array;
      Category_Count : Natural := 0;
      Total_Passed   : Natural := 0;
      Total_Failed   : Natural := 0;
   end record;

   type Docstring_Metrics is record
      Total_Subprograms   : Natural := 0;
      Documented_Subprogs : Natural := 0;
      Total_Parameters    : Natural := 0;
      Documented_Params   : Natural := 0;
      Total_Returns       : Natural := 0;
      Documented_Returns  : Natural := 0;
      Coverage_Pct        : Natural := 0;
   end record;

   type DAL_Failure_Array is array (1 .. 16) of Desc_Field;

   type DAL_Assessment is record
      Target_DAL            : DAL_Level := DAL_C;
      Status                : DAL_Status := Unmet;
      HLR_Total             : Natural := 0;
      HLR_Found             : Natural := 0;
      LLR_Total             : Natural := 0;
      LLR_Found             : Natural := 0;
      All_Subprograms_Traced: Boolean := False;
      Orphan_Tags           : Boolean := False;
      Tests_Passing         : Boolean := False;
      Min_SPARK_Level_Met   : Boolean := False;
      Failed_Reasons        : DAL_Failure_Array;
      Failed_Count          : Natural := 0;
   end record;

   type Badge_Config is record
      Spark_Lvl   : SPARK_Level := Stone;
      Test_Summ   : Test_Summary;
      DAL_Assess  : DAL_Assessment;
      Show_Spark  : Boolean := True;
      Show_Tests  : Boolean := True;
      Show_DO178C : Boolean := True;
   end record;

   --  Convert a SPARK_Level to its human-readable name.
   function To_String (L : SPARK_Level) return String;
   --  Convert a DAL_Level to its single-letter code (A–E).
   function To_String (L : DAL_Level) return String;
   --  Parse a single-letter DAL code string into a DAL_Level.
   --  Accepts both upper and lower case; defaults to DAL_C on parse failure.
   function To_DAL (S : String) return DAL_Level;
   --  Convert a DAL_Status to its human-readable string.
   function To_String (S : DAL_Status) return String;
   --  Convert a Test_Status to "PASS" or "FAIL".
   function To_String (S : Test_Status) return String;

end Adacovex.Types;
