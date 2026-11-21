package body Prove_Diag_Modular_Broken
  with SPARK_Mode => On
is

   procedure Narrow (X : Mod_256; Y : out Mod_16) is
   begin
      Y := Mod_16 (X);
   end Narrow;
end Prove_Diag_Modular_Broken;
