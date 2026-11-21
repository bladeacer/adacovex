--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Subtype_Conversion_Fixed
  with SPARK_Mode => On
is
   subtype Byte is Integer range 0 .. 255;

   --  Convert X into Y.
   --  @param X  Source value, already in the target range.
   --  @param Y  Converted value.
   procedure Convert (X : Integer; Y : out Byte)
     with Pre => X in Byte'Range;
end Prove_Diag_Subtype_Conversion_Fixed;
