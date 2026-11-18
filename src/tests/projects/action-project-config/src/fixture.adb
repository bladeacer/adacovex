package body Fixture with SPARK_Mode => On is
   function Next_Of (X : Integer) return Integer is
   begin
      return X + 1;
   end Next_Of;
end Fixture;
