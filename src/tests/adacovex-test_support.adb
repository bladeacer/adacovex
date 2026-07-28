with Ada.Text_IO; use Ada.Text_IO;

package body Adacovex.Test_Support is

   procedure Check (R : in out Runner; Cond : Boolean; Msg : String) is
   begin
      if Cond then
         R.Pass_Count := R.Pass_Count + 1;
         Put_Line ("  PASS: " & Msg);
      else
         R.Fail_Count := R.Fail_Count + 1;
         Put_Line ("  FAIL: " & Msg);
      end if;
   end Check;

   function Passed (R : Runner) return Natural is
   begin
      return R.Pass_Count;
   end Passed;

   function Failed (R : Runner) return Natural is
   begin
      return R.Fail_Count;
   end Failed;

end Adacovex.Test_Support;
