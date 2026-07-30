# adacovex 1.1.0

Date: _2026-07-30_

## Fixes

### H1: Generic keyword bounds not matching single-line declarations

`Is_Subprogram_Decl` in `adacovex-parsers-source.adb` had off-by-one bounds:
`"genericprocedure"` (16 chars) was compared against a 15-char slice, and
`"genericfunction"` (15 chars) against a 14-char slice. Since Ada string
equality requires matching lengths, both branches never fired, meaning
`generic procedure Reset;` on a single line was invisible to the scanner.

**Impact:** Single-line generic subprograms were silently excluded from
coverage tracking, docstring requirements, and subprogram counts.

**Fix:** Bounds corrected to `>= 16` and `>= 15`.

### H2: `Determine_SPARK_Level` returning Gold for missing proof data

When no GNATprove output exists (all fields zero), `0 >= 0` returned Gold
instead of Stone, causing DAL-C assessment to pass incorrectly for projects
with no proof data at all.

**Impact:** False-positive compliance pass for unproven projects.

**Fix:** `Parse_Prove_Out` now sets `Success := Summary.Total_VCs > 0`,
matching the existing guard in `Parse_Prove_JSON`. `Determine_SPARK_Level`
remains a pure function.

### H3: `I2S` dropping most significant digit for 10-digit numbers

`while R > 0 and Pos > 1` in `adacovex-renderers-svg.adb` exited when
`Pos = 1` even if `R` still held a digit. Numbers >= 1,000,000,000 (the
upper half of `Natural`'s domain) would lose their leading digit.

**Impact:** Incorrect SVG badge width or test-count output for very large
values (practically unlikely but technically incorrect).

**Fix:** Removed `and Pos > 1` condition; loop now exits when `R = 0`.
Return slice adjusted from `Buf (Pos + 1 .. 10)` to `Buf (Pos .. 10)`.

### M1: Unsynchronized `Running` flag across server tasks

The `Running` field in `Server_State` was read/written by 5 tasks (1 main
+ 4 workers) without synchronization. On weakly-ordered architectures,
writes may never become visible to other tasks.

**Impact:** If a worker hit 100 consecutive socket errors and set
`Running := False`, other workers and the main loop could hang indefinitely.

**Fix:** Extracted `Running` from the `Server_State` record to a local
`Boolean with Atomic` variable in `Start`, ensuring proper visibility
across tasks.

### M2: `Read_Request_Line` buffer overread on long request lines

When 4096 bytes filled the buffer without a CRLF terminator, the last
two received bytes were silently discarded. The returned string could
contain trailing undefined buffer content.

**Impact:** Malformed path extraction for request URIs >= 4094 bytes.

**Fix:** Added `or else Last >= Buffer'Length` guard, returning `""` on
buffer-full without CRLF to signal a malformed request.

### M4: `Start_Search` / `End_Search` unprotected against exceptions

`Ada.Directories.Search_Type` handles could leak if `Get_Next_Entry`
raised (e.g., on corrupted directory entries).

**Impact:** OS resource leak (directory handle) during source traversal.

**Fix:** Wrapped `Start_Search` .. `End_Search` in a `begin exception
when others => End_Search (Search); raise; end;` block.

### L1: `Natural'Image` leading spaces in user-facing output

`Natural'Image` and `Integer'Image` in Ada prepend a space for non-negative
values, producing ugly output like `"  found  19 packages"` and `<td> 19</td>`.

**Impact:** Cosmetic — extra whitespace in terminal reports and HTML dashboard.

**Fix:** Added local `Img(Natural)` helper that strips the leading space.
Applied to `adacovex_main.adb` (terminal output) and
`adacovex-renderers-html.adb` (dashboard HTML).

### L2: `HLR-` false match inside larger words

`Has_HLR_Tag` matched "HLR-" anywhere in a comment, including inside
larger words like `SUBHLR-SCAN`, producing false HLR tag detections.

**Impact:** False positive HLR traceability, potentially masking missing
requirements.

**Fix:** Added word-boundary check: skip `H` if preceded by an uppercase
letter.

### L5: Removed dead code `Parse_Test_Stdout`

The stub procedure `Parse_Test_Stdout` in `adacovex-parsers-tests` was
never called and served no purpose.

**Impact:** Dead code surface area.

**Fix:** Removed the specification and implementation.

### L8: `Close(F)` not inside exception protection after read loop

In `Scan_Ads_File`, `Flush_Pending` and `Close(F)` were outside the
exception-protected block. If `Flush_Pending` somehow raised, the file
handle would leak.

**Fix:** Moved `Flush_Pending` and `Close(F)` inside the `begin ...
exception ... end` block that protects the read loop.

## Proof Results

Self-assessment: **Platinum** (28/28 VCs proved, AoRTE-free).
Ada_CRDT (strict): **Platinum** (273 VCs, 5 justified overflow checks).
