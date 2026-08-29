with Ada.Calendar;
with Ada.Calendar.Time_Zones;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Adacovex.CPUs;

package body Adacovex.Timezones is

   use Ada.Calendar;
   use Ada.Characters.Handling;
   use Ada.Strings;
   use GNAT.OS_Lib;

   --  Built-in table of common IANA zone names -> standard-time offsets.
   --  Entries are "Name+OFFSET[~];" where OFFSET is a whole or half hour
   --  ("+8", "-5.5") and the optional "~" marks a zone that may observe
   --  daylight saving time.  adacovex ships no timezone database, so the
   --  table gives standard (non-DST) offsets.  A zone marked "~" is probed
   --  against the platform tzdata (via `zdump` and `date +%z`) so its
   --  resolved offset is DST-correct on Linux/WSL; the table offset is the
   --  fallback when the probe is unavailable.  A named zone not in the table
   --  is probed the same way and rejected when the platform does not know
   --  it.  Hand-written to keep the crate dependency-free; extend it for new
   --  zone names as needed.
   Zones_Table : constant String :=
     "Asia/Singapore+8;Asia/Shanghai+8;Asia/Hong_Kong+8;Asia/Taipei+8;"
     & "Asia/Manila+8;Asia/Kuala_Lumpur+8;Asia/Seoul+9;Asia/Tokyo+9;"
     & "Asia/Jakarta+7;Asia/Bangkok+7;Asia/Ho_Chi_Minh+7;Asia/Yangon+6.5;"
     & "Asia/Dhaka+6;Asia/Karachi+5;Asia/Kolkata+5.5;Asia/Colombo+5.5;"
     & "Asia/Dubai+4;Asia/Kabul+4.5;Asia/Tehran+3.5;Asia/Baghdad+3;"
     & "Asia/Riyadh+3;Asia/Jerusalem+2~;Asia/Beirut+2~;Asia/Baku+4;"
     & "Asia/Tbilisi+4;Asia/Yerevan+4;Asia/Almaty+6;Asia/Tashkent+5;"
     & "Asia/Bishkek+6;Asia/Ulaanbaatar+8;Australia/Eucla+8.75;"
     & "Australia/Perth+8;Australia/Darwin+9.5;Australia/Brisbane+10;"
     & "Australia/Adelaide+9.5~;Australia/Sydney+10~;Australia/Melbourne+10~;"
     & "Australia/Hobart+10~;Pacific/Auckland+12~;Pacific/Guam+10;"
     & "Pacific/Port_Moresby+10;Pacific/Honolulu-10;Pacific/Tahiti-10;"
     & "Pacific/Midway-11;Pacific/Niue-11;"
     & "Europe/London+0~;Europe/Dublin+0~;Europe/Lisbon+0~;Europe/Madrid+1~;"
     & "Europe/Paris+1~;Europe/Berlin+1~;Europe/Brussels+1~;"
     & "Europe/Amsterdam+1~;Europe/Zurich+1~;Europe/Vienna+1~;"
     & "Europe/Rome+1~;Europe/Warsaw+1~;Europe/Stockholm+1~;"
     & "Europe/Prague+1~;Europe/Copenhagen+1~;Europe/Oslo+1~;"
     & "Europe/Athens+2~;Europe/Bucharest+2~;Europe/Sofia+2~;"
     & "Europe/Helsinki+2~;Europe/Kyiv+2~;Europe/Kiev+2~;Europe/Riga+2~;"
     & "Europe/Vilnius+2~;Europe/Istanbul+3;Europe/Moscow+3;Europe/Minsk+3;"
     & "UTC+0;GMT+0;Etc/UTC+0;Etc/GMT+0;Zulu+0;"
     & "America/New_York-5~;America/Chicago-6~;America/Denver-7~;"
     & "America/Phoenix-7;America/Los_Angeles-8~;America/Anchorage-9~;"
     & "America/Honolulu-10;America/Toronto-5~;America/Montreal-5~;"
     & "America/Ottawa-5~;America/Vancouver-8~;America/Edmonton-7~;"
     & "America/Winnipeg-6~;America/Halifax-4~;America/St_Johns-3.5~;"
     & "America/Mexico_City-6;America/Guatemala-6;America/El_Salvador-6;"
     & "America/Bogota-5;America/Lima-5;America/Guayaquil-5;"
     & "America/Sao_Paulo-3;America/Argentina/Buenos_Aires-3;"
     & "America/Santiago-4~;America/Caracas-4;America/La_Paz-4;"
     & "America/Panama-5;America/Nassau-5~;America/Port-au-Prince-5~;"
     & "America/Costa_Rica-6;America/Managua-6;America/Tegucigalpa-6;"
     & "Africa/Lagos+1;Africa/Cairo+2~;Africa/Johannesburg+2;"
     & "Africa/Nairobi+3;Africa/Addis_Ababa+3;Africa/Casablanca+1~;"
     & "Africa/Accra+0;Africa/Kinshasa+1;Africa/Algiers+1;Africa/Tunis+1;"
     & "Antarctica/Troll+0~;";

   procedure Set_Display
     (Info        : in out Timezone_Info;
      Name        : String;
      Offset_Secs : Integer;
      Named       : Boolean) is
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
         if To_Lower (A (A'First + I - 1)) /= To_Lower (B (B'First + I - 1))
         then
            return False;
         end if;
      end loop;
      return True;
   end CI_Equal;

   --  Probe the platform tzdata for the current UTC offset of a named zone.
   --  One shell command validates the zone with `zdump` (which fails on
   --  unknown zones) and reads the offset from `date +%z`.  This is the
   --  DST-correct path on Linux/WSL.  When the probe is unavailable (no
   --  zdump/date on PATH) or the zone is unknown, OK is False and the caller
   --  falls back to the built-in table (or rejects the name).
   function Probe_Offset (Name : String; OK : out Boolean) return Integer is
      Tmp  : constant String :=
        Adacovex.CPUs.Get_Temp_Directory & "/adacovex-tz.tmp";
      Args : GNAT.OS_Lib.Argument_List :=
        (new String'("-c"),
         new String'
           ("zdump '"
            & Name
            & "' >/dev/null 2>&1 && TZ='"
            & Name
            & "' date +%z > '"
            & Tmp
            & "' 2>/dev/null"));
      --  The portable spawn fails on a bare program name, so resolve the
      --  shell to its full path first (the same pattern Run_Command uses in
      --  the prove subcommand).
      Prog : String_Access :=
        Locate_Exec_On_Path (Adacovex.CPUs.Get_Shell_Command);
      Code : Integer;
      Succ : Boolean;
      F    : Ada.Text_IO.File_Type;
      Line : String (1 .. 16);
      Len  : Natural := 0;
      H    : Natural := 0;
      Mn   : Natural := 0;
      Res  : Integer := 0;
   begin
      OK := False;
      --  Only multi-component names (containing '/') are probed.  A bare
      --  name is ambiguous: glibc would accept it as a POSIX-style TZ
      --  specification (for example "UTCX+8"), which is not a documented
      --  input form and must stay rejected.
      if (for all I in Name'Range => Name (I) /= '/') then
         return 0;
      end if;
      if Prog = null then
         return 0;
      end if;
      Spawn (Prog.all, Args, "/dev/null", Succ, Code, Err_To_Out => True);
      Free (Prog);
      Free (Args (1));
      Free (Args (2));
      if not Succ or else Code /= 0 then
         return 0;
      end if;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Tmp);
         if not Ada.Text_IO.End_Of_File (F) then
            declare
               L : constant String := Ada.Text_IO.Get_Line (F);
            begin
               if L'Length <= Line'Length then
                  Line (1 .. L'Length) := L;
                  Len := L'Length;
               end if;
            end;
         end if;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
      begin
         if Ada.Directories.Exists (Tmp) then
            Ada.Directories.Delete_File (Tmp);
         end if;
      exception
         when others =>
            null;
      end;
      --  Parse the date output: "+0800" / "-0530" / "+0000".
      if Len >= 5
        and then (Line (1) = '+' or else Line (1) = '-')
        and then Line (2) in '0' .. '9'
        and then Line (3) in '0' .. '9'
        and then Line (4) in '0' .. '9'
        and then Line (5) in '0' .. '9'
      then
         H :=
           (Character'Pos (Line (2)) - Character'Pos ('0'))
           * 10
           + (Character'Pos (Line (3)) - Character'Pos ('0'));
         Mn :=
           (Character'Pos (Line (4)) - Character'Pos ('0'))
           * 10
           + (Character'Pos (Line (5)) - Character'Pos ('0'));
         if H <= 14 and then Mn <= 59 then
            Res := H * 3600 + Mn * 60;
            if Line (1) = '-' then
               Res := -Res;
            end if;
            OK := True;
         end if;
      end if;
      return Res;
   end Probe_Offset;

   --  Look up an IANA name in the built-in table.  Found is True and the
   --  returned value is the offset in seconds when the name is present
   --  (the offset may be negative, so Found is the only presence test).
   --  May_DST is True when the table entry is marked "~" (the zone may
   --  observe daylight saving time, so the caller probes the platform
   --  tzdata for the current offset).
   function Lookup_Named
     (Name : String; Found : out Boolean; May_DST : out Boolean) return Integer
   is
      Start : Natural := Zones_Table'First;
      Fin   : Natural;
   begin
      Found := False;
      May_DST := False;
      while Start <= Zones_Table'Last loop
         Fin := Start;
         while Fin <= Zones_Table'Last and then Zones_Table (Fin) /= ';' loop
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
              and then (for all I in 1 .. NLen =>
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
                  H :=
                    H
                    * 10
                    + (Character'Pos (Zones_Table (P)) - Character'Pos ('0'));
                  P := P + 1;
               end loop;
               if H <= 14 then
                  if P + 1 < Fin
                    and then Zones_Table (P) = '.'
                    and then Zones_Table (P + 1) = '5'
                  then
                     Mn := 30;
                     P := P + 2;
                  end if;
                  May_DST := P < Fin and then Zones_Table (P) = '~';
                  Done := True;
               end if;
            end if;
            if Done then
               Found := True;
               return Mult * (H * 3600 + Mn * 60);
            end if;
         end;
         if Fin > Zones_Table'Last then
            exit;
         end if;
         Start := Fin + 1;
      end loop;
      return 0;
   end Lookup_Named;

   --  Parse a fixed UTC/GMT offset spec ("UTC+8", "GMT-5", "UTC+08:30", or
   --  a bare "UTC" / "GMT").  Found is True and the returned value is the
   --  offset in seconds when the spec is a valid fixed offset (the offset
   --  may be negative, so Found is the only presence test).
   function Parse_UTC_GMT (Spec : String; Found : out Boolean) return Integer
   is
      I      : Integer := Spec'First;
      Prelen : Natural := 0;
      Sign   : Integer := 1;
      H      : Natural := 0;
      Mn     : Natural := 0;
      Seen   : Boolean := False;
   begin
      Found := False;
      while I <= Spec'Last and then Spec (I) in 'a' .. 'z' | 'A' .. 'Z' loop
         Prelen := Prelen + 1;
         I := I + 1;
      end loop;
      --  "UTC"/"GMT" alone (offset 0) is allowed, including standards forms.
      if Prelen = 3 and then I > Spec'Last then
         if CI_Equal (Spec, "UTC") or else CI_Equal (Spec, "GMT") then
            Found := True;
            return 0;
         end if;
         return 0;
      end if;
      if Prelen /= 3
        or else not (CI_Equal (Spec (Spec'First .. Spec'First + 2), "UTC")
                     or else CI_Equal
                               (Spec (Spec'First .. Spec'First + 2), "GMT"))
      then
         return 0;
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
         H := H * 10 + (Character'Pos (Spec (I)) - Character'Pos ('0'));
         Seen := True;
         I := I + 1;
      end loop;
      if not Seen or else H > 14 then
         return 0;
      end if;
      --  Optional ":MM".
      if I <= Spec'Last and then Spec (I) = ':' then
         I := I + 1;
         while I <= Spec'Last and then Spec (I) in '0' .. '9' loop
            Mn := Mn * 10 + (Character'Pos (Spec (I)) - Character'Pos ('0'));
            I := I + 1;
         end loop;
         if Mn > 59 then
            return 0;
         end if;
      end if;
      --  Nothing else may follow.
      if I <= Spec'Last then
         return 0;
      end if;
      Found := True;
      return Sign * (H * 3600 + Mn * 60);
   end Parse_UTC_GMT;
   procedure Parse (Spec : String; Info : out Timezone_Info; OK : out Boolean)
   is
      Offset  : Integer;
      Found   : Boolean;
      May_DST : Boolean;
      F       : Integer := Spec'First;
      L       : Integer := Spec'Last;
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
      --  Named IANA zones resolve through the built-in table first.  A zone
      --  marked "~" may observe DST, so its current offset is probed against
      --  the platform tzdata (the table's standard-time offset is the
      --  fallback when the probe is unavailable).  The table may hold
      --  negative offsets, so presence is tested with Found, never with the
      --  offset sign.
      Offset := Lookup_Named (Spec (F .. L), Found, May_DST);
      if Found then
         if May_DST then
            declare
               POK : Boolean;
               PO  : constant Integer := Probe_Offset (Spec (F .. L), POK);
            begin
               Set_Display
                 (Info,
                  Spec (F .. L),
                  (if POK then PO else Offset),
                  Named => True);
            end;
         else
            Set_Display (Info, Spec (F .. L), Offset, Named => True);
         end if;
         OK := True;
         return;
      end if;
      --  Fixed UTC/GMT offsets (never probed; the table has no such names).
      Offset := Parse_UTC_GMT (Spec (F .. L), Found);
      if Found then
         Set_Display
           (Info, UTC_Offset_Display (Offset), Offset, Named => False);
         OK := True;
         return;
      end if;
      --  A name the table lacks: ask the platform tzdata.  The probe
      --  validates the zone, so an unknown name is rejected loudly.
      declare
         POK : Boolean;
         PO  : constant Integer := Probe_Offset (Spec (F .. L), POK);
      begin
         if POK then
            Set_Display (Info, Spec (F .. L), PO, Named => True);
            OK := True;
            return;
         end if;
      end;
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
      --  zone.  Ada.Calendar.Time_Zones.UTC_Time_Offset returns the current
      --  local-time offset in minutes (it honours the TZ variable and the
      --  system timezone), so the default is always the operator's wall-clock
      --  zone.  The env-var read above is the only non-SPARK construct; its
      --  Global-contract absence is suppressed, matching
      --  CPUs.Get_Temp_Directory.
      declare
         Off : constant Integer :=
           Integer (Ada.Calendar.Time_Zones.UTC_Time_Offset) * 60;
      begin
         Set_Display (Info, UTC_Offset_Display (Off), Off, Named => False);
      end;
      return Info;
   end Default;

   procedure Append_Int
     (Buf   : in out String;
      Len   : in out Natural;
      Value : Natural;
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
      --  Ada.Calendar.Clock is UTC-based, but GNAT's accessors (Seconds,
      --  Year, Month, Day) return the components in the process's local
      --  time zone (the C library's tzset offset), not UTC.  To render the
      --  wall-clock time in the resolved zone, shift the clock by the
      --  difference between the resolved offset and the local offset before
      --  splitting; the accessors then report the resolved zone's time.
      Local_Off : constant Integer :=
        Integer (Ada.Calendar.Time_Zones.UTC_Time_Offset) * 60;
      Clock     : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Local     : constant Ada.Calendar.Time :=
        Clock + Duration (Info.Offset_Secs - Local_Off);
      Secs      : constant Ada.Calendar.Day_Duration :=
        Ada.Calendar.Seconds (Local);
      Buf       : String (1 .. 48);
      Len       : Natural := 0;
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
