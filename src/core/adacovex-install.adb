with Ada.Command_Line;
with Ada.Directories;
with GNAT.OS_Lib;
with Adacovex.Paths;

package body Adacovex.Install is

   use type GNAT.OS_Lib.String_Access;

   --  The subprograms the spec declares carry their contracts there, so
   --  their bodies state only the mode: a repeated Global would have to
   --  be spelled Refined_Global, and a repeated Pre is not allowed on a
   --  body. The body-local helpers below keep their own contracts.
   function To_String (M : Install_Method) return String with SPARK_Mode => On
   is
   begin
      case M is
         when Source_Checkout =>
            return "source-checkout";

         when Alire_Global    =>
            return "alire-global";

         when On_Path         =>
            return "on-path";
      end case;
   end To_String;

   --  Whether S begins with the exact character sequence Pre. Both sides
   --  are walked from their own first index, so no slice is formed and
   --  the index bounds hold for any index origin.
   --  @param S  String to test.
   --  @param Pre  Prefix to look for.
   --  @return True when Pre prefixes S.
   function Starts_With (S : String; Pre : String) return Boolean
   with SPARK_Mode => On, Global => null
   is
   begin
      if Pre'Length = 0 then
         return True;
      end if;
      if S'Length < Pre'Length then
         return False;
      end if;
      for K in 0 .. Pre'Length - 1 loop
         if S (S'First + K) /= Pre (Pre'First + K) then
            return False;
         end if;
      end loop;
      return True;
   end Starts_With;

   --  The argument without one trailing path separator, so `~` and `~/`
   --  build the same prefix. The argument is returned unchanged
   --  otherwise. The result keeps the index origin of the argument, so
   --  a caller that knows the argument's origin knows the result's.
   --  @param S  Path to trim.
   --  @return S minus one trailing separator.
   function Trim_Trailing (S : String) return String
   with
     SPARK_Mode => On,
     Global     => null,
     Post       =>
       Trim_Trailing'Result'Length <= S'Length
       and Trim_Trailing'Result'First = S'First
   is
   begin
      if S'Length > 0 and then (S (S'Last) = '/' or else S (S'Last) = '\') then
         return S (S'First .. S'Last - 1);
      end if;
      return S;
   end Trim_Trailing;

   function Classify
     (Path : String; Home : String; In_Checkout : Boolean)
      return Install_Method
   with SPARK_Mode => On
   is
      H : constant String := Trim_Trailing (Home);
   begin
      if In_Checkout then
         return Source_Checkout;
      end if;
      --  Each relative prefix carries its own leading separator, so a
      --  match always ends at a path-component boundary and an empty
      --  home never matches. Both separator characters keep the rule
      --  true on Windows.
      if H'Length > 0
        and then (Starts_With (Path, H & "/.alire/")
                  or else Starts_With (Path, H & "\.alire\")
                  or else Starts_With (Path, H & "/.local/bin/")
                  or else Starts_With (Path, H & "\.local\bin\"))
      then
         return Alire_Global;
      end if;
      return On_Path;
   end Classify;

   function Dependency_Scope (M : Install_Method) return Types.Component_Scope
   with SPARK_Mode => On
   is
   begin
      if M = Source_Checkout then
         return Types.Scope_Dev;
      end if;
      return Types.Scope_System;
   end Dependency_Scope;

   --  PATH lookup of a bare command name.
   --  @param Base  Command name without a directory part.
   --  @return Absolute path of the executable, or "" when it is absent.
   function On_Path_Lookup (Base : String) return String is
      Exe : GNAT.OS_Lib.String_Access;
   begin
      if Base'Length = 0 then
         return "";
      end if;
      Exe := GNAT.OS_Lib.Locate_Exec_On_Path (Base);
      if Exe = null then
         return "";
      end if;
      declare
         Resolved : constant String := Exe.all;
      begin
         GNAT.OS_Lib.Free (Exe);
         return Resolved;
      end;
   end On_Path_Lookup;

   function Is_Source_Checkout (Path : String) return Boolean is
      Start   : constant Natural := Path'First;
      End_Idx : Natural;
   begin
      if Path'Length = 0 then
         return False;
      end if;
      --  Each round tests one directory -- the first round strips the
      --  executable name -- and then shrinks End_Idx by that component.
      --  Only slices of Path are built, so no string variable is ever
      --  reassigned a value of another length, and the walk always ends
      --  (at the first separator, at no separator, or at round 12).
      End_Idx := Path'Last;
      for Round in 1 .. 12 loop
         declare
            Sep : Natural := 0;
         begin
            for I in reverse Start .. End_Idx loop
               if Path (I) = '/' or else Path (I) = '\' then
                  Sep := I;
                  exit;
               end if;
            end loop;
            if Sep = 0 or else Sep = Start then
               return False;
            end if;
            declare
               Cur : constant String := Path (Start .. Sep - 1);
            begin
               if Ada.Directories.Exists (Cur & "/src/adacovex.ads") then
                  return True;
               end if;
            end;
            End_Idx := Sep - 1;
         end;
      end loop;
      return False;
   end Is_Source_Checkout;

   function Self_Path return String is
      Name : constant String := Ada.Command_Line.Command_Name;
   begin
      if Name'Length = 0 then
         return "";
      end if;
      if Adacovex.Paths.Is_Absolute (Name) then
         if Ada.Directories.Exists (Name) then
            return Ada.Directories.Full_Name (Name);
         end if;
         return "";
      end if;

      --  A relative command name: the working directory answers first,
      --  and the PATH lookup is the fallback.
      declare
         Cand : constant String :=
           Ada.Directories.Full_Name (".") & "/" & Name;
      begin
         if Ada.Directories.Exists (Cand) then
            return Ada.Directories.Full_Name (Cand);
         end if;
      end;

      declare
         Sep : Natural := 0;
      begin
         for I in reverse Name'Range loop
            if Name (I) = '/' or else Name (I) = '\' then
               Sep := I;
               exit;
            end if;
         end loop;
         if Sep = 0 then
            return On_Path_Lookup (Name);
         elsif Sep < Name'Last then
            return On_Path_Lookup (Name (Sep + 1 .. Name'Last));
         end if;
      end;
      return "";
   exception
      when others =>
         return "";
   end Self_Path;

   function Detect return Install_Method is
      P    : constant String := Self_Path;
      Home : constant String := Adacovex.Paths.Home_Directory;
   begin
      --  The classifier's precondition is guarded here rather than
      --  assumed: an over-long or oddly sliced home simply reports the
      --  default answer instead of tripping an assertion.
      if P'Length = 0
        or else Home'Length > Types.Max_Path
        or else Home'First > Types.Max_Path
      then
         return On_Path;
      end if;
      return Classify (P, Home, Is_Source_Checkout (P));
   end Detect;

end Adacovex.Install;
