--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Range_Fixed
  with SPARK_Mode => On
is
   subtype Small is Integer range 0 .. 100;

   --  Narrow X to the Small range.
   --  @param X  Value to narrow.
   --  @return X as a Small.
   function Narrow (X : Integer) return Small with Pre => X in 0 .. 100;
end Prove_Diag_Range_Fixed;
