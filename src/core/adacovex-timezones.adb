with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with GNAT.Calendar;

package body Adacovex.Timezones is

   use Ada.Calendar;
   use Ada.Characters.Handling;
   use Ada.Strings;

   --  Built-in table of common IANA zone names -> standard-time offsets.
   --  Entries are "Name+OFFSET;" where OFFSET is a whole or half hour
   --  ("+8", "-5.5").  adacovex ships no timezone database, so named zones
   --  resolve to their standard (non-DST) offset.  Hand-written to keep the
   --  crate dependency-free; extend it for new zone names as needed.
   Zones_Table : constant String :=
     "Asia/Singapore+8;Asia/Shanghai+8;Asia/Hong_Kong+8;Asia/Taipei+8;"
     & "Asia/Manila+8;Asia/Kuala_Lumpur+8;Asia/Seoul+9;Asia/Tokyo+9;"
     & "Asia/Jakarta+7;Asia/Bangkok+7;Asia/Ho_Chi_Minh+7;Asia/Yangon+6.5;"
     & "Asia/Dhaka+6;Asia/Karachi+5;Asia/Kolkata+5.5;Asia/Colombo+5.5;"
     & "Asia/Dubai+4;Asia/Kabul+4.5;Asia/Tehran+3.5;Asia/Baghdad+3;"
     & "Asia/Riyadh+3;Asia/Jerusalem+2;Asia/Beirut+2;Asia/Baku+4;"
     & "Asia/Tbilisi+4;Asia/Yerevan+4;Asia/Almaty+6;Asia/Tashkent+5;"
     & "Asia/Bishkek+6;Asia/Ulaanbaatar+8;Australia/Eucla+8.75;"
     & "Australia/Perth+8;Australia/Darwin+9.5;Australia/Brisbane+10;"
     & "Australia/Adelaide+9.5;Australia/Sydney+10;Australia/Melbourne+10;"
     & "Australia/Hobart+10;Pacific/Auckland+12;Pacific/Guam+10;"
     & "Pacific/Port_Moresby+10;Pacific/Honolulu-10;Pacific/Tahiti-10;"
     & "Pacific/Midway-11;Pacific/Niue-11;"
     & "Europe/London+0;Europe/Dublin+0;Europe/Lisbon+0;Europe/Madrid+1;"
     & "Europe/Paris+1;Europe/Berlin+1;Europe/Brussels+1;Europe/Amsterdam+1;"
     & "Europe/Zurich+1;Europe/Vienna+1;Europe/Rome+1;Europe/Warsaw+1;"
     & "Europe/Stockholm+1;Europe/Prague+1;Europe/Copenhagen+1;Europe/Oslo+1;"
     & "Europe/Athens+2;Europe/Bucharest+2;Europe/Sofia+2;Europe/Helsinki+2;"
     & "Europe/Kyiv+2;Europe/Kiev+2;Europe/Riga+2;Europe/Vilnius+2;"
     & "Europe/Istanbul+3;Europe/Moscow+3;Europe/Minsk+3;"
     & "UTC+0;GMT+0;Etc/UTC+0;Etc/GMT+0;Zulu+0;"
     & "America/New_York-5;America/Chicago-6;America/Denver-7;"
     & "America/Phoenix-7;America/Los_Angeles-8;America/Anchorage-9;"
     & "America/Honolulu-10;America/Toronto-5;America/Montreal-5;"
     & "America/Ottawa-5;America/Vancouver-8;America/Edmonton-7;"
     & "America/Winnipeg-6;America/Halifax-4;America/St_Johns-3.5;"
     & "America/Mexico_City-6;America/Guatemala-6;America/El_Salvador-6;"
     & "America/Bogota-5;America/Lima-5;America/Guayaquil-5;"
     & "America/Sao_Paulo-3;America/Argentina/Buenos_Aires-3;"
     & "America/Santiago-4;America/Caracas-4;America/La_Paz-4;"
     & "America/Panama-5;America/Nassau-5;America/Port-au-Prince-5;"
     & "America/Costa_Rica-6;America/Managua-6;America/Tegucigalpa-6;"
     & "Africa/Lagos+1;Africa/Cairo+2;Africa/Johannesburg+2;"
     & "Africa/Nairobi+3;Africa/Addis_Ababa+3;Africa/Casablanca+1;"
     & "Africa/Accra+0;Africa/Kinshasa+1;Africa/Algiers+1;Africa/Tunis+1;"
     & "Antarctica/Troll+0;";

   procedure Set_Display
     (Info : in out Timezone_Info; Name : String; Offset_Secs : Integer;
      Named : Boolean)
   is
   begin
      Info.Result_Valid := True;
      Info.Offset_Secs := Offset_Secs;
      Info.Is_Named := Named;
      Info.Display_Len := Natural'Min (Name'Length, Max_TZ_Name);
      if Info.Display_Len > 0 then
         Info.Display (1 .. Info.Display_Len) :=
           Name (Name'First .. Name'First + Info.Display_Len - 1);
      end if;
   end Set_Display;

   --  Render a fixed offset as "UTC+08:00" / "UTC-05:30" / "UTC+00:00".
   function UTC_Offset_Display (Offset_Secs : Integer) return String is
      Sign : Character := '+';
      AbsS : Integer := Offset_Secs;
      H    : Natural;
      M    : Natural;
      Buf  : String (1 .. 9);
   begin
      if Offset_Secs < 0 then
         Sign := '-';
         AbsS := -Offset_Secs;
      end if;
      H := AbsS / 3600;
      M := (AbsS mod 3600) / 60;
      Buf (1) := 'U';
      Buf (2) := 'T';
      Buf (3) := 'C';
      Buf (4) := Sign;
      Buf (5) := Character'Val (Character'Pos ('0') + H / 10);
      Buf (6) := Character'Val (Character'Pos ('0') + H mod 10);
      Buf (7) := ':';
      Buf (8) := Character'Val (Character'Pos ('0') + M / 10);
      Buf (9) := Character'Val (Character'Pos ('0') + M mod 10);
      return Buf;
   end UTC_Offset_Display;

   function CI_Equal (A, B : String) return Boolean is
   begin
      if A'Length /= B'Length then
         return False;
      end if;
      for I in 1 .. A'Length loop
         if To_Lower (A (A'First + I - 1))
           /= To_Lower (B (B'First + I - 1))
         then
            return False;
         end if;
      end loop;
      return True;
   end CI_Equal;

   --  Look up an IANA name in the built-in table and return its offset in
   --  seconds, or -1 when the name is absent.
   function Lookup_Named (Name : String) return Integer is
      Start : Natural := Zones_Table'First;
      Fin   : Natural;
   begin
      while Start <= Zones_Table'Last loop
         Fin := Start;
         while Fin <= Zones_Table'Last and then Zones_Table (Fin) /= ';'
         loop
            Fin := Fin + 1;
         end loop;
         declare
            Sign : Integer := Start;
            NLen : Natural := 0;
            P    : Integer := Start;
            Mult : Integer := 1;
            H    : Natural := 0;
            Mn   : Natural := 0;
            Done : Boolean := False;
         begin
            while Sign < Fin
              and then Zones_Table (Sign) /= '+'
              and then Zones_Table (Sign) /= '-'
            loop
               Sign := Sign + 1;
            end loop;
            NLen := Sign - Start;
            if NLen = Name'Length
              and then
                (for all I in 1 .. NLen =>
                   To_Lower (Zones_Table (Start + I - 1))
                     = To_Lower (Name (Name'First + I - 1)))
            then
               --  Parse the offset token: +8, +5.5, -9.
               P := Sign;
               if P < Fin and then Zones_Table (P) = '-' then
                  Mult := -1;
                  P := P + 1;
               elsif P < Fin and then Zones_Table (P) = '+' then
                  P := P + 1;
               end if;
               while P < Fin and then Zones_Table (P) in '0' .. '9' loop
                  H := H * 10
                    + (Character'Pos (Zones_Table (P)) - Character'Pos ('0'));
                  P := P + 1;
               end loop;
               if H <= 14 then
                  if P + 1 < Fin
                    and then Zones_Table (P) = '.'
                    and then Zones_Table (P + 1) = '5'
                  then
                     Mn := 30;
                  end if;
                  Done := True;
               end if;
            end if;
            if Done then
               return Mult * (H * 3600 + Mn * 60);
            end if;
         end;
         if Fin > Zones_Table'Last then
            exit;
         end if;
         Start := Fin + 1;
      end loop;
      return -1;
   end Lookup_Named;

   --  Parse a fixed UTC/GMT offset spec ("UTC+8", "GMT-5", "UTC+08:30", or
   --  a bare "UTC" / "GMT").  Returns offset seconds, or -1 on failure.
   function Parse_UTC_GMT (Spec : String) return Integer is
      I      : Integer := Spec'First;
      Prelen : Natural := 0;
      Sign   : Integer := 1;
      H      : Natural := 0;
      Mn     : Natural := 0;
      Seen   : Boolean := False;
   begin
      while I <= Spec'Last and then Spec (I) in 'a' .. 'z' | 'A' .. 'Z' loop
         Prelen := Prelen + 1;
         I := I + 1;
      end loop;
      --  "UTC"/"GMT" alone (offset 0) is allowed, including standards forms.
      if Prelen = 3 and then I > Spec'Last then
         if CI_Equal (Spec, "UTC") or else CI_Equal (Spec, "GMT") then
            return 0;
         end if;
         return -1;
      end if;
      if Prelen /= 3
        or else not (CI_Equal (Spec (Spec'First .. Spec'First + 2), "UTC")
                     or else
                       CI_Equal (Spec (Spec'First .. Spec'First + 2), "GMT"))
      then
         return -1;
      end if;
      --  Optional sign, then hours.
      if I <= Spec'Last and then Spec (I) = '+' then
         Sign := 1;
         I := I + 1;
      elsif I <= Spec'Last and then Spec (I) = '-' then
         Sign := -1;
         I := I + 1;
      end if;
      while I <= Spec'Last and then Spec (I) in '0' .. '9' loop
         H := H * 10
           + (Character'Pos (Spec (I)) - Character'Pos ('0'));
         Seen := True;
         I := I + 1;
      end loop;
      if not Seen or else H > 14 then
         return -1;
      end if;
      --  Optional ":MM".
      if I <= Spec'Last and then Spec (I) = ':' then
         I := I + 1;
         while I <= Spec'Last and then Spec (I) in '0' .. '9' loop
            Mn := Mn * 10
              + (Character'Pos (Spec (I)) - Character'Pos ('0'));
            I := I + 1;
         end loop;
         if Mn > 59 then
            return -1;
         end if;
      end if;
      --  Nothing else may follow.
      if I <= Spec'Last then
         return -1;
      end if;
      return Sign * (H * 3600 + Mn * 60);
   end Parse_UTC_GMT;

   procedure Parse
     (Spec : String; Info : out Timezone_Info; OK : out Boolean)
   is
      Offset : Integer;
      F      : Integer := Spec'First;
      L      : Integer := Spec'Last;
   begin
      while F <= L and then Spec (F) = ' ' loop
         F := F + 1;
      end loop;
      while L >= F and then Spec (L) = ' ' loop
         L := L - 1;
      end loop;
      if F > L then
         Info.Result_Valid := False;
         OK := False;
         return;
      end if;
      Offset := Lookup_Named (Spec (F .. L));
      if Offset >= 0 then
         Set_Display (Info, Spec (F .. L), Offset, Named => True);
         OK := True;
         return;
      end if;
      Offset := Parse_UTC_GMT (Spec (F .. L));
      if Offset >= 0 then
         Set_Display
           (Info, UTC_Offset_Display (Offset), Offset, Named => False);
         OK := True;
         return;
      end if;
      Info.Result_Valid := False;
      OK := False;
   end Parse;

    function Default return Timezone_Info is
       pragma Warnings (Off, "no Global contract available");
       TZ   : constant String :=
         (if Ada.Environment_Variables.Exists ("TZ")
          then Ada.Environment_Variables.Value ("TZ")
          else "");
       Info : Timezone_Info;
       OK   : Boolean;
    begin
       pragma Warnings (On, "no Global contract available");
       if TZ'Length > 0 then
          Parse (TZ, Info, OK);
          if OK then
             return Info;
          end if;
       end if;
       --  No explicit TZ override: honour the operating system's configured
       --  zone.  GNAT.Calendar.Time_Zone returns the C library's local-time
       --  offset (it honours the TZ variable and the system timezone), so the
       --  default is always the operator's wall-clock zone.  The env-var read
       --  above is the only non-SPARK construct; its Global-contract absence
       --  is suppressed, matching CPUs.Get_Temp_Directory.
       pragma Warnings (Off, "no Global contract available");
       declare
          Off : constant Integer := GNAT.Calendar.Time_Zone;
       begin
          pragma Warnings (On, "no Global contract available");
          Set_Display (Info, UTC_Offset_Display (Off), Off, Named => False);
       end;
       return Info;
    end Default;

   procedure Append_Int
     (Buf : in out String; Len : in out Natural; Value : Natural;
      Width : Positive)
   is
      Tmp : String (1 .. 10);
      N   : Natural := 0;
   begin
      if Value = 0 then
         N := 1;
         Tmp (1) := '0';
      else
         declare
            V : Natural := Value;
         begin
            while V > 0 loop
               N := N + 1;
               Tmp (N) := Character'Val (Character'Pos ('0') + V mod 10);
               V := V / 10;
            end loop;
         end;
      end if;
      while N < Width loop
         N := N + 1;
         Tmp (N) := '0';
      end loop;
      for I in reverse 1 .. N loop
         Len := Len + 1;
         if Len <= Buf'Last then
            Buf (Len) := Tmp (I);
         end if;
      end loop;
   end Append_Int;

   procedure Append (Buf : in out String; Len : in out Natural; S : String) is
   begin
      for I in S'Range loop
         Len := Len + 1;
         if Len <= Buf'Last then
            Buf (Len) := S (I);
         end if;
      end loop;
   end Append;

   function Now_Text (Info : Timezone_Info) return String is
      Clock : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Local : constant Ada.Calendar.Time :=
        Clock + Duration (Info.Offset_Secs);
      Secs  : constant Ada.Calendar.Day_Duration := Ada.Calendar.Seconds (Local);
      Buf   : String (1 .. 48);
      Len   : Natural := 0;
   begin
      if not Info.Result_Valid then
         return "unknown";
      end if;
      Append_Int (Buf, Len, Natural (Ada.Calendar.Year (Local)), 4);
      Append (Buf, Len, "-");
      Append_Int (Buf, Len, Natural (Ada.Calendar.Month (Local)), 2);
      Append (Buf, Len, "-");
      Append_Int (Buf, Len, Natural (Ada.Calendar.Day (Local)), 2);
      Append (Buf, Len, " ");
      Append_Int (Buf, Len, Natural (Integer (Secs) / 3600), 2);
      Append (Buf, Len, ":");
      Append_Int (Buf, Len, Natural ((Integer (Secs) mod 3600) / 60), 2);
      Append (Buf, Len, ":");
      Append_Int (Buf, Len, Natural (Integer (Secs) mod 60), 2);
      Append (Buf, Len, " ");
      Append
        (Buf,
         Len,
         (if Info.Display_Len > 0
          then Info.Display (1 .. Info.Display_Len)
          else UTC_Offset_Display (Info.Offset_Secs)));
      return Buf (1 .. Len);
   end Now_Text;

end Adacovex.Timezones;