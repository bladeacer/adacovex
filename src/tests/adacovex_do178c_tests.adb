with Adacovex.Parsers;
with Adacovex.Parsers.DO178C;
with Adacovex.Types;
with Adacovex.Cache;
with Adacovex.CPUs;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Adacovex_Do178C_Tests is

   Fixture_Dir : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_do178c_test";
   Cache_Dir   : constant String := Fixture_Dir & "/cache";

   --  Write a fixture file with exactly the given content.
   --  @param Name  File name inside the fixture directory.
   --  @param Text  Exact file content.
   procedure Write_File (Name : String; Text : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Fixture_Dir & "/" & Name);
      Ada.Text_IO.Put (F, Text);
      Ada.Text_IO.Close (F);
   end Write_File;

   --  True when Needle appears in Haystack.
   --  @param Haystack  Text to search.
   --  @param Needle  Substring to look for.
   --  @return True when the substring is present.
   function Contains (Haystack : String; Needle : String) return Boolean is
   begin
      if Needle'Length = 0 or else Needle'Length > Haystack'Length then
         return False;
      end if;
      for I in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
         if Haystack (I .. I + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   --  The identifier of a parsed HLR entry, trimmed to its length.
   --  @param E  Parsed HLR entry.
   --  @return The identifier text.
   function Id_Of (E : Adacovex.Parsers.DO178C.HLR_Info) return String is
   begin
      return E.Id (1 .. E.Id_Len);
   end Id_Of;

   --  The description of a parsed HLR entry, trimmed to its length.
   --  @param E  Parsed HLR entry.
   --  @return The description text.
   function Desc_Of (E : Adacovex.Parsers.DO178C.HLR_Info) return String is
   begin
      return E.Desc (1 .. E.D_Len);
   end Desc_Of;

   --  The identifier of a parsed LLR entry, trimmed to its length.
   --  @param E  Parsed LLR entry.
   --  @return The identifier text.
   function Id_Of (E : Adacovex.Parsers.DO178C.LLR_Info) return String is
   begin
      return E.Id (1 .. E.Id_Len);
   end Id_Of;

   --  The HLR reference of a parsed LLR entry, trimmed to its length.
   --  @param E  Parsed LLR entry.
   --  @return The referenced HLR identifier text.
   function Ref_Of (E : Adacovex.Parsers.DO178C.LLR_Info) return String is
   begin
      return E.HLR_Ref (1 .. E.HLR_Len);
   end Ref_Of;

   --  The description of a parsed LLR entry, trimmed to its length.
   --  @param E  Parsed LLR entry.
   --  @return The description text.
   function Desc_Of (E : Adacovex.Parsers.DO178C.LLR_Info) return String is
   begin
      return E.Desc (1 .. E.D_Len);
   end Desc_Of;

   --  The documented on-disk cache key for an HLR.md file.
   --  @param Path  Requirements file path.
   --  @return The "hlr:"-prefixed content-hash key.
   function HLR_Key (Path : String) return String is
   begin
      return "hlr:" & Adacovex.Cache.Hash_File (Path);
   end HLR_Key;

   --  Restore the default cache root after a cache test.
   procedure Restore_Cache_Dir is
      D : String (1 .. 4096);
      L : Natural;
   begin
      Adacovex.Cache.Default_Cache_Dir (D, L);
      Adacovex.Cache.Set_Cache_Dir (D (1 .. L));
   end Restore_Cache_Dir;

   --  A package vector holding one package with the given HLR tags.
   --  @param Tags  Space-separated HLR tag identifiers.
   --  @return The package vector.
   function Packages_With
     (Tags : String)
      return Adacovex.Types.Implementation.Package_Vectors.Vector
   is
      use Adacovex.Types;
      V     : Adacovex.Types.Implementation.Package_Vectors.Vector;
      P     : Adacovex.Types.Implementation.Package_Info;
      T     : Adacovex.Types.HLR_Tag_Entry;
      Start : Natural := Tags'First;
   begin
      P.Name_Len := 6;
      P.Name (1 .. 6) := "Sample";
      P.Path_Len := 12;
      P.File_Path (1 .. 12) := "sample.ads  ";

      for I in Tags'Range loop
         if Tags (I) = ' ' or else I = Tags'Last then
            declare
               Stop : constant Natural :=
                 (if Tags (I) = ' ' then I - 1 else I);
            begin
               if Stop >= Start then
                  T.Len := Stop - Start + 1;
                  T.Tag (1 .. T.Len) := Tags (Start .. Stop);
                  P.HLR_Tags.Append (T);
               end if;
               Start := I + 1;
            end;
         end if;
      end loop;

      V.Append (P);
      return V;
   end Packages_With;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Adacovex.Parsers.DO178C;
      LF : constant String := String'(1 => ASCII.LF);
   begin
      if Ada.Directories.Exists (Fixture_Dir) then
         Ada.Directories.Delete_Tree (Fixture_Dir);
      end if;
      Ada.Directories.Create_Directory (Fixture_Dir);

      --  The shared line reader: a short line, an over-long line that is
      --  reported and drained, and the line after it.
      Write_File
        ("lines.txt",
         "short" & LF & "01234567890123456789" & LF & "after" & LF);
      Write_File ("exact.txt", "0123456789abcdef" & LF & "next" & LF);
      Write_File ("tail.txt", "0123456789abcdef");

      --  The overflow diagnostic itself goes to the process standard error
      --  (the suite shows other overflow messages the same way), so these
      --  checks pin the observable contract: the flag, the buffer fill, and
      --  the stream position after the drain.
      declare
         F    : Ada.Text_IO.File_Type;
         Line : String (1 .. 16);
         Last : Natural;
         Ovf  : Boolean;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Fixture_Dir & "/lines.txt");
         Adacovex.Parsers.Read_Line (F, "lines.txt", 1, Line, Last, Ovf);
         R.Check
           (not Ovf and then Last = 5 and then Line (1 .. 5) = "short",
            "a line shorter than the buffer reads normally");

         Adacovex.Parsers.Read_Line (F, "lines.txt", 2, Line, Last, Ovf);
         R.Check (Ovf, "a line longer than the buffer reports overflow");
         R.Check (Last = 16, "an over-long line fills the whole buffer");

         Adacovex.Parsers.Read_Line (F, "lines.txt", 3, Line, Last, Ovf);
         R.Check
           (not Ovf and then Line (1 .. 5) = "after",
            "the reader is positioned at the next line after a drain");
         Ada.Text_IO.Close (F);

         --  A line that exactly fills the buffer is not an overflow, and
         --  it must not leave a spurious empty line behind.
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Fixture_Dir & "/exact.txt");
         Adacovex.Parsers.Read_Line (F, "exact.txt", 1, Line, Last, Ovf);
         R.Check
           (not Ovf and then Last = 16,
            "a line that exactly fills the buffer is not an overflow");
         Adacovex.Parsers.Read_Line (F, "exact.txt", 2, Line, Last, Ovf);
         R.Check
           (not Ovf and then Last = 4 and then Line (1 .. 4) = "next",
            "the line after a full-buffer line reads normally");
         Ada.Text_IO.Close (F);

         --  The same line at end of file, without a terminator.
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Fixture_Dir & "/tail.txt");
         Adacovex.Parsers.Read_Line (F, "tail.txt", 1, Line, Last, Ovf);
         R.Check
           (not Ovf and then Last = 16 and then Ada.Text_IO.End_Of_File (F),
            "a full-buffer last line without a terminator reads cleanly");
         Ada.Text_IO.Close (F);
      end;

      --  HLR parsing: tagged entries are collected, prose is ignored.
      Write_File
        ("HLR.md",
         "# High-Level Requirements"
         & LF
         & LF
         & "- HLR-ARCH: Architecture and build system"
         & LF
         & "- HLR-CACHE: Result caching"
         & LF
         & "Prose without a tag."
         & LF
         & "- HLR-SCAN: Ada source scanning"
         & LF);

      declare
         HLRs : Adacovex.Parsers.DO178C.HLR_Vectors.Vector;
         OK   : Boolean;
      begin
         Parse_HLR_MD (Fixture_Dir & "/HLR.md", HLRs, OK);
         R.Check (OK, "an HLR.md fixture parses");
         R.Check
           (Natural (HLRs.Length) = 3,
            "only the three tagged lines become HLR entries");
         R.Check (Id_Of (HLRs (1)) = "ARCH", "the first HLR id is parsed");
         R.Check
           (Desc_Of (HLRs (1)) = "Architecture and build system",
            "the first HLR description is parsed");
         R.Check (Id_Of (HLRs (2)) = "CACHE", "the second HLR id is parsed");
         R.Check (Id_Of (HLRs (3)) = "SCAN", "the third HLR id is parsed");
      end;

      --  LLR parsing: entries carry their HLR reference, and the reference
      --  itself never leaks into the description.
      Write_File
        ("LLR.md",
         "# Low-Level Requirements"
         & LF
         & LF
         & "- LLR-ARCH-01: `alire.toml` shall declare metadata [HLR-ARCH]"
         & LF
         & "- LLR-SCAN-01: Scan_Project shall walk directories [HLR-SCAN]"
         & LF);

      declare
         LLRs : Adacovex.Parsers.DO178C.LLR_Vectors.Vector;
         OK   : Boolean;
      begin
         Parse_LLR_MD (Fixture_Dir & "/LLR.md", LLRs, OK);
         R.Check (OK, "an LLR.md fixture parses");
         R.Check (Natural (LLRs.Length) = 2, "two LLR entries are collected");
         R.Check (Id_Of (LLRs (1)) = "ARCH-01", "the LLR id is parsed");
         R.Check
           (Ref_Of (LLRs (1)) = "ARCH", "the LLR carries its HLR reference");
         R.Check
           (Contains (Desc_Of (LLRs (1)), "shall declare metadata"),
            "the LLR description is parsed");
         R.Check
           (not Contains (Desc_Of (LLRs (1)), "[HLR-ARCH]"),
            "the HLR reference is stripped from the description");
         R.Check
           (Ref_Of (LLRs (2)) = "SCAN",
            "the second LLR carries its own reference");
      end;

      --  A missing requirements file is a parse failure, not an exception.
      declare
         HLRs : Adacovex.Parsers.DO178C.HLR_Vectors.Vector;
         LLRs : Adacovex.Parsers.DO178C.LLR_Vectors.Vector;
         OK   : Boolean;
      begin
         Parse_HLR_MD (Fixture_Dir & "/missing-HLR.md", HLRs, OK);
         R.Check (not OK, "a missing HLR.md reports failure");
         R.Check (HLRs.Is_Empty, "a failed HLR parse leaves the vector empty");
         Parse_LLR_MD (Fixture_Dir & "/missing-LLR.md", LLRs, OK);
         R.Check (not OK, "a missing LLR.md reports failure");
      end;

      --  Cached parse: the first pass stores the documented key, and the
      --  second pass serves the same entries.
      Ada.Directories.Create_Directory (Cache_Dir);
      Adacovex.Cache.Set_Cache_Dir (Cache_Dir);
      declare
         Blob  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
         Blen  : Natural;
         Found : Boolean;
      begin
         declare
            HLRs : Adacovex.Parsers.DO178C.HLR_Vectors.Vector;
            OK   : Boolean;
         begin
            Parse_HLR_MD
              (Fixture_Dir & "/HLR.md", HLRs, OK, Use_Cache => True);
            R.Check
              (OK and then Natural (HLRs.Length) = 3,
               "a cached HLR parse still returns every entry");
         end;

         Adacovex.Cache.Get_Cached
           (HLR_Key (Fixture_Dir & "/HLR.md"), Blob, Blen, Found);
         R.Check (Found, "the parsed HLR set is stored under its cache key");
         R.Check (Blen > 0, "the stored HLR blob is not empty");

         declare
            HLRs : Adacovex.Parsers.DO178C.HLR_Vectors.Vector;
            OK   : Boolean;
         begin
            Parse_HLR_MD
              (Fixture_Dir & "/HLR.md", HLRs, OK, Use_Cache => True);
            R.Check (OK, "the cached HLR set deserializes");
            R.Check
              (Natural (HLRs.Length) = 3 and then Id_Of (HLRs (1)) = "ARCH",
               "the cached HLR set matches the parsed one");
         end;
      end;
      Restore_Cache_Dir;

      --  Source tag matching over the scanned package set.
      declare
         HLRs : Adacovex.Parsers.DO178C.HLR_Vectors.Vector;
         OK   : Boolean;
      begin
         Parse_HLR_MD (Fixture_Dir & "/HLR.md", HLRs, OK);
         R.Check
           (Natural (HLRs.Length) = 3, "the fixture parses for tag matching");
      end;

      declare
         Pkgs  :
           constant Adacovex.Types.Implementation.Package_Vectors.Vector :=
             Packages_With ("ARCH CACHE");
         Empty : Adacovex.Types.Implementation.Package_Vectors.Vector;
      begin
         R.Check
           (Find_HLR_In_Source ("ARCH", Pkgs),
            "a traced HLR tag is found in the scanned sources");
         R.Check
           (Find_HLR_In_Source ("CACHE", Pkgs),
            "every traced HLR tag is found");
         R.Check
           (not Find_HLR_In_Source ("TEST", Pkgs),
            "an untraced HLR identifier is not found");
         R.Check
           (not Find_HLR_In_Source ("ARCH", Empty),
            "an untraced HLR is not found in an empty package set");
      end;

      Ada.Directories.Delete_Tree (Fixture_Dir);
   end Run;

end Adacovex_Do178C_Tests;
