--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Precondition_Broken
  with SPARK_Mode => On
is
   --  Return a non-negative value.
   --  @param X  Value to pass.
   --  @return X.
   function Non_Neg (X : Integer) return Integer
     with Pre => X >= 0;

   --  Call the checked subprogram without a guard.
   --  @param X  Value to pass.
   --  @return The result.
   function Unchecked_Call (X : Integer) return Integer
     with Pre => X in -10 .. 10;
end Prove_Diag_Precondition_Broken;
