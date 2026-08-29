--  Timezone resolution and local-time formatting for adacovex.
--
--  adacovex respects the operating system's timezone by default.  Users can
--  override it for a single invocation with --tz / --timezone.  Accepted
--  forms are a well-known IANA zone name (for example "Asia/Singapore") or a
--  fixed UTC/GMT offset ("UTC+8", "GMT+8", "UTC+08", "GMT+08", "UTC+08:30").
--
--  The crate has no library dependencies, so it ships no timezone database.
--  A named zone resolves from a built-in table of common IANA names and
--  their standard-time (non-DST) offsets.  A zone that may observe daylight
--  saving time (and any zone the table lacks) is probed against the
--  platform tzdata -- `zdump` + `date +%z` on Linux/WSL -- for the
--  DST-correct current offset; the table offset is the fallback when the
--  probe is unavailable.  The system default offset comes from the standard
--  Ada runtime (Ada.Calendar.Time_Zones.UTC_Time_Offset), which honours the
--  TZ environment variable and the operating system's local timezone, so
--  the default is always the operator's wall-clock timezone.
--  HLR-TZ: Timezone resolution and local-time formatting

package Adacovex.Timezones is

   Max_TZ_Name : constant := 64;

   --  A resolved timezone: a display name and its fixed offset from UTC in
   --  seconds (range -50400 .. 50400, i.e. UTC-14:00 .. UTC+14:00).
   type Timezone_Info is record
      Display      : String (1 .. Max_TZ_Name);
      Display_Len  : Natural := 0;
      Offset_Secs  : Integer := 0;
      --  True when Display is a named IANA zone resolved from the built-in
      --  table; False when it is a fixed UTC/GMT offset or the system zone.
      Is_Named     : Boolean := False;
      --  True when the zone came from an explicit --tz / --timezone value
      --  rather than the operating system default.
      Result_Valid : Boolean := True;
   end record;

   --  Resolve the timezone adacovex uses.  It honours an explicit TZ
   --  environment variable when that variable names a supported zone or
   --  carries a fixed UTC/GMT offset; otherwise it uses the operating
   --  system's timezone offset via Ada.Calendar.Time_Zones.UTC_Time_Offset.
   --  @return The effective timezone (nil display on failure).
   function Default
      return Timezone_Info;   --  Parse a user-supplied --tz / --timezone value.  Supported forms:
   --    * a named IANA zone ("Asia/Singapore", "Europe/London", "UTC", ...)
   --    * a fixed offset ("UTC+8", "GMT+8", "UTC+08:30", "UTC-5", ...)
   --  A named zone resolves from the built-in table first; a zone that may
   --  observe DST, or one the table lacks, is probed against the platform
   --  tzdata for the current offset.  On success OK is True and Info holds
   --  the resolved zone; on failure OK is False and Info.Result_Valid is
   --  False.  The spec is matched case-insensitively.
   --  @param Spec  The raw --tz / --timezone value to parse.
   --  @param Info  Resolved timezone on success.
   --  @param OK    True when Spec names a supported timezone.
   procedure Parse (Spec : String; Info : out Timezone_Info; OK : out Boolean);

   --  Render a fixed UTC offset as a display string in the form "UTC+08:00",
   --  "UTC-05:30", or "UTC+00:00".
   --  @param Offset_Secs  Offset from UTC in seconds.
   --  @return "UTC[+-]HH:MM" display string.
   function UTC_Offset_Display (Offset_Secs : Integer) return String;

   --  The current wall-clock date and time in the resolved zone, as a
   --  "YYYY-MM-DD HH:MM:SS UTC+HH:MM" string.  The date is computed from
   --  Ada.Calendar.Clock (UTC) shifted by the zone's offset.
   --  @param Info  Resolved timezone.
   --  @return Current date/time text, or "unknown" when Info is invalid.
   function Now_Text (Info : Timezone_Info) return String;

end Adacovex.Timezones;
