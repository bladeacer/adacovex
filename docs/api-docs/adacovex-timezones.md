# Adacovex.Timezones

Timezone resolution and local-time formatting for adacovex.

adacovex stores timestamps as UTC+0 by default. Users can opt into the
operating system's local timezone for a single invocation with
--tz=local (or --timezone=local). Other accepted forms are a well-known
IANA zone name (for example "Asia/Singapore") or a fixed UTC/GMT offset
("UTC+8", "GMT+8", "UTC+08", "GMT+08", "UTC+08:30").

The crate has no library dependencies, so it ships no timezone database.
A named zone resolves from a built-in table of common IANA names and
their standard-time (non-DST) offsets. A zone that may observe daylight
saving time (and any zone the table lacks) is probed against the
platform tzdata -- ``zdump`` + ``date +%z`` on Linux/WSL -- for the
DST-correct current offset; the table offset is the fallback when the
probe is unavailable. The system default offset comes from the standard
Ada runtime (Ada.Calendar.Time_Zones.UTC_Time_Offset), which honours the
TZ environment variable and the operating system's local timezone.
HLR-TZ: Timezone resolution and local-time formatting

> **Note:** All items in this package are public.

## Types

### type Timezone_Info

```ada
type Timezone_Info is record
Display      : String (1 .. Max_TZ_Name);
Display_Len  : Natural := 0;
Offset_Secs  : Integer := 0;
Is_Named     : Boolean := False;
Result_Valid : Boolean := True;
end record;
```

> A resolved timezone: a display name and its fixed offset from UTC in seconds (range -50400 .. 50400, i.e. UTC-14:00 .. UTC+14:00).

## Functions

### function Default return Adacovex.Timezones.Timezone_Info

> The default timezone adacovex uses: UTC+0. Timestamps are stored as UTC+0 unless the user opts into the local timezone with --tz=local.

**Returns:** The UTC+0 timezone (Result_Valid is True).

### function Default_Local return Adacovex.Timezones.Timezone_Info

> The operating system's configured local timezone, honoured only when the user opts in with --tz=local. Reads the TZ environment variable when that variable names a supported zone or carries a fixed UTC/GMT offset; otherwise uses the operating system's timezone offset via Ada.Calendar.Time_Zones.UTC_Time_Offset.

**Returns:** The effective local timezone (nil display on failure).

### function Is_Local_Spec (Spec : Standard.String) return Standard.Boolean

> True when Spec names the local-timezone opt-in ("local", matched case-insensitively, surrounding whitespace ignored). Such a spec is not parsed by Parse; instead Effective_TZ / the caller resolves the OS local zone via Default_Local.

| Parameter | Description |
|-----------|-------------|
| `Spec` | The raw --tz / --timezone value to test. |

**Returns:** True when Spec is the local opt-in keyword.

### function Now_Text (Info : Adacovex.Timezones.Timezone_Info) return Standard.String

> The current wall-clock date and time in the resolved zone, as a "YYYY-MM-DD HH:MM:SS UTC+HH:MM" string. The date is computed from Ada.Calendar.Clock (UTC) shifted by the zone's offset.

| Parameter | Description |
|-----------|-------------|
| `Info` | Resolved timezone. |

**Returns:** Current date/time text, or "unknown" when Info is invalid.

### function UTC_Offset_Display (Offset_Secs : Standard.Integer) return Standard.String

> Render a fixed UTC offset as a display string in the form "UTC+08:00", "UTC-05:30", or "UTC+00:00".

| Parameter | Description |
|-----------|-------------|
| `Offset_Secs` | Offset from UTC in seconds. |

**Returns:** "UTC[+-]HH:MM" display string.

## Procedures

### procedure Parse (Spec : Standard.String; Info : Adacovex.Timezones.Timezone_Info; OK : Standard.Boolean)

> Parse a user-supplied --tz / --timezone value. Supported forms: * a named IANA zone ("Asia/Singapore", "Europe/London", "UTC", ...) * a fixed offset ("UTC+8", "GMT+8", "UTC+08:30", "UTC-5", ...) The local opt-in ("local") is not a valid parse spec; callers detect it with Is_Local_Spec and resolve the OS zone via Default_Local. A named zone resolves from the built-in table first; a zone that may observe DST, or one the table lacks, is probed against the platform tzdata for the current offset. On success OK is True and Info holds the resolved zone; on failure OK is False and Info.Result_Valid is False. The spec is matched case-insensitively.

| Parameter | Description |
|-----------|-------------|
| `Info` | Resolved timezone on success. |
| `OK` | True when Spec names a supported timezone. |
| `Spec` | The raw --tz / --timezone value to parse. |
