# Adacovex.Timezones

Timezone resolution and local-time formatting for adacovex.

adacovex respects the operating system's timezone by default.  Users can
override it for a single invocation with --tz / --timezone.  Accepted
forms are a well-known IANA zone name (for example "Asia/Singapore") or a
fixed UTC/GMT offset ("UTC+8", "GMT+8", "UTC+08", "GMT+08", "UTC+08:30").

The crate has no library dependencies, so it ships no timezone database.
A named zone resolves from a built-in table of common IANA names and
their standard-time (non-DST) offsets.  A zone that may observe daylight
saving time (and any zone the table lacks) is probed against the
platform tzdata -- ``zdump`` + ``date +%z`` on Linux/WSL -- for the
DST-correct current offset; the table offset is the fallback when the
probe is unavailable.  The system default offset comes from the standard
Ada runtime (Ada.Calendar.Time_Zones.UTC_Time_Offset), which honours the
TZ environment variable and the operating system's local timezone, so
the default is always the operator's wall-clock timezone.
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

## Functions

### function Default return Adacovex.Timezones.Timezone_Info

**Returns:**  Parse a user-supplied --tz / --timezone value.  Supported forms:

### function Now_Text (Info : Adacovex.Timezones.Timezone_Info) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Info` | Resolved timezone. |

**Returns:** Current date/time text, or "unknown" when Info is invalid.

### function UTC_Offset_Display (Offset_Secs : Standard.Integer) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Offset_Secs` | Offset from UTC in seconds. |

**Returns:** "UTC[+-]HH:MM" display string.

## Procedures

### procedure Parse (Spec : Standard.String; Info : Adacovex.Timezones.Timezone_Info; OK : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Info` | Resolved timezone on success. |
| `OK` | True when Spec names a supported timezone. |
| `Spec` | The raw --tz / --timezone value to parse. |
