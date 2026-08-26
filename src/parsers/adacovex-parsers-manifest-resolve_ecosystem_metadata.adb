with Ada.Directories;

separate (Adacovex.Parsers.Manifest)
--  Resolve a component's version, licence and website from its ecosystem
--  registry CLI, table-driven across every supported ecosystem.  The
--  dispatch table below lists the CLI tool, its subcommand, and -- per
--  metadata field -- the registry key to query and how to parse the value
--  out of the command output.  Adding an ecosystem is a one-row edit.
--
--  Ecosystems with no reliable registry CLI (for example go) carry an empty
--  tool so the resolver returns quietly and the vendored-manifest scanner
--  still reads any in-repo licence file.  The alr row folds the former
--  Alr_Show_Crate path into the same table: one `alr show` answers for
--  version, licence and website without network access.  The npm and pnpm
--  rows issue a single `view <pkg> version license homepage --json` call and
--  parse the JSON, so they boot node only once per component instead of once
--  per field -- the main responsiveness win for vendored JavaScript trees.
--
--  The resolved answer is cached per project (under the project's result
--  cache, keyed by the target directory) so a warm run never spawns a
--  registry CLI and one project never serves another's licence or version.
procedure Resolve_Ecosystem_Metadata
  (Target    : String;
   Ecosystem : String;
   Name      : String;
   License   : out Types.Desc_Field;
   Lic_Len   : out Natural;
   Version   : out Types.Desc_Field;
   Ver_Len   : out Natural;
   Website   : out Types.Path_Field;
   Web_Len   : out Natural)
