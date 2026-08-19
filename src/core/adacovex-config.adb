with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;

package body Adacovex.Config is

   use type Types.SBOM_Format_Kind;

   function Has_Prefix (S : String; Prefix : String) return Boolean
   with SPARK_Mode => On,
        Post       =>
          Has_Prefix'Result =
            (S'Length >= Prefix'Length
             and then (for all I in Prefix'Range =>
                         S (S'First + (I - Prefix'First)) = Prefix (I))),
        Global     => null
   is
   begin
      if S'Length < Prefix'Length then
         return False;
      end if;
      for I in Prefix'Range loop
         pragma Loop_Invariant
           (for all J in Prefix'First .. I - 1 =>
              S (S'First + (J - Prefix'First)) = Prefix (J));
         if S (S'First + (I - Prefix'First)) /= Prefix (I) then
            return False;
         end if;
      end loop;
      return True;
   end Has_Prefix;

   --  True when S looks like a help-topic token: a --flag or a bare
   --  word (letters/hyphens only).  Used by the `help` keyword to decide
   --  whether the neighboring argument names the topic (help --serve,
   --  help serve, --serve help).  Unknown words are still accepted and
   --  Print_Topic_Help reports them as unknown rather than crashing.
   function Is_Help_Topic (S : String) return Boolean
   with SPARK_Mode => On,
        Post       =>
          Is_Help_Topic'Result =
            (S'Length > 0
             and then
               (S (S'First) = '-'
                or else (for all I in S'Range =>
                           S (I) in 'a' .. 'z' | 'A' .. 'Z' | '-'))),
        Global     => null
   is
   begin
      if S'Length = 0 then
         return False;
      end if;
      if S (S'First) = '-' then
         return True;
      end if;
      for I in S'Range loop
         pragma Loop_Invariant
           (for all J in S'First .. I - 1 =>
              S (J) in 'a' .. 'z' | 'A' .. 'Z' | '-');
         if S (I) in 'a' .. 'z' | 'A' .. 'Z' | '-' then
            null;
         else
            return False;
         end if;
      end loop;
      return True;
   end Is_Help_Topic;

   --  Case-insensitive test for the literal "all" (the --standard=all value).
   --  The upper-cased-buffer comparison collapses to three exact
   --  case-insensitive character tests, so the postcondition characterizes
   --  the result directly -- no quantified Post over the uppercased buffer
   --  is needed (the forms that were attempted blew the prover's step
   --  budget; see the 1.15.0 changelog).
   function Is_All (S : String) return Boolean
   with SPARK_Mode => On,
        Post       =>
          Is_All'Result =
            (S'Length = 3
             and then S (S'First) in 'a' | 'A'
             and then S (S'First + 1) in 'l' | 'L'
             and then S (S'First + 2) in 'l' | 'L'),
        Global     => null
   is
   begin
      return S'Length = 3
        and then S (S'First) in 'a' | 'A'
        and then S (S'First + 1) in 'l' | 'L'
        and then S (S'First + 2) in 'l' | 'L';
   end Is_All;

   procedure Set_String (Dst : out String; Dst_Len : out Natural; Src : String)
   is
   begin
      --  Clamp to the fixed destination buffer so an overlong CLI argument
      --  never raises Constraint_Error; Dst_Len reflects the clamped length.
      Dst_Len := Natural'Min (Src'Length, Dst'Length);
      for J in Src'First .. Src'First + Dst_Len - 1 loop
         Dst (J - Src'First + 1) := Src (J);
      end loop;
   end Set_String;

   procedure Add_Skip_Dir (Cfg : in out CLI_Config; Name : String) is
   begin
      if Cfg.Skip_Dir_Ct > 0 then
         if Cfg.Skip_Dir_Ct < Types.Max_Filename then
            Cfg.Skip_Dir_Ct := Cfg.Skip_Dir_Ct + 1;
            Cfg.Skip_Dirs (Cfg.Skip_Dir_Ct) := ',';
         end if;
      end if;
      if Cfg.Skip_Dir_Ct < Types.Max_Filename then
         for I in Name'Range loop
            exit when Cfg.Skip_Dir_Ct >= Types.Max_Filename;
            Cfg.Skip_Dir_Ct := Cfg.Skip_Dir_Ct + 1;
            Cfg.Skip_Dirs (Cfg.Skip_Dir_Ct) := Name (I);
         end loop;
      end if;
   end Add_Skip_Dir;

   procedure Set_Error (Cfg : in out CLI_Config; Msg : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "Error: " & Msg);
      Cfg.CLI_Error := True;
   end Set_Error;

   --  Parse a SPARK level name into a Types.SPARK_Level.  Accepts the exact
   --  names returned by Types.To_String (case matters) or ignores case for
   --  convenience.  Sets Valid False and Result to Stone on parse failure.
   procedure To_SPARK_Level
     (S : String; Result : out Types.SPARK_Level; Valid : out Boolean)
   is
      Up : String (1 .. S'Length);
   begin
      for I in S'Range loop
         if S (I) in 'a' .. 'z' then
            Up (I - S'First + 1) := Character'Val (Character'Pos (S (I)) - 32);
         else
            Up (I - S'First + 1) := S (I);
         end if;
      end loop;
      Valid := True;
      if Up = "STONE" then
         Result := Types.Stone;
      elsif Up = "BRONZE" then
         Result := Types.Bronze;
      elsif Up = "SILVER" then
         Result := Types.Silver;
      elsif Up = "GOLD" then
         Result := Types.Gold;
      elsif Up = "PLATINUM" then
         Result := Types.Platinum;
      else
         Result := Types.Stone;
         Valid := False;
      end if;
   end To_SPARK_Level;

   function Is_Valid_DAL (S : String) return Boolean
   with SPARK_Mode => On,
        Post       =>
          Is_Valid_DAL'Result =
            (S'Length = 1 and then S (S'First) in 'A' .. 'E' | 'a' .. 'e'),
        Global     => null
   is
   begin
      return S'Length = 1 and then (S (S'First) in 'A' .. 'E' | 'a' .. 'e');
   end Is_Valid_DAL;

   --  Parse an integer prove option into a config field, validating its
   --  range.  On a bad value or out-of-range value the config is flagged as
   --  an error and Field is left untouched.
   procedure Set_Prove_Int
     (Cfg   : in out CLI_Config;
      Field : out Integer;
      Val   : String;
      Min   : Integer;
      Max   : Integer;
      Flag  : String) is
   begin
      begin
         Field := Integer'Value (Val);
      exception
         when Constraint_Error =>
            Set_Error (Cfg, Flag & " must be an integer (got: " & Val & ")");
            return;
      end;
      if Field < Min or Field > Max then
         Set_Error
           (Cfg,
            Flag
            & " must be in"
            & Integer'Image (Min)
            & ".."
            & Integer'Image (Max)
            & " (got: "
            & Val
            & ")");
      end if;
   end Set_Prove_Int;

   --  Known CLI flags (without leading dashes), space-separated, used for
   --  the "did you mean" suggestion when the user typos a flag name.  Kept
   --  in sync with the Parse_Args branches below.
   Known_Flags : constant String :=
     "target manifest dal asil class standard serve theme port "
     & "emit-svg no-svg emit-markdown verbose relaxed cache no-cache "
     & "cache-dir cache-max skip-dir compare-base coverage-delta sbom "
     & "prove status man check dir version no-sbom sbom-format format out "
     & "jobs level timeout steps memlimit force no-loop-unrolling "
     & "no-inlining require-spark require-docstrings require-tests "
     & "require-proof help";

   --  Levenshtein edit distance between two strings, capped at 9 so the
   --  suggestion scan stays cheap (anything farther away is "not similar").
   function Edit_Distance (A, B : String) return Natural is
      subtype Row_Idx is Natural range 0 .. 64;
      type Row_Arr is array (Row_Idx) of Natural;
      ALen : constant Natural := A'Length;
      BLen : constant Natural := B'Length;
      Row  : Row_Arr := (others => 0);
      Prev : Row_Arr := (others => 0);
   begin
      if ALen > 64 or BLen > 64 then
         return 99;
      end if;
      for J in 0 .. BLen loop
         Row (J) := J;
      end loop;
      for I in 1 .. ALen loop
         Prev := Row;
         Row (0) := I;
         for J in 1 .. BLen loop
            if A (A'First + I - 1) = B (B'First + J - 1) then
               Row (J) := Prev (J - 1);
            else
               Row (J) :=
                 Natural'Min
                   (Natural'Min (Prev (J) + 1, Row (J - 1) + 1),
                    Prev (J - 1) + 1);
            end if;
            exit when Row (J) > 9 and J = BLen;
         end loop;
      end loop;
      return Natural'Min (Row (BLen), 99);
   end Edit_Distance;

   --  Normalize an unknown argument into a comparable flag name: strip a
   --  leading "--", drop any "=value" suffix, lowercase it.
   procedure Normalize_Flag
     (S : String; Out_Buf : out String; Out_Len : out Natural)
   is
      First : Natural := S'First;
   begin
      Out_Len := 0;
      if First <= S'Last and then S (First) = '-' then
         First := First + 1;
         if First <= S'Last and then S (First) = '-' then
            First := First + 1;
         end if;
      end if;
      while First <= S'Last loop
         exit when S (First) = '=';
         if S (First) in 'A' .. 'Z' then
            if Out_Len < Out_Buf'Last then
               Out_Len := Out_Len + 1;
               Out_Buf (Out_Len) :=
                 Character'Val (Character'Pos (S (First)) + 32);
            end if;
         else
            if Out_Len < Out_Buf'Last then
               Out_Len := Out_Len + 1;
               Out_Buf (Out_Len) := S (First);
            end if;
         end if;
         First := First + 1;
      end loop;
   end Normalize_Flag;

   --  Return " (did you mean --xxx?)" (or " --xxx or --yyy") for an
   --  unknown token, or "" when no known flag is close enough.  The caller
   --  appends this to the "unknown option/argument" error message.
   function Suggest_Flags (S : String) return String is
      Buf     : String (1 .. 128) := (others => ' ');
      Len     : Natural := 0;
      NFlag   : String (1 .. 64) := (others => ' ');
      NLen    : Natural := 0;
      Matches : array (1 .. 3) of String (1 .. 32) :=
        (others => (others => ' '));
      MLen    : array (1 .. 3) of Natural := (others => 0);
      MCt     : Natural := 0;
      Best    : Natural := 99;
      Start   : Natural := Known_Flags'First;
      Fin     : Natural;
   begin
      Normalize_Flag (S, NFlag, NLen);
      if NLen = 0 then
         return "";
      end if;
      --  Walk the space-separated Known_Flags list.
      while Start <= Known_Flags'Last loop
         Fin := Start;
         while Fin <= Known_Flags'Last and then Known_Flags (Fin) /= ' ' loop
            Fin := Fin + 1;
         end loop;
         declare
            D : constant Natural :=
              Edit_Distance
                (NFlag (1 .. NLen), Known_Flags (Start .. Fin - 1));
         begin
            if D <= 2 and then D <= Best then
               if D < Best then
                  MCt := 0;
                  Best := D;
               end if;
               if MCt < 3 then
                  MCt := MCt + 1;
                  MLen (MCt) := Fin - Start;
                  Matches (MCt) (1 .. MLen (MCt)) :=
                    Known_Flags (Start .. Fin - 1);
               end if;
            end if;
         end;
         exit when Fin > Known_Flags'Last;
         Start := Fin + 1;
      end loop;
      if MCt = 0 then
         return "";
      end if;
      --  " (did you mean --standard?)" or " (did you mean --jobs or --job?)"
      if Len < Buf'Last then
         Len := Len + 1;
         Buf (Len) := ' ';
      end if;
      if Len + 13 <= Buf'Last then
         Buf (Len + 1 .. Len + 13) := "(did you mean";
         Len := Len + 13;
      end if;
      for I in 1 .. MCt loop
         if Len < Buf'Last then
            Len := Len + 1;
            Buf (Len) := ' ';
         end if;
         if I > 1 and then Len < Buf'Last then
            Buf (Len + 1 .. Len + 3) := "or ";
            Len := Len + 3;
         end if;
         if Len + 2 + MLen (I) <= Buf'Last then
            Buf (Len + 1 .. Len + 2) := "--";
            Len := Len + 2;
            Buf (Len + 1 .. Len + MLen (I)) := Matches (I) (1 .. MLen (I));
            Len := Len + MLen (I);
         end if;
      end loop;
      if Len < Buf'Last then
         Len := Len + 1;
         Buf (Len) := '?';
      end if;
      return Buf (1 .. Len);
   end Suggest_Flags;

   package body Testing is

      procedure Parse_Args (Args : Arg_Vectors.Vector; Cfg : in out CLI_Config)
      is
         Count : constant Natural := Natural (Args.Length);
         I     : Positive := 1;
      begin
         Cfg.Target_Len := 0;
         Cfg.Manifest_Len := 0;
         Cfg.SVG_Path_Len := 0;
         Cfg.MD_Path_Len := 0;
         Cfg.Skip_Dir_Ct := 0;
         Cfg.Compare_Base_Len := 0;
         Cfg.Coverage_Delta_Len := 0;
         Cfg.SBOM_Out_Len := 0;
         Cfg.Cache_Dir_Len := 0;
         Cfg.Man_Dir_Len := 0;

         while I <= Count loop
            declare
               A : constant String := Args (I);
            begin
               if A = "--target" then
                  I := I + 1;
                  if I <= Count then
                     Set_String (Cfg.Target_Path, Cfg.Target_Len, Args (I));
                  else
                     Set_Error (Cfg, "--target requires a path argument");
                  end if;
               elsif Has_Prefix (A, "--target=") then
                  Set_String
                    (Cfg.Target_Path,
                     Cfg.Target_Len,
                     A (A'First + 9 .. A'Last));
               elsif A = "--manifest" then
                  I := I + 1;
                  if I <= Count then
                     Set_String
                       (Cfg.Manifest_Path, Cfg.Manifest_Len, Args (I));
                  else
                     Set_Error (Cfg, "--manifest requires a path argument");
                  end if;
               elsif Has_Prefix (A, "--manifest=") then
                  Set_String
                    (Cfg.Manifest_Path,
                     Cfg.Manifest_Len,
                     A (A'First + 11 .. A'Last));
               elsif A = "--dal" then
                  I := I + 1;
                  if I <= Count then
                     declare
                        Val : constant String := Args (I);
                     begin
                        if Is_Valid_DAL (Val) then
                           Cfg.DAL_Target := Types.To_DAL (Val);
                        else
                           Set_Error
                             (Cfg,
                              "--dal must be A, B, C, D, or E (got: "
                              & Val
                              & ")");
                        end if;
                     end;
                  else
                     Set_Error (Cfg, "--dal requires a level argument (A-E)");
                  end if;
               elsif Has_Prefix (A, "--dal=") then
                  declare
                     Val : constant String := A (A'First + 6 .. A'Last);
                  begin
                     if Is_Valid_DAL (Val) then
                        Cfg.DAL_Target := Types.To_DAL (Val);
                     else
                        Set_Error
                          (Cfg,
                           "--dal must be A, B, C, D, or E (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               elsif A = "--asil" then
                  I := I + 1;
                  if I <= Count then
                     declare
                        Val : constant String := Args (I);
                     begin
                        if Types.Is_Valid_ASIL (Val) then
                           Cfg.Standard_Target := Types.ISO_26262;
                           Cfg.DAL_Target := Types.To_ASIL (Val);
                           Cfg.Standard_All := False;
                           Cfg.Standard_Explicit := True;
                        else
                           Set_Error
                             (Cfg,
                              "--asil must be A, B, C, D, or QM (got: "
                              & Val
                              & ")");
                        end if;
                     end;
                  else
                     Set_Error
                       (Cfg, "--asil requires a level argument (A-D or QM)");
                  end if;
               elsif Has_Prefix (A, "--asil=") then
                  declare
                     Val : constant String := A (A'First + 7 .. A'Last);
                  begin
                     if Types.Is_Valid_ASIL (Val) then
                        Cfg.Standard_Target := Types.ISO_26262;
                        Cfg.DAL_Target := Types.To_ASIL (Val);
                        Cfg.Standard_All := False;
                        Cfg.Standard_Explicit := True;
                     else
                        Set_Error
                          (Cfg,
                           "--asil must be A, B, C, D, or QM (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               elsif A = "--class" then
                  I := I + 1;
                  if I <= Count then
                     declare
                        Val : constant String := Args (I);
                     begin
                        if Types.Is_Valid_Class (Val) then
                           Cfg.Standard_Target := Types.IEC_62304;
                           Cfg.DAL_Target := Types.To_Class (Val);
                           Cfg.Standard_All := False;
                           Cfg.Standard_Explicit := True;
                        else
                           Set_Error
                             (Cfg,
                              "--class must be A, B, or C (got: " & Val & ")");
                        end if;
                     end;
                  else
                     Set_Error
                       (Cfg, "--class requires a level argument (A-C)");
                  end if;
               elsif Has_Prefix (A, "--class=") then
                  declare
                     Val : constant String := A (A'First + 8 .. A'Last);
                  begin
                     if Types.Is_Valid_Class (Val) then
                        Cfg.Standard_Target := Types.IEC_62304;
                        Cfg.DAL_Target := Types.To_Class (Val);
                        Cfg.Standard_All := False;
                        Cfg.Standard_Explicit := True;
                     else
                        Set_Error
                          (Cfg,
                           "--class must be A, B, or C (got: " & Val & ")");
                     end if;
                  end;
               elsif A = "--standard" then
                  I := I + 1;
                  if I <= Count then
                     declare
                        Val : constant String := Args (I);
                     begin
                        if Is_All (Val) then
                           Cfg.Standard_All := True;
                           Cfg.Standard_Target := Types.DO_178C;
                        else
                           Cfg.Standard_All := False;
                           Cfg.Standard_Target := Types.To_Standard (Val);
                        end if;
                        Cfg.Standard_Explicit := True;
                     end;
                  else
                     Set_Error
                       (Cfg,
                        "--standard requires a name (do178c, iso26262, iec62304, "
                        & "all)");
                  end if;
               elsif Has_Prefix (A, "--standard=") then
                  declare
                     Val : constant String := A (A'First + 11 .. A'Last);
                  begin
                     if Is_All (Val) then
                        Cfg.Standard_All := True;
                        Cfg.Standard_Target := Types.DO_178C;
                     else
                        Cfg.Standard_All := False;
                        Cfg.Standard_Target := Types.To_Standard (Val);
                     end if;
                     Cfg.Standard_Explicit := True;
                  end;
               elsif A = "--serve" then
                  Cfg.Serve_Mode := True;
               elsif A = "--theme" then
                  I := I + 1;
                  if I <= Count then
                     declare
                        Val : constant String := Args (I);
                     begin
                        if Types.Is_Valid_Theme (Val) then
                           Cfg.Theme := Types.To_Theme (Val);
                        else
                           Set_Error
                             (Cfg,
                              "--theme must be light, dark, or system (got: "
                              & Val
                              & ")");
                        end if;
                     end;
                  else
                     Set_Error
                       (Cfg,
                        "--theme requires a value (light | dark | system)");
                  end if;
               elsif Has_Prefix (A, "--theme=") then
                  declare
                     Val : constant String := A (A'First + 8 .. A'Last);
                  begin
                     if Types.Is_Valid_Theme (Val) then
                        Cfg.Theme := Types.To_Theme (Val);
                     else
                        Set_Error
                          (Cfg,
                           "--theme must be light, dark, or system (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               elsif A = "--port" then
                  I := I + 1;
                  if I <= Count then
                     begin
                        Cfg.Port := Positive'Value (Args (I));
                     exception
                        when Constraint_Error =>
                           Set_Error
                             (Cfg,
                              "--port must be a positive integer (got: "
                              & Args (I)
                              & ")");
                     end;
                  else
                     Set_Error (Cfg, "--port requires an integer argument");
                  end if;
               elsif Has_Prefix (A, "--port=") then
                  begin
                     Cfg.Port := Positive'Value (A (A'First + 7 .. A'Last));
                  exception
                     when Constraint_Error =>
                        Set_Error
                          (Cfg,
                           "--port must be a positive integer (got: "
                           & A (A'First + 7 .. A'Last)
                           & ")");
                  end;
               elsif A = "--emit-svg" then
                  I := I + 1;
                  if I <= Count then
                     Cfg.Emit_SVG := True;
                     Set_String (Cfg.SVG_Path, Cfg.SVG_Path_Len, Args (I));
                  else
                     Set_Error
                       (Cfg, "--emit-svg requires a directory argument");
                  end if;
               elsif Has_Prefix (A, "--emit-svg=") then
                  Cfg.Emit_SVG := True;
                  Set_String
                    (Cfg.SVG_Path,
                     Cfg.SVG_Path_Len,
                     A (A'First + 11 .. A'Last));
               elsif A = "--emit-markdown" then
                  I := I + 1;
                  if I <= Count then
                     Cfg.Emit_Markdown := True;
                     Set_String (Cfg.MD_Path, Cfg.MD_Path_Len, Args (I));
                  else
                     Set_Error
                       (Cfg, "--emit-markdown requires a directory argument");
                  end if;
               elsif Has_Prefix (A, "--emit-markdown=") then
                  Cfg.Emit_Markdown := True;
                  Set_String
                    (Cfg.MD_Path, Cfg.MD_Path_Len, A (A'First + 16 .. A'Last));
               elsif A = "--no-svg" then
                  Cfg.No_SVG := True;
               elsif A = "--verbose" then
                  Cfg.Verbose := True;
               elsif A = "--relaxed" then
                  Cfg.Strict_Mode := False;
               elsif A = "--cache" then
                  Cfg.Cache_Enabled := True;
               elsif A = "--no-cache" then
                  Cfg.Cache_Enabled := False;
               elsif A = "--cache-dir" then
                  I := I + 1;
                  if I <= Count then
                     Set_String (Cfg.Cache_Dir, Cfg.Cache_Dir_Len, Args (I));
                  else
                     Set_Error
                       (Cfg, "--cache-dir requires a directory argument");
                  end if;
               elsif Has_Prefix (A, "--cache-dir=") then
                  Set_String
                    (Cfg.Cache_Dir,
                     Cfg.Cache_Dir_Len,
                     A (A'First + 12 .. A'Last));
               elsif A = "--cache-max" then
                  I := I + 1;
                  if I <= Count then
                     begin
                        Cfg.Cache_Max_Entries := Natural'Value (Args (I));
                     exception
                        when Constraint_Error =>
                           Set_Error
                             (Cfg,
                              "--cache-max must be a positive integer (got: "
                              & Args (I)
                              & ")");
                     end;
                  else
                     Set_Error
                       (Cfg, "--cache-max requires an integer argument");
                  end if;
               elsif Has_Prefix (A, "--cache-max=") then
                  begin
                     Cfg.Cache_Max_Entries :=
                       Natural'Value (A (A'First + 12 .. A'Last));
                  exception
                     when Constraint_Error =>
                        Set_Error
                          (Cfg,
                           "--cache-max must be a positive integer (got: "
                           & A (A'First + 12 .. A'Last)
                           & ")");
                  end;
               elsif A = "--skip-dir" then
                  I := I + 1;
                  if I <= Count then
                     Add_Skip_Dir (Cfg, Args (I));
                  else
                     Set_Error (Cfg, "--skip-dir requires a directory name");
                  end if;
               elsif Has_Prefix (A, "--skip-dir=") then
                  Add_Skip_Dir (Cfg, A (A'First + 10 .. A'Last));
               elsif A = "--compare-base" then
                  I := I + 1;
                  if I <= Count then
                     Set_String
                       (Cfg.Compare_Base, Cfg.Compare_Base_Len, Args (I));
                  else
                     Set_Error
                       (Cfg,
                        "--compare-base requires a branch/commit argument");
                  end if;
               elsif Has_Prefix (A, "--compare-base=") then
                  Set_String
                    (Cfg.Compare_Base,
                     Cfg.Compare_Base_Len,
                     A (A'First + 15 .. A'Last));
               elsif A = "--coverage-delta" then
                  I := I + 1;
                  if I <= Count then
                     Set_String
                       (Cfg.Coverage_Delta, Cfg.Coverage_Delta_Len, Args (I));
                  else
                     Set_Error
                       (Cfg,
                        "--coverage-delta requires a branch/commit argument");
                  end if;
               elsif Has_Prefix (A, "--coverage-delta=") then
                  Set_String
                    (Cfg.Coverage_Delta,
                     Cfg.Coverage_Delta_Len,
                     A (A'First + 17 .. A'Last));
               elsif A = "sbom" then
                  Cfg.SBOM_Mode := True;
               elsif A = "prove" then
                  Cfg.Prove_Mode := True;
               elsif A = "status" then
                  Cfg.Status_Mode := True;
               elsif A = "man" then
                  Cfg.Man_Mode := True;
               elsif A = "help" then
                  --  Contextual help: `help --serve`, `help serve`, or
                  --  `--serve help` all print flag-specific help.  The topic
                  --  is the next argument when it looks like one, else the
                  --  previous argument when it was a flag (--serve help).
                  Cfg.Help_Requested := True;
                  if I < Count and then Is_Help_Topic (Args (I + 1)) then
                     Set_String
                       (Cfg.Help_Topic, Cfg.Help_Topic_Len, Args (I + 1));
                     I := I + 1;
                  elsif I > 1 and then Is_Help_Topic (Args (I - 1)) then
                     Set_String
                       (Cfg.Help_Topic, Cfg.Help_Topic_Len, Args (I - 1));
                  end if;
               elsif A = "--check" then
                  Cfg.Man_Check := True;
               elsif A = "--dir" then
                  I := I + 1;
                  if I <= Count then
                     Set_String (Cfg.Man_Dir, Cfg.Man_Dir_Len, Args (I));
                  else
                     Set_Error (Cfg, "--dir requires a directory argument");
                  end if;
               elsif Has_Prefix (A, "--dir=") then
                  Set_String
                    (Cfg.Man_Dir, Cfg.Man_Dir_Len, A (A'First + 6 .. A'Last));
               elsif A = "--version" then
                  Cfg.Version_Requested := True;
               elsif A = "--no-sbom" then
                  Cfg.No_SBOM := True;
               elsif A = "--sbom-format" then
                  I := I + 1;
                  if I <= Count then
                     declare
                        Val : constant String := Args (I);
                     begin
                        if Val = "cyclonedx-json" then
                           Cfg.SBOM_Format := Types.CycloneDX_JSON;
                        elsif Val = "spdx-json" then
                           Cfg.SBOM_Format := Types.SPDX_JSON;
                        elsif Val = "md" then
                           Cfg.SBOM_Format := Types.Markdown;
                        else
                           Set_Error
                             (Cfg,
                              "--sbom-format must be cyclonedx-json, spdx-json, "
                              & "or md (got: "
                              & Val
                              & ")");
                        end if;
                     end;
                  else
                     Set_Error
                       (Cfg, "--sbom-format requires a format argument");
                  end if;
               elsif Has_Prefix (A, "--sbom-format=") then
                  declare
                     Val : constant String := A (A'First + 14 .. A'Last);
                  begin
                     if Val = "cyclonedx-json" then
                        Cfg.SBOM_Format := Types.CycloneDX_JSON;
                     elsif Val = "spdx-json" then
                        Cfg.SBOM_Format := Types.SPDX_JSON;
                     elsif Val = "md" then
                        Cfg.SBOM_Format := Types.Markdown;
                     else
                        Set_Error
                          (Cfg,
                           "--sbom-format must be cyclonedx-json, spdx-json, "
                           & "or md (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               elsif A = "--format" then
                  I := I + 1;
                  if I <= Count then
                     declare
                        Val : constant String := Args (I);
                     begin
                        if Val = "cyclonedx-json" then
                           Cfg.SBOM_Format := Types.CycloneDX_JSON;
                        elsif Val = "spdx-json" then
                           Cfg.SBOM_Format := Types.SPDX_JSON;
                        elsif Val = "md" then
                           Cfg.SBOM_Format := Types.Markdown;
                        else
                           Set_Error
                             (Cfg,
                              "--format must be cyclonedx-json, spdx-json, or "
                              & "md (got: "
                              & Val
                              & ")");
                        end if;
                     end;
                  else
                     Set_Error (Cfg, "--format requires a format argument");
                  end if;
               elsif Has_Prefix (A, "--format=") then
                  declare
                     Val : constant String := A (A'First + 9 .. A'Last);
                  begin
                     if Val = "cyclonedx-json" then
                        Cfg.SBOM_Format := Types.CycloneDX_JSON;
                     elsif Val = "spdx-json" then
                        Cfg.SBOM_Format := Types.SPDX_JSON;
                     elsif Val = "md" then
                        Cfg.SBOM_Format := Types.Markdown;
                     else
                        Set_Error
                          (Cfg,
                           "--format must be cyclonedx-json, spdx-json, or "
                           & "md (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               elsif A = "--out" then
                  I := I + 1;
                  if I <= Count then
                     Set_String (Cfg.SBOM_Out, Cfg.SBOM_Out_Len, Args (I));
                  else
                     Set_Error (Cfg, "--out requires a path argument");
                  end if;
               elsif Has_Prefix (A, "--out=") then
                  Set_String
                    (Cfg.SBOM_Out,
                     Cfg.SBOM_Out_Len,
                     A (A'First + 6 .. A'Last));
               elsif A = "--jobs" or A = "-j" then
                  I := I + 1;
                  if I <= Count then
                     Set_Prove_Int
                       (Cfg, Cfg.Prove_Jobs, Args (I), -1, 1024, "--jobs");
                  else
                     Set_Error (Cfg, "--jobs requires an integer argument");
                  end if;
               elsif Has_Prefix (A, "--jobs=") then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Jobs,
                     A (A'First + 7 .. A'Last),
                     -1,
                     1024,
                     "--jobs");
               elsif Has_Prefix (A, "-j") and then A'Length > 2 then
                  --  Combined short form: -j12
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Jobs,
                     A (A'First + 2 .. A'Last),
                     -1,
                     1024,
                     "-j");
               elsif A = "--level" then
                  I := I + 1;
                  if I <= Count then
                     Set_Prove_Int
                       (Cfg, Cfg.Prove_Level, Args (I), 0, 4, "--level");
                  else
                     Set_Error (Cfg, "--level requires an integer argument");
                  end if;
               elsif Has_Prefix (A, "--level=") then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Level,
                     A (A'First + 8 .. A'Last),
                     0,
                     4,
                     "--level");
               elsif A = "--timeout" then
                  I := I + 1;
                  if I <= Count then
                     Set_Prove_Int
                       (Cfg,
                        Cfg.Prove_Timeout,
                        Args (I),
                        1,
                        3600,
                        "--timeout");
                  else
                     Set_Error (Cfg, "--timeout requires an integer argument");
                  end if;
               elsif Has_Prefix (A, "--timeout=") then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Timeout,
                     A (A'First + 10 .. A'Last),
                     1,
                     3600,
                     "--timeout");
               elsif A = "--steps" then
                  I := I + 1;
                  if I <= Count then
                     Set_Prove_Int
                       (Cfg,
                        Cfg.Prove_Steps,
                        Args (I),
                        1,
                        100_000_000,
                        "--steps");
                  else
                     Set_Error (Cfg, "--steps requires an integer argument");
                  end if;
               elsif Has_Prefix (A, "--steps=") then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Steps,
                     A (A'First + 8 .. A'Last),
                     1,
                     100_000_000,
                     "--steps");
               elsif A = "--memlimit" then
                  I := I + 1;
                  if I <= Count then
                     Set_Prove_Int
                       (Cfg,
                        Cfg.Prove_Memlimit,
                        Args (I),
                        1,
                        1_000_000,
                        "--memlimit");
                  else
                     Set_Error
                       (Cfg, "--memlimit requires an integer argument");
                  end if;
               elsif Has_Prefix (A, "--memlimit=") then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Prove_Memlimit,
                     A (A'First + 11 .. A'Last),
                     1,
                     1_000_000,
                     "--memlimit");
               elsif A = "--force" then
                  --  --force is shared between prove (bypass the result cache)
                  --  and man (override an existing/up-to-date man page).
                  Cfg.Prove_Force := True;
                  Cfg.Man_Force := True;
               elsif A = "--no-loop-unrolling" then
                  Cfg.Prove_No_Loop_Unroll := True;
               elsif A = "--no-inlining" then
                  Cfg.Prove_No_Inlining := True;
               elsif A = "--require-spark" then
                  I := I + 1;
                  if I <= Count then
                     declare
                        Val : constant String := Args (I);
                        Lvl : Types.SPARK_Level;
                        OK  : Boolean;
                     begin
                        To_SPARK_Level (Val, Lvl, OK);
                        if OK then
                           Cfg.Require_SPARK := Lvl;
                           Cfg.Require_SPARK_Set := True;
                        else
                           Set_Error
                             (Cfg,
                              "--require-spark must be Stone, Bronze, Silver, "
                              & "Gold, or Platinum (got: "
                              & Val
                              & ")");
                        end if;
                     end;
                  else
                     Set_Error
                       (Cfg, "--require-spark requires a level argument");
                  end if;
               elsif Has_Prefix (A, "--require-spark=") then
                  declare
                     Val : constant String := A (A'First + 16 .. A'Last);
                     Lvl : Types.SPARK_Level;
                     OK  : Boolean;
                  begin
                     To_SPARK_Level (Val, Lvl, OK);
                     if OK then
                        Cfg.Require_SPARK := Lvl;
                        Cfg.Require_SPARK_Set := True;
                     else
                        Set_Error
                          (Cfg,
                           "--require-spark must be Stone, Bronze, Silver, "
                           & "Gold, or Platinum (got: "
                           & Val
                           & ")");
                     end if;
                  end;
               elsif A = "--require-docstrings" then
                  I := I + 1;
                  if I <= Count then
                     Set_Prove_Int
                       (Cfg,
                        Cfg.Require_Docstrings,
                        Args (I),
                        0,
                        100,
                        "--require-docstrings");
                     if not Cfg.CLI_Error then
                        Cfg.Require_Docstrings_Set := True;
                     end if;
                  else
                     Set_Error
                       (Cfg,
                        "--require-docstrings requires a percentage argument");
                  end if;
               elsif Has_Prefix (A, "--require-docstrings=") then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Require_Docstrings,
                     A (A'First + 21 .. A'Last),
                     0,
                     100,
                     "--require-docstrings");
                  if not Cfg.CLI_Error then
                     Cfg.Require_Docstrings_Set := True;
                  end if;
               elsif A = "--require-tests" then
                  I := I + 1;
                  if I <= Count then
                     Set_Prove_Int
                       (Cfg,
                        Cfg.Require_Tests,
                        Args (I),
                        0,
                        1_000_000,
                        "--require-tests");
                     if not Cfg.CLI_Error then
                        Cfg.Require_Tests_Set := True;
                     end if;
                  else
                     Set_Error
                       (Cfg, "--require-tests requires a count argument");
                  end if;
               elsif Has_Prefix (A, "--require-tests=") then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Require_Tests,
                     A (A'First + 16 .. A'Last),
                     0,
                     1_000_000,
                     "--require-tests");
                  if not Cfg.CLI_Error then
                     Cfg.Require_Tests_Set := True;
                  end if;
               elsif A = "--require-proof" then
                  I := I + 1;
                  if I <= Count then
                     Set_Prove_Int
                       (Cfg,
                        Cfg.Require_Proof,
                        Args (I),
                        0,
                        100,
                        "--require-proof");
                     if not Cfg.CLI_Error then
                        Cfg.Require_Proof_Set := True;
                     end if;
                  else
                     Set_Error
                       (Cfg, "--require-proof requires a percentage argument");
                  end if;
               elsif Has_Prefix (A, "--require-proof=") then
                  Set_Prove_Int
                    (Cfg,
                     Cfg.Require_Proof,
                     A (A'First + 16 .. A'Last),
                     0,
                     100,
                     "--require-proof");
                  if not Cfg.CLI_Error then
                     Cfg.Require_Proof_Set := True;
                  end if;
               elsif A = "--help" then
                  --  Full usage is printed by the caller (main / tests) when
                  --  Help_Requested is set, so `--help`, `help`, and
                  --  `help TOPIC` share one printing path.
                  Cfg.Help_Requested := True;
               else
                  --  Unknown token: reject loudly instead of silently running
                  --  an assessment.  Flag-like tokens (--foo) and bare words
                  --  (a typo'd subcommand) both get a "did you mean" hint.
                  --  When no similar flag exists the hint is empty; the main
                  --  program then prints the full usage so the user lands on
                  --  the flag list instead of a bare one-line error.
                  declare
                     Hint : constant String := Suggest_Flags (A);
                  begin
                     if A'Length >= 1 and then A (A'First) = '-' then
                        Set_Error (Cfg, "unknown option '" & A & "'" & Hint);
                     else
                        Set_Error (Cfg, "unknown argument '" & A & "'" & Hint);
                     end if;
                     if Hint'Length = 0 then
                        Cfg.Unknown_No_Suggest := True;
                     end if;
                  end;
               end if;
            end;
            I := I + 1;
         end loop;

         --  The sbom subcommand and the serve dashboard are standard-aware:
         --  without an explicit --standard / --asil / --class they default to
         --  all standards, so the SBOM carries the joined DO-178C / ISO
         --  26262 / IEC 62304 properties at the shared DAL tier and the
         --  served dashboard renders every standard's compliance level.  An
         --  explicit standard flag narrows them to that single standard
         --  (e.g. --asil=B -> ISO 26262 at ASIL B).
         if (Cfg.SBOM_Mode or Cfg.Serve_Mode) and not Cfg.Standard_Explicit
         then
            Cfg.Standard_All := True;
         end if;
      end Parse_Args;

      procedure Parse_Command_Line (Cfg : out CLI_Config) is
         Args : Arg_Vectors.Vector;
      begin
         for I in 1 .. Ada.Command_Line.Argument_Count loop
            Arg_Vectors.Append (Args, Ada.Command_Line.Argument (I));
         end loop;
         Parse_Args (Args, Cfg);
      end Parse_Command_Line;

   end Testing;

   function Parse_CLI return CLI_Config is
      Cfg : CLI_Config;
   begin
      Testing.Parse_Command_Line (Cfg);

      -- Default skip dirs (used in relaxed mode; .git/obj always skipped)
      if Cfg.Skip_Dir_Ct = 0 then
         Set_String (Cfg.Skip_Dirs, Cfg.Skip_Dir_Ct, "demo,deps,examples");
      end if;

      -- --no-svg overrides --emit-svg
      if Cfg.No_SVG then
         Cfg.Emit_SVG := False;
         Cfg.SVG_Path_Len := 0;
      end if;

      -- Differential modes are mutually exclusive
      if Cfg.Compare_Base_Len > 0 and then Cfg.Coverage_Delta_Len > 0 then
         Set_Error
           (Cfg, "--compare-base and --coverage-delta are mutually exclusive");
      end if;

      -- SBOM mode is exclusive with the differential modes
      if Cfg.SBOM_Mode
        and then (Cfg.Compare_Base_Len > 0 or Cfg.Coverage_Delta_Len > 0)
      then
         Set_Error
           (Cfg,
            "sbom cannot be combined with --compare-base/--coverage-delta");
      end if;

      -- Prove mode is exclusive with the differential modes and sbom mode
      if Cfg.Prove_Mode
        and then (Cfg.Compare_Base_Len > 0
                  or Cfg.Coverage_Delta_Len > 0
                  or Cfg.SBOM_Mode)
      then
         Set_Error
           (Cfg,
            "prove cannot be combined with --compare-base, --coverage-delta, "
            & "or sbom");
      end if;

      -- Status mode is a pure toolchain/platform report: no assessment runs.
      if Cfg.Status_Mode
        and then (Cfg.Prove_Mode
                  or Cfg.SBOM_Mode
                  or Cfg.Compare_Base_Len > 0
                  or Cfg.Coverage_Delta_Len > 0)
      then
         Set_Error
           (Cfg,
            "status cannot be combined with prove, sbom, --compare-base, "
            & "or --coverage-delta");
      end if;

      -- Man mode is a standalone installer: it cannot be combined with any
      -- assessment mode (the man page is generated from the bundled version,
      -- it does not need a target).
      if Cfg.Man_Mode
        and then (Cfg.Status_Mode
                  or Cfg.Prove_Mode
                  or Cfg.SBOM_Mode
                  or Cfg.Compare_Base_Len > 0
                  or Cfg.Coverage_Delta_Len > 0)
      then
         Set_Error
           (Cfg,
            "man cannot be combined with status, prove, sbom, --compare-base, "
            & "or --coverage-delta");
      end if;

      -- --check and --dir only make sense with the man subcommand; a bare
      -- `adacovex --check` is almost certainly a typo, so fail loudly rather
      -- than silently running an assessment that ignores them.
      if (Cfg.Man_Check or Cfg.Man_Dir_Len > 0) and then not Cfg.Man_Mode then
         Set_Error (Cfg, "--check and --dir require the man subcommand");
      end if;

      -- --version is a pure banner: nothing else is meaningful with it.
      if Cfg.Version_Requested
        and then (Cfg.Man_Mode
                  or Cfg.Status_Mode
                  or Cfg.Prove_Mode
                  or Cfg.SBOM_Mode
                  or Cfg.Compare_Base_Len > 0
                  or Cfg.Coverage_Delta_Len > 0)
      then
         Set_Error (Cfg, "--version cannot be combined with other modes");
      end if;

      -- GNATprove options only make sense in prove mode.  --force is shared
      -- with the man subcommand (man --force overrides the installed page),
      -- so it is only an error when neither prove nor man mode is set.
      if not Cfg.Prove_Mode
        and then not Cfg.Man_Mode
        and then (Cfg.Prove_Jobs >= 0
                  or Cfg.Prove_Level >= 0
                  or Cfg.Prove_Timeout >= 0
                  or Cfg.Prove_Steps >= 0
                  or Cfg.Prove_Memlimit >= 0
                  or Cfg.Prove_Force
                  or Cfg.Prove_No_Loop_Unroll
                  or Cfg.Prove_No_Inlining)
      then
         Set_Error
           (Cfg,
            "prove options (--jobs, --level, --timeout, --steps, --memlimit, "
            & "--force, --no-loop-unrolling, --no-inlining) require the prove "
            & "subcommand");
      end if;

      -- Automatic SBOM at the end of every assessment is skipped only in the
      -- single-purpose modes (differential, coverage gate, sbom) or when
      -- --no-sbom is passed. Prove mode runs gnatprove and then falls through
      -- to the normal assessment, so the automatic SBOM still applies.
      if Cfg.SBOM_Mode
        or Cfg.Compare_Base_Len > 0
        or Cfg.Coverage_Delta_Len > 0
      then
         Cfg.No_SBOM := True;
      end if;

      -- Default target if not provided: current working directory
      if Cfg.Target_Len = 0 then
         Set_String
           (Cfg.Target_Path,
            Cfg.Target_Len,
            Ada.Directories.Current_Directory);
      end if;

      -- Resolve target path to absolute, then derive default manifest
      declare
         Raw : constant String := Cfg.Target_Path (1 .. Cfg.Target_Len);
      begin
         if Raw'Length > 0 and then Raw (Raw'First) /= '/' then
            declare
               CD : constant String := Ada.Directories.Current_Directory;
               AP : constant String := CD & "/" & Raw;
            begin
               -- Normalize a trailing "/." (e.g. "--target=.") to the
               -- plain directory so display paths stay clean.
               if AP'Length >= 2 and then AP (AP'Last - 1 .. AP'Last) = "/."
               then
                  Set_String (Cfg.Target_Path, Cfg.Target_Len, CD);
               else
                  Set_String (Cfg.Target_Path, Cfg.Target_Len, AP);
               end if;
            end;
         end if;
      end;

      -- Default SVG output path: project-scoped (relative to resolved target)
      if Cfg.Emit_SVG and then Cfg.SVG_Path_Len = 0 then
         Set_String
           (Cfg.SVG_Path,
            Cfg.SVG_Path_Len,
            Cfg.Target_Path (1 .. Cfg.Target_Len) & "/docs/badges");
      end if;

      -- Default manifest derived from target
      if Cfg.Manifest_Len = 0 then
         declare
            TDir : constant String := Cfg.Target_Path (1 .. Cfg.Target_Len);
         begin
            if Ada.Directories.Exists (TDir & "/alire.toml") then
               Set_String
                 (Cfg.Manifest_Path, Cfg.Manifest_Len, TDir & "/alire.toml");
            else
               Set_String
                 (Cfg.Manifest_Path,
                  Cfg.Manifest_Len,
                  TDir & "/alire-dev.toml");
            end if;
         end;
      end if;

      -- Default SBOM output path: project-scoped, format-aware.  Applies to
      -- both the explicit `adacovex sbom` subcommand and the automatic SBOM
      -- generation that runs at the end of every normal assessment (unless
      -- disabled with --no-sbom).
      if Cfg.SBOM_Out_Len = 0 then
         declare
            TDir : constant String := Cfg.Target_Path (1 .. Cfg.Target_Len);
         begin
            case Cfg.SBOM_Format is
               when Types.SPDX_JSON =>
                  Set_String
                    (Cfg.SBOM_Out, Cfg.SBOM_Out_Len, TDir & "/sbom.spdx.json");

               when Types.Markdown  =>
                  Set_String
                    (Cfg.SBOM_Out,
                     Cfg.SBOM_Out_Len,
                     TDir & "/docs/compliance/SBOM.md");

               when others          =>
                  Set_String
                    (Cfg.SBOM_Out, Cfg.SBOM_Out_Len, TDir & "/sbom.json");
            end case;
         end;
      end if;

      return Cfg;
   end Parse_CLI;

   procedure Print_Usage is
   begin
      Ada.Text_IO.Put_Line
        ("adacovex v"
         & Adacovex.Version
         & " -- Ada/SPARK Coverage, Proof & Multi-Standard Compliance Tool");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Usage: adacovex [options]");
      Ada.Text_IO.Put_Line
        ("       adacovex sbom [--format=FMT] [--out=PATH] [--standard=NAME]");
      Ada.Text_IO.Put_Line
        ("                        [--dal=LEVEL | --asil=LEVEL | --class=LEVEL]");
      Ada.Text_IO.Put_Line ("       adacovex prove --target=PATH");
      Ada.Text_IO.Put_Line ("       adacovex status --target=PATH");
      Ada.Text_IO.Put_Line ("       adacovex man [--check] [--dir=PATH]");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.Put_Line
        ("  --target=PATH         Target project path (default: current directory)");
      Ada.Text_IO.Put_Line
        ("  --manifest=PATH       Target manifest file override");
      Ada.Text_IO.Put_Line
        ("  --dal=LEVEL           DO-178C DAL level: A | B | C | D | E");
      Ada.Text_IO.Put_Line
        ("                        (default: C; also the shared rigor tier)");
      Ada.Text_IO.Put_Line
        ("  --asil=LEVEL          ISO 26262 ASIL level: A | B | C | D | QM");
      Ada.Text_IO.Put_Line
        ("                        (e.g. --asil=B selects ASIL B)");
      Ada.Text_IO.Put_Line
        ("  --class=LEVEL         IEC 62304 safety class: A | B | C");
      Ada.Text_IO.Put_Line
        ("                        (e.g. --class=A selects Class A)");
      Ada.Text_IO.Put_Line
        ("  --standard=NAME       Compliance standard: do178c | iso26262 |");
      Ada.Text_IO.Put_Line
        ("                        iec62304 | all (default: do178c); all emits");
      Ada.Text_IO.Put_Line
        ("                        badges for every standard at the same tier");
      Ada.Text_IO.Put_Line
        ("  status                Report toolchain + platform status (no");
      Ada.Text_IO.Put_Line
        ("                        assessment); exit 0 when alr + gnatprove are");
      Ada.Text_IO.Put_Line
        ("                        available or dependency-managed");
      Ada.Text_IO.Put_Line
        ("  --serve               Start HTTP dashboard on :8080 (standard-aware,");
      Ada.Text_IO.Put_Line
        ("                        defaults to all standards; light/dark/system");
      Ada.Text_IO.Put_Line
        ("                        themes via the header dropdown)");
      Ada.Text_IO.Put_Line
        ("  --theme=NAME          Dashboard theme: light | dark | system");
      Ada.Text_IO.Put_Line
        ("                        (default: system; only with --serve)");
      Ada.Text_IO.Put_Line
        ("  --port=N              HTTP server port (default: 8080)");
      Ada.Text_IO.Put_Line
        ("  --emit-svg=PATH       Write SVG badges to directory (default: <target>/docs/badges)");
      Ada.Text_IO.Put_Line
        ("  --no-svg              Suppress automatic SVG output");
      Ada.Text_IO.Put_Line
        ("  --emit-markdown=PATH  Write VERIFICATION.md + TRACE.md");
      Ada.Text_IO.Put_Line
        ("  --skip-dir=NAME       Add directory name to skip list (repeatable)");
      Ada.Text_IO.Put_Line
        ("  --relaxed             Disable strict mode (skip dirs, no patches); strict is default");
      Ada.Text_IO.Put_Line
        ("  --cache               Enable result caching (default: on)");
      Ada.Text_IO.Put_Line
        ("  --no-cache            Disable result caching (always re-scan/re-prove)");
      Ada.Text_IO.Put_Line
        ("  --cache-dir=PATH      Cache directory (default: ~/.adacovex/cache/<ver>)");
      Ada.Text_IO.Put_Line
        ("  --cache-max=N         Max cache entries before eviction (default: 4096)");
      Ada.Text_IO.Put_Line
        ("  --compare-base=REF    Differential mode: compare against a base");
      Ada.Text_IO.Put_Line
        ("                        revision (branch/commit/rev) in a temporary");
      Ada.Text_IO.Put_Line
        ("                        snapshot and report VC/DAL delta (supports");
      Ada.Text_IO.Put_Line
        ("                        git, mercurial, subversion, fossil, jj)");
      Ada.Text_IO.Put_Line
        ("  --coverage-delta=REF  Docstring coverage gate: exit non-zero if");
      Ada.Text_IO.Put_Line
        ("                        current docstring coverage is below the base");
      Ada.Text_IO.Put_Line
        ("                        (any supported VCS; git, hg, svn, fossil, jj)");
      Ada.Text_IO.Put_Line
        ("  prove --target=PATH   Run GNATprove on the target project, then");
      Ada.Text_IO.Put_Line
        ("                        assess it (bundled gnatprove resolution,");
      Ada.Text_IO.Put_Line
        ("                        no alire.toml required in the target)");
      Ada.Text_IO.Put_Line
        ("  --jobs=N, -j N        GNATprove parallelism (default: auto-detect");
      Ada.Text_IO.Put_Line
        ("                        CPU count; 0 = all cores; e.g. -j12)");
      Ada.Text_IO.Put_Line
        ("  --level=N             GNATprove proof effort 0-4 (default: tool default)");
      Ada.Text_IO.Put_Line
        ("  --timeout=N           Per-check prover timeout in seconds");
      Ada.Text_IO.Put_Line
        ("  --steps=N             Max proof steps (reproducible)");
      Ada.Text_IO.Put_Line
        ("  --memlimit=N          Prover memory limit in MB");
      Ada.Text_IO.Put_Line
        ("  --force               Force full gnatprove reanalysis (-f)");
      Ada.Text_IO.Put_Line
        ("  --no-loop-unrolling   Disable automatic loop unrolling");
      Ada.Text_IO.Put_Line
        ("  --no-inlining         Disable contextual analysis inlining");
      Ada.Text_IO.Put_Line
        ("  --require-spark=LVL   Fail if SPARK level < LVL (Stone..Platinum)");
      Ada.Text_IO.Put_Line
        ("  --require-docstrings=PCT Fail if docstring coverage < PCT% (0-100)");
      Ada.Text_IO.Put_Line
        ("  --require-tests=N     Fail if passing test count < N");
      Ada.Text_IO.Put_Line
        ("  --require-proof=PCT   Fail if proved-VC coverage < PCT% (0-100)");
      Ada.Text_IO.Put_Line
        ("                        (CI gates: default off, fail loudly when set)");
      Ada.Text_IO.Put_Line
        ("  sbom --format=FMT     Generate a proof-aware SBOM (FMT: cyclonedx-json");
      Ada.Text_IO.Put_Line
        ("                        | spdx-json | md; default: cyclonedx-json)");
      Ada.Text_IO.Put_Line
        ("  sbom --out=PATH       SBOM output path (default: <target>/sbom.json");
      Ada.Text_IO.Put_Line
        ("                        or <target>/sbom.spdx.json, or");
      Ada.Text_IO.Put_Line
        ("                        <target>/docs/compliance/SBOM.md for md)");
      Ada.Text_IO.Put_Line
        ("  --no-sbom             Skip the automatic SBOM generated at the end");
      Ada.Text_IO.Put_Line
        ("                        of every assessment (generated by default)");
      Ada.Text_IO.Put_Line
        ("  --sbom-format=FMT     Format for the automatic SBOM (cyclonedx-json");
      Ada.Text_IO.Put_Line
        ("                        | spdx-json | md; default: cyclonedx-json)");
      Ada.Text_IO.Put_Line ("  --verbose             Verbose diagnostics");
      Ada.Text_IO.Put_Line
        ("  --version             Print the bundled version (read from");
      Ada.Text_IO.Put_Line
        ("                        alire-dev.toml; release builds bundle the");
      Ada.Text_IO.Put_Line ("                        release tag) and exit");
      Ada.Text_IO.Put_Line
        ("  man [--check]         Install the man page into the local man");
      Ada.Text_IO.Put_Line
        ("                        database (~/.local/share/man, Linux/WSL);");
      Ada.Text_IO.Put_Line
        ("                        --check exits 0 when the installed man page");
      Ada.Text_IO.Put_Line
        ("                        matches this binary's version, 1 when a");
      Ada.Text_IO.Put_Line
        ("                        newer version is available or none is");
      Ada.Text_IO.Put_Line
        ("                        installed (man page contains the version)");
      Ada.Text_IO.Put_Line
        ("  man --dir=PATH        Install the man page into PATH/man1 instead");
      Ada.Text_IO.Put_Line
        ("                        of the default local man directory");
      Ada.Text_IO.Put_Line
        ("  man --force           Override an existing man page even when it");
      Ada.Text_IO.Put_Line
        ("                        already matches this binary (repair a");
      Ada.Text_IO.Put_Line
        ("                        hand-edited/corrupt installed page)");
      Ada.Text_IO.Put_Line
        ("  help [TOPIC]          Show this message, or contextual help for a");
      Ada.Text_IO.Put_Line
        ("                        flag/subcommand (e.g. `adacovex help serve`);");
      Ada.Text_IO.Put_Line
        ("                        `adacovex --serve help` also works");
      Ada.Text_IO.Put_Line
        ("  --help                Show this message and exit");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line
        ("Outputs: ANSI terminal report, SVG badges, Markdown reports,");
      Ada.Text_IO.Put_Line
        ("         HTML dashboard (--serve), JSON API (GET /api/metrics)");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line
        ("Zero-dependency Ada/SPARK tool for DO-178C / ISO 26262 / IEC 62304");
      Ada.Text_IO.Put_Line
        ("compliance assessment (DAL / ASIL / safety-class levels)");
   end Print_Usage;

   --  Lowercase a string, stripping a leading "--" and any "=value" suffix
   --  so "--standard=all", "--Serve", and "standard" all match "standard".
   function Normalize_Topic (Topic : String) return String is
      First : Natural := Topic'First;
      Last  : Natural := Topic'Last;
      Buf   : String (1 .. Topic'Length);
      Len   : Natural := 0;
   begin
      if Last - First + 1 >= 2
        and then Topic (First) = '-'
        and then Topic (First + 1) = '-'
      then
         First := First + 2;
      end if;
      for I in First .. Last loop
         exit when Topic (I) = '=';
         Len := Len + 1;
         Buf (Len) := Topic (I);
      end loop;
      for I in 1 .. Len loop
         if Buf (I) in 'A' .. 'Z' then
            Buf (I) := Character'Val (Character'Pos (Buf (I)) + 32);
         end if;
      end loop;
      return Buf (1 .. Len);
   end Normalize_Topic;

   --  Print a named help section (title + body lines).
   procedure Print_Section (Title : String; Body_Text : String) is
      Start : Natural := Body_Text'First;
   begin
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line (Title);
      Ada.Text_IO.Put_Line
        ("------------------------------------------------------------");
      while Start <= Body_Text'Last loop
         declare
            Fin : Natural := Start;
         begin
            while Fin < Body_Text'Last and then Body_Text (Fin) /= ASCII.LF
            loop
               Fin := Fin + 1;
            end loop;
            Ada.Text_IO.Put_Line (Body_Text (Start .. Fin));
            exit when Fin = Body_Text'Last;
            Start := Fin + 1;
         end;
      end loop;
   end Print_Section;

   procedure Print_Topic_Help (Topic : String) is
      T : constant String := Normalize_Topic (Topic);
   begin
      if T = "" then
         Print_Usage;
      elsif T = "help" then
         Print_Section
           ("help [TOPIC]",
            "Show the full usage message, or contextual help for a single"
            & ASCII.LF
            & "flag or subcommand when TOPIC names one."
            & ASCII.LF
            & ASCII.LF
            & "  adacovex help serve       contextual help for --serve"
            & ASCII.LF
            & "  adacovex help --standard  contextual help for --standard"
            & ASCII.LF
            & "  adacovex --serve help     topic after the flag also works"
            & ASCII.LF
            & "  adacovex help             full usage"
            & ASCII.LF
            & ASCII.LF
            & "TOPIC is case-insensitive; a leading -- is optional, and a"
            & ASCII.LF
            & "=value suffix is ignored (help --standard=all == help standard).");
      elsif T = "serve" then
         Print_Section
           ("--serve",
            "Start the built-in HTTP/1.1 web dashboard on --port (default"
            & ASCII.LF
            & "8080) after the assessment.  Endpoints:"
            & ASCII.LF
            & ASCII.LF
            & "  GET /                HTML dashboard (coverage, proof, tests,"
            & ASCII.LF
            & "                       compliance cards)"
            & ASCII.LF
            & "  GET /api/metrics     JSON object with key metrics"
            & ASCII.LF
            & "  GET /badge/*.svg     SVG badges (spark, tests, do178c,"
            & ASCII.LF
            & "                       iso26262, iec62304)"
            & ASCII.LF
            & ASCII.LF
            & "Standard-aware: like the sbom subcommand it defaults to all"
            & ASCII.LF
            & "standards when no --standard / --asil / --class is given; an"
            & ASCII.LF
            & "explicit standard flag narrows the dashboard to that single"
            & ASCII.LF
            & "standard.  The dashboard supports light / dark / system themes"
            & ASCII.LF
            & "via the header dropdown (--theme sets the initial choice; the"
            & ASCII.LF
            & "browser's own choice persists in localStorage)."
            & ASCII.LF
            & ASCII.LF
            & "Related: --theme, --port.");
      elsif T = "theme" then
         Print_Section
           ("--theme=NAME",
            "Dashboard color theme for --serve:"
            & ASCII.LF
            & ASCII.LF
            & "  system   follow the browser's prefers-color-scheme (default)"
            & ASCII.LF
            & "  light    force the light theme"
            & ASCII.LF
            & "  dark     force the dark theme"
            & ASCII.LF
            & ASCII.LF
            & "The header dropdown switches live between the three; the"
            & ASCII.LF
            & "browser's selection is persisted in localStorage and wins over"
            & ASCII.LF
            & "--theme on later visits.  Only relevant with --serve.");
      elsif T = "port" then
         Print_Section
           ("--port=N",
            "HTTP server port for --serve (default 8080).  Must be a valid"
            & ASCII.LF
            & "positive integer.  Only relevant with --serve.");
      elsif T = "standard"
        or else T = "dal"
        or else T = "asil"
        or else T = "class"
      then
         Print_Section
           ("--standard / --dal / --asil / --class",
            "Select the compliance standard and integrity level.  The"
            & ASCII.LF
            & "evidence checks are identical across standards; only the"
            & ASCII.LF
            & "level labels change:"
            & ASCII.LF
            & ASCII.LF
            & "  --standard=do178c    DO-178C DAL A-E (default)"
            & ASCII.LF
            & "  --standard=iso26262  ISO 26262 ASIL D/QM"
            & ASCII.LF
            & "  --standard=iec62304  IEC 62304 Class C/A"
            & ASCII.LF
            & "  --standard=all       all standards at the shared tier"
            & ASCII.LF
            & "  --dal=LEVEL          shared rigor tier A-E"
            & ASCII.LF
            & "  --asil=LEVEL         ISO 26262 level (sets standard + tier)"
            & ASCII.LF
            & "  --class=LEVEL        IEC 62304 class (sets standard + tier)"
            & ASCII.LF
            & ASCII.LF
            & "Run `adacovex status` for toolchain state; see docs/standards.md"
            & ASCII.LF
            & "for the full tier mapping.");
      elsif T = "target" or else T = "manifest" then
         Print_Section
           ("--target / --manifest",
            "--target=PATH sets the project root to scan and assess (default"
            & ASCII.LF
            & "current directory); relative paths are resolved to absolute."
            & ASCII.LF
            & "--manifest=PATH overrides the auto-detected Alire manifest"
            & ASCII.LF
            & "(alire-dev.toml, then alire.toml).");
      elsif T = "compare-base" or else T = "coverage-delta" then
         Print_Section
           ("--compare-base / --coverage-delta",
            "Differential modes: snapshot a base revision in a temporary"
            & ASCII.LF
            & "directory and compare it against the current working tree"
            & ASCII.LF
            & "without touching the repo.  --compare-base reports the full"
            & ASCII.LF
            & "VC/DAL delta; --coverage-delta gates on docstring coverage"
            & ASCII.LF
            & "only.  Works on git, mercurial, subversion, fossil, and jj.");
      elsif T = "sbom"
        or else T = "format"
        or else T = "out"
        or else T = "no-sbom"
        or else T = "sbom-format"
      then
         Print_Section
           ("adacovex sbom",
            "Generate a proof-aware software bill of materials (CycloneDX"
            & ASCII.LF
            & "1.5, SPDX 2.3, or Markdown).  Standard-aware: defaults to all"
            & ASCII.LF
            & "standards unless narrowed by --standard / --asil / --class."
            & ASCII.LF
            & ASCII.LF
            & "  adacovex sbom --format=cyclonedx-json --dal=C"
            & ASCII.LF
            & "  adacovex sbom --format=spdx-json --asil=B --out=sbom.spdx.json"
            & ASCII.LF
            & ASCII.LF
            & "--format (alias --sbom-format) and --out select the format"
            & ASCII.LF
            & "and destination.  --no-sbom skips SBOM generation in the main"
            & ASCII.LF
            & "pipeline entirely.");
      elsif T = "prove"
        or else T = "jobs"
        or else T = "level"
        or else T = "timeout"
        or else T = "steps"
        or else T = "memlimit"
        or else T = "force"
        or else T = "no-loop-unrolling"
        or else T = "no-inlining"
      then
         Print_Section
           ("adacovex prove",
            "Resolve gnatprove (manifest pin, PATH, cached toolchain, or"
            & ASCII.LF
            & "download), run it on the target, then assess the result."
            & ASCII.LF
            & ASCII.LF
            & "Options: --jobs/-j (parallelism), --level (proof level),"
            & ASCII.LF
            & "--timeout (seconds per proof), --steps (max steps),"
            & ASCII.LF
            & "--memlimit, --force (bypass the result cache),"
            & ASCII.LF
            & "--no-loop-unrolling, --no-inlining.");
      elsif T = "status" then
         Print_Section
           ("adacovex status",
            "Report toolchain + platform state without running an assessment"
            & ASCII.LF
            & "or downloading anything: alire/gnatprove detectability, CPU"
            & ASCII.LF
            & "count, CI status, and which VCS tools are on PATH.");
      elsif T = "man" or else T = "check" or else T = "dir" or else T = "force"
      then
         Print_Section
           ("adacovex man",
            "Install the man page into the local man database (default"
            & ASCII.LF
            & "~/.local/share/man on Linux/WSL; --dir=PATH overrides) and"
            & ASCII.LF
            & "refresh it with mandb when present.  --check exits 0 when the"
            & ASCII.LF
            & "installed page matches this binary's version, 1 otherwise."
            & ASCII.LF
            & ASCII.LF
            & "--force always (re)writes the installed page even when it"
            & ASCII.LF
            & "already matches this binary -- use it to repair a hand-edited"
            & ASCII.LF
            & "or corrupt installed page.");
      elsif T = "emit-svg" or else T = "no-svg" then
         Print_Section
           ("--emit-svg / --no-svg",
            "Write SVG badges (spark, tests, do178c, iso26262, iec62304) into"
            & ASCII.LF
            & "a directory (default <target>/docs/badges).  --no-svg"
            & ASCII.LF
            & "suppresses badge output.");
      elsif T = "emit-markdown" then
         Print_Section
           ("--emit-markdown=PATH",
            "Write the Markdown verification report (VERIFICATION.md) and"
            & ASCII.LF
            & "traceability report (TRACE.md) into the given directory.");
      elsif T = "skip-dir" or else T = "relaxed" then
         Print_Section
           ("--skip-dir / --relaxed",
            "--relaxed disables strict mode (docstrings then only count in"
            & ASCII.LF
            & "source dirs, and patch overlays are inactive).  --skip-dir=NAME"
            & ASCII.LF
            & "adds a directory to the skip list in relaxed mode.");
      elsif T = "verbose" then
         Print_Section
           ("--verbose",
            "Print extra progress detail while scanning, proving, parsing,"
            & ASCII.LF
            & "and rendering.");
      elsif T = "version" then
         Print_Section
           ("--version",
            "Print the bundled version and exit.  The version source depends"
            & ASCII.LF
            & "on the installation method: ADACOVEX_VERSION (release builds),"
            & ASCII.LF
            & "then alire-dev.toml (source checkouts), then alire.toml.");
      elsif T = "cache"
        or else T = "no-cache"
        or else T = "cache-dir"
        or else T = "cache-max"
      then
         Print_Section
           ("--cache / --no-cache / --cache-dir / --cache-max",
            "Result caching: unchanged inputs are served from an on-disk"
            & ASCII.LF
            & "content-addressed cache (default on).  --cache-dir relocates"
            & ASCII.LF
            & "it; --cache-max caps entries before oldest-first eviction.");
      elsif T = "require-spark"
        or else T = "require-docstrings"
        or else T = "require-tests"
        or else T = "require-proof"
      then
         Print_Section
           ("--require-* CI gates",
            "Fail loudly (exit 1) when a pinned minimum is not met:"
            & ASCII.LF
            & "--require-spark=LVL, --require-docstrings=PCT,"
            & ASCII.LF
            & "--require-tests=N, --require-proof=PCT.  Default off.");
      else
         Print_Usage;
         Ada.Text_IO.Put_Line
           ("Unknown topic '" & Topic & "' -- showing full usage above.");
      end if;
   end Print_Topic_Help;

end Adacovex.Config;
