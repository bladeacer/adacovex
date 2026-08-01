--  All domain types used across the adacovex tool chain.
--  Package and subprogram collections use Ada.Containers.Vectors
--  (unbounded, up to Natural'Last ~ 2.1B). Fixed-size buffers
--  (Max_Path, Max_Line, Max_Desc_Str, etc.) are bounded at compile time
--  with generous production-suitable limits (Max_Path=4096, Max_Line=8192).
--  HLR-METRICS: Docstring_Metrics type
--  HLR-PROOF: Proof_Summary type
--  HLR-TEST: Test_Summary type
--  HLR-COMPLIANCE: DAL_Assessment type
--  HLR-DAL-A: DAL_Level (DAL_A)
--  HLR-DAL-B: DAL_Level (DAL_B)
--  HLR-DAL-C: DAL_Level (DAL_C)
--  HLR-DAL-D: DAL_Level (DAL_D)
--  HLR-DAL-E: DAL_Level (DAL_E)

with Ada.Containers.Vectors;

package Adacovex.Types is
   pragma SPARK_Mode (On);

   Max_Path     : constant := 4096;
   Max_Line     : constant := 8192;
   Max_Id_Str   : constant := 64;
   Max_Desc_Str : constant := 128;
   Max_Filename : constant := 128;

   subtype Desc_Field is String (1 .. Max_Desc_Str);
   subtype Name_Field is String (1 .. Max_Filename);
   subtype Path_Field is String (1 .. Max_Path);

   type HLR_Tag_Entry is record
      Tag : String (1 .. Max_Id_Str);
      Len : Natural := 0;
   end record;

   type SPARK_Level is (Stone, Bronze, Silver, Gold, Platinum);

   type DAL_Level is (DAL_A, DAL_B, DAL_C, DAL_D, DAL_E);

   type DAL_Status is (Achieved, Unmet);

   type Test_Status is (Pass, Fail);

   type Subprogram_Info is record
      Name          : Desc_Field;
      Name_Len      : Natural := 0;
      Line_Number   : Natural := 0;
      Has_Docstring : Boolean := False;
      Doc_Param_Ct  : Natural := 0;
      Has_Return    : Boolean := False;
      Doc_Return    : Boolean := False;
   end record;

   type Proof_Summary is record
      Total_VCs          : Natural := 0;
      Proved_VCs         : Natural := 0;
      Flow_Checks        : Natural := 0;
      Flow_Proved        : Natural := 0;
      Init_Checks        : Natural := 0;
      Init_Proved        : Natural := 0;
      Runtime_Checks     : Natural := 0;
      Runtime_Proved     : Natural := 0;
      Assertions         : Natural := 0;
      Assert_Proved      : Natural := 0;
      Functional_Ct      : Natural := 0;
      Functional_Proved  : Natural := 0;
      Termination_Ct     : Natural := 0;
      Termination_Proved : Natural := 0;
      Justified          : Natural := 0;
      Unproved           : Natural := 0;
      Level              : SPARK_Level := Stone;
      Units_Analyzed     : Natural := 0;
      Units_Skipped      : Natural := 0;
   end record;

   type Test_Metrics is record
      Category   : Desc_Field;
      Cat_Len    : Natural := 0;
      Test_Count : Natural := 0;
      Status     : Test_Status := Pass;
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

   package Implementation is
      pragma SPARK_Mode (Off);
      package Subprogram_Vectors is new
        Ada.Containers.Vectors (Positive, Subprogram_Info);

      package HLR_Tag_Vectors is new
        Ada.Containers.Vectors (Positive, HLR_Tag_Entry);

      type Package_Info is record
         Name        : Name_Field;
         Name_Len    : Natural := 0;
         File_Path   : Path_Field;
         Path_Len    : Natural := 0;
         Subprograms : Subprogram_Vectors.Vector;
         HLR_Tags    : HLR_Tag_Vectors.Vector;
      end record;

      package Package_Vectors is new
        Ada.Containers.Vectors (Positive, Package_Info);

      package Test_Metrics_Vectors is new
        Ada.Containers.Vectors (Positive, Test_Metrics);

      type Test_Summary is record
         Categories   : Test_Metrics_Vectors.Vector;
         Total_Passed : Natural := 0;
         Total_Failed : Natural := 0;
      end record;

      package DAL_Failure_Vectors is new
        Ada.Containers.Vectors (Positive, Desc_Field);

      type DAL_Assessment is record
         Target_DAL             : DAL_Level := DAL_C;
         Status                 : DAL_Status := Unmet;
         HLR_Total              : Natural := 0;
         HLR_Found              : Natural := 0;
         LLR_Total              : Natural := 0;
         LLR_Found              : Natural := 0;
         All_Subprograms_Traced : Boolean := False;
         Orphan_Tags            : Boolean := False;
         Tests_Passing          : Boolean := False;
         Min_SPARK_Level_Met    : Boolean := False;
         Failed_Reasons         : DAL_Failure_Vectors.Vector;
      end record;

      type Badge_Config is record
         Spark_Lvl   : SPARK_Level := Stone;
         Test_Summ   : Test_Summary;
         DAL_Assess  : DAL_Assessment;
         Show_Spark  : Boolean := True;
         Show_Tests  : Boolean := True;
         Show_DO178C : Boolean := True;
      end record;
   end Implementation;

   --  Convert a SPARK_Level to its human-readable name.
   --  Returns "Stone", "Bronze", "Silver", "Gold", or "Platinum".
   --  @return Human-readable SPARK level name.
   function To_String (L : SPARK_Level) return String
   with
     Post   =>
       To_String'Result'Length > 0 and then To_String'Result'Length <= 8,
     Global => null;

   --  Convert a DAL_Level to its single-letter code ('A' through 'E').
   --  @return Single-letter DAL code.
   function To_String (L : DAL_Level) return String
   with Post => To_String'Result'Length = 1, Global => null;

   --  Parse a single-letter DAL code string into a DAL_Level.
   --  Accepts both upper and lower case; defaults to DAL_C on parse failure.
   --  @param S  Single-letter DAL code (A-E, case-insensitive).
   --  @return Converted DAL_Level (defaults to DAL_C on failure).
   function To_DAL (S : String) return DAL_Level
   with Global => null;

   --  Convert a DAL_Status ("Achieved" or "Unmet") to its human-readable string.
   --  @return "Achieved" or "Unmet".
   function To_String (S : DAL_Status) return String
   with Post => To_String'Result'Length > 0, Global => null;

   --  Convert a Test_Status ("Pass" or "Fail") to "PASS" or "FAIL".
   --  @return "PASS" or "FAIL".
   function To_String (S : Test_Status) return String
   with Post => To_String'Result'Length > 0, Global => null;

end Adacovex.Types;
