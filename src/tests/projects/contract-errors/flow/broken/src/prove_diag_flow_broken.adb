package body Prove_Diag_Flow_Broken
  with SPARK_Mode => On
is

   function Offset_Of (X : Integer) return Integer is
      Offset : Integer;
   begin
      return X + Offset;
   end Offset_Of;
end Prove_Diag_Flow_Broken;
