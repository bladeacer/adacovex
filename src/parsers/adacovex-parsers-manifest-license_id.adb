with Ada.Directories;

separate (Adacovex.Parsers.Manifest)
--  SPDX identifier for the licence file that ships beside an ecosystem
--  manifest. The file is located by name in Dir (LICENSE, LICENCE, and
--  COPYING, each with the .md and .txt suffixes the supported ecosystems
--  use), and its opening text is matched against a table of marker
--  phrases. A row matches when M1 is present, M2 is present (unless
--  empty), and NX is absent (unless empty), so an ambiguous text resolves
--  to nothing rather than to the wrong identifier: a four-clause BSD text
--  carries both the three-clause marker and the advertising clause, so it
--  matches no row and reports no licence.
--
--  Only the first 200 lines and 8 KB of the file are read: every marker
--  phrase lives in the title or the grant clause at the top of a licence
--  text. A licence that carries no marker (for example the GPL family,
--  whose only-versus-or-later choice adacovex cannot see from the text)
--  reports "". A licence is never guessed.
--  @param Dir  Directory that holds the ecosystem manifest.
--  @return The SPDX identifier, or "" when no licence file is present or
--  the text matches no marker.
function License_Id (Dir : String) return String is
   Mark_Len : constant := 80;
   Id_Len   : constant := 24;

   --  A marker phrase in a fixed-width field, with its used length. The
   --  phrase is space-padded so the row literal stays readable; the length
   --  is what the matcher reads, never the padding. An empty phrase (the
   --  literal "") has length 0 and never matches.
   subtype Phrase_Text is String (1 .. Mark_Len);
   type Phrase is record
      Text : Phrase_Text := (others => ' ');
      Len  : Natural := 0;
   end record;

   function P (S : String) return Phrase is
      R : Phrase;
   begin
      R.Len := S'Length;
      R.Text (1 .. S'Length) := S;
      return R;
   end P;

   --  An SPDX identifier in its fixed-width field, space-padded on the
   --  right, with its own length beside it. The length is derived from the
   --  identifier, never written out by hand, so it can never drift from
   --  the identifier it belongs to.
   type Id is record
      Text : String (1 .. Id_Len) := (others => ' ');
      Len  : Natural := 0;
   end record;

   function Id_Of (S : String) return Id is
      R : Id;
   begin
      R.Len := S'Length;
      R.Text (1 .. S'Length) := S;
      return R;
   end Id_Of;

   type Row is record
      M1   : Phrase;
      M2   : Phrase;
      NX   : Phrase;
      Spdx : Id;
   end record;

   Redist : constant String :=
     "Redistribution and use in source and binary forms";
   Unenc  : constant String :=
     "This is free and unencumbered software released into the public domain";
   Table  : constant array (1 .. 7) of Row :=
     (1 =>
        (M1   => P ("Apache License"),
         M2   => P ("Version 2.0"),
         NX   => P (""),
         Spdx => Id_Of ("Apache-2.0")),
      2 =>
        (M1   => P ("Mozilla Public License Version 2.0"),
         M2   => P (""),
         NX   => P (""),
         Spdx => Id_Of ("MPL-2.0")),
      3 =>
        (M1   => P ("Permission is hereby granted, free of charge"),
         M2   => P ("WITHOUT WARRANTY OF ANY KIND"),
         NX   => P (""),
         Spdx => Id_Of ("MIT")),
      4 =>
        (M1   => P (Redist),
         M2   => P ("Neither the name of"),
         NX   => P ("All advertising materials"),
         Spdx => Id_Of ("BSD-3-Clause")),
      5 =>
        (M1   => P (Redist),
         M2   => P (""),
         NX   => P ("Neither the name of"),
         Spdx => Id_Of ("BSD-2-Clause")),
      6 =>
        (M1   => P ("Permission to use, copy, modify, and/or distribute"),
         M2   => P (""),
         NX   => P (""),
         Spdx => Id_Of ("ISC")),
      7 =>
        (M1   => P (Unenc),
         M2   => P (""),
         NX   => P (""),
         Spdx => Id_Of ("Unlicense")));

   --  Candidate licence file names, in probe order. The bare name is
   --  probed first, then the .md and .txt spellings.
   subtype File_Name is String (1 .. 12);
   type File_Row is record
      Name : File_Name;
      Len  : Natural;
   end record;
   function F (S : String) return File_Row is
      R : File_Row;
   begin
      R.Len := S'Length;
      R.Name (1 .. S'Length) := S;
      return R;
   end F;

   Files : constant array (1 .. 9) of File_Row :=
     (1 => F ("LICENSE"),
      2 => F ("LICENCE"),
      3 => F ("COPYING"),
      4 => F ("LICENSE.md"),
      5 => F ("LICENCE.md"),
      6 => F ("COPYING.md"),
      7 => F ("LICENSE.txt"),
      8 => F ("LICENCE.txt"),
      9 => F ("COPYING.txt"));

   use Ada.Directories;
   use Ada.Strings.Fixed;
   use Ada.Text_IO;

   --  Whether Text carries the first Phrase.Len characters of Phrase. An
   --  empty phrase (Len = 0) is never present, so an empty M2 or NX
   --  behaves as the match rule above requires.
   function Has (Text : String; Ph : Phrase) return Boolean is
   begin
      return
        Ph.Len > 0
        and then Index
                   (Text,
                    Ph.Text (Ph.Text'First .. Ph.Text'First + Ph.Len - 1))
                 > 0;
   end Has;

   --  Read at most 200 lines of Path into Win, stopping at the window
   --  size. Returns the filled length; an unreadable file reads as 0.
   function Read_Head (Path : String; Win : out String) return Natural is
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      N        : Natural := 0;
   begin
      N := 0;
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return 0;
      end;
      while not End_Of_File (F) and then Line_Num < 200 loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            exit;
         end if;
         exit when N + Last + 1 > Win'Length;
         Win (N + 1 .. N + Last) := Line (1 .. Last);
         N := N + Last + 1;
         Win (N) := ASCII.LF;
      end loop;
      Close (F);
      return N;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         return N;
   end Read_Head;

   Win     : String (1 .. 8192) := (others => ' ');
   Win_Len : Natural := 0;
begin
   for FI in Files'Range loop
      declare
         P_Path : constant String :=
           Dir & "/" & Files (FI).Name (1 .. Files (FI).Len);
      begin
         if Exists (P_Path) then
            Win_Len := Read_Head (P_Path, Win);
            if Win_Len > 0 then
               declare
                  Text : constant String := Win (1 .. Win_Len);
               begin
                  for J in Table'Range loop
                     if Has (Text, Table (J).M1)
                       and then Has (Text, Table (J).M2)
                       and then not Has (Text, Table (J).NX)
                     then
                        return Table (J).Spdx.Text (1 .. Table (J).Spdx.Len);
                     end if;
                  end loop;
               end;
            end if;
            return "";
         end if;
      end;
   end loop;
   return "";
end License_Id;
