--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Typo_Identifier_Broken
  with SPARK_Mode => On
is
   --  Double a bounded value.
   --  @param X  Value to double.
   --  @return Twice X.
   function Doubled (X : Integer) return Integer
     with Pre  => X in 0 .. Max_Value,
          Post => Doubled'Result = 2 * X;
end Prove_Diag_Typo_Identifier_Broken;
