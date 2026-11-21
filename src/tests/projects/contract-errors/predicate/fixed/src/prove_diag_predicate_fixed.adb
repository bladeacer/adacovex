package body Prove_Diag_Predicate_Fixed
  with SPARK_Mode => On
is

   procedure Set (X : out Small) is
   begin
      X := 5;
   end Set;
end Prove_Diag_Predicate_Fixed;
