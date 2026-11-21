package body Prove_Diag_Predicate_Broken
  with SPARK_Mode => On
is

   procedure Set (X : out Small) is
   begin
      X := 100;
   end Set;
end Prove_Diag_Predicate_Broken;
