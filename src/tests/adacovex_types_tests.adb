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

      --  Compliance-standard conversions + level re-labelling (1.10.0).
      R.Check
        (To_String (DO_178C) = "DO-178C",
         "Compliance_Standard DO_178C -> string");
      R.Check
        (To_String (ISO_26262) = "ISO 26262",
         "Compliance_Standard ISO_26262 -> string");
      R.Check
        (To_String (IEC_62304) = "IEC 62304",
         "Compliance_Standard IEC_62304 -> string");

      R.Check (To_Standard ("do178c") = DO_178C, "String do178c -> DO_178C");
      R.Check (To_Standard ("DO-178C") = DO_178C, "String DO-178C -> DO_178C");
      R.Check
        (To_Standard ("iso26262") = ISO_26262, "String iso26262 -> ISO_26262");
      R.Check
        (To_Standard ("ISO-26262") = ISO_26262,
         "String ISO-26262 -> ISO_26262");
      R.Check
        (To_Standard ("iec62304") = IEC_62304, "String iec62304 -> IEC_62304");
      R.Check
        (To_Standard ("IEC-62304") = IEC_62304,
         "String IEC-62304 -> IEC_62304");
      R.Check
        (To_Standard ("bogus") = DO_178C,
         "Unknown standard -> DO_178C default");
      R.Check
        (To_Standard ("") = DO_178C, "Empty standard -> DO_178C default");

      --  Standard-aware level labels.
      R.Check
        (Standard_Level_Name (DO_178C, DAL_C) = "DAL-C",
         "DO-178C DAL C -> DAL-C");
      R.Check
        (Standard_Level_Name (ISO_26262, DAL_C) = "ASIL B",
         "ISO 26262 DAL C -> ASIL B");
      R.Check
        (Standard_Level_Name (ISO_26262, DAL_A) = "ASIL D",
         "ISO 26262 DAL A -> ASIL D");
      R.Check
        (Standard_Level_Name (ISO_26262, DAL_E) = "QM",
         "ISO 26262 DAL E -> QM");
      R.Check
        (Standard_Level_Name (IEC_62304, DAL_C) = "Class A",
         "IEC 62304 DAL C -> Class A");
      R.Check
        (Standard_Level_Name (IEC_62304, DAL_A) = "Class C",
         "IEC 62304 DAL A -> Class C");
      R.Check
        (Standard_Level_Name (IEC_62304, DAL_E) = "No class",
         "IEC 62304 DAL E -> No class");

      --  Dedicated level parsers (1.10.0): ASIL + IEC safety-class selectors.
      R.Check (To_ASIL ("A") = DAL_D, "ASIL A -> DAL_D tier");
      R.Check (To_ASIL ("B") = DAL_C, "ASIL B -> DAL_C tier");
      R.Check (To_ASIL ("C") = DAL_B, "ASIL C -> DAL_B tier");
      R.Check (To_ASIL ("D") = DAL_A, "ASIL D -> DAL_A tier");
      R.Check (To_ASIL ("QM") = DAL_E, "ASIL QM -> DAL_E tier");
      R.Check (To_ASIL ("qm") = DAL_E, "ASIL qm -> DAL_E tier (lowercase)");
      R.Check (To_ASIL ("X") = DAL_C, "ASIL X -> DAL_C (unknown default)");
      R.Check (Is_Valid_ASIL ("B"), "Is_Valid_ASIL B true");
      R.Check (Is_Valid_ASIL ("qm"), "Is_Valid_ASIL qm true");
      R.Check (not Is_Valid_ASIL ("E"), "Is_Valid_ASIL E false");
      R.Check (not Is_Valid_ASIL (""), "Is_Valid_ASIL empty false");

      R.Check (To_Class ("A") = DAL_C, "Class A -> DAL_C tier");
      R.Check (To_Class ("B") = DAL_B, "Class B -> DAL_B tier");
      R.Check (To_Class ("C") = DAL_A, "Class C -> DAL_A tier");
      R.Check (To_Class ("c") = DAL_A, "Class c -> DAL_A tier (lowercase)");
      R.Check (To_Class ("D") = DAL_C, "Class D -> DAL_C (unknown default)");
      R.Check (Is_Valid_Class ("A"), "Is_Valid_Class A true");
      R.Check (Is_Valid_Class ("c"), "Is_Valid_Class c true");
      R.Check (not Is_Valid_Class ("D"), "Is_Valid_Class D false");
      R.Check (not Is_Valid_Class (""), "Is_Valid_Class empty false");

      R.Check (Standard_Slug (DO_178C) = "do178c", "Standard_Slug DO_178C");
      R.Check
        (Standard_Slug (ISO_26262) = "iso26262", "Standard_Slug ISO_26262");
      R.Check
        (Standard_Slug (IEC_62304) = "iec62304", "Standard_Slug IEC_62304");

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
