package body Prove_Diag_Subtype_Conversion_Broken
  with SPARK_Mode => On
is

   procedure Convert (X : Integer; Y : out Byte) is
   begin
      Y := Byte (X);
   end Convert;
end Prove_Diag_Subtype_Conversion_Broken;
