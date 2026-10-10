with Ada.Text_IO;
with Adacovex.Paths;

package body Adacovex.Parsers is

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (2 .. S'Last);
   end Img;

   procedure Read_Line
     (F         : in out Ada.Text_IO.File_Type;
      File_Path : String;
      Line_Num  : Natural;
      Line      : out String;
      Last      : out Natural;
      Overflow  : out Boolean)
   is
      use Ada.Text_IO;
      Drain : String (1 .. Line'Length);
      DLast : Natural;
   begin
      Get_Line (F, Line, Last);
      Overflow := False;
      if Last = Line'Last and then not End_Of_File (F) then
         if not End_Of_Line (F) then
            Overflow := True;
            loop
               exit when End_Of_File (F);
               Get_Line (F, Drain, DLast);
               exit when DLast < Line'Length;
            end loop;
         else
            --  The line exactly fills the buffer. Get_Line stops at the
            --  buffer bound and leaves the line terminator pending, so the
            --  next Get_Line would report a spurious empty line (and shift
            --  every later line number). Consume the terminator now: the
            --  reader is then positioned at the next physical line, exactly
            --  as it is after a drain.
            Skip_Line (F);
         end if;
      end if;
      if Overflow then
         declare
            --  Built only when the line is overlong: the normal read path
            --  allocates no diagnostic string.
            Loc : constant String :=
              Adacovex.Paths.Display (File_Path)
              & (if Line_Num > 0 then ":" & Img (Line_Num) else "");
         begin
            Put_Line
              (Standard_Error,
               "Error: "
               & Loc
               & ": line exceeds Max_Line buffer ("
               & Img (Line'Length)
               & " bytes)");
         end;
      end if;
   end Read_Line;

end Adacovex.Parsers;
