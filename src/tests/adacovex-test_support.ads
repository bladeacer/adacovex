package Adacovex.Test_Support is

   type Runner is tagged limited private;

   procedure Check (R : in out Runner; Cond : Boolean; Msg : String);

   function Passed (R : Runner) return Natural;
   function Failed (R : Runner) return Natural;

private

   type Runner is tagged limited record
      Pass_Count : Natural := 0;
      Fail_Count : Natural := 0;
   end record;

end Adacovex.Test_Support;
