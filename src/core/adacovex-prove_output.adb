with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Adacovex.Ansi;
with Adacovex.Cache;

package body Adacovex.Prove_Output is

   use Ada.Strings.Fixed;

   --  First non-blank character of S (' ' when S is blank).
   function Head (S : String) return Character is
   begin
      for I in S'Range loop
         if S (I) not in ' ' | ASCII.HT then
            return S (I);
         end if;
      end loop;
      return ' ';
   end Head;

   --  True when S (trimmed) starts with Prefix.
   function Starts (S : String; Prefix : String) return Boolean is
      T : constant String := Trim (S, Ada.Strings.Both);
   begin
      return
        T'Length >= Prefix'Length
        and then T (T'First .. T'First + Prefix'Length - 1) = Prefix;
   end Starts;

   --  True when L names an error in any of the shapes gnatprove prints.
   --  Used only to pick a colour.
   function Is_Error_Line (L : String) return Boolean is
      T : constant String := Trim (L, Ada.Strings.Both);
   begin
      return
        Starts (T, "error:")
        or else Starts (T, "gnatprove: error")
        or else Index (L, ": error:") > 0;
   end Is_Error_Line;

   --  True when L names a warning in the same three shapes.
   function Is_Warning_Line (L : String) return Boolean is
      T : constant String := Trim (L, Ada.Strings.Both);
   begin
      return
        Starts (T, "warning:")
        or else Starts (T, "gnatprove: warning")
        or else Index (L, ": warning:") > 0;
   end Is_Warning_Line;

   --  True when the run is inside GitHub Actions, where a finding should
   --  also appear as an inline annotation on the pull request.
   --  A fix hint derived from a check kind: what a developer most often
   --  changes to make that class of check provable. It never claims the
   --  finding is fixed; it names the contract shape the check needs.
   --  @param Kind  Check kind, as Collect_Failures derived it.
   --  @return One-line guidance for that kind of check.
   function Fix_Hint (Kind : String) return String is
   begin
      if Index (Kind, "divide") > 0 or else Index (Kind, "division") > 0 then
         return
           "state the divisor is non-zero as a precondition, so the"
           & " division check follows";
      elsif Index (Kind, "range") > 0
        or else Index (Kind, "index") > 0
        or else Index (Kind, "overflow") > 0
        or else Index (Kind, "division") > 0
        or else Index (Kind, "discriminant") > 0
      then
         return
           "state the bound as a subtype constraint or a precondition, so"
           & " the check follows from the contracts";
      elsif Index (Kind, "precondition") > 0 then
         return
           "establish the caller's precondition at the call site, or relax"
           & " it to what the body needs";
      elsif Index (Kind, "postcondition") > 0
        or else Index (Kind, "contract") > 0
      then
         return
           "add the missing fact to the loop invariant or the postcondition"
           & " it derives from";
      elsif Index (Kind, "assert") > 0 then
         return
           "add the assertion's fact as a loop invariant, or state it where"
           & " the body makes it true";
      elsif Index (Kind, "invariant") > 0 then
         return
           "move the fact into the loop invariant, where the loop preserves"
           & " it";
      elsif Index (Kind, "termination") > 0 then
         return "add a Loop_Variant that decreases on every iteration";
      elsif Index (Kind, "initializ") > 0 then
         return
           "initialise the object before its first read, and declare its"
           & " Global aspect";
      else
         return
           "add the precondition, loop invariant, or postcondition that"
           & " establishes the check (--verbose shows the raw prover lines)";
      end if;
   end Fix_Hint;

   procedure Collect_Failures (Path : String; Stats : out Failure_Stats) is
      use Ada.Strings.Unbounded;
      use Ada.Text_IO;

      F : File_Type;

      --  The distinct findings already recorded, keyed by `location|kind` and
      --  preceded by a line feed so a match is a whole-key match. A repeated
      --  finding is not counted again. The blob is bounded: past the cap the
      --  pass stops remembering, so a later repeat is kept (the count can be
      --  larger, never wrong).
      Max_Seen_Chars : constant := 1_000_000;
      Seen           : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String (String'(1 => ASCII.LF));

      --  The finding being read. gnatprove starts a message block with the
      --  message and its severity, names the location on a `-->` line, and
      --  continues with the code excerpt, the caret ruler, and the `+`
      --  sub-messages. The block stays open until the next one starts, so a
      --  `+` line that says the provers gave up can still attach to it.
      Have_Cand   : Boolean := False;
      Cand_Kind   : Unbounded_String := Null_Unbounded_String;
      Cand_Loc    : Unbounded_String := Null_Unbounded_String;
      Cand_Flow   : Boolean := False;
      Cand_Budget : Boolean := False;

      --  True when S starts with Prefix.
      function Starts (S : String; Prefix : String) return Boolean is
      begin
         return
           S'Length >= Prefix'Length
           and then S (S'First .. S'First + Prefix'Length - 1) = Prefix;
      end Starts;

      --  Index of the ':' that ends a `file:line:column` prefix in L, or 0
      --  when L does not carry one. The scan tries every colon, so a path
      --  that itself holds digits and colons is still handled from the
      --  left-most shape that is followed by a line and a column number.
      function Location_End (L : String) return Natural is
      begin
         for C in L'First .. L'Last loop
            if L (C) = ':' then
               declare
                  Ln : Natural := C + 1;
                  Cl : Natural;
               begin
                  while Ln <= L'Last and then L (Ln) in '0' .. '9' loop
                     Ln := Ln + 1;
                  end loop;
                  if Ln > C + 1 and then Ln <= L'Last and then L (Ln) = ':'
                  then
                     Cl := Ln + 1;
                     while Cl <= L'Last and then L (Cl) in '0' .. '9' loop
                        Cl := Cl + 1;
                     end loop;
                     if Cl > Ln + 1 and then Cl <= L'Last and then L (Cl) = ':'
                     then
                        return Cl;
                     end if;
                  end if;
               end;
            end if;
         end loop;
         return 0;
      end Location_End;

      --  M with gnatprove's optional severity word (`low:`, `medium: `,
      --  `high:`, `info:`, `warning:`, `error:`) removed and both ends
      --  trimmed.
      function Without_Severity (M : String) return String is
         Levels : constant array (1 .. 6) of String (1 .. 8) :=
           ("low:    ",
            "medium: ",
            "high:   ",
            "info:   ",
            "warning:",
            "error:  ");
         Lens   : constant array (1 .. 6) of Natural := (4, 7, 5, 5, 8, 6);
         T      : constant String := Trim (M, Ada.Strings.Both);
      begin
         for K in Levels'Range loop
            if Starts (T, Levels (K) (1 .. Lens (K))) then
               if T'Length = Lens (K) then
                  return "";
               end if;
               return
                 Trim (T (T'First + Lens (K) .. T'Last), Ada.Strings.Both);
            end if;
         end loop;
         return T;
      end Without_Severity;

      --  The text of Msg before the first Marker, trimmed.
      function Before (Msg : String; Marker : String) return String is
         P : constant Natural := Index (Msg, Marker);
      begin
         if P = 0 then
            return Trim (Msg, Ada.Strings.Both);
         elsif P = Msg'First then
            return "";
         else
            return Trim (Msg (Msg'First .. P - 1), Ada.Strings.Both);
         end if;
      end Before;

      --  The check kind when Msg reports an unproved check or a flow
      --  finding, and "" when it reports something else. Flow is set for an
      --  object that is read before its first write.
      function Failure_Kind (Msg : String; Flow : out Boolean) return String is
         M : constant String := Without_Severity (Msg);
      begin
         Flow := False;
         if Index (M, "might fail") > 0 then
            return Before (M, "might fail");
         elsif Index (M, "cannot be proved") > 0 then
            return Before (M, "cannot be proved");
         elsif Index (M, "cannot prove") > 0 then
            return Before (M, "cannot prove");
         elsif Index (M, "not initialized") > 0
           or else Index (M, "uninitialized") > 0
         then
            Flow := True;
            return "initialization";
         end if;
         return "";
      end Failure_Kind;

      --  True when a finding with this location and kind is already recorded,
      --  recording it when it is new. The compare and the store use the same
      --  `location|kind` key, so a repeated finding is recognised exactly.
      --  @param Loc  Source location of the finding (may be empty).
      --  @param Kind  Check kind of the finding.
      --  @return True when the same location and kind were recorded earlier.
      function Already_Seen (Loc : String; Kind : String) return Boolean is
         Key : constant String := ASCII.LF & Loc & "|" & Kind;
      begin
         if Ada.Strings.Unbounded.Index (Seen, Key) > 0 then
            return True;
         elsif Ada.Strings.Unbounded.Length (Seen) < Max_Seen_Chars then
            Ada.Strings.Unbounded.Append (Seen, Key);
         end if;
         return False;
      end Already_Seen;

      --  Record the open finding, if there is one, and close the block. A
      --  finding whose location and kind are already recorded is dropped, so
      --  one check reported per inlined call site counts once.
      procedure Finalize is
         Loc  : constant String := To_String (Cand_Loc);
         Kind : constant String :=
           (if Length (Cand_Kind) = 0
            then "unproved check"
            else To_String (Cand_Kind));
      begin
         if Have_Cand and then not Already_Seen (Loc, Kind) then
            Stats.Unproved := Stats.Unproved + 1;
            if Stats.Count < Max_Failure_Items then
               Stats.Count := Stats.Count + 1;
               Stats.Items (Stats.Count) :=
                 (Location => Cand_Loc,
                  Kind     => To_Unbounded_String (Kind),
                  Flow     => Cand_Flow,
                  Budget   => Cand_Budget);
            end if;
         end if;
         Have_Cand := False;
         Cand_Kind := Null_Unbounded_String;
         Cand_Loc := Null_Unbounded_String;
         Cand_Flow := False;
         Cand_Budget := False;
      end Finalize;

      --  Start a finding from a line that carries both its location and its
      --  message (the single-line shape gnatprove uses for flow findings).
      procedure Add_Line (Loc : String; Msg : String) is
         Flow : Boolean;
         Kind : constant String := Failure_Kind (Msg, Flow);
      begin
         if Kind'Length > 0 then
            Finalize;
            Have_Cand := True;
            Cand_Kind := To_Unbounded_String (Kind);
            Cand_Loc := To_Unbounded_String (Loc);
            Cand_Flow := Flow;
            Cand_Budget := False;
         end if;
      end Add_Line;
   begin
      Stats :=
        (Unproved => 0,
         Count    => 0,
         Items    =>
           (others =>
              (Location => Null_Unbounded_String,
               Kind     => Null_Unbounded_String,
               Flow     => False,
               Budget   => False)));
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            L : constant String := Get_Line (F);
            T : constant String := Trim (L, Ada.Strings.Both);
         begin
            if T'Length = 0 then
               Finalize;
            elsif Starts (T, "-->") then
               --  The location line of the open block.
               if Have_Cand and then Length (Cand_Loc) = 0 then
                  if T'Length > 3 then
                     declare
                        Sp      : constant String :=
                          Trim (T (T'First + 3 .. T'Last), Ada.Strings.Both);
                        End_Pos : constant Natural := Location_End (Sp);
                     begin
                        if End_Pos > 0 then
                           Cand_Loc :=
                             To_Unbounded_String
                               (Sp (Sp'First .. End_Pos - 1));
                        else
                           Cand_Loc := To_Unbounded_String (Sp);
                        end if;
                     end;
                  end if;
               end if;
            elsif T (T'First) in 'A' .. 'Z' | 'a' .. 'z' then
               --  A line that starts with a letter opens a message block or
               --  carries unrelated output such as the run summary.
               declare
                  Loc_End : constant Natural := Location_End (L);
               begin
                  if Loc_End > 0 and then Loc_End < L'Last then
                     Add_Line
                       (L (L'First .. Loc_End - 1), L (Loc_End + 1 .. L'Last));
                  else
                     Finalize;
                     declare
                        Flow : Boolean;
                        Kind : constant String := Failure_Kind (L, Flow);
                     begin
                        if Kind'Length > 0 then
                           Have_Cand := True;
                           Cand_Kind := To_Unbounded_String (Kind);
                           Cand_Loc := Null_Unbounded_String;
                           Cand_Flow := Flow;
                           Cand_Budget := False;
                        end if;
                     end;
                  end if;
               end;
            else
               --  A continuation of the open block: the code excerpt, the
               --  caret ruler, or a `+` sub-message. A sub-message that says
               --  the provers gave up states the reason: the proof ran out
               --  of budget, so no counterexample was found either.
               if Have_Cand
                 and then Starts (T, "+")
                 and then Index (T, "gave up") > 0
               then
                  Cand_Budget := True;
               end if;
            end if;
         end;
      end loop;
      Finalize;
      Close (F);
   end Collect_Failures;

   function Diagnostics_Text
     (Prover : String; Stats : Failure_Stats) return String
   is
      use Ada.Strings.Unbounded;

      R : Unbounded_String := Null_Unbounded_String;
   begin
      if Stats.Unproved = 0 then
         return "";
      end if;
      Append
        (R,
         "  proof:     "
         & Natural'Image (Stats.Unproved)
         & " unproved check(s)");
      if Prover'Length > 0 then
         Append (R, " (prover " & Prover & ")");
      end if;
      Append (R, ASCII.LF);
      for I in 1 .. Stats.Count loop
         Append
           (R,
            "    "
            & To_String (Stats.Items (I).Location)
            & "  "
            & To_String (Stats.Items (I).Kind)
            & (if Stats.Items (I).Budget
               then " (provers gave up)"
               elsif Stats.Items (I).Flow
               then " (flow analysis)"
               else "")
            & ASCII.LF);
      end loop;
      if Stats.Unproved > Stats.Count then
         Append
           (R,
            "    ... "
            & Natural'Image (Stats.Unproved - Stats.Count)
            & " more (--verbose lists every check)"
            & ASCII.LF);
      end if;
      if Stats.Items (1).Budget then
         --  The provers did not find a counterexample, so the first thing to
         --  raise is the budget, not the contract.
         Append
           (R,
            "  fix:       the provers gave up before completing the proof;"
            & " raise the proof budget with --steps=<N> (10000 by default)"
            & ASCII.LF);
      else
         Append
           (R,
            "  fix:       "
            & Fix_Hint (To_String (Stats.Items (1).Kind))
            & ASCII.LF);
      end if;
      return To_String (R);
   end Diagnostics_Text;

   --  True when the run is inside GitHub Actions, where a finding should
   --  also appear as an inline annotation on the pull request.
   function In_GitHub_Actions return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("GITHUB_ACTIONS");
   end In_GitHub_Actions;

   --  Build the GitHub Actions workflow command for one unproved finding:
   --  `::error file=...,line=...,col=...,title=SPARK proof failed::<kind>`.
   --  The location gnatprove prints is `file:line:column`, so the two
   --  trailing colon-separated fields are split off; a location without a
   --  column still yields an annotation, and anything else returns "" so a
   --  malformed line is never emitted as an empty file annotation.
   --  @param Location  Source location as Collect_Failures recorded it.
   --  @param Kind  Check kind (the message before "might fail").
   --  @return The workflow command, or "" when the location cannot be split.
   function Annotation_Line (Location : String; Kind : String) return String is
      use Ada.Strings.Unbounded;
      L : constant String := Trim (Location, Ada.Strings.Both);

      --  True when S is a non-empty run of decimal digits.
      function All_Digits (S : String) return Boolean is
      begin
         if S'Length = 0 then
            return False;
         end if;
         for I in S'Range loop
            if S (I) not in '0' .. '9' then
               return False;
            end if;
         end loop;
         return True;
      end All_Digits;

      Col_Colon  : Natural := 0;
      Line_Colon : Natural := 0;
      R          : Unbounded_String := Null_Unbounded_String;
   begin
      if L'Length = 0 or else Kind'Length = 0 then
         return "";
      end if;
      --  Rightmost shape: file:line:column.
      for I in reverse L'Range loop
         if L (I) = ':' and then I < L'Last then
            if Col_Colon = 0 and then All_Digits (L (I + 1 .. L'Last)) then
               Col_Colon := I;
            elsif Col_Colon > 0
              and then I + 1 <= Col_Colon - 1
              and then All_Digits (L (I + 1 .. Col_Colon - 1))
            then
               Line_Colon := I;
               exit;
            end if;
         end if;
      end loop;
      if Line_Colon = 0 then
         --  file:line without a column.
         for I in reverse L'Range loop
            if L (I) = ':'
              and then I < L'Last
              and then All_Digits (L (I + 1 .. L'Last))
              and then I > L'First
            then
               Line_Colon := I;
               exit;
            end if;
         end loop;
      end if;
      if Line_Colon = 0 or else Line_Colon = L'First then
         return "";
      end if;
      --  One colon only (a Windows drive letter or a bare file:line): the
      --  rightmost field is the line, not a column.
      if Col_Colon <= Line_Colon then
         Col_Colon := 0;
      end if;
      Append (R, "::error file=" & L (L'First .. Line_Colon - 1));
      Append
        (R,
         ",line="
         & L
             (Line_Colon
              + 1
              .. (if Col_Colon > 0 then Col_Colon - 1 else L'Last)));
      if Col_Colon > 0 then
         Append (R, ",col=" & L (Col_Colon + 1 .. L'Last));
      end if;
      Append (R, ",title=SPARK proof failed::" & Kind);
      return To_String (R);
   end Annotation_Line;

   --  Emit one annotation per distinct finding when running in GitHub
   --  Actions. A local run prints nothing here, so the diagnostics block
   --  stays the only failure detail.
   --  @param Stats  Findings gathered by Collect_Failures.
   procedure Emit_Annotations (Stats : Failure_Stats) is
      use Ada.Strings.Unbounded;
   begin
      if not In_GitHub_Actions then
         return;
      end if;
      for I in 1 .. Stats.Count loop
         declare
            L : constant String :=
              Annotation_Line
                (To_String (Stats.Items (I).Location),
                 To_String (Stats.Items (I).Kind));
         begin
            if L'Length > 0 then
               Ada.Text_IO.Put_Line (L);
            end if;
         end;
      end loop;
   end Emit_Annotations;

   --  Print one replay line with its severity colour.
   --  @param L  One line of the cached or fresh replay.
   procedure Print_Replay_Line (L : String) is
      T : constant String := Trim (L, Ada.Strings.Both);
   begin
      if Is_Error_Line (L) then
         Ada.Text_IO.Put_Line (Adacovex.Ansi.Red (L));
      elsif Is_Warning_Line (L) then
         Ada.Text_IO.Put_Line (Adacovex.Ansi.Yellow (L));
      elsif Starts (T, "Success:") then
         Ada.Text_IO.Put_Line (Adacovex.Ansi.Green (L));
      elsif Starts (T, "info:")
        or else Starts (T, "-->")
        or else Head (L) = '+'
      then
         Ada.Text_IO.Put_Line (Adacovex.Ansi.Dim (L));
      elsif Starts (T, "coverage:")
        or else Starts (T, "cache:")
        or else Starts (T, "proof:")
        or else Starts (T, "filtered:")
        or else Starts (T, "duplicates:")
      then
         Ada.Text_IO.Put_Line (Adacovex.Ansi.Bold (L));
      else
         Ada.Text_IO.Put_Line (L);
      end if;
   end Print_Replay_Line;

   procedure Print_Replay_Blob (S : String) is
      Start : Positive := S'First;
   begin
      if S'Length = 0 then
         return;
      end if;
      for I in S'Range loop
         if S (I) = ASCII.LF then
            Print_Replay_Line (S (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      if Start <= S'Last then
         Print_Replay_Line (S (Start .. S'Last));
      end if;
   end Print_Replay_Blob;

   procedure Print_Replay_File (Path : String) is
      F : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (F) loop
         Print_Replay_Line (Ada.Text_IO.Get_Line (F));
      end loop;
      Ada.Text_IO.Close (F);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
   end Print_Replay_File;

   procedure Append_Text (Path : String; Text : String) is
      F : Ada.Text_IO.File_Type;
   begin
      if Text'Length = 0 then
         return;
      end if;
      Ada.Text_IO.Open (F, Ada.Text_IO.Append_File, Path);
      Ada.Text_IO.Put (F, Text);
      Ada.Text_IO.New_Line (F);
      Ada.Text_IO.Close (F);
   end Append_Text;

   procedure Cache_Replay (Key : String; Path : String) is
      Buf     : String (1 .. Adacovex.Cache.Max_Cache_Blob);
      Len     : Natural := 0;
      OK      : Boolean;
      Too_Big : Boolean := False;
      F       : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (F) and then not Too_Big loop
         declare
            L : constant String := Ada.Text_IO.Get_Line (F);
         begin
            --  Keep one line feed after every line but the last, so the
            --  cached text is byte-identical to the file.
            if Len + L'Length + 1 <= Buf'Length then
               for I in L'Range loop
                  Len := Len + 1;
                  Buf (Len) := L (I);
               end loop;
               if not Ada.Text_IO.End_Of_File (F) then
                  Len := Len + 1;
                  Buf (Len) := ASCII.LF;
               end if;
            else
               Too_Big := True;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (F);
      if not Too_Big and then Len > 0 then
         Adacovex.Cache.Store (Key, Buf (1 .. Len), OK);
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
   end Cache_Replay;

   procedure Print_Cached_Replay (Key : String) is
      Buf   : String (1 .. Adacovex.Cache.Max_Cache_Blob);
      Len   : Natural := 0;
      Found : Boolean := False;
   begin
      Adacovex.Cache.Get_Cached (Key, Buf, Len, Found);
      if Found and then Len > 0 then
         Print_Replay_Blob (Buf (1 .. Len));
      end if;
   end Print_Cached_Replay;

end Adacovex.Prove_Output;
