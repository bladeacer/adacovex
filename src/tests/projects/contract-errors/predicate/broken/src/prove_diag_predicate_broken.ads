--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Predicate_Broken
  with SPARK_Mode => On
is
   subtype Small is Integer with Dynamic_Predicate => Small in 0 .. 10;

   --  Store a value in X.
   --  @param X  Destination, which carries the predicate.
   procedure Set (X : out Small);
end Prove_Diag_Predicate_Broken;
