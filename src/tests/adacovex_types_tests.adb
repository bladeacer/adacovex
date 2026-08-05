with Adacovex.Types; use Adacovex.Types;
with System;

package body Adacovex_Types_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      R.Check (To_String (Stone) = "Stone", "SPARK_Level Stone -> string");
      R.Check (To_String (Bronze) = "Bronze", "SPARK_Level Bronze -> string");
      R.Check (To_String (Silver) = "Silver", "SPARK_Level Silver -> string");
      R.Check (To_String (Gold) = "Gold", "SPARK_Level Gold -> string");
      R.Check
        (To_String (Platinum) = "Platinum", "SPARK_Level Platinum -> string");

      R.Check (To_String (DAL_A) = "A", "DAL_Level A -> string");
      R.Check (To_String (DAL_B) = "B", "DAL_Level B -> string");
      R.Check (To_String (DAL_C) = "C", "DAL_Level C -> string");
      R.Check (To_String (DAL_D) = "D", "DAL_Level D -> string");
      R.Check (To_String (DAL_E) = "E", "DAL_Level E -> string");

      R.Check (To_DAL ("A") = DAL_A, "String A -> DAL_A");
      R.Check (To_DAL ("C") = DAL_C, "String C -> DAL_C");
      R.Check (To_DAL ("E") = DAL_E, "String E -> DAL_E");
      R.Check (To_DAL ("b") = DAL_B, "String b -> DAL_B (lowercase)");
      R.Check (To_DAL ("d") = DAL_D, "String d -> DAL_D (lowercase)");
      R.Check (To_DAL ("X") = DAL_C, "String X -> DAL_C (unknown default)");
      R.Check (To_DAL ("") = DAL_C, "String empty -> DAL_C (default)");

      R.Check
        (To_String (Achieved) = "Achieved", "DAL_Status Achieved -> string");
      R.Check (To_String (Unmet) = "Unmet", "DAL_Status Unmet -> string");

      R.Check (To_String (Pass) = "PASS", "Test_Status Pass -> string");
      R.Check (To_String (Fail) = "FAIL", "Test_Status Fail -> string");

      --  Host word-size auto-detection (added 1.6.0).
      R.Check
        (Host_Word_Bits = System.Word_Size,
         "Host_Word_Bits matches System.Word_Size");
      R.Check
        (Host_Word_Bits in 8 | 16 | 32 | 64,
         "Host_Word_Bits is a supported word size");
      R.Check
        (Max_Path = 64 * System.Word_Size,
         "Max_Path scales with host word size");
      R.Check
        (Max_Line = 4096 * System.Word_Size,
         "Max_Line scales with host word size");
      R.Check
        (Max_Desc_Str = 128 and Max_Filename = 128 and Max_Id_Str = 64,
         "Identifier/description limits remain fixed");
   end Run;

end Adacovex_Types_Tests;
