package body Prove_Diag_Invariant_Broken
  with SPARK_Mode => On
is

   function Sum_To (N : Natural) return Natural is
      Total : Natural := 0;
   begin
      for I in 1 .. N loop
         Total := Total + I;
      end loop;
      return Total;
   end Sum_To;
end Prove_Diag_Invariant_Broken;
