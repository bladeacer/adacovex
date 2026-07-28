package Adacovex.Test_Support is

   type Runner is tagged limited private;

   --  Record a test result.
   --  Increments the pass count if Cond is True, fail count otherwise.
   --  @param Cond  Test condition (True = pass, False = fail)
   --  @param Msg   Human-readable test description.
   procedure Check (R : in out Runner; Cond : Boolean; Msg : String);

   --  Return the number of passed checks.
   --  @return Pass count.
   function Passed (R : Runner) return Natural;

   --  Return the number of failed checks.
   --  @return Fail count.
   function Failed (R : Runner) return Natural;

private

   type Runner is tagged limited record
      Pass_Count : Natural := 0;
      Fail_Count : Natural := 0;
   end record;

end Adacovex.Test_Support;
