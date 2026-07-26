package body Adacovex.Types is
--  SPDX-License-Identifier: Apache-2.0

   function To_String (L : SPARK_Level) return String is
   begin
      case L is
         when Stone    => return "Stone";
         when Bronze   => return "Bronze";
         when Silver   => return "Silver";
         when Gold     => return "Gold";
         when Platinum => return "Platinum";
      end case;
   end To_String;

   function To_String (L : DAL_Level) return String is
   begin
      case L is
         when DAL_A => return "A";
         when DAL_B => return "B";
         when DAL_C => return "C";
         when DAL_D => return "D";
         when DAL_E => return "E";
      end case;
   end To_String;

   function To_DAL (S : String) return DAL_Level is
      U : String (1 .. S'Length);
   begin
      if S'Length = 0 then
         return DAL_C;
      end if;
      for I in S'Range loop
         if S (I) in 'a' .. 'z' then
            U (I - S'First + 1) := Character'Val
              (Character'Pos (S (I)) - 32);
         else
            U (I - S'First + 1) := S (I);
         end if;
      end loop;
      if U = "A" then return DAL_A;
      elsif U = "B" then return DAL_B;
      elsif U = "C" then return DAL_C;
      elsif U = "D" then return DAL_D;
      elsif U = "E" then return DAL_E;
      else return DAL_C;
      end if;
   end To_DAL;

   function To_String (S : DAL_Status) return String is
   begin
      case S is
         when Achieved => return "Achieved";
         when Unmet    => return "Unmet";
      end case;
   end To_String;

   function To_String (S : Test_Status) return String is
   begin
      case S is
         when Pass => return "PASS";
         when Fail => return "FAIL";
      end case;
   end To_String;

end Adacovex.Types;
