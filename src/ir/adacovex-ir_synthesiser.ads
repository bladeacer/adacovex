with Adacovex.Target_Profiles; use Adacovex.Target_Profiles;

--  IR synthesiser (future use).
--  Lowers foreign type names found while parsing Ada sources (usize, size_t,
--  int32_t, int64_t, ...) onto the bounded target types in
--  Adacovex.Target_Profiles and synthesises bounded Ada declarations and
--  package skeletons from them.  Currently provides the type-lowering layer;
--  the full AST-to-IR pipeline is planned to build on it.
--  The package is SPARK-proved: gnatprove discharges the bounds checks on the
--  synthesized text buffers (result lengths never exceed the fixed-size
--  output buffer), so string generation on the lowered types is
--  machine-checked like the bounded IR types it lowers onto.
--  HLR-IR: IR type synthesis

package Adacovex.IR_Synthesiser is
   pragma SPARK_Mode (On);

   --  Longest synthesized declaration line.
   Max_Decl_Len : constant := 96;

   --  Upper bound of a synthesized package skeleton, in characters.
   --  The generated text is truncated (never overflowing) at this limit.
   Max_Pkg_Len : constant := 4096;

   --  Return the bounded IR type name a foreign type name lowers onto.
   --  @param Name  Foreign type name (case-sensitive).
   --  @param Cfg   Host/target word-size configuration.
   --  @return "IR_Int32" for "int32_t", "IR_UInt64" for "size_t" on a 64-bit
   --          target; an empty string when the name is not recognized.
   function IR_Type_Name (Name : String; Cfg : Target_Config) return String
   with Post => IR_Type_Name'Result'Length <= 9, Global => null;

   --  Synthesize a bounded Ada type declaration for a foreign type name.
   --  @param Name  Foreign type name (case-sensitive).
   --  @param Cfg   Host/target word-size configuration.
   --  @return "type int32_t is new Adacovex.Target_Profiles.IR_Int32;",
   --          or an empty string when the name is not recognized.
   function Lower_Type_Name (Name : String; Cfg : Target_Config) return String
   with
     Pre    => Name'Length <= Natural'Last - 48,
     Post   => Lower_Type_Name'Result'Length <= Name'Length + 48,
     Global => null;

   --  Synthesize a package skeleton holding the lowered declarations for
   --  each comma-separated foreign type name.
   --  @param Pkg_Name   Name of the synthesized package.
   --  @param Type_Names Comma-separated foreign type names.
   --  @param Cfg        Host/target word-size configuration.
   --  @return The synthesized package text.
   function Synthesize_Package
     (Pkg_Name : String; Type_Names : String; Cfg : Target_Config)
      return String
   with
     Pre    =>
       Pkg_Name'Length <= Max_Pkg_Len
       and then Type_Names'Length <= Max_Pkg_Len
       and then Type_Names'Last <= Natural'Last - 2,
     Post   => Synthesize_Package'Result'Length <= Max_Pkg_Len,
     Global => null;

end Adacovex.IR_Synthesiser;
