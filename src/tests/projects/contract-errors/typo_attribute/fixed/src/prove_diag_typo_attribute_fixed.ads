--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Typo_Attribute_Fixed
  with SPARK_Mode => On
is
   --  Double a bounded value.
   --  @param X  Value to double.
   --  @return Twice X.
   function Doubled (X : Integer) return Integer
     with Pre  => X in 0 .. 1_000,
          Post => Doubled'Result = 2 * X;
end Prove_Diag_Typo_Attribute_Fixed;
