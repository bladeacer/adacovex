package body Adacovex.Types is
   pragma SPARK_Mode (On);

   function To_String (L : SPARK_Level) return String is
   begin
      case L is
         when Stone    =>
            return "Stone";

         when Bronze   =>
            return "Bronze";

         when Silver   =>
            return "Silver";

         when Gold     =>
            return "Gold";

         when Platinum =>
            return "Platinum";
      end case;
   end To_String;

   function To_String (L : DAL_Level) return String is
   begin
      case L is
         when DAL_A =>
            return "A";

         when DAL_B =>
            return "B";

         when DAL_C =>
            return "C";

         when DAL_D =>
            return "D";

         when DAL_E =>
            return "E";
      end case;
   end To_String;

   function To_DAL (S : String) return DAL_Level is
      U : String (1 .. S'Length) := (others => ' ');
   begin
      if S'Length = 0 then
         return DAL_C;
      end if;
      for I in S'Range loop
         pragma
           Loop_Invariant
             (I >= S'First
                and then I <= S'Last
                and then U'Length = S'Length
                and then (I - S'First + 1) in U'Range);
         if S (I) in 'a' .. 'z' then
            U (I - S'First + 1) := Character'Val (Character'Pos (S (I)) - 32);
         else
            U (I - S'First + 1) := S (I);
         end if;
      end loop;
      if U = "A" then
         return DAL_A;
      elsif U = "B" then
         return DAL_B;
      elsif U = "C" then
         return DAL_C;
      elsif U = "D" then
         return DAL_D;
      elsif U = "E" then
         return DAL_E;
      else
         return DAL_C;
      end if;
   end To_DAL;

   function To_String (S : Compliance_Standard) return String is
   begin
      case S is
         when DO_178C   =>
            return "DO-178C";

         when ISO_26262 =>
            return "ISO 26262";

         when IEC_62304 =>
            return "IEC 62304";
      end case;
   end To_String;

   function To_Standard (S : String) return Compliance_Standard is
      U : String (1 .. S'Length) := (others => ' ');
   begin
      if S'Length = 0 then
         return DO_178C;
      end if;
      for I in S'Range loop
         pragma
           Loop_Invariant
             (I >= S'First
                and then I <= S'Last
                and then U'Length = S'Length
                and then (I - S'First + 1) in U'Range);
         if S (I) in 'a' .. 'z' then
            U (I - S'First + 1) := Character'Val (Character'Pos (S (I)) - 32);
         elsif S (I) = '-' then
            U (I - S'First + 1) := '_';
         else
            U (I - S'First + 1) := S (I);
         end if;
      end loop;
      if U = "DO_178C" or else U = "DO178C" then
         return DO_178C;
      elsif U = "ISO_26262" or else U = "ISO26262" then
         return ISO_26262;
      elsif U = "IEC_62304" or else U = "IEC62304" then
         return IEC_62304;
      else
         return DO_178C;
      end if;
   end To_Standard;

   --  Uppercase a string (ASCII only).  Reused by the dedicated level
   --  parsers below; mirrors the loop already proved in To_Standard.
   function To_Upper (S : String) return String
   with Post => To_Upper'Result'Length = S'Length
   is
      U : String (1 .. S'Length) := (others => ' ');
   begin
      for I in S'Range loop
         pragma
           Loop_Invariant
             (I >= S'First
                and then I <= S'Last
                and then U'Length = S'Length
                and then (I - S'First + 1) in U'Range);
         if S (I) in 'a' .. 'z' then
            U (I - S'First + 1) := Character'Val (Character'Pos (S (I)) - 32);
         else
            U (I - S'First + 1) := S (I);
         end if;
      end loop;
      return U;
   end To_Upper;

   function To_ASIL (S : String) return DAL_Level is
      U : constant String := To_Upper (S);
   begin
      if U = "A" then
         return DAL_D;
      elsif U = "B" then
         return DAL_C;
      elsif U = "C" then
         return DAL_B;
      elsif U = "D" then
         return DAL_A;
      elsif U = "QM" then
         return DAL_E;
      else
         return DAL_C;
      end if;
   end To_ASIL;

   function Is_Valid_ASIL (S : String) return Boolean is
      U : constant String := To_Upper (S);
   begin
      return
        U = "A"
        or else U = "B"
        or else U = "C"
        or else U = "D"
        or else U = "QM";
   end Is_Valid_ASIL;

   function To_Class (S : String) return DAL_Level is
      U : constant String := To_Upper (S);
   begin
      if U = "A" then
         return DAL_C;
      elsif U = "B" then
         return DAL_B;
      elsif U = "C" then
         return DAL_A;
      else
         return DAL_C;
      end if;
   end To_Class;

   function Is_Valid_Class (S : String) return Boolean is
      U : constant String := To_Upper (S);
   begin
      return U = "A" or else U = "B" or else U = "C";
   end Is_Valid_Class;

   function Standard_Slug (S : Compliance_Standard) return String is
   begin
      case S is
         when DO_178C   =>
            return "do178c";

         when ISO_26262 =>
            return "iso26262";

         when IEC_62304 =>
            return "iec62304";
      end case;
   end Standard_Slug;

   function Standard_Level_Name
     (Standard : Compliance_Standard; Level : DAL_Level) return String is
   begin
      case Standard is
         when DO_178C   =>
            return "DAL-" & To_String (Level);

         when ISO_26262 =>
            case Level is
               when DAL_A =>
                  return "ASIL D";

               when DAL_B =>
                  return "ASIL C";

               when DAL_C =>
                  return "ASIL B";

               when DAL_D =>
                  return "ASIL A";

               when DAL_E =>
                  return "QM";
            end case;

         when IEC_62304 =>
            case Level is
               when DAL_A         =>
                  return "Class C";

               when DAL_B         =>
                  return "Class B";

               when DAL_C         =>
                  return "Class A";

               when DAL_D | DAL_E =>
                  return "No class";
            end case;
      end case;
   end Standard_Level_Name;

   function To_String (S : DAL_Status) return String is
   begin
      case S is
         when Achieved =>
            return "Achieved";

         when Unmet    =>
            return "Unmet";
      end case;
   end To_String;

   function To_String (S : Test_Status) return String is
   begin
      case S is
         when Pass =>
            return "PASS";

         when Fail =>
            return "FAIL";
      end case;
   end To_String;

end Adacovex.Types;
