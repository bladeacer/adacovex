with Ada.Text_IO;
with Ada.Characters.Handling;

package body Adacovex.Opt_Outs is

   use Ada.Characters.Handling;

   Max_Header_Lines : constant := 24;

   --  Trim leading/trailing blanks, tabs, CR, and LF from S.
   function Trim (S : String) return String is
      F, L : Natural;
   begin
      F := S'First;
      while F <= S'Last loop
         exit when
           S (F) /= ' '
           and then S (F) /= ASCII.HT
           and then S (F) /= ASCII.CR
           and then S (F) /= ASCII.LF;
         F := F + 1;
      end loop;
      L := S'Last;
      while L >= F loop
         exit when
           S (L) /= ' '
           and then S (L) /= ASCII.HT
           and then S (L) /= ASCII.CR
           and then S (L) /= ASCII.LF;
         L := L - 1;
      end loop;
      if F > L then
         return "";
      end if;
      return S (F .. L);
   end Trim;

   --  True when the trimmed line looks like a comment: it begins with a
   --  recognised comment prefix (--, #, //, /*, *, <!--, .., ;, ', ", or
   --  {%).  A Markdown ATX heading (a bare '# title') is not a comment:
   --  the prefix must be followed by a space or the end of the line.
   function Is_Comment_Line (T : String) return Boolean is
   begin
      if T'Length = 0 then
         return False;
      end if;
      if T'Length >= 2 and then T (T'First .. T'First + 1) = "--" then
         return True;
      end if;
      if T (T'First) = '#' then
         --  A shebang (#!) is a comment line; any other non-space '#...'
         --  (for example a Markdown ATX heading) is content, not a comment.
         return
           T'Length = 1
           or else T (T'First + 1) = ' '
           or else T (T'First + 1) = '!';
      end if;
      if T'Length >= 2 and then T (T'First .. T'First + 1) = "//" then
         return True;
      end if;
      if T'Length >= 2 and then T (T'First .. T'First + 1) = "/*" then
         return True;
      end if;
      if T (T'First) = '*'
        or else T (T'First) = ';'
        or else T (T'First) = '''
        or else T (T'First) = '"'
        or else T (T'First) = '{'
      then
         return True;
      end if;
      if T'Length >= 4 and then T (T'First .. T'First + 3) = "<!--" then
         return True;
      end if;
      if T'Length >= 2 and then T (T'First .. T'First + 1) = ".." then
         return True;
      end if;
      return False;
   end Is_Comment_Line;

   --  True when the trimmed comment line T carries Token as a standalone
   --  directive: the token appears (case-insensitively) and everything
   --  before and after it is comment decoration only -- spaces, the comment
   --  prefix (--, #, //, <!--, ...), and its closer (-->), but no letters
   --  or digits.  A prose line that merely *mentions* a marker (for example
   --  this unit's own header documentation, or a docs page explaining the
   --  markers) therefore never opts the file out; the marker must sit on a
   --  comment line of its own.
   function Is_Directive_Line (T : String; Token : String) return Boolean is
      function Is_Alnum (C : Character) return Boolean is
      begin
         return C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9';
      end Is_Alnum;
   begin
      if Token'Length = 0 or else T'Length < Token'Length then
         return False;
      end if;
      for I in T'First .. T'Last - Token'Length + 1 loop
         declare
            Match : Boolean := True;
            Clean : Boolean := True;
         begin
            for J in Token'Range loop
               if To_Lower (T (I + (J - Token'First))) /= To_Lower (Token (J))
               then
                  Match := False;
                  exit;
               end if;
            end loop;
            if Match then
               for K in T'First .. I - 1 loop
                  if Is_Alnum (T (K)) then
                     Clean := False;
                     exit;
                  end if;
               end loop;
               if Clean then
                  for K in I + Token'Length .. T'Last loop
                     if Is_Alnum (T (K)) then
                        Clean := False;
                        exit;
                     end if;
                  end loop;
               end if;
               if Clean then
                  return True;
               end if;
            end if;
         end;
      end loop;
      return False;
   end Is_Directive_Line;

   function File_Opts_Out (Path : String; G : Gate) return Boolean is
      use Ada.Text_IO;
      F     : File_Type;
      Line  : String (1 .. 512);
      Last  : Natural;
      Read  : Natural := 0;
      Found : Boolean := False;
   begin
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return False;
      end;

      begin
         while not End_Of_File (F) and then Read < Max_Header_Lines loop
            Get_Line (F, Line, Last);
            Read := Read + 1;
            declare
               T : constant String := Trim (Line (1 .. Last));
            begin
               if T'Length = 0 then
                  null;
               elsif Is_Comment_Line (T) then
                  if Is_Directive_Line (T, "no-covex-analysis")
                    or else (G = Complexity_Scan
                             and then Is_Directive_Line
                                        (T, "no-covex-complexity-scan"))
                    or else (G = Docstrings
                             and then Is_Directive_Line
                                        (T, "no-covex-docstrings"))
                    or else (G = SPARK_Proof
                             and then Is_Directive_Line
                                        (T, "no-covex-spark-proof"))
                  then
                     Found := True;
                     exit;
                  end if;
               else
                  --  The first non-comment, non-blank line ends the header
                  --  block: prose and code below it never count.
                  exit;
               end if;
            end;
         end loop;
      exception
         when others =>
            null;
      end;
      if Is_Open (F) then
         Close (F);
      end if;
      return Found;
   end File_Opts_Out;

end Adacovex.Opt_Outs;
