with Adacovex.Target_Profiles; use Adacovex.Target_Profiles;

--  IR synthesiser (future use).
--  Lowers foreign type names found while parsing Ada sources (usize, size_t,
--  int32_t, int64_t, and more) onto the bounded target types in
--  Adacovex.Target_Profiles.  It synthesises bounded Ada declarations and
--  package skeletons from them.
--  Currently provides the type-lowering layer.
--  The full AST-to-IR pipeline is planned to build on it.
--  The package is SPARK-proved.  gnatprove discharges the bounds checks on
--  the synthesised text buffers.  Result lengths never exceed the fixed-size
--  output buffer.  String generation on the lowered types is machine-checked
--  like the bounded IR types.
--  HLR-IR: IR type synthesis

package Adacovex.IR_Synthesiser is
   pragma SPARK_Mode (On);

   --  Longest synthesised declaration line.
   Max_Decl_Len : constant := 96;

   --  Upper bound of a synthesised package skeleton, in characters.
   --  The generated text is truncated (it never overflows) at this limit.
   Max_Pkg_Len : constant := 4096;

   --  Returns the bounded IR type name a foreign type name lowers onto.
   --  @param Name  Foreign type name (case-sensitive).
   --  @param Cfg   Host/target word-size configuration.
   --  @return "IR_Int32" for "int32_t", "IR_UInt64" for "size_t" on a 64-bit
   --          target; an empty string when the name is not recognised.
   function IR_Type_Name (Name : String; Cfg : Target_Config) return String
   with Post => IR_Type_Name'Result'Length <= 9, Global => null;

   --  Synthesize a bounded Ada type declaration for a foreign type name.
   --  @param Name  Foreign type name (case-sensitive).
   --  @param Cfg   Host/target word-size configuration.
   --  @return "type int32_t is new Adacovex.Target_Profiles.IR_Int32;",
   --  or an empty string when the name is not recognised.
   function Lower_Type_Name (Name : String; Cfg : Target_Config) return String
   with
     Pre    => Name'Length <= Natural'Last - 48,
     Post   => Lower_Type_Name'Result'Length <= Name'Length + 48,
     Global => null;

   --  Synthesises a package skeleton that holds the lowered declarations for
   --  each comma-separated foreign type name.
   --  @param Pkg_Name   Name of the synthesised package.
   --  @param Type_Names Comma-separated foreign type names.
   --  @param Cfg        Host/target word-size configuration.
   --  @return The synthesised package text.
   function Synthesize_Package
     (Pkg_Name : String; Type_Names : String; Cfg : Target_Config)
      return String
   with
     Pre    =>
       Pkg_Name'First >= 1
       and then Pkg_Name'Length <= Max_Pkg_Len
       and then Type_Names'First >= 1
       and then Type_Names'Length <= Max_Pkg_Len
       and then Type_Names'Last <= Natural'Last - 2,
     Post   => Synthesize_Package'Result'Length <= Max_Pkg_Len,
     Global => null;

   --  Synthesises a contract-carrying bounded-function spec from a
   --  foreign-style signature.  This is the multi-pair form of a
   --  gnatprove-friendly IR: it lowers every comma-separated "P:Type"
   --  parameter pair onto a bounded IR scalar type and joins the signed
   --  pairs' half-range Pre guards with "and then" into one contract
   --  chain, the guard shape gnatprove discharges for the checked
   --  arithmetic (the same guard as Adacovex.Target_Profiles.Checked_Add32
   --  / the Adacovex.IR_Bounds fixture).  Unsigned (modular) parameters
   --  carry no guard.  Lowered code carries its contracts in the
   --  generated text, so a proof run checks only bounded-scalar
   --  arithmetic instead of foreign semantics.  The three-pass design and
   --  the full exploration are documented in docs/contributing/ir.md.
   --  @param Name        Subprogram name (an Ada identifier).
   --  @param Param_List  Comma-separated "P:Type" pairs, no spaces, at
   --                     most 32 pairs.  Each Type is an IR_* name
   --                     (IR_Int32, IR_UInt64, ...).  An empty list emits
   --                     the nullary spec.
   --  @param Return_Type IR_* name of the result; "" emits a procedure.
   --  @return The synthesised spec text (a function or procedure spec with
   --          an optional Pre contract), or "" when Name is empty, any
   --          pair is malformed (no ':', embedded whitespace, or a type
   --          that is not a bounded IR type name), or the list holds more
   --          than 32 pairs.
   function Synthesize_Bounded_Function
     (Name : String; Param_List : String; Return_Type : String) return String
   with
     Pre    =>
       (if Name'Length > 0
        then Name'First >= 1 and then Name'Last <= Natural'Last - 64)
       and then Param_List'First >= 1
       and then Param_List'Last <= Natural'Last - 64
       and then Return_Type'First >= 1
       and then Return_Type'Last <= Natural'Last - 64
       and then Param_List'Length <= Max_Pkg_Len
       and then Return_Type'Length <= Max_Pkg_Len,
     Post   => Synthesize_Bounded_Function'Result'Length <= Max_Pkg_Len,
     Global => null;

end Adacovex.IR_Synthesiser;