is
   function Norm_Target (S : String) return String is
   begin
      if S'Length = 0 then
         return S;
      end if;
      return Ada.Directories.Full_Name (S);
   exception
      when others =>
         return S;
   end Norm_Target;

   Target_Norm : constant String := Norm_Target (Target);
   type Eco_Field_Fmt is (Eco_Bare, Eco_Colon, Eco_Token);

   type Eco_Field is record
      Field : String (1 .. 16);
      FLen  : Natural;
      Fmt   : Eco_Field_Fmt;
   end record;

   type Eco_Query is record
      Kind   : String (1 .. 7);
      KLen   : Natural;
      Tool   : String (1 .. 8);
      TLen   : Natural;
      Sub    : String (1 .. 8);
      SLen   : Natural;
      Sub2   : String (1 .. 8) := (others => ' ');
      Sub2Ln : Natural := 0;
      V      : Eco_Field;
      L      : Eco_Field;
      W      : Eco_Field;
      Single : Boolean;
      Json   : Boolean := False;
   end record;

   Table : constant array (1 .. 7) of Eco_Query :=
     (1 =>
        (Kind   => "npm" & (4 .. 7 => ' '),
         KLen   => 3,
         Tool   => "npm" & (4 .. 8 => ' '),
         TLen   => 3,
         Sub    => "view" & (5 .. 8 => ' '),
         SLen   => 4,
         V      =>
           (Field => "version" & (8 .. 16 => ' '), FLen => 7, Fmt => Eco_Bare),
         L      =>
           (Field => "license" & (8 .. 16 => ' '), FLen => 7, Fmt => Eco_Bare),
         W      =>
           (Field => "homepage" & (9 .. 16 => ' '),
            FLen  => 8,
            Fmt   => Eco_Bare),
         Sub2   => (others => ' '),
         Sub2Ln => 0,
         Single => True,
         Json   => True),
      2 =>
        (Kind   => "pnpm" & (5 .. 7 => ' '),
         KLen   => 4,
         Tool   => "pnpm" & (5 .. 8 => ' '),
         TLen   => 4,
         Sub    => "view" & (5 .. 8 => ' '),
         SLen   => 4,
         V      =>
           (Field => "version" & (8 .. 16 => ' '), FLen => 7, Fmt => Eco_Bare),
         L      =>
           (Field => "license" & (8 .. 16 => ' '), FLen => 7, Fmt => Eco_Bare),
         W      =>
           (Field => "homepage" & (9 .. 16 => ' '),
            FLen  => 8,
            Fmt   => Eco_Bare),
         Sub2   => (others => ' '),
         Sub2Ln => 0,
         Single => True,
         Json   => True),
      3 =>
        (Kind   => "yarn" & (5 .. 7 => ' '),
         KLen   => 4,
         Tool   => "yarn" & (5 .. 8 => ' '),
         TLen   => 4,
         Sub    => "npm" & (4 .. 8 => ' '),
         SLen   => 3,
         Sub2   => "info" & (5 .. 8 => ' '),
         Sub2Ln => 4,
         V      =>
           (Field => "version" & (8 .. 16 => ' '), FLen => 7, Fmt => Eco_Bare),
         L      =>
           (Field => "license" & (8 .. 16 => ' '), FLen => 7, Fmt => Eco_Bare),
         W      =>
           (Field => "homepage" & (9 .. 16 => ' '),
            FLen  => 8,
            Fmt   => Eco_Bare),
         Single => True,
         Json   => True),
      4 =>
        (Kind   => "bun" & (4 .. 7 => ' '),
         KLen   => 3,
         Tool   => "bun" & (4 .. 8 => ' '),
         TLen   => 3,
         Sub    => "pm" & (3 .. 8 => ' '),
         SLen   => 2,
         Sub2   => "view" & (5 .. 8 => ' '),
         Sub2Ln => 4,
         V      =>
           (Field => "version" & (8 .. 16 => ' '), FLen => 7, Fmt => Eco_Bare),
         L      =>
           (Field => "license" & (8 .. 16 => ' '), FLen => 7, Fmt => Eco_Bare),
         W      =>
           (Field => "homepage" & (9 .. 16 => ' '),
            FLen  => 8,
            Fmt   => Eco_Bare),
         Single => True,
         Json   => True),
      5 =>
        (Kind   => "cargo" & (6 .. 7 => ' '),
         KLen   => 5,
         Tool   => "cargo" & (6 .. 8 => ' '),
         TLen   => 5,
         Sub    => "search" & (7 .. 8 => ' '),
         SLen   => 6,
         V      => (Field => (others => ' '), FLen => 0, Fmt => Eco_Bare),
         L      =>
           (Field => "license" & (8 .. 16 => ' '),
            FLen  => 7,
            Fmt   => Eco_Token),
         W      => (Field => (others => ' '), FLen => 0, Fmt => Eco_Bare),
         Sub2   => (others => ' '),
         Sub2Ln => 0,
         Json   => False,
         Single => False),
      6 =>
        (Kind   => "go" & (3 .. 7 => ' '),
         KLen   => 2,
         Tool   => (others => ' '),
         TLen   => 0,
         Sub    => (others => ' '),
         SLen   => 0,
         V      => (Field => (others => ' '), FLen => 0, Fmt => Eco_Bare),
         L      => (Field => (others => ' '), FLen => 0, Fmt => Eco_Bare),
         W      => (Field => (others => ' '), FLen => 0, Fmt => Eco_Bare),
         Sub2   => (others => ' '),
         Sub2Ln => 0,
         Json   => False,
         Single => False),
      7 =>
        (Kind   => "alire" & (6 .. 7 => ' '),
         KLen   => 5,
         Tool   => "alr" & (4 .. 8 => ' '),
         TLen   => 3,
         Sub    => "show" & (5 .. 8 => ' '),
         SLen   => 4,
         V      =>
           (Field => "Version" & (8 .. 16 => ' '),
            FLen  => 7,
            Fmt   => Eco_Colon),
         L      =>
           (Field => "Licenses" & (9 .. 16 => ' '),
            FLen  => 8,
            Fmt   => Eco_Colon),
         W      =>
           (Field => "Website" & (8 .. 16 => ' '),
            FLen  => 7,
            Fmt   => Eco_Colon),
         Sub2   => (others => ' '),
         Sub2Ln => 0,
         Json   => False,
         Single => True));

   Pid     : constant Integer := Pid_To_Integer (Current_Process_Id);
   Pid_Img : constant String := Integer'Image (Pid);
   Tmp     : constant String :=
     Adacovex.CPUs.Get_Temp_Directory
     & "/adacovex-eco-"
     & Pid_Img (2 .. Pid_Img'Last)
     & ".out";
   Buf     : String (1 .. 16384);
   BLen    : Natural := 0;
   F       : Ada.Text_IO.File_Type;
   OK      : Boolean;
   Code    : Integer;
   Exe     : String_Access;

   procedure Capture (Args : Argument_List) is
   begin
      BLen := 0;
      Spawn (Exe.all, Args, Tmp, OK, Code, Err_To_Out => True);
      if not OK then
         return;
      end if;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Tmp);
         while not Ada.Text_IO.End_Of_File (F) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (F);
            begin
               for C in Line'Range loop
                  if BLen < Buf'Last then
                     BLen := BLen + 1;
                     Buf (BLen) := Line (C);
                  end if;
               end loop;
               if BLen < Buf'Last then
                  BLen := BLen + 1;
                  Buf (BLen) := ASCII.LF;
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
   end Capture;

   procedure Extract_Desc
     (Fld : Eco_Field; Dst : out Types.Desc_Field; DLn : out Natural)
   is
      S : constant String := Buf (1 .. BLen);
      I : Natural := S'First;
   begin
      DLn := 0;
      while I <= S'Last loop
         declare
            J : Natural := I;
         begin
            while J <= S'Last and then S (J) /= ASCII.LF loop
               J := J + 1;
            end loop;
            declare
               T : constant String :=
                 (if J > S'First then Trim (S (I .. J - 1)) else "");
            begin
               if DLn = 0 and then T'Length > 0 then
                  if Fld.Fmt = Eco_Colon or else Fld.Fmt = Eco_Token then
                     if T'Length > Fld.FLen + 1
                       and then T (T'First .. T'First + Fld.FLen - 1)
                                = Fld.Field
                       and then T (T'First + Fld.FLen) = ':'
                     then
                        declare
                           A : Natural := T'First + Fld.FLen + 1;
                           B : Natural := T'Last;
                        begin
                           while A <= B
                             and then (T (A) = ' ' or else T (A) = ASCII.HT)
                           loop
                              A := A + 1;
                           end loop;
                           if Fld.Fmt = Eco_Token then
                              while B >= A and then T (B) /= ')' loop
                                 B := B - 1;
                              end loop;
                              B := B - 1;
                           end if;
                           if A <= B then
                              Set_Field (Dst, DLn, Trim (T (A .. B)));
                           end if;
                        end;
                     end if;
                  else
                     --  Eco_Bare: first non-empty line wins
                     Set_Field (Dst, DLn, T);
                  end if;
               end if;
            end;
            I := J + 1;
         end;
      end loop;
   end Extract_Desc;

   procedure Extract_Path
     (Fld : Eco_Field; Dst : out Types.Path_Field; DLn : out Natural)
   is
      S : constant String := Buf (1 .. BLen);
      I : Natural := S'First;
   begin
      DLn := 0;
      while I <= S'Last loop
         declare
            J : Natural := I;
         begin
            while J <= S'Last and then S (J) /= ASCII.LF loop
               J := J + 1;
            end loop;
            declare
               T : constant String :=
                 (if J > S'First then Trim (S (I .. J - 1)) else "");
            begin
               if DLn = 0 and then T'Length > 0 then
                  if T'Length > Fld.FLen + 1
                    and then T (T'First .. T'First + Fld.FLen - 1) = Fld.Field
                    and then T (T'First + Fld.FLen) = ':'
                  then
                     declare
                        A : Natural := T'First + Fld.FLen + 1;
                        B : Natural := T'Last;
                     begin
                        while A <= B
                          and then (T (A) = ' ' or else T (A) = ASCII.HT)
                        loop
                           A := A + 1;
                        end loop;
                        if A <= B then
                           Set_Path (Dst, DLn, Trim (T (A .. B)));
                        end if;
                     end;
                  end if;
               end if;
            end;
            I := J + 1;
         end;
      end loop;
   end Extract_Path;

   --  Return the quoted string value for "Key" inside a JSON object held in
   --  Buf (for example "version": "1.2.3").  "" when the key is absent or
   --  not a string.  A single --json spawn answers for every field, so this
   --  is the only parse path for npm/pnpm.
   function Json_Value (Key : String) return String is
      S  : constant String := Buf (1 .. BLen);
      KT : constant String := '"' & Key & '"';
      P  : constant Natural := Ada.Strings.Fixed.Index (S, KT);
      Q  : Natural;
      R  : Natural;
   begin
      if P = 0 then
         return "";
      end if;
      Q := P + KT'Length;
      while Q <= S'Last and then S (Q) /= ':' loop
         Q := Q + 1;
      end loop;
      if Q > S'Last then
         return "";
      end if;
      Q := Q + 1;
      while Q <= S'Last and then (S (Q) = ' ' or else S (Q) = ASCII.HT) loop
         Q := Q + 1;
      end loop;
      if Q > S'Last or else S (Q) /= '"' then
         return "";
      end if;
      R := Q + 1;
      while R <= S'Last and then S (R) /= '"' loop
         R := R + 1;
      end loop;
      if R > S'Last then
         return "";
      end if;
      return S (Q + 1 .. R - 1);
   end Json_Value;

begin
   Lic_Len := 0;
   Ver_Len := 0;
   Web_Len := 0;
   if Ecosystem'Length = 0 or else Name'Length = 0 then
      return;
   end if;

   --  Serve from the per-project metadata cache (stored in the project's
   --  result cache, keyed by the target directory, same 7-day TTL as the
   --  system-tool probes) so a warm run never spawns a registry CLI.  This
   --  is what makes `make prove` responsive on the second run: the registry
   --  calls (node for npm/pnpm) are the one cost the content-addressed
   --  result cache does not cover, so without this layer they re-ran every
   --  invocation.
   declare
      Found : Boolean;
   begin
      Adacovex.Cache.Get_Meta
        (Target_Norm,
         Ecosystem,
         Name,
         License,
         Lic_Len,
         Version,
         Ver_Len,
         Website,
         Web_Len,
         Found);
      if Found then
         return;
      end if;
   end;

   declare
      --  Resolve one table row into the out parameters.  Returns Got = True
      --  when the spawn produced at least one field (so the caller can stop
      --  and cache).  Resets the out lengths first so a failed attempt does
      --  not leak fields from a previous candidate.
      procedure Resolve_One (J : Positive; Got : out Boolean) is
      begin
         Got := False;
         Lic_Len := 0;
         Ver_Len := 0;
         Web_Len := 0;
         if Table (J).TLen = 0 then
            return;  --  no reliable registry CLI for this ecosystem

         end if;
         Exe := Locate_Exec_On_Path (Table (J).Tool (1 .. Table (J).TLen));
         if Exe = null then
            return;
         end if;
         if Table (J).Single then
            if Table (J).Json then
               --  One JSON spawn answers for every field at once, so the
               --  resolver boots node/pnpm only once per component instead of
               --  once per field.  The optional Sub2 (for example yarn's
               --  `npm info`) is appended before the package name.
               declare
                  Has_Sub2 : constant Boolean := Table (J).Sub2Ln > 0;
                  Args     : Argument_List (1 .. (if Has_Sub2 then 7 else 6));
                  N        : Natural := 0;
                  procedure Add (S : String) is
                  begin
                     N := N + 1;
                     Args (N) := new String'(S);
                  end Add;
               begin
                  Add (Table (J).Sub (1 .. Table (J).SLen));
                  if Has_Sub2 then
                     Add (Table (J).Sub2 (1 .. Table (J).Sub2Ln));
                  end if;
                  Add (Name);
                  Add ("version");
                  Add ("license");
                  Add ("homepage");
                  Add ("--json");
                  Capture (Args (1 .. N));
                  for X in 1 .. N loop
                     Free (Args (X));
                  end loop;
               end;
               Set_Field (Version, Ver_Len, Json_Value ("version"));
               Set_Field (License, Lic_Len, Json_Value ("license"));
               Set_Path (Website, Web_Len, Json_Value ("homepage"));
            else
               declare
                  Args : Argument_List (1 .. 2);
               begin
                  Args (1) := new String'(Table (J).Sub (1 .. Table (J).SLen));
                  Args (2) := new String'(Name);
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
               end;
               Extract_Desc (Table (J).V, Version, Ver_Len);
               Extract_Desc (Table (J).L, License, Lic_Len);
               Extract_Path (Table (J).W, Website, Web_Len);
            end if;
         else
            if Table (J).V.FLen > 0 then
               declare
                  Args : Argument_List (1 .. 3);
               begin
                  Args (1) := new String'(Table (J).Sub (1 .. Table (J).SLen));
                  Args (2) := new String'(Name);
                  Args (3) :=
                    new String'(Table (J).V.Field (1 .. Table (J).V.FLen));
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
                  Free (Args (3));
               end;
               Extract_Desc (Table (J).V, Version, Ver_Len);
            end if;
            if Table (J).L.FLen > 0 then
               declare
                  Args : Argument_List (1 .. 3);
               begin
                  Args (1) := new String'(Table (J).Sub (1 .. Table (J).SLen));
                  Args (2) := new String'(Name);
                  Args (3) :=
                    new String'(Table (J).L.Field (1 .. Table (J).L.FLen));
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
                  Free (Args (3));
               end;
               Extract_Desc (Table (J).L, License, Lic_Len);
            end if;
            if Table (J).W.FLen > 0 then
               declare
                  Args : Argument_List (1 .. 3);
               begin
                  Args (1) := new String'(Table (J).Sub (1 .. Table (J).SLen));
                  Args (2) := new String'(Name);
                  Args (3) :=
                    new String'(Table (J).W.Field (1 .. Table (J).W.FLen));
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
                  Free (Args (3));
               end;
               Extract_Path (Table (J).W, Website, Web_Len);
            end if;
         end if;
         Free (Exe);
         Got := (Lic_Len > 0 or else Ver_Len > 0 or else Web_Len > 0);
      end Resolve_One;

      Is_Js    : constant Boolean :=
        Ecosystem = "npm"
        or else Ecosystem = "pnpm"
        or else Ecosystem = "yarn"
        or else Ecosystem = "bun";
      Js_Order : constant array (1 .. 4) of String (1 .. 7) :=
        ("pnpm   ", "npm    ", "yarn   ", "bun    ");
      Got      : Boolean := False;
      J        : Natural := 0;
   begin
      if Is_Js then
         --  JavaScript packages resolve through whichever package manager is
         --  installed, preferring pnpm, then npm, then yarn, then bun.  The
         --  first manager that answers wins; a missing or failing manager
         --  falls through to the next without costing a correct answer.
         for K in Js_Order'Range loop
            J := 0;
            for I in Table'Range loop
               if Table (I).KLen > 0
                 and then Table (I).Kind (1 .. Table (I).KLen)
                          = Js_Order (K) (1 .. Table (I).KLen)
               then
                  J := I;
                  exit;
               end if;
            end loop;
            if J /= 0 then
               Resolve_One (J, Got);
               if Got then
                  Adacovex.Cache.Put_Meta
                    (Target_Norm,
                     Ecosystem,
                     Name,
                     License (1 .. Lic_Len),
                     Version (1 .. Ver_Len),
                     Website (1 .. Web_Len));
                  return;
               end if;
            end if;
         end loop;
      else
         for I in Table'Range loop
            if Table (I).KLen = Ecosystem'Length
              and then Table (I).Kind (1 .. Table (I).KLen) = Ecosystem
            then
               Resolve_One (I, Got);
               if Got then
                  Adacovex.Cache.Put_Meta
                    (Target_Norm,
                     Ecosystem,
                     Name,
                     License (1 .. Lic_Len),
                     Version (1 .. Ver_Len),
                     Website (1 .. Web_Len));
               end if;
               return;
            end if;
         end loop;
      end if;
   end;
end Resolve_Ecosystem_Metadata;
