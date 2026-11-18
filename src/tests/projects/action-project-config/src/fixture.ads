package Fixture with SPARK_Mode => On is
   --  Add one to a bounded value.
   --  @param X  Value to increment.
   --  @return X plus one.
   function Next_Of (X : Integer) return Integer
     with Pre  => X in 0 .. 100,
          Post => Next_Of'Result = X + 1;
end Fixture;
