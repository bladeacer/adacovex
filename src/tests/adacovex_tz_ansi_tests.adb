with Adacovex.Timezones;
with Adacovex.Ansi;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;

package body Adacovex_TZ_ANSI_Tests is

   --  Parse Spec and check that it is accepted with the exact Expected
   --  offset (seconds).  The expected offset may be negative, so acceptance
   --  is always asserted separately.
   --  @param R  Test runner.
   --  @param Spec  Raw --tz / --timezone value.
   --  @param Expected  Expected offset in seconds.
   --  @param Msg  Test description.
   procedure Check_Parse
     (R        : in out Adacovex.Test_Support.Runner'Class;
      Spec     : String;
      Expected : Integer;
      Msg      : String)
   is
      Info : Adacovex.Timezones.Timezone_Info;
      OK   : Boolean;
   begin
      Adacovex.Timezones.Parse (Spec, Info, OK);
      R.Check (OK, Msg & " is accepted");
      R.Check
        (OK and then Info.Offset_Secs = Expected, Msg & " resolves to offset");
   end Check_Parse;

   --  Parse Spec and check that it is rejected.
   --  @param R  Test runner.
   --  @param Spec  Raw --tz / --timezone value.
   --  @param Msg  Test description.
   procedure Check_Reject
     (R    : in out Adacovex.Test_Support.Runner'Class;
      Spec : String;
      Msg  : String)
   is
      Info : Adacovex.Timezones.Timezone_Info;
      OK   : Boolean;
   begin
      Adacovex.Timezones.Parse (Spec, Info, OK);
      R.Check (not OK, Msg & " is rejected");
   end Check_Reject;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Info : Adacovex.Timezones.Timezone_Info;
      OK   : Boolean;
   begin
      --  Named IANA zones resolve from the built-in table (fixed-offset
      --  zones never observe DST, so these are deterministic).
      Check_Parse (R, "Asia/Singapore", 8 * 3600, "Asia/Singapore");
      Check_Parse (R, "Asia/Kolkata", 5 * 3600 + 1800, "Asia/Kolkata");
      Check_Parse (R, "America/Phoenix", -7 * 3600, "America/Phoenix");
      Check_Parse (R, "UTC", 0, "UTC");
      Check_Parse (R, "GMT", 0, "GMT");
      Check_Parse (R, "Zulu", 0, "Zulu");

      --  The table is matched case-insensitively.
      Check_Parse (R, "asia/singapore", 8 * 3600, "asia/singapore");

      --  DST-observing zones probe the platform tzdata for the current
      --  offset.  The result is either the standard or the DST offset,
      --  depending on the season (and falls back to the table's standard
      --  offset when the probe is unavailable).
      Adacovex.Timezones.Parse ("Europe/London", Info, OK);
      R.Check
        (OK and then (Info.Offset_Secs = 0 or else Info.Offset_Secs = 3600),
         "Europe/London resolves to UTC or UTC+1 (DST-aware)");
      Adacovex.Timezones.Parse ("America/New_York", Info, OK);
      R.Check
        (OK
         and then (Info.Offset_Secs = -5 * 3600
                   or else Info.Offset_Secs = -4 * 3600),
         "America/New_York resolves to UTC-5 or UTC-4 (DST-aware)");

      --  A zone the table lacks resolves through the platform tzdata when
      --  it is available; without the probe tools it is rejected.
      Adacovex.Timezones.Parse ("America/Indiana/Indianapolis", Info, OK);
      R.Check
        ((not OK)
         or else (Info.Offset_Secs = -5 * 3600
                  or else Info.Offset_Secs = -4 * 3600),
         "table-missing zone probes tzdata when available");

      --  Fixed UTC/GMT offsets in every documented form.
      Check_Parse (R, "UTC+8", 8 * 3600, "UTC+8");
      Check_Parse (R, "GMT+8", 8 * 3600, "GMT+8");
      Check_Parse (R, "UTC+08", 8 * 3600, "UTC+08");
      Check_Parse (R, "GMT+08", 8 * 3600, "GMT+08");
      Check_Parse (R, "UTC+08:30", 8 * 3600 + 1800, "UTC+08:30");
      Check_Parse (R, "UTC-5", -5 * 3600, "UTC-5");
      Check_Parse (R, "GMT-05:30", -5 * 3600 - 1800, "GMT-05:30");
      Check_Parse (R, "UTC+00:00", 0, "UTC+00:00");

      --  Malformed and out-of-range values are rejected.
      Check_Reject (R, "", "empty value");
      Check_Reject (R, "Not/AZone", "Not/AZone");
      Check_Reject (R, "UTC+99", "UTC+99");
      Check_Reject (R, "UTC+8:99", "UTC+8:99");
      Check_Reject (R, "UTCX+8", "UTCX+8");
      Check_Reject (R, "Asia/Singapre", "Asia/Singapre (typo)");

      --  Fixed offsets are displayed as UTC+/-HH:MM.
      R.Check
        (Adacovex.Timezones.UTC_Offset_Display (8 * 3600 + 1800) = "UTC+08:30",
         "UTC_Offset_Display renders +08:30");
      R.Check
        (Adacovex.Timezones.UTC_Offset_Display (-5 * 3600 - 1800)
         = "UTC-05:30",
         "UTC_Offset_Display renders -05:30");
      R.Check
        (Adacovex.Timezones.UTC_Offset_Display (0) = "UTC+00:00",
         "UTC_Offset_Display renders +00:00");

      --  A named zone keeps its IANA name as the display.
      Adacovex.Timezones.Parse ("Asia/Singapore", Info, OK);
      R.Check (OK and then Info.Is_Named, "named zone is flagged as named");
      R.Check
        (OK and then Info.Display (1 .. Info.Display_Len) = "Asia/Singapore",
         "named zone keeps its display name");

      --  A fixed offset is flagged as not-named and re-displayed.
      Adacovex.Timezones.Parse ("UTC+8", Info, OK);
      R.Check
        (OK and then not Info.Is_Named,
         "fixed offset is flagged as not-named");
      R.Check
        (OK and then Info.Display (1 .. Info.Display_Len) = "UTC+08:00",
         "fixed offset is normalised to UTC+08:00");

      --  Now_Text renders the current date/time in the resolved zone.
      Adacovex.Timezones.Parse ("Asia/Singapore", Info, OK);
      declare
         T : constant String := Adacovex.Timezones.Now_Text (Info);
      begin
         R.Check (T'Length >= 25, "Now_Text is a full date/time string");
         R.Check
           (Ada.Strings.Fixed.Index (T, "Asia/Singapore") > 0,
            "Now_Text carries the zone name");
         R.Check
           (Ada.Strings.Fixed.Index (T, "-") > 0
            and then Ada.Strings.Fixed.Index (T, ":") > 0,
            "Now_Text has date and time separators");
      end;

      --  An invalid zone renders as "unknown".
      declare
         Bad : Adacovex.Timezones.Timezone_Info :=
           (Result_Valid => False, others => <>);
      begin
         R.Check
           (Adacovex.Timezones.Now_Text (Bad) = "unknown",
            "Now_Text reports unknown for an invalid zone");
      end;

      --  The OS default always resolves to a valid zone within range.
      declare
         D : constant Adacovex.Timezones.Timezone_Info :=
           Adacovex.Timezones.Default;
      begin
         R.Check (D.Result_Valid, "OS default zone is valid");
         R.Check
           (D.Offset_Secs >= -50400 and then D.Offset_Secs <= 50400,
            "OS default offset is within UTC-14:00 .. UTC+14:00");
      end;

      --  ANSI colour gating: the pure decision function is off under CI,
      --  NO_COLOR, or TERM=dumb, and on otherwise.  This is deterministic
      --  and does not depend on the surrounding test runner's environment.
      R.Check
        (Adacovex.Ansi.Colour_Allowed (False, False, False),
         "colour allowed with a clean environment");
      R.Check
        (not Adacovex.Ansi.Colour_Allowed (True, False, False),
         "colour off when CI is set");
      R.Check
        (not Adacovex.Ansi.Colour_Allowed (False, True, False),
         "colour off when NO_COLOR is set");
      R.Check
        (not Adacovex.Ansi.Colour_Allowed (False, False, True),
         "colour off when TERM=dumb");
      R.Check
        (not Adacovex.Ansi.Colour_Allowed (True, True, True),
         "colour off when every signal is set");

      --  With colour enabled, wrappers emit SGR escapes.  The prefix is
      --  ESC + "[" + code + "m" and the suffix is ESC + "[0m".
      Adacovex.Ansi.Colour_Enabled := True;
      R.Check
        (Adacovex.Ansi.Red ("x")'Length = 10,
         "Red wraps with SGR escapes when enabled");
      R.Check
        (Adacovex.Ansi.Bold ("x")'Length = 9,
         "Bold wraps with SGR escapes when enabled");
      R.Check
        (Adacovex.Ansi.Green ("x")'Length = 10
         and then Adacovex.Ansi.Yellow ("x")'Length = 10
         and then Adacovex.Ansi.Blue ("x")'Length = 10,
         "every colour wrapper emits SGR escapes when enabled");
      R.Check
        (Adacovex.Ansi.Dim ("x")'Length = 9,
         "Dim wraps with the dim SGR sequence when enabled");

      --  With colour disabled, wrappers return the input unchanged.
      Adacovex.Ansi.Colour_Enabled := False;
      R.Check
        (Adacovex.Ansi.Red ("x") = "x"
         and then Adacovex.Ansi.Green ("x") = "x"
         and then Adacovex.Ansi.Yellow ("x") = "x"
         and then Adacovex.Ansi.Blue ("x") = "x"
         and then Adacovex.Ansi.Dim ("x") = "x"
         and then Adacovex.Ansi.Bold ("x") = "x",
         "wrappers are no-ops when colour is off");

      --  Init agrees with Colour_Allowed on the current environment.
      Adacovex.Ansi.Init;
      declare
         Term_Dumb : Boolean := False;
      begin
         if Ada.Environment_Variables.Exists ("TERM") then
            declare
               V : constant String := Ada.Environment_Variables.Value ("TERM");
            begin
               Term_Dumb := V = "dumb" or else V = "";
            end;
         end if;
         R.Check
           (Adacovex.Ansi.Colour_Enabled
            = Adacovex.Ansi.Colour_Allowed
                (Ada.Environment_Variables.Exists ("CI"),
                 Ada.Environment_Variables.Exists ("NO_COLOR"),
                 Term_Dumb),
            "Init agrees with Colour_Allowed on the environment");
      end;
   end Run;

end Adacovex_TZ_ANSI_Tests;
