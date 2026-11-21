--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Subtype_Conversion_Broken
  with SPARK_Mode => On
is
   subtype Byte is Integer range 0 .. 255;

   --  Convert X into Y.
   --  @param X  Source value.
   --  @param Y  Converted value.
   procedure Convert (X : Integer; Y : out Byte);
end Prove_Diag_Subtype_Conversion_Broken;
