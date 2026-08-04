with Ada.Strings.Fixed;
with Adacovex.Target_Profiles;
use Adacovex.Target_Profiles;
with Adacovex.IR_Synthesiser;
use Adacovex.IR_Synthesiser;
with Adacovex.IR_Bounds;
use Adacovex.IR_Bounds;

package body Adacovex_IR_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Cfg64 : constant Target_Config := (others => Bits_64);
      Cfg32 : constant Target_Config :=
        (Host_Bits => Bits_64, Target_Bits => Bits_32,
         Pointer_Bits => Bits_32);
   begin
      --  Test 1: bounded scalar type bounds.
      R.Check
        (IR_Int8'First = -128 and then IR_Int8'Last = 127,
         "Test 1: IR_Int8 bounds");
      R.Check
        (IR_Int16'First = -32768 and then IR_Int16'Last = 32767,
         "Test 1: IR_Int16 bounds");
      R.Check
        (IR_Int32'First = -2**31 and then IR_Int32'Last = 2**31 - 1,
         "Test 1: IR_Int32 bounds");
      R.Check
        (IR_Int64'First = -2**63 and then IR_Int64'Last = 2**63 - 1,
         "Test 1: IR_Int64 bounds");

      --  Test 2: unsigned modular types.
      R.Check
        (IR_UInt8'Modulus = 2**8 and then IR_UInt16'Modulus = 2**16,
         "Test 2: IR_UInt8/16 modulus");
      R.Check
        (IR_UInt32'Modulus = 2**32 and then IR_UInt64'Modulus = 2**64,
         "Test 2: IR_UInt32/64 modulus");

      --  Test 3: target config defaults and fields.
      declare
         C : constant Target_Config := (others => <>);
      begin
         R.Check
           (C.Host_Bits = Bits_64 and then C.Target_Bits = Bits_64
            and then C.Pointer_Bits = Bits_64,
            "Test 3: default target config is 64-bit host/target");
         R.Check
           (Cfg32.Target_Bits = Bits_32 and then Cfg32.Pointer_Bits = Bits_32,
            "Test 3: 32-bit target config fields");
      end;

      --  Test 4: IR_Type_Name fixed-width mappings.
      R.Check
        (IR_Type_Name ("int8_t", Cfg64) = "IR_Int8"
         and then IR_Type_Name ("uint8_t", Cfg64) = "IR_UInt8",
         "Test 4: int8_t/uint8_t mapping");
      R.Check
        (IR_Type_Name ("int32_t", Cfg64) = "IR_Int32"
         and then IR_Type_Name ("int64_t", Cfg64) = "IR_Int64",
         "Test 4: int32_t/int64_t mapping");
      R.Check
        (IR_Type_Name ("uint32_t", Cfg64) = "IR_UInt32"
         and then IR_Type_Name ("uint64_t", Cfg64) = "IR_UInt64",
         "Test 4: uint32_t/uint64_t mapping");

      --  Test 5: size-tagged mappings follow the target word size.
      R.Check
        (IR_Type_Name ("size_t", Cfg64) = "IR_UInt64"
         and then IR_Type_Name ("usize", Cfg64) = "IR_UInt64"
         and then IR_Type_Name ("isize", Cfg64) = "IR_Int64",
         "Test 5: size_t/usize/isize on a 64-bit target");
      R.Check
        (IR_Type_Name ("size_t", Cfg32) = "IR_UInt32"
         and then IR_Type_Name ("ptrdiff_t", Cfg32) = "IR_Int32"
         and then IR_Type_Name ("uintptr_t", Cfg32) = "IR_UInt32",
         "Test 5: size_t/ptrdiff_t/uintptr_t on a 32-bit target");
      R.Check
        (IR_Type_Name ("size_t", Cfg64) = "IR_UInt64"
         and then IR_Type_Name ("ptrdiff_t", Cfg32) = "IR_Int32",
         "Test 5: pointer-tagged types follow pointer width");

      --  Test 6: unrecognized names map to an empty string.
      R.Check
        (IR_Type_Name ("float", Cfg64) = ""
         and then IR_Type_Name ("", Cfg64) = ""
         and then IR_Type_Name ("INT32_T", Cfg64) = "",
         "Test 6: unrecognized / case-mismatched names are empty");

      --  Test 7: Lower_Type_Name synthesized declarations.
      R.Check
        (Lower_Type_Name ("int32_t", Cfg64)
         = "type int32_t is new Adacovex.Target_Profiles.IR_Int32;",
         "Test 7: int32_t lowered declaration");
      R.Check
        (Lower_Type_Name ("size_t", Cfg64)
         = "type size_t is new Adacovex.Target_Profiles.IR_UInt64;",
         "Test 7: size_t lowered declaration on 64-bit target");
      R.Check
        (Lower_Type_Name ("float", Cfg64) = "",
         "Test 7: unrecognized name lowers to empty string");

      --  Test 8: Synthesize_Package builds a package skeleton.
      declare
         Pkg_Text : constant String :=
           Synthesize_Package ("IR_Add", "int32_t,uint64_t", Cfg64);
      begin
         R.Check
           (Pkg_Text'Length > 0
            and then Pkg_Text'Length <= 4096,
            "Test 8: synthesized package has bounded length");
         R.Check
           (Ada.Strings.Fixed.Index (Pkg_Text, "package IR_Add is") > 0,
            "Test 8: package header synthesized");
         R.Check
           (Ada.Strings.Fixed.Index
              (Pkg_Text,
               "type int32_t is new Adacovex.Target_Profiles.IR_Int32;")
            > 0
            and then Ada.Strings.Fixed.Index
                      (Pkg_Text,
                       "type uint64_t is new Adacovex.Target_Profiles.IR_UInt64;")
            > 0,
            "Test 8: lowered declarations present");
         R.Check
           (Ada.Strings.Fixed.Index (Pkg_Text, "end IR_Add;") > 0,
            "Test 8: package end synthesized");
      end;

      --  Test 9: bounds-checked arithmetic returns correct sums.
      R.Check
        (Adacovex.Target_Profiles.Checked_Add32 (10, 20) = 30,
         "Test 9: Checked_Add32 sum");
      R.Check
        (Adacovex.Target_Profiles.Checked_Add64
           (2**40, 2**40) = 2**41,
         "Test 9: Checked_Add64 sum");

      --  Test 10: IR_Bounds fixture (synthesized-style lowered types).
      R.Check
        (Adacovex.IR_Bounds.int32_t'First = -2**31
         and then Adacovex.IR_Bounds.int32_t'Last = 2**31 - 1,
         "Test 10: IR_Bounds int32_t inherits IR_Int32 bounds");
      R.Check
        (Adacovex.IR_Bounds.Add32 (1000, 2000) = 3000
         and then Adacovex.IR_Bounds.Add64 (2**40, 2**40) = 2**41,
         "Test 10: IR_Bounds checked additions");
   end Run;

end Adacovex_IR_Tests;
