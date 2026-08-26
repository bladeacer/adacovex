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
procedure Resolve_Ecosystem_Metadata
  (Ecosystem : String;
   Name      : String;
   License   : out Types.Desc_Field;
   Lic_Len   : out Natural;
   Version   : out Types.Desc_Field;
   Ver_Len   : out Natural;
   Website   : out Types.Path_Field;
   Web_Len   : out Natural)
is
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
      V      : Eco_Field;
      L      : Eco_Field;
      W      : Eco_Field;
      Single : Boolean;
      Json   : Boolean := False;
   end record;

   Table : constant array (1 .. 5) of Eco_Query :=
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
         Single => True,
         Json   => True),
      3 =>
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
         Json   => False,
         Single => False),
      4 =>
        (Kind   => "go" & (3 .. 7 => ' '),
         KLen   => 2,
         Tool   => (others => ' '),
         TLen   => 0,
         Sub    => (others => ' '),
         SLen   => 0,
         V      => (Field => (others => ' '), FLen => 0, Fmt => Eco_Bare),
         L      => (Field => (others => ' '), FLen => 0, Fmt => Eco_Bare),
         W      => (Field => (others => ' '), FLen => 0, Fmt => Eco_Bare),
         Json   => False,
         Single => False),
      5 =>
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
   for I in Table'Range loop
      if Table (I).KLen = Ecosystem'Length
        and then Table (I).Kind (1 .. Table (I).KLen) = Ecosystem
      then
         if Table (I).TLen = 0 then
            return;  --  no reliable registry CLI for this ecosystem

         end if;
         Exe := Locate_Exec_On_Path (Table (I).Tool (1 .. Table (I).TLen));
         if Exe = null then
            return;
         end if;
         if Table (I).Single then
            if Table (I).Json then
               --  One JSON spawn answers for every field at once, so the
               --  resolver boots node/pnpm only once per component instead of
               --  once per field.  This is the dominant responsiveness win
               --  for npm/pnpm vendored trees.
               declare
                  Args : Argument_List (1 .. 6);
               begin
                  Args (1) := new String'(Table (I).Sub (1 .. Table (I).SLen));
                  Args (2) := new String'(Name);
                  Args (3) := new String'("version");
                  Args (4) := new String'("license");
                  Args (5) := new String'("homepage");
                  Args (6) := new String'("--json");
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
                  Free (Args (3));
                  Free (Args (4));
                  Free (Args (5));
                  Free (Args (6));
               end;
               declare
                  V : constant String := Json_Value ("version");
               begin
                  Set_Field (Version, Ver_Len, V);
               end;
               declare
                  V : constant String := Json_Value ("license");
               begin
                  Set_Field (License, Lic_Len, V);
               end;
               declare
                  V : constant String := Json_Value ("homepage");
               begin
                  Set_Path (Website, Web_Len, V);
               end;
            else
               declare
                  Args : Argument_List (1 .. 2);
               begin
                  Args (1) := new String'(Table (I).Sub (1 .. Table (I).SLen));
                  Args (2) := new String'(Name);
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
               end;
               Extract_Desc (Table (I).V, Version, Ver_Len);
               Extract_Desc (Table (I).L, License, Lic_Len);
               Extract_Path (Table (I).W, Website, Web_Len);
            end if;
         else
            if Table (I).V.FLen > 0 then
               declare
                  Args : Argument_List (1 .. 3);
               begin
                  Args (1) := new String'(Table (I).Sub (1 .. Table (I).SLen));
                  Args (2) := new String'(Name);
                  Args (3) :=
                    new String'(Table (I).V.Field (1 .. Table (I).V.FLen));
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
                  Free (Args (3));
               end;
               Extract_Desc (Table (I).V, Version, Ver_Len);
            end if;
            if Table (I).L.FLen > 0 then
               declare
                  Args : Argument_List (1 .. 3);
               begin
                  Args (1) := new String'(Table (I).Sub (1 .. Table (I).SLen));
                  Args (2) := new String'(Name);
                  Args (3) :=
                    new String'(Table (I).L.Field (1 .. Table (I).L.FLen));
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
                  Free (Args (3));
               end;
               Extract_Desc (Table (I).L, License, Lic_Len);
            end if;
            if Table (I).W.FLen > 0 then
               declare
                  Args : Argument_List (1 .. 3);
               begin
                  Args (1) := new String'(Table (I).Sub (1 .. Table (I).SLen));
                  Args (2) := new String'(Name);
                  Args (3) :=
                    new String'(Table (I).W.Field (1 .. Table (I).W.FLen));
                  Capture (Args);
                  Free (Args (1));
                  Free (Args (2));
                  Free (Args (3));
               end;
               Extract_Path (Table (I).W, Website, Web_Len);
            end if;
         end if;
         Free (Exe);
         return;
      end if;
   end loop;
end Resolve_Ecosystem_Metadata;
