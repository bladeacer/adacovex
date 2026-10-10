# STE100 Technical Names: reports and concepts

The **reports and concepts** half of the **Code Identifier Names** category
of the [STE100 Technical Names](index.md) dictionary. These
terms name the generated report files, the time standards, and the
command-line spellings. The tool and file identifiers are on
[tools and files](identifiers.md).

## Technical Name: Verification Report
- **Part of Speech:** Noun
- **Definition:** The generated report file `VERIFICATION.md`. It records the
  assessment results of the target project.
- **Approved Form:** Verification Report (singular), VERIFICATION.md (the
  file name)
- **Do Not Use:** Report file (when VERIFICATION.md is meant), Assessment
  report (after the first use)
- **Correct Example:** *The renderer writes the **verification report** to `VERIFICATION.md`.*
- **Incorrect Example:** *The renderer writes the report file to `VERIFICATION.md`.*

## Technical Name: Traceability Matrix
- **Part of Speech:** Noun
- **Definition:** The generated report file `TRACE.md`. It maps every
  high-level requirement to the source elements that implement it.
- **Approved Form:** Traceability Matrix (singular), TRACE.md (the file
  name)
- **Do Not Use:** Trace table, Mapping file (when TRACE.md is meant)
- **Correct Example:** *The renderer writes the **traceability matrix** to `TRACE.md`.*
- **Incorrect Example:** *The renderer writes the mapping file to `TRACE.md`.*

## Technical Name: Timezone
- **Part of Speech:** Noun
- **Definition:** The named region or fixed offset that defines local time
  for the operator. It includes IANA names (for example `Asia/Singapore`)
  and fixed UTC/GMT offsets (for example `UTC+8`).
- **Approved Form:** Timezone (singular), Timezones (plural)
- **Do Not Use:** Time zone (two words), Zone (when Timezone is meant)
- **Correct Example:** *The report shows the time in the operator's **timezone**.*
- **Incorrect Example:** *The report shows the time in the operator's time zone.*

## Technical Name: UTC
- **Part of Speech:** Noun
- **Definition:** The coordinated universal time standard. It is the
  zero-offset reference that adacovex uses to display fixed offsets.
- **Approved Form:** UTC (exact capitals)
- **Do Not Use:** Universal time, Greenwich Mean Time (when UTC is meant)
- **Correct Example:** *The report shows the offset as `UTC+08:00`.*
- **Incorrect Example:** *The report shows the offset in universal time.*

## Technical Name: GMT
- **Part of Speech:** Noun
- **Definition:** The Greenwich mean time standard. adacovex accepts `GMT`
  as a synonym for `UTC` in fixed offset values.
- **Approved Form:** GMT (exact capitals)
- **Do Not Use:** Greenwich time, London time
- **Correct Example:** *`GMT+8` is a valid fixed offset value.*
- **Incorrect Example:** *`Greenwich time +8` is a valid fixed offset value.*

## Technical Name: IANA
- **Part of Speech:** Modifier
- **Definition:** The Internet Assigned Numbers Authority. Always use it
  with the noun name to mean the tz database zone identifiers.
- **Approved Form:** IANA (exact capitals, as modifier, for example IANA
  name)
- **Do Not Use:** Olson, tz database (as a modifier)
- **Correct Example:** *`Asia/Singapore` is an **IANA** name.*
- **Incorrect Example:** *`Asia/Singapore` is a tz database name.*

## Technical Name: Alias
- **Part of Speech:** Noun
- **Definition:** A second long spelling for the same command-line flag.
  An alias has the same effect as the canonical flag (for example
  `--workers` is an alias of `--serve-workers`).
- **Approved Form:** Alias (singular), Aliases (plural)
- **Do Not Use:** Synonym flag, Alternate name
- **Correct Example:** *`--workers` is an **alias** of `--serve-workers`.*
- **Incorrect Example:** *`--workers` is a synonym flag for `--serve-workers`.*

## Technical Name: Shorthand
- **Part of Speech:** Noun
- **Definition:** A short single-letter form of a command-line flag (for
  example `-t` for `--target`). A shorthand takes the same value as the
  canonical flag.
- **Approved Form:** Shorthand (singular), Shorthands (plural)
- **Do Not Use:** Shortcut, Abbreviation
- **Correct Example:** *Use the **shorthand** `-t` for `--target`.*
- **Incorrect Example:** *Use the shortcut `-t` for `--target`.*

## Technical Name: Tier Token
- **Part of Speech:** Noun
- **Definition:** A value for `--standard` that names a standard together
  with a rigour tier (for example `dal-B`, `asil-b`, or `class-c`).
- **Approved Form:** Tier token (singular), Tier tokens (plural)
- **Do Not Use:** Level token, Compliance token
- **Correct Example:** *`--standard=asil-b` is a **tier token**.*
- **Incorrect Example:** *`--standard=asil-b` is a level token.*
