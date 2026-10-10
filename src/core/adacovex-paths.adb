with Ada.Environment_Variables;
with Adacovex.CPUs;

package body Adacovex.Paths is

   --  Whether C separates path components. The two characters are the only
   --  separators any supported host uses, so the result is characterised
   --  directly by the comparison.
   function Is_Separator (C : Character) return Boolean is
   begin
      return C = '/' or else C = '\';
   end Is_Separator;

   --  Whether Path is absolute: a leading separator, a Windows drive-letter
   --  prefix, or a UNC root. Everything else is relative.
   function Is_Absolute (Path : String) return Boolean is
   begin
      if Path'Length = 0 then
         return False;
      end if;
      if Is_Separator (Path (Path'First)) then
         return True;
      end if;
      if Path'Length >= 2
        and then Path (Path'First) in 'A' .. 'Z' | 'a' .. 'z'
        and then Path (Path'First + 1) = ':'
      then
         return True;
      end if;
      return False;
   end Is_Absolute;

   pragma Warnings (Off, "no Global contract available");
   function Home_Directory return String is
      use Ada.Environment_Variables;
   begin
      if Exists ("HOME") and then Value ("HOME")'Length > 0 then
         return Value ("HOME");
      end if;
      if Exists ("USERPROFILE") and then Value ("USERPROFILE")'Length > 0 then
         return Value ("USERPROFILE");
      end if;
      return Adacovex.CPUs.Get_Temp_Directory;
   end Home_Directory;
   pragma Warnings (On, "no Global contract available");

   function Expand_User (Path : String) return String is
      Home : constant String := Home_Directory;
      --  The slice after "~" plus a separator. A null slice (Path = "~/"
      --  or "~") yields the empty string, so only the leading "~" needs a
      --  case of its own.
      Rest : constant String :=
        (if Path'Length >= 2 and then Is_Separator (Path (Path'First + 1))
         then Path (Path'First + 2 .. Path'Last)
         else "");
   begin
      if Path'Length = 0 then
         return Path;
      end if;
      if Path (Path'First) /= '~' then
         return Path;
      end if;
      if Path'Length >= 2
        and then Path (Path'First + 1) not in '/' | '\' | ' '
      then
         --  "~name": another user's home, which only the shell resolves.
         return Path;
      end if;
      if Rest = "" then
         return Home;
      end if;
      if Home'Length > 0 and then Is_Separator (Home (Home'Last)) then
         return Home & Rest;
      end if;
      return Home & "/" & Rest;
   end Expand_User;

   function Join (Dir : String; Name : String) return String is
      Trimmed : constant String := Strip_Trailing_Separators (Dir);
   begin
      if Trimmed'Length = 0 then
         return Name;
      end if;
      if Name'Length = 0 then
         return Trimmed;
      end if;
      if Is_Separator (Trimmed (Trimmed'Last)) then
         return Trimmed & Name;
      end if;
      return Trimmed & "/" & Name;
   end Join;

   function Strip_Trailing_Separators (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      if Path'Length = 0 then
         return Path;
      end if;
      while Last > Path'First and then Is_Separator (Path (Last)) loop
         pragma Loop_Invariant (Last in Path'First .. Path'Last);
         pragma Loop_Variant (Decreases => Last - Path'First);
         Last := Last - 1;
      end loop;
      return Path (Path'First .. Last);
   end Strip_Trailing_Separators;

end Adacovex.Paths;
