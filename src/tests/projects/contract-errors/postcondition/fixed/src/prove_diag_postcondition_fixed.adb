package body Prove_Diag_Postcondition_Fixed
  with SPARK_Mode => On
is

   function Magnitude (X : Integer) return Integer is
   begin
      return (if X < 0 then -X else X);
   end Magnitude;
end Prove_Diag_Postcondition_Fixed;
