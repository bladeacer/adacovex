--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Postcondition_Broken
  with SPARK_Mode => On
is
   --  Return the magnitude of X.
   --  @param X  Value in -100 .. 100.
   --  @return The magnitude of X.
   function Magnitude (X : Integer) return Integer
     with Pre => X in -100 .. 100,
          Post => Magnitude'Result >= 0;
end Prove_Diag_Postcondition_Broken;
